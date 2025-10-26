import { getUser, getAdminStats } from '@/lib/db/queries';
import { NextResponse } from 'next/server';

/**
 * @swagger
 * /api/admin/stats:
 *   get:
 *     tags:
 *       - Admin - Stats
 *     summary: Get admin statistics
 *     description: Retrieve statistics including total users, total teams, recent users, and recent teams
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: Admin statistics retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 totalUsers:
 *                   type: number
 *                 totalTeams:
 *                   type: number
 *                 recentUsers:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/User'
 *                 recentTeams:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Team'
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

    const stats = await getAdminStats();
    return NextResponse.json(stats);
  } catch (error) {
    console.error('Error fetching admin stats:', error);
    return NextResponse.json(
      { error: 'Failed to fetch stats' },
      { status: 500 }
    );
  }
}
