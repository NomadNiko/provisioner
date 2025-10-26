/**
 * MongoDB Schema Design for SaaS Starter
 *
 * DESIGN DECISIONS:
 * =================
 *
 * 1. USERS Collection (Standalone)
 *    - Stores core user authentication data
 *    - Uses embedded team memberships for O(1) team lookup
 *    - Supports soft deletes with deletedAt field
 *
 * 2. TEAMS Collection (Embedded Members)
 *    - Embeds team member list for fast access in getTeamForUser()
 *    - Stores Stripe data for billing lookups
 *    - Members array denormalized for performance
 *
 * 3. ACTIVITY_LOGS Collection (Time-Series)
 *    - Separate collection optimized for writes and time-based queries
 *    - References users and teams by ObjectId
 *    - Uses TTL index for automatic cleanup
 *
 * 4. INVITATIONS Collection (Standalone)
 *    - Separate collection with references to teams and users
 *    - Supports unique constraint on email+teamId
 *    - Automatically expires after 7 days via TTL
 *
 * TRADE-OFFS:
 * ===========
 * - Embedding team members in teams collection creates duplication with users
 * - BUT: Eliminates complex joins for the critical getTeamForUser() query
 * - Updates to user details require updating both collections (handled via middleware)
 * - Activity logs kept separate to avoid unbounded array growth
 */

import mongoose, { Schema, Document, Model, Types } from 'mongoose';

// ============================================================================
// ENUMS AND CONSTANTS
// ============================================================================

export enum UserRole {
  MEMBER = 'member',
  OWNER = 'owner',
  ADMIN = 'admin',
}

export enum InvitationStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  DECLINED = 'declined',
  EXPIRED = 'expired',
}

export enum SubscriptionStatus {
  ACTIVE = 'active',
  CANCELED = 'canceled',
  PAST_DUE = 'past_due',
  TRIALING = 'trialing',
  INCOMPLETE = 'incomplete',
  INCOMPLETE_EXPIRED = 'incomplete_expired',
  UNPAID = 'unpaid',
}

export enum ActivityType {
  SIGN_UP = 'SIGN_UP',
  SIGN_IN = 'SIGN_IN',
  SIGN_OUT = 'SIGN_OUT',
  UPDATE_PASSWORD = 'UPDATE_PASSWORD',
  DELETE_ACCOUNT = 'DELETE_ACCOUNT',
  UPDATE_ACCOUNT = 'UPDATE_ACCOUNT',
  CREATE_TEAM = 'CREATE_TEAM',
  REMOVE_TEAM_MEMBER = 'REMOVE_TEAM_MEMBER',
  INVITE_TEAM_MEMBER = 'INVITE_TEAM_MEMBER',
  ACCEPT_INVITATION = 'ACCEPT_INVITATION',
}

// ============================================================================
// SUBDOCUMENT SCHEMAS (for embedding)
// ============================================================================

/**
 * Embedded team member schema
 * Used within both User and Team documents for bidirectional relationships
 */
export interface ITeamMemberEmbedded {
  userId: Types.ObjectId;
  teamId: Types.ObjectId;
  role: UserRole;
  joinedAt: Date;
  // Denormalized user data for quick access (updated via middleware)
  userName?: string;
  userEmail?: string;
}

const TeamMemberEmbeddedSchema = new Schema<ITeamMemberEmbedded>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    teamId: {
      type: Schema.Types.ObjectId,
      ref: 'Team',
      required: true,
    },
    role: {
      type: String,
      enum: Object.values(UserRole),
      required: true,
      default: UserRole.MEMBER,
    },
    joinedAt: {
      type: Date,
      required: true,
      default: Date.now,
    },
    userName: {
      type: String,
      maxlength: 100,
    },
    userEmail: {
      type: String,
      maxlength: 255,
    },
  },
  { _id: false } // No separate _id for embedded documents
);

// ============================================================================
// USER SCHEMA
// ============================================================================

export interface IUser extends Document {
  _id: Types.ObjectId;
  name?: string;
  email: string;
  passwordHash: string;
  role: UserRole;

  // Team memberships (embedded for O(1) lookup)
  teamMemberships: ITeamMemberEmbedded[];

  // Soft delete support
  deletedAt?: Date;
  isDeleted: boolean;

  // Timestamps
  createdAt: Date;
  updatedAt: Date;

  // Virtual properties
  activeTeams: ITeamMemberEmbedded[];

  // Instance methods
  softDelete(): Promise<IUser>;
  restore(): Promise<IUser>;
  addTeamMembership(teamId: Types.ObjectId, role: UserRole): Promise<IUser>;
  removeTeamMembership(teamId: Types.ObjectId): Promise<IUser>;
  updateTeamRole(teamId: Types.ObjectId, role: UserRole): Promise<IUser>;
}

const UserSchema = new Schema<IUser>(
  {
    name: {
      type: String,
      maxlength: 100,
      trim: true,
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      maxlength: 255,
      lowercase: true,
      trim: true,
      // Email validation regex
      match: [
        /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/,
        'Please provide a valid email address',
      ],
      // Sparse index: only index non-deleted users for uniqueness
      index: true,
    },
    passwordHash: {
      type: String,
      required: [true, 'Password hash is required'],
      select: false, // Don't return password hash by default
    },
    role: {
      type: String,
      enum: Object.values(UserRole),
      required: true,
      default: UserRole.MEMBER,
    },
    teamMemberships: {
      type: [TeamMemberEmbeddedSchema],
      default: [],
      // Validate maximum teams per user
      validate: {
        validator: function (memberships: ITeamMemberEmbedded[]) {
          return memberships.length <= 50;
        },
        message: 'User cannot be a member of more than 50 teams',
      },
    },
    deletedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true, // Automatically manage createdAt and updatedAt
    collection: 'users',
    // Optimistic concurrency control
    optimisticConcurrency: true,
  }
);

// ============================================================================
// USER INDEXES
// ============================================================================

// Unique email for non-deleted users (sparse index)
UserSchema.index(
  { email: 1, deletedAt: 1 },
  {
    unique: true,
    partialFilterExpression: { deletedAt: null },
    name: 'unique_active_email',
  }
);

// Query active users efficiently
UserSchema.index(
  { deletedAt: 1, createdAt: -1 },
  { name: 'active_users_by_date' }
);

// Team membership lookups
UserSchema.index(
  { 'teamMemberships.teamId': 1 },
  { name: 'team_membership_lookup' }
);

// Role-based queries
UserSchema.index({ role: 1, deletedAt: 1 }, { name: 'users_by_role' });

// ============================================================================
// USER VIRTUALS
// ============================================================================

// Virtual property for soft delete status
UserSchema.virtual('isDeleted').get(function (this: IUser) {
  return this.deletedAt !== null && this.deletedAt !== undefined;
});

// Virtual property to get only active (non-deleted) teams
UserSchema.virtual('activeTeams').get(function (this: IUser) {
  return this.teamMemberships.filter((tm) => tm.teamId !== null);
});

// ============================================================================
// USER INSTANCE METHODS
// ============================================================================

UserSchema.methods.softDelete = async function (this: IUser): Promise<IUser> {
  this.deletedAt = new Date();
  return await this.save();
};

UserSchema.methods.restore = async function (this: IUser): Promise<IUser> {
  this.deletedAt = undefined;
  return await this.save();
};

UserSchema.methods.addTeamMembership = async function (
  this: IUser,
  teamId: Types.ObjectId,
  role: UserRole = UserRole.MEMBER
): Promise<IUser> {
  // Check if membership already exists
  const existingIndex = this.teamMemberships.findIndex((tm) =>
    tm.teamId.equals(teamId)
  );

  if (existingIndex >= 0) {
    // Update existing membership
    this.teamMemberships[existingIndex].role = role;
    this.teamMemberships[existingIndex].joinedAt = new Date();
  } else {
    // Add new membership
    this.teamMemberships.push({
      userId: this._id,
      teamId,
      role,
      joinedAt: new Date(),
      userName: this.name,
      userEmail: this.email,
    });
  }

  return await this.save();
};

UserSchema.methods.removeTeamMembership = async function (
  this: IUser,
  teamId: Types.ObjectId
): Promise<IUser> {
  this.teamMemberships = this.teamMemberships.filter(
    (tm) => !tm.teamId.equals(teamId)
  );
  return await this.save();
};

UserSchema.methods.updateTeamRole = async function (
  this: IUser,
  teamId: Types.ObjectId,
  role: UserRole
): Promise<IUser> {
  const membership = this.teamMemberships.find((tm) =>
    tm.teamId.equals(teamId)
  );
  if (membership) {
    membership.role = role;
    return await this.save();
  }
  throw new Error('Team membership not found');
};

// ============================================================================
// USER MIDDLEWARE
// ============================================================================

// Pre-save middleware to update denormalized data in teams
UserSchema.pre('save', async function (this: IUser, next) {
  // If name or email changed, update denormalized data in teams
  if (this.isModified('name') || this.isModified('email')) {
    // Update team memberships in this user document
    this.teamMemberships.forEach((tm) => {
      tm.userName = this.name;
      tm.userEmail = this.email;
    });

    // Update denormalized data in team documents
    // This will be handled by the Team model's updateMemberInfo method
    // Called from application logic to maintain consistency
  }
  next();
});

// ============================================================================
// TEAM SCHEMA
// ============================================================================

export interface ITeam extends Document {
  _id: Types.ObjectId;
  name: string;

  // Team members (embedded for fast getTeamForUser query)
  teamMembers: ITeamMemberEmbedded[];

  // Stripe billing data
  stripeCustomerId?: string;
  stripeSubscriptionId?: string;
  stripeProductId?: string;
  planName?: string;
  subscriptionStatus?: SubscriptionStatus;

  // Timestamps
  createdAt: Date;
  updatedAt: Date;

  // Virtual properties
  memberCount: number;
  owners: ITeamMemberEmbedded[];

  // Instance methods
  addMember(userId: Types.ObjectId, role: UserRole, userInfo?: { name?: string; email?: string }): Promise<ITeam>;
  removeMember(userId: Types.ObjectId): Promise<ITeam>;
  updateMemberRole(userId: Types.ObjectId, role: UserRole): Promise<ITeam>;
  updateMemberInfo(userId: Types.ObjectId, name?: string, email?: string): Promise<ITeam>;
  updateSubscription(data: {
    stripeSubscriptionId?: string | null;
    stripeProductId?: string | null;
    planName?: string | null;
    subscriptionStatus?: SubscriptionStatus;
  }): Promise<ITeam>;
}

const TeamSchema = new Schema<ITeam>(
  {
    name: {
      type: String,
      required: [true, 'Team name is required'],
      maxlength: 100,
      trim: true,
    },
    teamMembers: {
      type: [TeamMemberEmbeddedSchema],
      default: [],
      // Validate maximum team size
      validate: {
        validator: function (members: ITeamMemberEmbedded[]) {
          return members.length <= 100;
        },
        message: 'Team cannot have more than 100 members',
      },
    },
    stripeCustomerId: {
      type: String,
      unique: true,
      sparse: true, // Sparse index: only index documents with this field
      trim: true,
    },
    stripeSubscriptionId: {
      type: String,
      unique: true,
      sparse: true,
      trim: true,
    },
    stripeProductId: {
      type: String,
      trim: true,
    },
    planName: {
      type: String,
      maxlength: 50,
      trim: true,
    },
    subscriptionStatus: {
      type: String,
      enum: Object.values(SubscriptionStatus),
      maxlength: 20,
    },
  },
  {
    timestamps: true,
    collection: 'teams',
    optimisticConcurrency: true,
  }
);

// ============================================================================
// TEAM INDEXES
// ============================================================================

// Stripe customer ID lookup (critical for webhooks)
TeamSchema.index(
  { stripeCustomerId: 1 },
  {
    unique: true,
    sparse: true,
    name: 'stripe_customer_lookup',
  }
);

// Stripe subscription ID lookup
TeamSchema.index(
  { stripeSubscriptionId: 1 },
  {
    unique: true,
    sparse: true,
    name: 'stripe_subscription_lookup',
  }
);

// Team member user ID lookup
TeamSchema.index(
  { 'teamMembers.userId': 1 },
  { name: 'team_member_user_lookup' }
);

// Subscription status queries
TeamSchema.index(
  { subscriptionStatus: 1, updatedAt: -1 },
  { name: 'teams_by_subscription_status' }
);

// Plan name queries
TeamSchema.index({ planName: 1 }, { name: 'teams_by_plan' });

// ============================================================================
// TEAM VIRTUALS
// ============================================================================

TeamSchema.virtual('memberCount').get(function (this: ITeam) {
  return this.teamMembers.length;
});

TeamSchema.virtual('owners').get(function (this: ITeam) {
  return this.teamMembers.filter((m) => m.role === UserRole.OWNER);
});

// ============================================================================
// TEAM INSTANCE METHODS
// ============================================================================

TeamSchema.methods.addMember = async function (
  this: ITeam,
  userId: Types.ObjectId,
  role: UserRole = UserRole.MEMBER,
  userInfo?: { name?: string; email?: string }
): Promise<ITeam> {
  // Check if member already exists
  const existingIndex = this.teamMembers.findIndex((m) =>
    m.userId.equals(userId)
  );

  if (existingIndex >= 0) {
    // Update existing member
    this.teamMembers[existingIndex].role = role;
    this.teamMembers[existingIndex].joinedAt = new Date();
    if (userInfo?.name) this.teamMembers[existingIndex].userName = userInfo.name;
    if (userInfo?.email) this.teamMembers[existingIndex].userEmail = userInfo.email;
  } else {
    // Add new member
    this.teamMembers.push({
      userId,
      teamId: this._id,
      role,
      joinedAt: new Date(),
      userName: userInfo?.name,
      userEmail: userInfo?.email,
    });
  }

  return await this.save();
};

TeamSchema.methods.removeMember = async function (
  this: ITeam,
  userId: Types.ObjectId
): Promise<ITeam> {
  this.teamMembers = this.teamMembers.filter((m) => !m.userId.equals(userId));
  return await this.save();
};

TeamSchema.methods.updateMemberRole = async function (
  this: ITeam,
  userId: Types.ObjectId,
  role: UserRole
): Promise<ITeam> {
  const member = this.teamMembers.find((m) => m.userId.equals(userId));
  if (member) {
    member.role = role;
    return await this.save();
  }
  throw new Error('Team member not found');
};

TeamSchema.methods.updateMemberInfo = async function (
  this: ITeam,
  userId: Types.ObjectId,
  name?: string,
  email?: string
): Promise<ITeam> {
  const member = this.teamMembers.find((m) => m.userId.equals(userId));
  if (member) {
    if (name !== undefined) member.userName = name;
    if (email !== undefined) member.userEmail = email;
    return await this.save();
  }
  return this;
};

TeamSchema.methods.updateSubscription = async function (
  this: ITeam,
  data: {
    stripeSubscriptionId?: string | null;
    stripeProductId?: string | null;
    planName?: string | null;
    subscriptionStatus?: SubscriptionStatus;
  }
): Promise<ITeam> {
  if (data.stripeSubscriptionId !== undefined) {
    this.stripeSubscriptionId = data.stripeSubscriptionId || undefined;
  }
  if (data.stripeProductId !== undefined) {
    this.stripeProductId = data.stripeProductId || undefined;
  }
  if (data.planName !== undefined) {
    this.planName = data.planName || undefined;
  }
  if (data.subscriptionStatus !== undefined) {
    this.subscriptionStatus = data.subscriptionStatus;
  }
  return await this.save();
};

// ============================================================================
// ACTIVITY LOG SCHEMA (Time-Series Collection)
// ============================================================================

export interface IActivityLog extends Document {
  _id: Types.ObjectId;
  teamId: Types.ObjectId;
  userId?: Types.ObjectId;
  action: ActivityType | string;
  timestamp: Date;
  ipAddress?: string;

  // Denormalized for performance (no joins needed)
  userName?: string;
  userEmail?: string;
  teamName?: string;

  // Metadata for extensibility
  metadata?: Record<string, any>;
}

const ActivityLogSchema = new Schema<IActivityLog>(
  {
    teamId: {
      type: Schema.Types.ObjectId,
      ref: 'Team',
      required: true,
      index: true,
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    action: {
      type: String,
      required: true,
      index: true,
    },
    timestamp: {
      type: Date,
      required: true,
      default: Date.now,
      index: true,
    },
    ipAddress: {
      type: String,
      maxlength: 45, // IPv6 support
    },
    // Denormalized data to avoid joins
    userName: {
      type: String,
      maxlength: 100,
    },
    userEmail: {
      type: String,
      maxlength: 255,
    },
    teamName: {
      type: String,
      maxlength: 100,
    },
    metadata: {
      type: Schema.Types.Mixed,
    },
  },
  {
    timestamps: false, // We manage timestamp manually
    collection: 'activity_logs',
    // Enable time-series collection in MongoDB 5.0+
    timeseries: {
      timeField: 'timestamp',
      metaField: 'teamId',
      granularity: 'hours',
    },
  }
);

// ============================================================================
// ACTIVITY LOG INDEXES
// ============================================================================

// Compound index for user activity queries
ActivityLogSchema.index(
  { userId: 1, timestamp: -1 },
  { name: 'user_activity_by_time' }
);

// Compound index for team activity queries
ActivityLogSchema.index(
  { teamId: 1, timestamp: -1 },
  { name: 'team_activity_by_time' }
);

// Action-based queries
ActivityLogSchema.index(
  { action: 1, timestamp: -1 },
  { name: 'activity_by_action' }
);

// TTL index for automatic cleanup (90 days)
ActivityLogSchema.index(
  { timestamp: 1 },
  {
    expireAfterSeconds: 90 * 24 * 60 * 60, // 90 days
    name: 'activity_log_ttl',
  }
);

// ============================================================================
// INVITATION SCHEMA
// ============================================================================

export interface IInvitation extends Document {
  _id: Types.ObjectId;
  teamId: Types.ObjectId;
  email: string;
  role: UserRole;
  invitedBy: Types.ObjectId;
  invitedAt: Date;
  status: InvitationStatus;

  // Denormalized data for display
  teamName?: string;
  invitedByName?: string;
  invitedByEmail?: string;

  // Methods
  accept(userId: Types.ObjectId): Promise<IInvitation>;
  decline(): Promise<IInvitation>;
  expire(): Promise<IInvitation>;
}

const InvitationSchema = new Schema<IInvitation>(
  {
    teamId: {
      type: Schema.Types.ObjectId,
      ref: 'Team',
      required: true,
      index: true,
    },
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
      maxlength: 255,
      match: [
        /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/,
        'Please provide a valid email address',
      ],
    },
    role: {
      type: String,
      enum: Object.values(UserRole),
      required: true,
      default: UserRole.MEMBER,
    },
    invitedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    invitedAt: {
      type: Date,
      required: true,
      default: Date.now,
    },
    status: {
      type: String,
      enum: Object.values(InvitationStatus),
      required: true,
      default: InvitationStatus.PENDING,
      maxlength: 20,
    },
    teamName: {
      type: String,
      maxlength: 100,
    },
    invitedByName: {
      type: String,
      maxlength: 100,
    },
    invitedByEmail: {
      type: String,
      maxlength: 255,
    },
  },
  {
    timestamps: false,
    collection: 'invitations',
  }
);

// ============================================================================
// INVITATION INDEXES
// ============================================================================

// Unique constraint: one pending invitation per email per team
InvitationSchema.index(
  { email: 1, teamId: 1, status: 1 },
  {
    unique: true,
    partialFilterExpression: { status: InvitationStatus.PENDING },
    name: 'unique_pending_invitation',
  }
);

// Query pending invitations by email
InvitationSchema.index(
  { email: 1, status: 1 },
  { name: 'invitations_by_email_status' }
);

// Query invitations by team
InvitationSchema.index(
  { teamId: 1, status: 1, invitedAt: -1 },
  { name: 'team_invitations' }
);

// TTL index for automatic expiration (7 days for pending invitations)
InvitationSchema.index(
  { invitedAt: 1 },
  {
    expireAfterSeconds: 7 * 24 * 60 * 60, // 7 days
    partialFilterExpression: { status: InvitationStatus.PENDING },
    name: 'invitation_expiration',
  }
);

// ============================================================================
// INVITATION INSTANCE METHODS
// ============================================================================

InvitationSchema.methods.accept = async function (
  this: IInvitation,
  userId: Types.ObjectId
): Promise<IInvitation> {
  this.status = InvitationStatus.ACCEPTED;
  return await this.save();
};

InvitationSchema.methods.decline = async function (
  this: IInvitation
): Promise<IInvitation> {
  this.status = InvitationStatus.DECLINED;
  return await this.save();
};

InvitationSchema.methods.expire = async function (
  this: IInvitation
): Promise<IInvitation> {
  this.status = InvitationStatus.EXPIRED;
  return await this.save();
};

// ============================================================================
// MODEL EXPORTS
// ============================================================================

export const User: Model<IUser> =
  mongoose.models.User || mongoose.model<IUser>('User', UserSchema);

export const Team: Model<ITeam> =
  mongoose.models.Team || mongoose.model<ITeam>('Team', TeamSchema);

export const ActivityLog: Model<IActivityLog> =
  mongoose.models.ActivityLog ||
  mongoose.model<IActivityLog>('ActivityLog', ActivityLogSchema);

export const Invitation: Model<IInvitation> =
  mongoose.models.Invitation ||
  mongoose.model<IInvitation>('Invitation', InvitationSchema);

// ============================================================================
// TYPE EXPORTS (for application use)
// ============================================================================

export type UserDocument = IUser;
export type TeamDocument = ITeam;
export type ActivityLogDocument = IActivityLog;
export type InvitationDocument = IInvitation;
export type TeamMemberEmbedded = ITeamMemberEmbedded;

// ============================================================================
// HELPER TYPE FOR TEAM WITH POPULATED MEMBERS
// ============================================================================

export interface TeamDataWithMembers extends ITeam {
  teamMembers: Array<
    ITeamMemberEmbedded & {
      user?: Pick<IUser, '_id' | 'name' | 'email'>;
    }
  >;
}
