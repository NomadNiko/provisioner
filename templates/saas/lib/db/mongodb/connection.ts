/**
 * MongoDB Connection Manager
 *
 * FEATURES:
 * - Connection pooling with optimal settings
 * - Automatic reconnection on failure
 * - Connection monitoring and health checks
 * - Environment-based configuration
 * - TypeScript type safety
 */

import mongoose from 'mongoose';

// ============================================================================
// CONFIGURATION
// ============================================================================

const MONGODB_URI = process.env.MONGODB_URI || process.env.DATABASE_URL || '';

if (!MONGODB_URI) {
  throw new Error(
    'Please define the MONGODB_URI or DATABASE_URL environment variable inside .env'
  );
}

// Connection options optimized for Next.js and serverless environments
const options: mongoose.ConnectOptions = {
  // Connection pool settings
  maxPoolSize: 10, // Maximum number of connections in the pool
  minPoolSize: 2, // Minimum number of connections to maintain

  // Timeout settings
  serverSelectionTimeoutMS: 5000, // How long to wait for server selection
  socketTimeoutMS: 45000, // How long to wait for socket to timeout
  connectTimeoutMS: 10000, // How long to wait for initial connection

  // Retry settings
  retryWrites: true, // Retry write operations on failure
  retryReads: true, // Retry read operations on failure

  // Authentication and SSL
  authSource: 'admin', // Default auth database

  // Application name for monitoring
  appName: 'saas-starter',

  // Compression
  compressors: ['zlib'], // Enable compression for network traffic
  zlibCompressionLevel: 6, // Compression level (1-9)
};

// ============================================================================
// CONNECTION STATE
// ============================================================================

interface MongooseConnection {
  conn: typeof mongoose | null;
  promise: Promise<typeof mongoose> | null;
}

// Cache the database connection in development to prevent creating new connections
// on every hot-reload. In production, this helps with serverless function reuse.
declare global {
  var mongoose: MongooseConnection | undefined;
}

let cached: MongooseConnection = global.mongoose || { conn: null, promise: null };

if (!global.mongoose) {
  global.mongoose = cached;
}

// ============================================================================
// CONNECTION EVENTS
// ============================================================================

mongoose.connection.on('connected', () => {
  console.log('[MongoDB] Connected successfully');
});

mongoose.connection.on('error', (err) => {
  console.error('[MongoDB] Connection error:', err);
});

mongoose.connection.on('disconnected', () => {
  console.log('[MongoDB] Disconnected');
});

mongoose.connection.on('reconnected', () => {
  console.log('[MongoDB] Reconnected successfully');
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await mongoose.connection.close();
  console.log('[MongoDB] Connection closed due to application termination');
  process.exit(0);
});

// ============================================================================
// CONNECTION FUNCTION
// ============================================================================

/**
 * Connect to MongoDB with connection pooling and caching
 *
 * This function ensures that we reuse existing connections in serverless
 * environments and during development hot-reloads.
 *
 * @returns Promise<typeof mongoose> - Connected mongoose instance
 */
export async function connectDB(): Promise<typeof mongoose> {
  // If we have a cached connection, return it
  if (cached.conn) {
    return cached.conn;
  }

  // If we don't have a cached promise, create a new connection
  if (!cached.promise) {
    cached.promise = mongoose.connect(MONGODB_URI, options).then((mongoose) => {
      console.log('[MongoDB] New connection established');
      return mongoose;
    });
  }

  try {
    // Wait for the connection to be established
    cached.conn = await cached.promise;
  } catch (error) {
    // Reset the promise on error so we can retry
    cached.promise = null;
    console.error('[MongoDB] Failed to connect:', error);
    throw error;
  }

  return cached.conn;
}

// ============================================================================
// HEALTH CHECK
// ============================================================================

/**
 * Check if MongoDB connection is healthy
 *
 * @returns Promise<boolean> - True if connected and healthy
 */
export async function isHealthy(): Promise<boolean> {
  try {
    if (mongoose.connection.readyState !== 1) {
      return false;
    }

    // Ping the database
    if (!mongoose.connection.db) {
      return false;
    }
    await mongoose.connection.db.admin().ping();
    return true;
  } catch (error) {
    console.error('[MongoDB] Health check failed:', error);
    return false;
  }
}

// ============================================================================
// CONNECTION INFO
// ============================================================================

/**
 * Get current connection state information
 *
 * @returns Object with connection details
 */
export function getConnectionInfo() {
  const states = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
    99: 'uninitialized',
  };

  return {
    state: states[mongoose.connection.readyState as keyof typeof states] || 'unknown',
    readyState: mongoose.connection.readyState,
    host: mongoose.connection.host,
    port: mongoose.connection.port,
    name: mongoose.connection.name,
  };
}

// ============================================================================
// GRACEFUL DISCONNECT
// ============================================================================

/**
 * Gracefully close MongoDB connection
 *
 * Use this when you need to close the connection manually
 */
export async function disconnectDB(): Promise<void> {
  if (cached.conn) {
    await cached.conn.connection.close();
    cached.conn = null;
    cached.promise = null;
    console.log('[MongoDB] Connection closed gracefully');
  }
}

// ============================================================================
// TRANSACTION HELPER
// ============================================================================

/**
 * Execute a function within a MongoDB transaction
 *
 * @param fn - Async function to execute within transaction
 * @returns Promise<T> - Result of the function
 *
 * @example
 * await withTransaction(async (session) => {
 *   await User.create([{ email: 'test@example.com' }], { session });
 *   await Team.create([{ name: 'Test Team' }], { session });
 * });
 */
export async function withTransaction<T>(
  fn: (session: mongoose.ClientSession) => Promise<T>
): Promise<T> {
  const session = await mongoose.startSession();

  try {
    session.startTransaction();
    const result = await fn(session);
    await session.commitTransaction();
    return result;
  } catch (error) {
    await session.abortTransaction();
    throw error;
  } finally {
    session.endSession();
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

export default connectDB;
export { mongoose };
