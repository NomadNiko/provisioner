import { NextResponse } from 'next/server';
import { swaggerSpec } from '@/lib/swagger/config';

/**
 * @swagger
 * /api/swagger:
 *   get:
 *     summary: Get OpenAPI specification
 *     description: Returns the OpenAPI/Swagger specification for the API
 *     responses:
 *       200:
 *         description: OpenAPI specification
 */
export async function GET() {
  return NextResponse.json(swaggerSpec);
}
