'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Button } from '@/components/ui/button';
import useSWR from 'swr';
import { useState, useMemo } from 'react';
import { Search, Building2, Edit2, Trash2, X } from 'lucide-react';

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

interface EditTeamData {
  _id: string;
  name: string;
}

export default function TeamsPage() {
  const { data: teams, isLoading, error, mutate } = useSWR('/api/admin/teams', fetcher);
  const [searchQuery, setSearchQuery] = useState('');
  const [sortField, setSortField] = useState<string>('createdAt');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc');
  const [editingTeam, setEditingTeam] = useState<EditTeamData | null>(null);
  const [deletingTeamId, setDeletingTeamId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Filter and sort teams
  const filteredAndSortedTeams = useMemo(() => {
    if (!teams) return [];

    let filtered = teams.filter((team: any) => {
      const searchLower = searchQuery.toLowerCase();
      return (
        team.name?.toLowerCase().includes(searchLower) ||
        team.planName?.toLowerCase().includes(searchLower) ||
        team.subscriptionStatus?.toLowerCase().includes(searchLower)
      );
    });

    // Sort
    filtered.sort((a: any, b: any) => {
      let aVal = a[sortField];
      let bVal = b[sortField];

      // Handle special cases
      if (sortField === 'memberCount') {
        aVal = a.teamMembers?.length || 0;
        bVal = b.teamMembers?.length || 0;
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1;
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1;
      return 0;
    });

    return filtered;
  }, [teams, searchQuery, sortField, sortDirection]);

  const handleSort = (field: string) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const handleEditTeam = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingTeam) return;

    setIsSubmitting(true);
    try {
      const response = await fetch(`/api/admin/teams/${editingTeam._id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: editingTeam.name,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to update team');
      }

      await mutate();
      setEditingTeam(null);
    } catch (error: any) {
      alert(error.message || 'Failed to update team');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteTeam = async () => {
    if (!deletingTeamId) return;

    setIsSubmitting(true);
    try {
      const response = await fetch(`/api/admin/teams/${deletingTeamId}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to delete team');
      }

      await mutate();
      setDeletingTeamId(null);
    } catch (error: any) {
      alert(error.message || 'Failed to delete team');
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

  const getSubscriptionBadgeVariant = (status?: string) => {
    if (!status) return 'outline';
    switch (status) {
      case 'active':
        return 'default';
      case 'trialing':
        return 'secondary';
      case 'canceled':
      case 'past_due':
      case 'unpaid':
        return 'destructive';
      default:
        return 'outline';
    }
  };

  if (error) {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4">
        <p className="text-sm text-red-800">
          Failed to load teams. {error.error || 'Please try again.'}
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
            <Building2 className="mr-3 h-8 w-8 text-orange-500" />
            Teams
          </h1>
          <p className="text-muted-foreground mt-2">
            Manage and view all teams in your application.
          </p>
        </div>
        <div className="text-sm text-muted-foreground">
          {isLoading ? (
            <Skeleton className="h-6 w-24" />
          ) : (
            <span className="font-medium">
              {filteredAndSortedTeams.length} total teams
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
              placeholder="Search by team name, plan, or status..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />
          </div>
        </CardContent>
      </Card>

      {/* Teams Table */}
      <Card>
        <CardHeader>
          <CardTitle>All Teams</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <TableSkeleton />
          ) : filteredAndSortedTeams.length === 0 ? (
            <div className="text-center py-12">
              <Building2 className="mx-auto h-12 w-12 text-gray-400" />
              <p className="mt-4 text-sm text-gray-500">
                {searchQuery ? 'No teams found matching your search.' : 'No teams found.'}
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <SortableHeader field="name" label="Team Name" />
                    <SortableHeader field="memberCount" label="Members" />
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Owner(s)
                    </th>
                    <SortableHeader field="planName" label="Plan" />
                    <SortableHeader field="subscriptionStatus" label="Status" />
                    <SortableHeader field="createdAt" label="Created" />
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {filteredAndSortedTeams.map((team: any) => {
                    const owners = team.teamMembers?.filter((m: any) => m.role === 'owner') || [];
                    const memberCount = team.teamMembers?.length || 0;

                    return (
                      <tr key={team._id} className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="flex items-center">
                            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-100 text-orange-600 font-semibold mr-3">
                              {(team.name || 'T')[0].toUpperCase()}
                            </div>
                            <div className="text-sm font-medium text-gray-900">
                              {team.name}
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm text-gray-900">
                            {memberCount} member{memberCount !== 1 ? 's' : ''}
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm text-gray-900">
                            {owners.length > 0 ? (
                              <div className="flex flex-col space-y-1">
                                {owners.map((owner: any, idx: number) => (
                                  <span key={idx}>
                                    {owner.userName || owner.userEmail || 'Unknown'}
                                  </span>
                                ))}
                              </div>
                            ) : (
                              <span className="text-gray-400">No owner</span>
                            )}
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="text-sm text-gray-900">
                            {team.planName || <span className="text-gray-400">Free</span>}
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {team.subscriptionStatus ? (
                            <Badge
                              variant={getSubscriptionBadgeVariant(team.subscriptionStatus)}
                              className="capitalize"
                            >
                              {team.subscriptionStatus.replace('_', ' ')}
                            </Badge>
                          ) : (
                            <span className="text-gray-400 text-sm">-</span>
                          )}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {new Date(team.createdAt).toLocaleDateString('en-US', {
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
                              onClick={() => setEditingTeam({
                                _id: team._id,
                                name: team.name,
                              })}
                              className="text-orange-600 hover:text-orange-700 hover:bg-orange-50"
                            >
                              <Edit2 className="h-4 w-4" />
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => setDeletingTeamId(team._id)}
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

      {/* Edit Team Modal */}
      {editingTeam && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full">
            <div className="flex items-center justify-between p-6 border-b">
              <h2 className="text-xl font-semibold">Edit Team</h2>
              <button
                onClick={() => setEditingTeam(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <form onSubmit={handleEditTeam} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Team Name
                </label>
                <Input
                  type="text"
                  value={editingTeam.name}
                  onChange={(e) => setEditingTeam({ ...editingTeam, name: e.target.value })}
                  placeholder="Team name"
                  required
                />
              </div>
              <div className="flex justify-end space-x-3 pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setEditingTeam(null)}
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
      {deletingTeamId && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full">
            <div className="p-6">
              <h2 className="text-xl font-semibold mb-4">Delete Team</h2>
              <p className="text-gray-600 mb-6">
                Are you sure you want to delete this team? This will remove all team members and cannot be undone.
              </p>
              <div className="flex justify-end space-x-3">
                <Button
                  variant="outline"
                  onClick={() => setDeletingTeamId(null)}
                  disabled={isSubmitting}
                >
                  Cancel
                </Button>
                <Button
                  variant="destructive"
                  onClick={handleDeleteTeam}
                  disabled={isSubmitting}
                  className="bg-red-600 hover:bg-red-700"
                >
                  {isSubmitting ? 'Deleting...' : 'Delete Team'}
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
