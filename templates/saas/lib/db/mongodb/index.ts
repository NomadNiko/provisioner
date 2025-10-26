/**
 * MongoDB Database Layer - Main Export
 *
 * This is the main entry point for the MongoDB database layer.
 * Import everything you need from this file.
 *
 * @example
 * ```typescript
 * import { connectDB, User, Team, getUser, createTeam } from '@/lib/db/mongodb';
 * ```
 */

// Connection utilities
export {
  connectDB,
  disconnectDB,
  isHealthy,
  getConnectionInfo,
  withTransaction,
  mongoose,
} from './connection';

// Schemas and models
export {
  User,
  Team,
  ActivityLog,
  Invitation,
  UserRole,
  InvitationStatus,
  SubscriptionStatus,
  ActivityType,
} from './schema';

// TypeScript types
export type {
  IUser,
  ITeam,
  IActivityLog,
  IInvitation,
  ITeamMemberEmbedded,
  UserDocument,
  TeamDocument,
  ActivityLogDocument,
  InvitationDocument,
  TeamMemberEmbedded,
  TeamDataWithMembers,
} from './schema';

// Query functions
export {
  // Authentication
  getUser,
  getUserByEmail,
  getUserById,
  // Teams
  getTeamById,
  getTeamByStripeCustomerId,
  getTeamForUser,
  getTeamsForUser,
  getUserWithTeam,
  updateTeamSubscription,
  // Activity logs
  getActivityLogs,
  getTeamActivityLogs,
  createActivityLog,
  // Invitations
  getInvitationByEmail,
  getPendingInvitationsForEmail,
  getTeamInvitations,
  createInvitation,
  acceptInvitation,
  // User mutations
  createUser,
  updateUser,
  softDeleteUser,
  // Team mutations
  createTeam,
  addTeamMember,
  removeTeamMember,
} from './queries';

// Re-export types for query results
export type { UserWithTeamId, ActivityLogWithUser } from './queries';

// Serialization utilities for Next.js Client Components
export { serialize, serializeArray, serializeDocument } from './serialize';

// MongoDB-specific types for convenience
export { Types } from 'mongoose';
