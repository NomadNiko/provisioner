# Next.js SaaS Starter (MongoDB + Admin Panel)

This is a starter template for building a SaaS application using **Next.js** with support for authentication, Stripe integration for payments, and a dashboard for logged-in users.

**Note:** This is a spin-off of [nextjs/saas-starter](https://github.com/nextjs/saas-starter) that uses **MongoDB** instead of PostgreSQL and includes a comprehensive **Admin Panel** for user and team management.

## Features

- Marketing landing page (`/`) with animated Terminal element and sign-in button
- Pricing page (`/pricing`) which connects to Stripe Checkout
- Dashboard pages with CRUD operations on users/teams
- **Admin Panel** (`/admin`) with user and team management
  - Overview dashboard with stats and recent activity
  - Full users table with search and sorting
  - Full teams table with search and sorting
  - Role-based access control (admin users only)
- RBAC with Admin, Owner, and Member roles
- Subscription management with Stripe Customer Portal
- Email/password authentication with JWTs stored to cookies
- Global middleware to protect logged-in routes
- Local middleware to protect Server Actions or validate Zod schemas
- Activity logging system for any user events

## Tech Stack

- **Framework**: [Next.js](https://nextjs.org/)
- **Database**: [MongoDB](https://www.mongodb.com/)
- **ODM**: [Mongoose](https://mongoosejs.com/)
- **Payments**: [Stripe](https://stripe.com/)
- **UI Library**: [shadcn/ui](https://ui.shadcn.com/)

## Getting Started

```bash
git clone https://github.com/NomadNiko/saas-starter
cd saas-starter
pnpm install
```

## Setting Up MongoDB

You'll need a MongoDB database. You can use:

- **MongoDB Atlas** (recommended for production): Create a free cluster at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)
- **Local MongoDB**: Install MongoDB locally from [mongodb.com/docs/manual/installation](https://www.mongodb.com/docs/manual/installation/)

Once you have your MongoDB connection string, add it to your `.env` file (see below).

## Running Locally

### 1. Set up Stripe

[Install](https://docs.stripe.com/stripe-cli) and log in to your Stripe account:

```bash
stripe login
```

### 2. Configure environment variables

Create a `.env` file in the root directory with the following variables:

```bash
# MongoDB Connection
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/database-name

# Stripe Configuration
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Application Configuration
BASE_URL=http://localhost:3000
AUTH_SECRET=your_auth_secret_here
```

Generate a secure `AUTH_SECRET` with:

```bash
openssl rand -base64 32
```

### 3. Seed the database

Seed the database with a default user and team:

```bash
pnpm db:seed
```

This will create the following test user:

- Email: `test@test.com`
- Password: `admin123`
- Role: `owner`

You can also create new users through the `/sign-up` route.

**Note:** The seed script creates a user with the `owner` role by default. To create an admin user with access to the admin panel, you'll need to update the user's role in MongoDB:

```javascript
// In MongoDB shell or Compass
db.users.updateOne({ email: "test@test.com" }, { $set: { role: "admin" } });
```

Admin users will be automatically redirected to `/admin` on login instead of `/dashboard`.

### 4. Run the development server

```bash
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser to see the app in action.

### 5. Listen for Stripe webhooks (optional)

You can listen for Stripe webhooks locally through their CLI to handle subscription change events:

```bash
stripe listen --forward-to localhost:3000/api/stripe/webhook
```

## Testing Payments

To test Stripe payments, use the following test card details:

- Card Number: `4242 4242 4242 4242`
- Expiration: Any future date
- CVC: Any 3-digit number

## Database Schema

The application uses MongoDB with the following collections:

- **users** - User accounts with email/password authentication
  - Includes `role` field for RBAC (admin, owner, member)
  - Embedded `teamMemberships` array for team associations
- **teams** - Team/organization entities with embedded team members
  - Embedded `teamMembers` array with user details
  - Stripe subscription data (customer ID, subscription ID, plan)
- **activity_logs** - Activity tracking for user actions
  - Denormalized user and team data for efficient queries
- **invitations** - Team invitations (pending/accepted/declined)

Team members are embedded within both `users` and `teams` collections for optimal query performance, eliminating the need for complex joins.

## User Roles

The application supports three user roles:

- **Admin** - Full system access, can view admin panel at `/admin`
  - Access to user and team management
  - View all users and teams in the system
  - Automatically redirected to `/admin` on login
- **Owner** - Team owner with full control over their team
  - Can manage team members and subscriptions
  - Can invite new members to their team
- **Member** - Standard team member with limited permissions
  - Can view team information
  - Cannot manage team settings or members

You can set a user's role in the database by updating the `role` field in the `users` collection.

## Admin Panel

The admin panel is accessible at `/admin` for users with the `admin` role. It provides a comprehensive view of your application's users and teams.

### Features

- **Dashboard Overview** (`/admin`)

  - Total users and teams statistics
  - Recent users with their roles
  - Recent teams with subscription status

- **Users Management** (`/admin/users`)

  - Searchable and sortable table of all users
  - Displays: name, email, role, team, subscription plan, created date
  - Real-time search by name, email, or role
  - Click column headers to sort

- **Teams Management** (`/admin/teams`)
  - Searchable and sortable table of all teams
  - Displays: team name, member count, owners, plan, subscription status, created date
  - Real-time search by team name, plan, or subscription status
  - Color-coded subscription status badges

### Access Control

- Only users with `role: 'admin'` can access the admin panel
- Non-admin users are automatically redirected to `/dashboard`
- Server-side authentication checks on all admin routes
- API endpoints require admin role verification

## Going to Production

When you're ready to deploy your SaaS application to production, follow these steps:

### Set up a production MongoDB database

1. Create a production MongoDB cluster (recommended: MongoDB Atlas)
2. Configure network access and database users
3. Get your production connection string

### Set up a production Stripe webhook

1. Go to the Stripe Dashboard and create a new webhook for your production environment
2. Set the endpoint URL to your production API route (e.g., `https://yourdomain.com/api/stripe/webhook`)
3. Select the events you want to listen for:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`

### Deploy to Vercel

1. Push your code to a GitHub repository
2. Connect your repository to [Vercel](https://vercel.com/) and deploy it
3. Follow the Vercel deployment process, which will guide you through setting up your project

### Add environment variables

In your Vercel project settings (or during deployment), add all the necessary environment variables:

1. `MONGODB_URI`: Your production MongoDB connection string
2. `BASE_URL`: Set this to your production domain (e.g., `https://yourdomain.com`)
3. `STRIPE_SECRET_KEY`: Use your Stripe secret key for the production environment
4. `STRIPE_WEBHOOK_SECRET`: Use the webhook secret from the production webhook you created
5. `AUTH_SECRET`: Set this to a random string (`openssl rand -base64 32` will generate one)

**Important:** Never commit your `.env` file to version control. The `.env.example` file is provided as a template.

## Available Scripts

- `pnpm dev` - Start the development server
- `pnpm build` - Build the production application
- `pnpm start` - Start the production server
- `pnpm lint` - Run ESLint
- `pnpm db:seed` - Seed the database with test data
