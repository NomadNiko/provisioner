import { getUser } from '@/lib/db/queries';
import { NextResponse } from 'next/server';
import { connectDB } from '@/lib/db/connection';
import { ActivityLog } from '@/lib/db/schema';
import { serializeArray } from '@/lib/db/mongodb/serialize';

/**
 * @swagger
 * /api/admin/activity:
 *   get:
 *     tags:
 *       - Admin - Activity
 *     summary: Get activity logs
 *     description: Retrieve the last 500 activity logs (Admin only)
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: List of activity logs
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/ActivityLog'
 *       403:
 *         description: Unauthorized - Admin access required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
export async function GET() {
  try {
    // Check if user is admin
    const currentUser = await getUser();

    if (!currentUser || currentUser.role !== 'admin') {
      return NextResponse.json(
        { error: 'Unauthorized. Admin access required.' },
        { status: 403 }
      );
    }

    await connectDB();

    // Get all activity logs, sorted by most recent
    const logs = await ActivityLog.find()
      .sort({ timestamp: -1 })
      .limit(500) // Limit to last 500 logs for performance
      .lean()
      .exec();

    return NextResponse.json(serializeArray(logs));
  } catch (error) {
    console.error('Error fetching activity logs for admin:', error);
    return NextResponse.json(
      { error: 'Failed to fetch activity logs' },
      { status: 500 }
    );
  }
}
