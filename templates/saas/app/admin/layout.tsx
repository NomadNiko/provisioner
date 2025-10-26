import { getUser } from '@/lib/db/queries';
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Home, Users, Building2, BarChart3, Activity, FileText } from 'lucide-react';

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await getUser();

  // Redirect non-admin users
  if (!user || user.role !== 'admin') {
    redirect('/dashboard');
  }

  return (
    <div className="flex min-h-screen flex-col">
      {/* Admin Header */}
      <header className="border-b border-gray-200 bg-white">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <BarChart3 className="h-6 w-6 text-orange-500" />
              <h1 className="text-xl font-semibold text-gray-900">
                Admin Panel
              </h1>
            </div>
            <Button asChild variant="outline" size="sm">
              <Link href="/dashboard">
                <Home className="mr-2 h-4 w-4" />
                Back to Dashboard
              </Link>
            </Button>
          </div>
        </div>
      </header>

      {/* Admin Navigation */}
      <nav className="border-b border-gray-200 bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            <Link
              href="/admin"
              className="border-b-2 border-transparent px-1 py-4 text-sm font-medium text-gray-700 hover:border-orange-500 hover:text-orange-600"
            >
              Overview
            </Link>
            <Link
              href="/admin/users"
              className="border-b-2 border-transparent px-1 py-4 text-sm font-medium text-gray-700 hover:border-orange-500 hover:text-orange-600 flex items-center"
            >
              <Users className="mr-2 h-4 w-4" />
              Users
            </Link>
            <Link
              href="/admin/teams"
              className="border-b-2 border-transparent px-1 py-4 text-sm font-medium text-gray-700 hover:border-orange-500 hover:text-orange-600 flex items-center"
            >
              <Building2 className="mr-2 h-4 w-4" />
              Teams
            </Link>
            <Link
              href="/admin/activity"
              className="border-b-2 border-transparent px-1 py-4 text-sm font-medium text-gray-700 hover:border-orange-500 hover:text-orange-600 flex items-center"
            >
              <Activity className="mr-2 h-4 w-4" />
              Activity
            </Link>
            <Link
              href="/api-docs"
              className="border-b-2 border-transparent px-1 py-4 text-sm font-medium text-gray-700 hover:border-orange-500 hover:text-orange-600 flex items-center"
              target="_blank"
              rel="noopener noreferrer"
            >
              <FileText className="mr-2 h-4 w-4" />
              API Docs
            </Link>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="flex-1 bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
          {children}
        </div>
      </main>
    </div>
  );
}
