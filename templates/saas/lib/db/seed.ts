import 'dotenv/config';

import { stripe } from '../payments/stripe';
import {
  connectDB,
  disconnectDB,
  User,
  Team,
  createUser,
  createTeam,
  addTeamMember,
  UserRole
} from './mongodb';
import { hashPassword } from '@/lib/auth/session';

async function createStripeProducts() {
  console.log('Creating Stripe products and prices...');

  const baseProduct = await stripe.products.create({
    name: 'Base',
    description: 'Base subscription plan',
  });

  await stripe.prices.create({
    product: baseProduct.id,
    unit_amount: 800, // $8 in cents
    currency: 'usd',
    recurring: {
      interval: 'month',
      trial_period_days: 7,
    },
  });

  const plusProduct = await stripe.products.create({
    name: 'Plus',
    description: 'Plus subscription plan',
  });

  await stripe.prices.create({
    product: plusProduct.id,
    unit_amount: 1200, // $12 in cents
    currency: 'usd',
    recurring: {
      interval: 'month',
      trial_period_days: 7,
    },
  });

  console.log('Stripe products and prices created successfully.');
}

async function seed() {
  const email = 'test@test.com';
  const password = 'admin123';

  console.log('Connecting to MongoDB...');
  await connectDB();

  console.log('Creating initial user...');
  const passwordHash = await hashPassword(password);

  const user = await createUser({
    email: email,
    passwordHash: passwordHash,
    role: UserRole.ADMIN,
  });

  console.log('Initial user created with ID:', user._id.toString());

  console.log('Creating test team...');
  const team = await createTeam({
    name: 'Test Team',
  });

  console.log('Test team created with ID:', team._id.toString());

  console.log('Adding user to team...');
  await addTeamMember(team._id, user._id, UserRole.OWNER);

  console.log('User added to team successfully.');

  // Only create Stripe products if STRIPE_SECRET_KEY is configured
  if (process.env.STRIPE_SECRET_KEY) {
    await createStripeProducts();
  } else {
    console.log('Skipping Stripe product creation (no STRIPE_SECRET_KEY configured)');
  }

  console.log('\n✅ Seed completed successfully!');
  console.log(`\nTest credentials:`);
  console.log(`  Email: ${email}`);
  console.log(`  Password: ${password}`);
}

seed()
  .catch((error) => {
    console.error('Seed process failed:', error);
    process.exit(1);
  })
  .finally(async () => {
    console.log('Disconnecting from MongoDB...');
    await disconnectDB();
    console.log('Seed process finished. Exiting...');
    process.exit(0);
  });
