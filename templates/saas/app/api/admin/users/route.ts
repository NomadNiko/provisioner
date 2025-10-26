import { getUser, getAllUsersForAdmin } from '@/lib/db/queries';
import { NextResponse } from 'next/server';

/**
 * @swagger
 * /api/admin/users:
 *   get:
 *     tags:
 *       - Admin - Users
 *     summary: Get all users
 *     description: Retrieve all users with their team information (Admin only)
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: List of all users
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/User'
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

    const users = await getAllUsersForAdmin();
    return NextResponse.json(users);
  } catch (error) {
    console.error('Error fetching users for admin:', error);
    return NextResponse.json(
      { error: 'Failed to fetch users' },
      { status: 500 }
    );
  }
}
