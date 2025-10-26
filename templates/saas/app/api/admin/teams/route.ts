import { getUser, getAllTeamsForAdmin } from '@/lib/db/queries';
import { NextResponse } from 'next/server';

/**
 * @swagger
 * /api/admin/teams:
 *   get:
 *     tags:
 *       - Admin - Teams
 *     summary: Get all teams
 *     description: Retrieve all teams with their member information (Admin only)
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: List of all teams
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Team'
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

    const teams = await getAllTeamsForAdmin();
    return NextResponse.json(teams);
  } catch (error) {
    console.error('Error fetching teams for admin:', error);
    return NextResponse.json(
      { error: 'Failed to fetch teams' },
      { status: 500 }
    );
  }
}
