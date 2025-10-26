'use client';

import { useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import 'swagger-ui-react/swagger-ui.css';

// Dynamically import SwaggerUI to avoid SSR issues
const SwaggerUI = dynamic(() => import('swagger-ui-react'), { ssr: false });

export default function ApiDocsPage() {
  const [spec, setSpec] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/swagger')
      .then((res) => res.json())
      .then((data) => {
        setSpec(data);
        setLoading(false);
      })
      .catch((err) => {
        console.error('Failed to load API specification:', err);
        setError('Failed to load API specification');
        setLoading(false);
      });
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading API Documentation...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 max-w-md">
          <h2 className="text-red-800 font-semibold mb-2">Error</h2>
          <p className="text-red-600">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header with auth instructions */}
      <div className="bg-orange-50 border-b border-orange-200 px-6 py-4">
        <div className="max-w-7xl mx-auto">
          <h1 className="text-xl font-bold text-gray-900 mb-2">API Documentation</h1>
          <div className="bg-white rounded-lg p-4 border border-orange-200">
            <h2 className="font-semibold text-orange-900 mb-2">🔐 Testing Authentication</h2>
            <p className="text-sm text-gray-700 mb-2">
              To test protected endpoints, first login using <strong>POST /api/auth/login</strong>:
            </p>
            <div className="bg-gray-900 rounded-md p-3 text-sm font-mono text-gray-100 mb-2">
              {`{ "email": "test@test.com", "password": "admin123" }`}
            </div>
            <p className="text-xs text-gray-600">
              After successful login, your session cookie will be automatically included in subsequent requests.
            </p>
          </div>
        </div>
      </div>

      {/* Swagger UI */}
      <div className="bg-white">
        {spec && <SwaggerUI spec={spec} />}
      </div>
    </div>
  );
}
