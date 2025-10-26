/**
 * Serialization utilities for MongoDB documents
 *
 * Converts Mongoose documents and ObjectIds to plain objects that can be
 * safely passed to Next.js Client Components.
 */

import { Types } from 'mongoose';

/**
 * Recursively converts all ObjectIds in an object to strings
 * This is necessary for Next.js Server Components to Client Components communication
 */
export function serializeDocument<T>(doc: T): T {
  if (doc === null || doc === undefined) {
    return doc;
  }

  // Handle ObjectId
  if (doc instanceof Types.ObjectId) {
    return doc.toString() as any;
  }

  // Handle Date objects
  if (doc instanceof Date) {
    return doc;
  }

  // Handle arrays
  if (Array.isArray(doc)) {
    return doc.map((item) => serializeDocument(item)) as any;
  }

  // Handle plain objects
  if (typeof doc === 'object' && doc.constructor === Object) {
    const serialized: any = {};
    for (const key in doc) {
      if (Object.prototype.hasOwnProperty.call(doc, key)) {
        serialized[key] = serializeDocument((doc as any)[key]);
      }
    }
    return serialized;
  }

  // Handle Mongoose documents (shouldn't happen with .lean() but just in case)
  if (typeof doc === 'object' && '_id' in doc) {
    const plain: any = {};
    for (const key in doc) {
      if (Object.prototype.hasOwnProperty.call(doc, key)) {
        plain[key] = serializeDocument((doc as any)[key]);
      }
    }
    return plain;
  }

  // Return primitives as-is
  return doc;
}

/**
 * Type-safe wrapper for serializing documents
 */
export function serialize<T>(doc: T | null): T | null {
  if (!doc) return null;
  return serializeDocument(doc);
}

/**
 * Serialize an array of documents
 */
export function serializeArray<T>(docs: T[]): T[] {
  return docs.map((doc) => serializeDocument(doc));
}
