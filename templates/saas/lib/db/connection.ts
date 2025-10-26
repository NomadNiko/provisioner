// Re-export MongoDB connection for backwards compatibility
export { connectDB, disconnectDB, isHealthy, getConnectionInfo, withTransaction, mongoose } from './mongodb/connection';
