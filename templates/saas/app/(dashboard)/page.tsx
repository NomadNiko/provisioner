import { Button } from "@/components/ui/button";
import {
  ArrowRight,
  CreditCard,
  Database,
  Shield,
  Users,
  Code,
  Zap,
} from "lucide-react";
import { Terminal } from "./terminal";
import Link from "next/link";

export default function HomePage() {
  return (
    <main>
      <section className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-12 lg:gap-8">
            <div className="sm:text-center md:max-w-2xl md:mx-auto lg:col-span-6 lg:text-left">
              <div className="mb-4">
                <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-orange-100 text-orange-800">
                  MongoDB + Admin Panel
                </span>
              </div>
              <h1 className="text-4xl font-bold text-gray-900 tracking-tight sm:text-5xl md:text-6xl">
                Next.js SaaS Starter
                <span className="block text-orange-500">Built for Scale</span>
              </h1>
              <p className="mt-3 text-base text-gray-500 sm:mt-5 sm:text-xl lg:text-lg xl:text-xl">
                A production-ready SaaS template with MongoDB, Stripe payments,
                and a powerful admin panel. Built on Next.js 15 with TypeScript
                and modern best practices.
              </p>
              <div className="mt-8 sm:max-w-lg sm:mx-auto sm:text-center lg:text-left lg:mx-0">
                <div className="flex flex-col sm:flex-row gap-3">
                  <Link href="/sign-in">
                    <Button
                      size="lg"
                      className="text-lg rounded-full w-full sm:w-auto"
                    >
                      Get Started
                      <ArrowRight className="ml-2 h-5 w-5" />
                    </Button>
                  </Link>
                  <a
                    href="https://github.com/NomadNiko/saas-starter"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <Button
                      size="lg"
                      variant="outline"
                      className="text-lg rounded-full w-full sm:w-auto"
                    >
                      <Code className="mr-2 h-5 w-5" />
                      View on GitHub
                    </Button>
                  </a>
                  <a
                    href="https://github.com/nextjs/saas-starter"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <Button
                      size="lg"
                      variant="outline"
                      className="text-lg rounded-full w-full sm:w-auto"
                    >
                      View Original
                    </Button>
                  </a>
                </div>
              </div>
            </div>
            <div className="mt-12 relative sm:max-w-lg sm:mx-auto lg:mt-0 lg:max-w-none lg:mx-0 lg:col-span-6 lg:flex lg:items-center">
              <Terminal />
            </div>
          </div>
        </div>
      </section>

      {/* Key Features */}
      <section className="py-16 bg-white w-full">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 sm:text-4xl">
              Everything you need to build and scale
            </h2>
            <p className="mt-4 text-lg text-gray-500">
              Production-ready features built with modern technologies
            </p>
          </div>
          <div className="grid grid-cols-1 gap-8 md:grid-cols-2 lg:grid-cols-3">
            <div className="relative p-6 bg-white rounded-lg border border-gray-200 hover:border-orange-500 transition-colors">
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <Database className="h-6 w-6" />
              </div>
              <div className="mt-5">
                <h3 className="text-lg font-semibold text-gray-900">
                  MongoDB with Mongoose
                </h3>
                <p className="mt-2 text-base text-gray-500">
                  Flexible NoSQL database with embedded documents and optimized
                  queries. No complex joins needed.
                </p>
              </div>
            </div>

            <div className="relative p-6 bg-white rounded-lg border border-gray-200 hover:border-orange-500 transition-colors">
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <Shield className="h-6 w-6" />
              </div>
              <div className="mt-5">
                <h3 className="text-lg font-semibold text-gray-900">
                  Admin Panel
                </h3>
                <p className="mt-2 text-base text-gray-500">
                  Comprehensive admin dashboard with user management, team
                  overview, and real-time search.
                </p>
              </div>
            </div>

            <div className="relative p-6 bg-white rounded-lg border border-gray-200 hover:border-orange-500 transition-colors">
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <CreditCard className="h-6 w-6" />
              </div>
              <div className="mt-5">
                <h3 className="text-lg font-semibold text-gray-900">
                  Stripe Payments
                </h3>
                <p className="mt-2 text-base text-gray-500">
                  Complete subscription management with checkout, customer
                  portal, and webhook handling.
                </p>
              </div>
            </div>

            <div className="relative p-6 bg-white rounded-lg border border-gray-200 hover:border-orange-500 transition-colors">
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <Users className="h-6 w-6" />
              </div>
              <div className="mt-5">
                <h3 className="text-lg font-semibold text-gray-900">
                  Team Management
                </h3>
                <p className="mt-2 text-base text-gray-500">
                  Multi-tenant architecture with role-based access control
                  (Admin, Owner, Member).
                </p>
              </div>
            </div>

            <div className="relative p-6 bg-white rounded-lg border border-gray-200 hover:border-orange-500 transition-colors">
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <Zap className="h-6 w-6" />
              </div>
              <div className="mt-5">
                <h3 className="text-lg font-semibold text-gray-900">
                  Next.js 15
                </h3>
                <p className="mt-2 text-base text-gray-500">
                  Built with App Router, Server Components, and Server Actions
                  for optimal performance.
                </p>
              </div>
            </div>

            <div className="relative p-6 bg-white rounded-lg border border-gray-200 hover:border-orange-500 transition-colors">
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <Code className="h-6 w-6" />
              </div>
              <div className="mt-5">
                <h3 className="text-lg font-semibold text-gray-900">
                  TypeScript
                </h3>
                <p className="mt-2 text-base text-gray-500">
                  Full type safety with strict TypeScript configuration and
                  comprehensive interfaces.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Getting Started */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 sm:text-4xl">
              Get Started in Minutes
            </h2>
            <p className="mt-4 text-lg text-gray-500">
              Quick setup guide to get your SaaS up and running
            </p>
          </div>

          <div className="grid gap-8 lg:grid-cols-2">
            <div className="bg-white rounded-lg border border-gray-200 p-8">
              <h3 className="text-xl font-semibold text-gray-900 mb-4">
                1. Clone and Install
              </h3>
              <div className="bg-gray-900 rounded-md p-4 text-sm font-mono text-gray-100 overflow-x-auto">
                <div className="mb-2">
                  git clone https://github.com/NomadNiko/saas-starter
                </div>
                <div className="mb-2">cd saas-starter</div>
                <div>pnpm install</div>
              </div>
            </div>

            <div className="bg-white rounded-lg border border-gray-200 p-8">
              <h3 className="text-xl font-semibold text-gray-900 mb-4">
                2. Configure Environment
              </h3>
              <div className="space-y-2 text-sm text-gray-600">
                <p>
                  Create a{" "}
                  <code className="bg-gray-100 px-2 py-1 rounded">.env</code>{" "}
                  file with:
                </p>
                <ul className="list-disc list-inside space-y-1 ml-2">
                  <li>MongoDB connection URI</li>
                  <li>Stripe API keys</li>
                  <li>Auth secret (generate with OpenSSL)</li>
                </ul>
              </div>
            </div>

            <div className="bg-white rounded-lg border border-gray-200 p-8">
              <h3 className="text-xl font-semibold text-gray-900 mb-4">
                3. Seed Database
              </h3>
              <div className="bg-gray-900 rounded-md p-4 text-sm font-mono text-gray-100 overflow-x-auto mb-3">
                <div>pnpm db:seed</div>
              </div>
              <p className="text-sm text-gray-600">
                Creates a test user:{" "}
                <code className="bg-gray-100 px-2 py-1 rounded">
                  test@test.com
                </code>{" "}
                /{" "}
                <code className="bg-gray-100 px-2 py-1 rounded">admin123</code>
              </p>
            </div>

            <div className="bg-white rounded-lg border border-gray-200 p-8">
              <h3 className="text-xl font-semibold text-gray-900 mb-4">
                4. Start Development
              </h3>
              <div className="bg-gray-900 rounded-md p-4 text-sm font-mono text-gray-100 overflow-x-auto mb-3">
                <div>pnpm dev</div>
              </div>
              <p className="text-sm text-gray-600">
                Visit{" "}
                <code className="bg-gray-100 px-2 py-1 rounded">
                  localhost:3000
                </code>{" "}
                to see your app
              </p>
            </div>
          </div>

          <div className="mt-12 bg-orange-50 border border-orange-200 rounded-lg p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-3">
              💡 Admin Panel Access
            </h3>
            <p className="text-sm text-gray-700 mb-3">
              To access the admin panel at{" "}
              <code className="bg-white px-2 py-1 rounded">/admin</code>, update
              the user role in MongoDB:
            </p>
            <div className="bg-gray-900 rounded-md p-4 text-sm font-mono text-gray-100 overflow-x-auto">
              <div>db.users.updateOne(</div>
              <div className="ml-4">{'{ email: "test@test.com" },'}</div>
              <div className="ml-4">{'{ $set: { role: "admin" } }'}</div>
              <div>{")"}</div>
            </div>
          </div>

          <div className="mt-12 text-center">
            <h3 className="text-xl font-semibold text-gray-900 mb-4">
              Based on the official Next.js SaaS Starter
            </h3>
            <p className="text-gray-600 mb-6">
              This is a MongoDB + Admin Panel fork of{" "}
              <a
                href="https://github.com/NomadNiko/saas-starter"
                className="text-orange-600 hover:text-orange-700 underline"
                target="_blank"
                rel="noopener noreferrer"
              >
                nextjs/saas-starter
              </a>
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link href="/sign-up">
                <Button size="lg" className="rounded-full">
                  Create an Account
                  <ArrowRight className="ml-2 h-5 w-5" />
                </Button>
              </Link>
              <a
                href="https://github.com/NomadNiko/saas-starter"
                target="_blank"
                rel="noopener noreferrer"
              >
                <Button size="lg" variant="outline" className="rounded-full">
                  <Code className="mr-2 h-5 w-5" />
                  View Documentation
                </Button>
              </a>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
