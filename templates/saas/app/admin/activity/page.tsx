'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import useSWR from 'swr';
import { useState, useMemo } from 'react';
import { Search, Activity as ActivityIcon, Filter } from 'lucide-react';
import { Button } from '@/components/ui/button';

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

const activityTypeColors: Record<string, string> = {
  'sign_in': 'bg-blue-100 text-blue-800',
  'sign_out': 'bg-gray-100 text-gray-800',
  'sign_up': 'bg-green-100 text-green-800',
  'create_team': 'bg-purple-100 text-purple-800',
  'update_account': 'bg-yellow-100 text-yellow-800',
  'update_password': 'bg-orange-100 text-orange-800',
  'delete_account': 'bg-red-100 text-red-800',
  'invite_team_member': 'bg-indigo-100 text-indigo-800',
  'remove_team_member': 'bg-red-100 text-red-800',
  'accept_invitation': 'bg-green-100 text-green-800',
};

export default function ActivityPage() {
  const { data: logs, isLoading, error } = useSWR('/api/admin/activity', fetcher);
  const [searchQuery, setSearchQuery] = useState('');
  const [actionFilter, setActionFilter] = useState<string>('all');

  // Get unique action types
  const actionTypes = useMemo<string[]>(() => {
    if (!logs) return [];
    const types = new Set<string>(logs.map((log: any) => log.action));
    return ['all', ...Array.from(types)];
  }, [logs]);

  // Filter logs
  const filteredLogs = useMemo(() => {
    if (!logs) return [];

    let filtered = logs.filter((log: any) => {
      const searchLower = searchQuery.toLowerCase();
      const matchesSearch =
        log.userName?.toLowerCase().includes(searchLower) ||
        log.userEmail?.toLowerCase().includes(searchLower) ||
        log.teamName?.toLowerCase().includes(searchLower) ||
        log.action?.toLowerCase().includes(searchLower);

      const matchesAction = actionFilter === 'all' || log.action === actionFilter;

      return matchesSearch && matchesAction;
    });

    return filtered;
  }, [logs, searchQuery, actionFilter]);

  if (error) {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4">
        <p className="text-sm text-red-800">
          Failed to load activity logs. {error.error || 'Please try again.'}
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
            <ActivityIcon className="mr-3 h-8 w-8 text-orange-500" />
            Activity Logs
          </h1>
          <p className="text-muted-foreground mt-2">
            Monitor all user activity across your application.
          </p>
        </div>
        <div className="text-sm text-muted-foreground">
          {isLoading ? (
            <Skeleton className="h-6 w-24" />
          ) : (
            <span className="font-medium">
              {filteredLogs.length} log entries
            </span>
          )}
        </div>
      </div>

      {/* Filters */}
      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardContent className="pt-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
              <Input
                type="text"
                placeholder="Search by user, team, or action..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            <div className="relative">
              <Filter className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
              <select
                value={actionFilter}
                onChange={(e) => setActionFilter(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-md bg-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              >
                {actionTypes.map((type) => (
                  <option key={type} value={type}>
                    {type === 'all' ? 'All Actions' : type.replace(/_/g, ' ').toUpperCase()}
                  </option>
                ))}
              </select>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Activity Logs Table */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Activity</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <TableSkeleton />
          ) : filteredLogs.length === 0 ? (
            <div className="text-center py-12">
              <ActivityIcon className="mx-auto h-12 w-12 text-gray-400" />
              <p className="mt-4 text-sm text-gray-500">
                {searchQuery || actionFilter !== 'all' ? 'No activity logs found matching your filters.' : 'No activity logs found.'}
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Timestamp
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      User
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Action
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Team
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      IP Address
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {filteredLogs.map((log: any) => (
                    <tr key={log._id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {new Date(log.timestamp).toLocaleString('en-US', {
                          year: 'numeric',
                          month: 'short',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">
                          {log.userName || 'Unknown'}
                        </div>
                        <div className="text-sm text-gray-500">{log.userEmail}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${activityTypeColors[log.action] || 'bg-gray-100 text-gray-800'}`}>
                          {log.action.replace(/_/g, ' ')}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {log.teamName || <span className="text-gray-400">-</span>}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {log.ipAddress || <span className="text-gray-400">-</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
