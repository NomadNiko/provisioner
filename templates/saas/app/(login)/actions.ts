'use server';

import { z } from 'zod';
import { Types } from 'mongoose';
import {
  ActivityType,
  UserRole,
  connectDB,
  User,
  Team,
  Invitation,
  InvitationStatus,
  createActivityLog,
  getUserByEmail,
  getUser,
  getUserWithTeam,
  createUser,
  createTeam,
  addTeamMember,
  removeTeamMember as removeTeamMemberDB,
  updateUser,
  softDeleteUser,
  getInvitationByEmail,
  createInvitation,
  acceptInvitation,
  getTeamForUser,
  type IUser,
  type ITeam,
} from '@/lib/db/mongodb';
import { comparePasswords, hashPassword, setSession } from '@/lib/auth/session';
import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';
import { createCheckoutSession } from '@/lib/payments/stripe';
import {
  validatedAction,
  validatedActionWithUser
} from '@/lib/auth/middleware';

async function logActivity(
  teamId: string | Types.ObjectId | null | undefined,
  userId: string | Types.ObjectId,
  type: ActivityType,
  ipAddress?: string
) {
  if (!teamId) {
    return;
  }

  try {
    await createActivityLog({
      teamId,
      userId,
      action: type,
      ipAddress: ipAddress || ''
    });
  } catch (error) {
    console.error('Failed to log activity:', error);
  }
}

const signInSchema = z.object({
  email: z.string().email().min(3).max(255),
  password: z.string().min(8).max(100)
});

export const signIn = validatedAction(signInSchema, async (data, formData) => {
  const { email, password } = data;

  await connectDB();

  // Get user with password hash
  const foundUser = await getUserByEmail(email, true);

  if (!foundUser) {
    return {
      error: 'Invalid email or password. Please try again.',
      email,
      password
    };
  }

  const isPasswordValid = await comparePasswords(
    password,
    foundUser.passwordHash
  );

  if (!isPasswordValid) {
    return {
      error: 'Invalid email or password. Please try again.',
      email,
      password
    };
  }

  // Get user's team
  const teamId = foundUser.teamMemberships && foundUser.teamMemberships.length > 0
    ? foundUser.teamMemberships[0].teamId
    : null;

  let foundTeam: ITeam | null = null;
  if (teamId) {
    foundTeam = await Team.findById(teamId).lean<ITeam>().exec();
  }

  await Promise.all([
    setSession(foundUser),
    logActivity(teamId, foundUser._id, ActivityType.SIGN_IN)
  ]);

  const redirectTo = formData.get('redirect') as string | null;
  if (redirectTo === 'checkout') {
    const priceId = formData.get('priceId') as string;
    return createCheckoutSession({ team: foundTeam, priceId });
  }

  // Redirect admin users to admin panel, regular users to dashboard
  redirect(foundUser.role === 'admin' ? '/admin' : '/dashboard');
});

const signUpSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  inviteId: z.string().optional()
});

export const signUp = validatedAction(signUpSchema, async (data, formData) => {
  const { email, password, inviteId } = data;

  await connectDB();

  // Check if user already exists
  const existingUser = await getUserByEmail(email);

  if (existingUser) {
    return {
      error: 'Failed to create user. Please try again.',
      email,
      password
    };
  }

  const passwordHash = await hashPassword(password);

  // Create user
  const createdUser = await createUser({
    email,
    passwordHash,
    role: UserRole.OWNER // Default role, will be overridden if there's an invitation
  });

  if (!createdUser) {
    return {
      error: 'Failed to create user. Please try again.',
      email,
      password
    };
  }

  let teamId: Types.ObjectId;
  let userRole: UserRole;
  let createdTeam: ITeam | null = null;

  if (inviteId) {
    // Check if there's a valid invitation
    const invitation = await Invitation.findOne({
      _id: new Types.ObjectId(inviteId),
      email: email.toLowerCase(),
      status: InvitationStatus.PENDING
    }).lean().exec();

    if (invitation) {
      teamId = invitation.teamId;
      userRole = invitation.role;

      // Accept the invitation (adds user to team)
      await acceptInvitation(invitation._id, createdUser._id);

      await logActivity(teamId, createdUser._id, ActivityType.ACCEPT_INVITATION);

      createdTeam = await Team.findById(teamId).lean<ITeam>().exec();
    } else {
      return { error: 'Invalid or expired invitation.', email, password };
    }
  } else {
    // Create a new team if there's no invitation
    createdTeam = await createTeam({
      name: `${email}'s Team`
    });

    if (!createdTeam) {
      return {
        error: 'Failed to create team. Please try again.',
        email,
        password
      };
    }

    teamId = createdTeam._id;
    userRole = UserRole.OWNER;

    // Add user to team
    await addTeamMember(teamId, createdUser._id, userRole);

    await logActivity(teamId, createdUser._id, ActivityType.CREATE_TEAM);
  }

  await Promise.all([
    logActivity(teamId, createdUser._id, ActivityType.SIGN_UP),
    setSession(createdUser)
  ]);

  const redirectTo = formData.get('redirect') as string | null;
  if (redirectTo === 'checkout') {
    const priceId = formData.get('priceId') as string;
    return createCheckoutSession({ team: createdTeam, priceId });
  }

  // Redirect admin users to admin panel, regular users to dashboard
  redirect(createdUser.role === 'admin' ? '/admin' : '/dashboard');
});

export async function signOut() {
  const user = await getUser();
  if (!user) {
    return;
  }

  const userWithTeam = await getUserWithTeam(user._id);
  await logActivity(userWithTeam?.teamId, user._id, ActivityType.SIGN_OUT);
  (await cookies()).delete('session');
}

const updatePasswordSchema = z.object({
  currentPassword: z.string().min(8).max(100),
  newPassword: z.string().min(8).max(100),
  confirmPassword: z.string().min(8).max(100)
});

export const updatePassword = validatedActionWithUser(
  updatePasswordSchema,
  async (data, _, user) => {
    const { currentPassword, newPassword, confirmPassword } = data;

    await connectDB();

    // Get user with password hash
    const userWithPassword = await User.findById(user._id)
      .select('+passwordHash')
      .lean()
      .exec();

    if (!userWithPassword) {
      return {
        currentPassword,
        newPassword,
        confirmPassword,
        error: 'User not found.'
      };
    }

    const isPasswordValid = await comparePasswords(
      currentPassword,
      userWithPassword.passwordHash
    );

    if (!isPasswordValid) {
      return {
        currentPassword,
        newPassword,
        confirmPassword,
        error: 'Current password is incorrect.'
      };
    }

    if (currentPassword === newPassword) {
      return {
        currentPassword,
        newPassword,
        confirmPassword,
        error: 'New password must be different from the current password.'
      };
    }

    if (confirmPassword !== newPassword) {
      return {
        currentPassword,
        newPassword,
        confirmPassword,
        error: 'New password and confirmation password do not match.'
      };
    }

    const newPasswordHash = await hashPassword(newPassword);
    const userWithTeam = await getUserWithTeam(user._id);

    await Promise.all([
      User.findByIdAndUpdate(user._id, {
        $set: { passwordHash: newPasswordHash, updatedAt: new Date() }
      }).exec(),
      logActivity(userWithTeam?.teamId, user._id, ActivityType.UPDATE_PASSWORD)
    ]);

    return {
      success: 'Password updated successfully.'
    };
  }
);

const deleteAccountSchema = z.object({
  password: z.string().min(8).max(100)
});

export const deleteAccount = validatedActionWithUser(
  deleteAccountSchema,
  async (data, _, user) => {
    const { password } = data;

    await connectDB();

    // Get user with password hash
    const userWithPassword = await User.findById(user._id)
      .select('+passwordHash')
      .lean()
      .exec();

    if (!userWithPassword) {
      return {
        password,
        error: 'User not found.'
      };
    }

    const isPasswordValid = await comparePasswords(password, userWithPassword.passwordHash);
    if (!isPasswordValid) {
      return {
        password,
        error: 'Incorrect password. Account deletion failed.'
      };
    }

    const userWithTeam = await getUserWithTeam(user._id);

    await logActivity(
      userWithTeam?.teamId,
      user._id,
      ActivityType.DELETE_ACCOUNT
    );

    // Soft delete user
    await softDeleteUser(user._id);

    // Remove from team
    if (userWithTeam?.teamId) {
      await removeTeamMemberDB(userWithTeam.teamId, user._id);
    }

    (await cookies()).delete('session');
    redirect('/sign-in');
  }
);

const updateAccountSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  email: z.string().email('Invalid email address')
});

export const updateAccount = validatedActionWithUser(
  updateAccountSchema,
  async (data, _, user) => {
    const { name, email } = data;

    await connectDB();

    const userWithTeam = await getUserWithTeam(user._id);

    await Promise.all([
      updateUser(user._id, { name, email }),
      logActivity(userWithTeam?.teamId, user._id, ActivityType.UPDATE_ACCOUNT)
    ]);

    return { name, success: 'Account updated successfully.' };
  }
);

const removeTeamMemberSchema = z.object({
  memberId: z.string() // Changed from number to string for ObjectId
});

export const removeTeamMember = validatedActionWithUser(
  removeTeamMemberSchema,
  async (data, _, user) => {
    const { memberId } = data;

    await connectDB();

    const userWithTeam = await getUserWithTeam(user._id);

    if (!userWithTeam?.teamId) {
      return { error: 'User is not part of a team' };
    }

    // Remove the member from the team
    await removeTeamMemberDB(userWithTeam.teamId, memberId);

    await logActivity(
      userWithTeam.teamId,
      user._id,
      ActivityType.REMOVE_TEAM_MEMBER
    );

    return { success: 'Team member removed successfully' };
  }
);

const inviteTeamMemberSchema = z.object({
  email: z.string().email('Invalid email address'),
  role: z.enum(['member', 'owner'])
});

export const inviteTeamMember = validatedActionWithUser(
  inviteTeamMemberSchema,
  async (data, _, user) => {
    const { email, role } = data;

    await connectDB();

    const userWithTeam = await getUserWithTeam(user._id);

    if (!userWithTeam?.teamId) {
      return { error: 'User is not part of a team' };
    }

    // Check if user is already a member
    const team = await Team.findById(userWithTeam.teamId).lean().exec();

    if (team && team.teamMembers) {
      const existingMember = team.teamMembers.find(
        m => m.userEmail?.toLowerCase() === email.toLowerCase()
      );

      if (existingMember) {
        return { error: 'User is already a member of this team' };
      }
    }

    // Check if there's an existing invitation
    const existingInvitation = await getInvitationByEmail(email, userWithTeam.teamId);

    if (existingInvitation) {
      return { error: 'An invitation has already been sent to this email' };
    }

    // Create a new invitation
    await createInvitation({
      teamId: userWithTeam.teamId,
      email,
      role: role === 'owner' ? UserRole.OWNER : UserRole.MEMBER,
      invitedBy: user._id
    });

    await logActivity(
      userWithTeam.teamId,
      user._id,
      ActivityType.INVITE_TEAM_MEMBER
    );

    // TODO: Send invitation email and include ?inviteId={id} to sign-up URL
    // await sendInvitationEmail(email, team.name, role)

    return { success: 'Invitation sent successfully' };
  }
);
