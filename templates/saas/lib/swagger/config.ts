import swaggerJsdoc from 'swagger-jsdoc';

const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'SaaS Starter API Documentation',
    version: '1.0.0',
    description: `
# Next.js SaaS Starter API

API documentation for Next.js SaaS Starter with MongoDB and Admin Panel.

## Authentication

This API uses HTTP-only session cookies for authentication. To authenticate:

1. Call **POST /api/auth/login** with your credentials
2. The response will set a session cookie
3. All subsequent requests will automatically include this cookie
4. Use **POST /api/auth/logout** to clear the session

### Test Credentials
- Email: \`test@test.com\`
- Password: \`admin123\`

**Note**: After logging in via Swagger UI, the session cookie will be automatically included in subsequent requests within the same browser session.

## Admin Endpoints

Endpoints under the "Admin" tags require the authenticated user to have the \`admin\` role.
    `,
    contact: {
      name: 'API Support',
    },
  },
  servers: [
    {
      url: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
      description: 'Development server',
    },
  ],
  components: {
    securitySchemes: {
      cookieAuth: {
        type: 'apiKey',
        in: 'cookie',
        name: 'session',
        description: 'Session cookie authentication',
      },
    },
    schemas: {
      User: {
        type: 'object',
        properties: {
          _id: { type: 'string' },
          email: { type: 'string', format: 'email' },
          name: { type: 'string' },
          role: { type: 'string', enum: ['admin', 'owner', 'member'] },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      Team: {
        type: 'object',
        properties: {
          _id: { type: 'string' },
          name: { type: 'string' },
          planName: { type: 'string' },
          subscriptionStatus: { type: 'string' },
          stripeCustomerId: { type: 'string' },
          stripeSubscriptionId: { type: 'string' },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      ActivityLog: {
        type: 'object',
        properties: {
          _id: { type: 'string' },
          teamId: { type: 'string' },
          userId: { type: 'string' },
          action: { type: 'string' },
          timestamp: { type: 'string', format: 'date-time' },
          ipAddress: { type: 'string' },
          userAgent: { type: 'string' },
        },
      },
      Error: {
        type: 'object',
        properties: {
          error: { type: 'string' },
        },
      },
    },
  },
  tags: [
    {
      name: 'Authentication',
      description: 'User authentication endpoints',
    },
    {
      name: 'Admin - Users',
      description: 'Admin endpoints for user management',
    },
    {
      name: 'Admin - Teams',
      description: 'Admin endpoints for team management',
    },
    {
      name: 'Admin - Activity',
      description: 'Admin endpoints for activity logs',
    },
    {
      name: 'Admin - Stats',
      description: 'Admin endpoints for statistics',
    },
    {
      name: 'Stripe',
      description: 'Stripe payment and webhook endpoints',
    },
  ],
};

const options = {
  definition: swaggerDefinition,
  apis: ['./app/api/**/*.ts'], // Path to API route files
};

export const swaggerSpec = swaggerJsdoc(options);
