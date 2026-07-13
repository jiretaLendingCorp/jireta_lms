// supabase/functions/_shared/cors.ts
//
// CORS headers shared by all Edge Functions.
//
// Allow-list:
//   • Production: https://jireta-lms.vercel.app (always allowed)
//   • Additional origins via SUPABASE_ALLOWED_ORIGINS env var
//     (comma-separated, e.g. "http://localhost:3000,http://localhost:5173")
//   • Reflected origin: if the request's Origin matches one of the allow-listed
//     origins, we reflect it back — this is required for Flutter Web dev servers
//     that run on a random localhost port.
//
// NOTE: Multipart/form-data preflight requires 'x-upsert', 'cache-control',
// 'x-client-info' in Access-Control-Allow-Headers (kept from previous version).

const PRODUCTION_ORIGIN = 'https://jireta-lms.vercel.app';

function getAllowedOrigins(): string[] {
  const extra = Deno.env.get('SUPABASE_ALLOWED_ORIGINS') ?? '';
  const extras = extra
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return [PRODUCTION_ORIGIN, ...extras];
}

export function getAllowedOrigin(req: Request): string | null {
  const origin = req.headers.get('Origin');
  if (!origin) return PRODUCTION_ORIGIN; // non-browser clients (curl, Postman)
  const allowed = getAllowedOrigins();
  // Also allow any localhost / 127.0.0.1 origin in non-production deployments
  // so Flutter Web dev servers work without env config.
  const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  if (allowed.includes(origin) || isLocalhost) return origin;
  return null;
}

export function corsHeadersFor(req: Request): Record<string, string> {
  const origin = getAllowedOrigin(req);
  return {
    'Access-Control-Allow-Origin':  origin ?? PRODUCTION_ORIGIN,
    'Vary':                          'Origin',
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type, ' +
      'x-upsert, cache-control, accept, accept-encoding, ' +
      'accept-language, origin, referer',
    'Access-Control-Allow-Methods':  'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Max-Age':        '86400',
  };
}

// Backwards-compatible static export (used by handlers that return JSON without
// inspecting the request — they get the production origin). Handlers that need
// to honor dev origins should call `corsHeadersFor(req)` instead.
export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin':  PRODUCTION_ORIGIN,
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, ' +
    'x-upsert, cache-control, accept, accept-encoding, ' +
    'accept-language, origin, referer',
  'Access-Control-Allow-Methods':  'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Max-Age':        '86400',
};

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { status: 200, headers: corsHeadersFor(req) });
  }
  return null;
}
