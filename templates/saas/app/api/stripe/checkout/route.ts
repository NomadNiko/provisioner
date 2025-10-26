import { Types } from 'mongoose';
import { connectDB } from '@/lib/db/connection';
import { User, Team } from '@/lib/db/schema';
import {
  getUserById,
  getUserWithTeam,
  updateTeamSubscription
} from '@/lib/db/queries';
import { setSession } from '@/lib/auth/session';
import { NextRequest, NextResponse } from 'next/server';
import { stripe } from '@/lib/payments/stripe';
import Stripe from 'stripe';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const sessionId = searchParams.get('session_id');
  const baseUrl = process.env.BASE_URL || process.env.NEXT_PUBLIC_BASE_URL || 'http://localhost:3000';

  if (!sessionId) {
    return NextResponse.redirect(new URL('/pricing', baseUrl));
  }

  try {
    await connectDB();

    const session = await stripe.checkout.sessions.retrieve(sessionId, {
      expand: ['customer', 'subscription'],
    });

    if (!session.customer || typeof session.customer === 'string') {
      throw new Error('Invalid customer data from Stripe.');
    }

    const customerId = session.customer.id;
    const subscriptionId =
      typeof session.subscription === 'string'
        ? session.subscription
        : session.subscription?.id;

    if (!subscriptionId) {
      throw new Error('No subscription found for this session.');
    }

    const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['items.data.price.product'],
    });

    const plan = subscription.items.data[0]?.price;

    if (!plan) {
      throw new Error('No plan found for this subscription.');
    }

    const productId = (plan.product as Stripe.Product).id;

    if (!productId) {
      throw new Error('No product ID found for this subscription.');
    }

    const userId = session.client_reference_id;
    if (!userId) {
      throw new Error("No user ID found in session's client_reference_id.");
    }

    // Get user by ObjectId
    const user = await getUserById(userId);

    if (!user) {
      throw new Error('User not found in database.');
    }

    // Get user's team
    const userWithTeam = await getUserWithTeam(user._id);

    if (!userWithTeam?.teamId) {
      throw new Error('User is not associated with any team.');
    }

    // Update team with Stripe data
    await updateTeamSubscription(userWithTeam.teamId, {
      stripeCustomerId: customerId,
      stripeSubscriptionId: subscriptionId,
      stripeProductId: productId,
      planName: (plan.product as Stripe.Product).name,
      subscriptionStatus: subscription.status,
    });

    await setSession(user);
    // Redirect admin users to admin panel, regular users to dashboard
    const redirectPath = user.role === 'admin' ? '/admin' : '/dashboard';
    return NextResponse.redirect(new URL(redirectPath, baseUrl));
  } catch (error) {
    console.error('Error handling successful checkout:', error);
    return NextResponse.redirect(new URL('/error', baseUrl));
  }
}
