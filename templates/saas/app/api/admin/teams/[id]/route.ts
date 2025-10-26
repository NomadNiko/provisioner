import { getUser } from '@/lib/db/queries';
import { NextRequest, NextResponse } from 'next/server';
import { Types } from 'mongoose';
import { connectDB } from '@/lib/db/connection';
import { Team } from '@/lib/db/schema';

/**
 * @swagger
 * /api/admin/teams/{id}:
 *   patch:
 *     tags:
 *       - Admin - Teams
 *     summary: Update a team
 *     description: Update team name (Admin only)
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Team ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *     responses:
 *       200:
 *         description: Team updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 team:
 *                   $ref: '#/components/schemas/Team'
 *       400:
 *         description: Invalid team ID
 *       403:
 *         description: Unauthorized - Admin access required
 *       404:
 *         description: Team not found
 *       500:
 *         description: Server error
 */
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    // Check if user is admin
    const currentUser = await getUser();

    if (!currentUser || currentUser.role !== 'admin') {
      return NextResponse.json(
        { error: 'Unauthorized. Admin access required.' },
        { status: 403 }
      );
    }

    const { id } = await params;

    if (!Types.ObjectId.isValid(id)) {
      return NextResponse.json(
        { error: 'Invalid team ID' },
        { status: 400 }
      );
    }

    await connectDB();

    const body = await request.json();
    const { name } = body;

    // Update team
    const updatedTeam = await Team.findByIdAndUpdate(
      id,
      { $set: { name, updatedAt: new Date() } },
      { new: true }
    )
      .lean()
      .exec();

    if (!updatedTeam) {
      return NextResponse.json(
        { error: 'Team not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true, team: updatedTeam });
  } catch (error) {
    console.error('Error updating team:', error);
    return NextResponse.json(
      { error: 'Failed to update team' },
      { status: 500 }
    );
  }
}

/**
 * @swagger
 * /api/admin/teams/{id}:
 *   delete:
 *     tags:
 *       - Admin - Teams
 *     summary: Delete a team
 *     description: Delete a team and remove all team members (Admin only)
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Team ID
 *     responses:
 *       200:
 *         description: Team deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *       400:
 *         description: Invalid team ID
 *       403:
 *         description: Unauthorized - Admin access required
 *       404:
 *         description: Team not found
 *       500:
 *         description: Server error
 */
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    // Check if user is admin
    const currentUser = await getUser();

    if (!currentUser || currentUser.role !== 'admin') {
      return NextResponse.json(
        { error: 'Unauthorized. Admin access required.' },
        { status: 403 }
      );
    }

    const { id } = await params;

    if (!Types.ObjectId.isValid(id)) {
      return NextResponse.json(
        { error: 'Invalid team ID' },
        { status: 400 }
      );
    }

    await connectDB();

    // Delete the team
    const deletedTeam = await Team.findByIdAndDelete(id).exec();

    if (!deletedTeam) {
      return NextResponse.json(
        { error: 'Team not found' },
        { status: 404 }
      );
    }

    // TODO: Also remove team references from users' teamMemberships
    // This could be done in a transaction for data consistency

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error deleting team:', error);
    return NextResponse.json(
      { error: 'Failed to delete team' },
      { status: 500 }
    );
  }
}
