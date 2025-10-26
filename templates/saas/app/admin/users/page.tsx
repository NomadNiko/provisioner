'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Button } from '@/components/ui/button';
import useSWR from 'swr';
import { useState, useMemo } from 'react';
import { Search, Users as UsersIcon, Edit2, Trash2, X } from 'lucide-react';

const fetcher = (url: string) => fetch(url).then((res) => res.json());

function TableSkeleton() {
  return (
    <div className="space-y-4">
      {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
        <div key={i} className="flex items-center space-x-4">
          <Skeleton className="h-12 w-full" />
        </div>
      ))}
    </div>
  );
}

interface EditUserData {
  _id: string;
  name: string;
  email: string;
  role: string;
}

export default function UsersPage() {
  const { data: users, isLoading, error, mutate } = useSWR('/api/admin/users', fetcher);
  const [searchQuery, setSearchQuery] = useState('');
  const [sortField, setSortField] = useState<string>('createdAt');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc');
  const [editingUser, setEditingUser] = useState<EditUserData | null>(null);
  const [deletingUserId, setDeletingUserId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Filter and sort users
  const filteredAndSortedUsers = useMemo(() => {
    if (!users) return [];

    let filtered = users.filter((user: any) => {
      const searchLower = searchQuery.toLowerCase();
      return (
        user.name?.toLowerCase().includes(searchLower) ||
        user.email?.toLowerCase().includes(searchLower) ||
        user.role?.toLowerCase().includes(searchLower)
      );
    });

    // Sort
    filtered.sort((a: any, b: any) => {
      let aVal = a[sortField];
      let bVal = b[sortField];

      // Handle nested values for team data
      if (sortField === 'teamName') {
        aVal = a.teams?.[0]?.name || '';
        bVal = b.teams?.[0]?.name || '';
      }
      if (sortField === 'planName') {
        aVal = a.teams?.[0]?.planName || '';
        bVal = b.teams?.[0]?.planName || '';
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1;
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1;
      return 0;
    });

    return filtered;
  }, [users, searchQuery, sortField, sortDirection]);

  const handleSort = (field: string) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const handleEditUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingUser) return;

    setIsSubmitting(true);
    try {
      const response = await fetch(`/api/admin/users/${editingUser._id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: editingUser.name,
          email: editingUser.email,
          role: editingUser.role,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to update user');
      }

      await mutate();
      setEditingUser(null);
    } catch (error: any) {
      alert(error.message || 'Failed to update user');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteUser = async () => {
    if (!deletingUserId) return;

    setIsSubmitting(true);
    try {
      const response = await fetch(`/api/admin/users/${deletingUserId}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to delete user');
      }

      await mutate();
      setDeletingUserId(null);
    } catch (error: any) {
      alert(error.message || 'Failed to delete user');
    } finally {
      setIsSubmitting(false);
    }
  };

  const SortableHeader = ({ field, label }: { field: string; label: string }) => (
    <th
      className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
      onClick={() => handleSort(field)}
    >
      <div className="flex items-center space-x-1">
        <span>{label}</span>
        {sortField === field && (
          <span className="text-orange-500">
            {sortDirection === 'asc' ? '↑' : '↓'}
          </span>
        )}
      </div>
    </th>
  );

  if (error) {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4">
        <p className="text-sm text-red-800">
          Failed to load users. {error.error || 'Please try again.'}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight flex items-center">
            <UsersIcon className="mr-3 h-8 w-8 text-orange-500" />
            Users
          </h1>
          <p className="text-muted-foreground mt-2">
            Manage and view all users in your application.
          </p>
        </div>
        <div className="text-sm text-muted-foreground">
          {isLoading ? (
            <Skeleton className="h-6 w-24" />
          ) : (
            <span className="font-medium">
              {filteredAndSortedUsers.length} total users
            </span>
          )}
        </div>
      </div>

      {/* Search Bar */}
      <Card>
        <CardContent className="pt-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
            <Input
              type="text"
              placeholder="Search by name, email, or role..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />
          </div>
        </CardContent>
      </Card>

      {/* Users Table */}
      <Card>
        <CardHeader>
          <CardTitle>All Users</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <TableSkeleton />
          ) : filteredAndSortedUsers.length === 0 ? (
            <div className="text-center py-12">
              <UsersIcon className="mx-auto h-12 w-12 text-gray-400" />
              <p className="mt-4 text-sm text-gray-500">
                {searchQuery ? 'No users found matching your search.' : 'No users found.'}
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <SortableHeader field="name" label="Name" />
                    <SortableHeader field="email" label="Email" />
                    <SortableHeader field="role" label="Role" />
                    <SortableHeader field="teamName" label="Team" />
                    <SortableHeader field="planName" label="Plan" />
                    <SortableHeader field="createdAt" label="Created" />
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {filteredAndSortedUsers.map((user: any) => {
                    const userTeam = user.teams?.[0];

                    return (
                      <tr key={user._id} className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="flex items-center">
                            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-100 text-orange-600 font-semibold mr-3">
                              {(user.name || user.email || 'U')[0].toUpperCase()}
                            </div>
                            <div className="text-sm font-medium text-gray-900">
                              {user.name || <span className="text-gray-400">Not set</span>}
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm text-gray-900">{user.email}</div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <Badge variant="outline" className="capitalize">
                            {user.role || 'member'}
                          </Badge>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm text-gray-900">
                            {userTeam?.name || <span className="text-gray-400">No team</span>}
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm text-gray-900">
                            {userTeam?.planName || <span className="text-gray-400">Free</span>}
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {new Date(user.createdAt).toLocaleDateString('en-US', {
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric',
                          })}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                          <div className="flex items-center space-x-2">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => setEditingUser({
                                _id: user._id,
                                name: user.name || '',
                                email: user.email,
                                role: user.role || 'member',
                              })}
                              className="text-orange-600 hover:text-orange-700 hover:bg-orange-50"
                            >
                              <Edit2 className="h-4 w-4" />
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => setDeletingUserId(user._id)}
                              className="text-red-600 hover:text-red-700 hover:bg-red-50"
                            >
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Edit User Modal */}
      {editingUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full">
            <div className="flex items-center justify-between p-6 border-b">
              <h2 className="text-xl font-semibold">Edit User</h2>
              <button
                onClick={() => setEditingUser(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <form onSubmit={handleEditUser} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Name
                </label>
                <Input
                  type="text"
                  value={editingUser.name}
                  onChange={(e) => setEditingUser({ ...editingUser, name: e.target.value })}
                  placeholder="User name"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email
                </label>
                <Input
                  type="email"
                  value={editingUser.email}
                  onChange={(e) => setEditingUser({ ...editingUser, email: e.target.value })}
                  placeholder="user@example.com"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Role
                </label>
                <select
                  value={editingUser.role}
                  onChange={(e) => setEditingUser({ ...editingUser, role: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                >
                  <option value="member">Member</option>
                  <option value="owner">Owner</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
              <div className="flex justify-end space-x-3 pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setEditingUser(null)}
                  disabled={isSubmitting}
                >
                  Cancel
                </Button>
                <Button type="submit" disabled={isSubmitting}>
                  {isSubmitting ? 'Saving...' : 'Save Changes'}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deletingUserId && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full">
            <div className="p-6">
              <h2 className="text-xl font-semibold mb-4">Delete User</h2>
              <p className="text-gray-600 mb-6">
                Are you sure you want to delete this user? This action cannot be undone.
              </p>
              <div className="flex justify-end space-x-3">
                <Button
                  variant="outline"
                  onClick={() => setDeletingUserId(null)}
                  disabled={isSubmitting}
                >
                  Cancel
                </Button>
                <Button
                  variant="destructive"
                  onClick={handleDeleteUser}
                  disabled={isSubmitting}
                  className="bg-red-600 hover:bg-red-700"
                >
                  {isSubmitting ? 'Deleting...' : 'Delete User'}
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
