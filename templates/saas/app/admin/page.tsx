'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Users, Building2, ArrowRight, Activity } from 'lucide-react';
import Link from 'next/link';
import useSWR from 'swr';
import { Skeleton } from '@/components/ui/skeleton';
import { Badge } from '@/components/ui/badge';

const fetcher = (url: string) => fetch(url).then((res) => res.json());

function StatCard({
  title,
  value,
  icon: Icon,
  href,
}: {
  title: string;
  value: number;
  icon: React.ElementType;
  href: string;
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
        <Icon className="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        <Button asChild variant="link" className="px-0 mt-2 h-auto">
          <Link href={href} className="text-sm text-orange-600 hover:text-orange-700">
            View all <ArrowRight className="ml-1 h-3 w-3 inline" />
          </Link>
        </Button>
      </CardContent>
    </Card>
  );
}

function RecentUsersSkeleton() {
  return (
    <div className="space-y-4">
      {[1, 2, 3, 4, 5].map((i) => (
        <div key={i} className="flex items-center space-x-4">
          <Skeleton className="h-12 w-12 rounded-full" />
          <div className="space-y-2 flex-1">
            <Skeleton className="h-4 w-1/3" />
            <Skeleton className="h-3 w-1/4" />
          </div>
        </div>
      ))}
    </div>
  );
}

function RecentUsers({ users }: { users: any[] }) {
  if (!users || users.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">No users found.</p>
    );
  }

  return (
    <div className="space-y-4">
      {users.map((user: any) => (
        <div key={user._id} className="flex items-center justify-between border-b pb-4 last:border-0">
          <div className="flex items-center space-x-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-100 text-orange-600 font-semibold">
              {(user.name || user.email || 'U')[0].toUpperCase()}
            </div>
            <div>
              <p className="text-sm font-medium">
                {user.name || 'Not set'}
              </p>
              <p className="text-xs text-muted-foreground">{user.email}</p>
            </div>
          </div>
          <Badge variant="outline" className="capitalize">
            {user.role || 'member'}
          </Badge>
        </div>
      ))}
    </div>
  );
}

function RecentTeamsSkeleton() {
  return (
    <div className="space-y-4">
      {[1, 2, 3, 4, 5].map((i) => (
        <div key={i} className="flex items-center justify-between">
          <div className="space-y-2 flex-1">
            <Skeleton className="h-4 w-1/3" />
            <Skeleton className="h-3 w-1/4" />
          </div>
          <Skeleton className="h-6 w-16" />
        </div>
      ))}
    </div>
  );
}

function RecentTeams({ teams }: { teams: any[] }) {
  if (!teams || teams.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">No teams found.</p>
    );
  }

  return (
    <div className="space-y-4">
      {teams.map((team: any) => (
        <div key={team._id} className="flex items-center justify-between border-b pb-4 last:border-0">
          <div>
            <p className="text-sm font-medium">{team.name}</p>
            <p className="text-xs text-muted-foreground">
              {team.teamMembers?.length || 0} member{team.teamMembers?.length !== 1 ? 's' : ''}
              {team.planName && ` • ${team.planName}`}
            </p>
          </div>
          {team.subscriptionStatus && (
            <Badge
              variant={team.subscriptionStatus === 'active' ? 'default' : 'secondary'}
              className="capitalize"
            >
              {team.subscriptionStatus}
            </Badge>
          )}
        </div>
      ))}
    </div>
  );
}

function RecentActivitySkeleton() {
  return (
    <div className="space-y-4">
      {[1, 2, 3, 4, 5].map((i) => (
        <div key={i} className="flex items-center justify-between">
          <div className="space-y-2 flex-1">
            <Skeleton className="h-4 w-2/3" />
            <Skeleton className="h-3 w-1/2" />
          </div>
          <Skeleton className="h-6 w-20" />
        </div>
      ))}
    </div>
  );
}

function RecentActivity({ activity }: { activity: any[] }) {
  if (!activity || activity.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">No recent activity.</p>
    );
  }

  const getActionBadgeVariant = (action: string) => {
    if (action.includes('created')) return 'default';
    if (action.includes('updated')) return 'secondary';
    if (action.includes('deleted')) return 'destructive';
    return 'outline';
  };

  return (
    <div className="space-y-4">
      {activity.map((log: any, index: number) => (
        <div key={log._id || index} className="flex items-center justify-between border-b pb-4 last:border-0">
          <div className="flex-1">
            <p className="text-sm font-medium">
              {log.userName || log.userEmail || 'Unknown user'}
            </p>
            <p className="text-xs text-muted-foreground">
              {log.action}
              {log.teamName && ` • ${log.teamName}`}
              {' • '}
              {new Date(log.timestamp).toLocaleString('en-US', {
                month: 'short',
                day: 'numeric',
                hour: 'numeric',
                minute: '2-digit',
              })}
            </p>
          </div>
          <Badge variant={getActionBadgeVariant(log.action)} className="capitalize">
            {log.action.split('.')[0]}
          </Badge>
        </div>
      ))}
    </div>
  );
}

export default function AdminDashboard() {
  const { data: stats, isLoading, error } = useSWR('/api/admin/stats', fetcher);
  const { data: activity, isLoading: activityLoading } = useSWR('/api/admin/activity', fetcher);

  if (error) {
    return (
      <div className="rounded-lg border border-red-200 bg-red-50 p-4">
        <p className="text-sm text-red-800">
          Failed to load admin data. {error.error || 'Please try again.'}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Dashboard Overview</h1>
        <p className="text-muted-foreground mt-2">
          Monitor your application's users and teams.
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {isLoading ? (
          <>
            <Card>
              <CardHeader>
                <Skeleton className="h-4 w-24" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-8 w-16" />
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <Skeleton className="h-4 w-24" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-8 w-16" />
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <Skeleton className="h-4 w-24" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-8 w-16" />
              </CardContent>
            </Card>
          </>
        ) : (
          <>
            <StatCard
              title="Total Users"
              value={stats?.totalUsers || 0}
              icon={Users}
              href="/admin/users"
            />
            <StatCard
              title="Total Teams"
              value={stats?.totalTeams || 0}
              icon={Building2}
              href="/admin/teams"
            />
            <StatCard
              title="Recent Activity"
              value={activity?.length || 0}
              icon={Activity}
              href="/admin/activity"
            />
          </>
        )}
      </div>

      {/* Recent Data */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {/* Recent Users */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle>Recent Users</CardTitle>
            <Button asChild variant="outline" size="sm">
              <Link href="/admin/users">View All</Link>
            </Button>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <RecentUsersSkeleton />
            ) : (
              <RecentUsers users={stats?.recentUsers || []} />
            )}
          </CardContent>
        </Card>

        {/* Recent Teams */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle>Recent Teams</CardTitle>
            <Button asChild variant="outline" size="sm">
              <Link href="/admin/teams">View All</Link>
            </Button>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <RecentTeamsSkeleton />
            ) : (
              <RecentTeams teams={stats?.recentTeams || []} />
            )}
          </CardContent>
        </Card>

        {/* Recent Activity */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle>Recent Activity</CardTitle>
            <Button asChild variant="outline" size="sm">
              <Link href="/admin/activity">View All</Link>
            </Button>
          </CardHeader>
          <CardContent>
            {activityLoading ? (
              <RecentActivitySkeleton />
            ) : (
              <RecentActivity activity={activity?.slice(0, 5) || []} />
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
