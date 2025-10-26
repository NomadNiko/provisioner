import { getUser, updateUser, softDeleteUser } from '@/lib/db/queries';
import { NextRequest, NextResponse } from 'next/server';
import { Types } from 'mongoose';

/**
 * @swagger
 * /api/admin/users/{id}:
 *   patch:
 *     tags:
 *       - Admin - Users
 *     summary: Update a user
 *     description: Update user information including name, email, and role (Admin only)
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               email:
 *                 type: string
 *                 format: email
 *               role:
 *                 type: string
 *                 enum: [admin, owner, member]
 *     responses:
 *       200:
 *         description: User updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: Invalid user ID
 *       403:
 *         description: Unauthorized - Admin access required
 *       404:
 *         description: User not found
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
        { error: 'Invalid user ID' },
        { status: 400 }
      );
    }

    const body = await request.json();
    const { name, email, role } = body;

    // Update user
    const updatedUser = await updateUser(id, { name, email, role });

    if (!updatedUser) {
      return NextResponse.json(
        { error: 'User not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true, user: updatedUser });
  } catch (error) {
    console.error('Error updating user:', error);
    return NextResponse.json(
      { error: 'Failed to update user' },
      { status: 500 }
    );
  }
}

/**
 * @swagger
 * /api/admin/users/{id}:
 *   delete:
 *     tags:
 *       - Admin - Users
 *     summary: Delete a user
 *     description: Soft delete a user (Admin only). Admins cannot delete themselves.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     responses:
 *       200:
 *         description: User deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *       400:
 *         description: Invalid user ID or attempting to delete self
 *       403:
 *         description: Unauthorized - Admin access required
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
        { error: 'Invalid user ID' },
        { status: 400 }
      );
    }

    // Prevent admin from deleting themselves
    if (currentUser._id.toString() === id) {
      return NextResponse.json(
        { error: 'You cannot delete your own account from admin panel' },
        { status: 400 }
      );
    }

    // Soft delete user
    await softDeleteUser(id);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error deleting user:', error);
    return NextResponse.json(
      { error: 'Failed to delete user' },
      { status: 500 }
    );
  }
}
