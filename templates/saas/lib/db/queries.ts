// Re-export MongoDB queries for backwards compatibility
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
  // Admin queries
  getAllUsersForAdmin,
  getAllTeamsForAdmin,
  getAdminStats,
} from './mongodb/queries';

// Re-export types for query results
export type { UserWithTeamId, ActivityLogWithUser } from './mongodb/queries';
