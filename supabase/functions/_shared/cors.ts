// supabase/functions/_shared/cors.ts
//
// FIX: Added 'x-upsert', 'cache-control', 'x-client-info' to
// Access-Control-Allow-Headers so multipart/form-data preflight succeeds.
// Previously XMLHttpRequest on web (Flutter Web) got a network-layer error
// because the CORS preflight for the upload-avatar multipart request was
// rejected before it reached the edge function handler.

export const corsHeaders = {
  'Access-Control-Allow-Origin':  'https://jireta-lms.vercel.app',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, ' +
    'x-upsert, cache-control, accept, accept-encoding, ' +
    'accept-language, origin, referer',
  'Access-Control-Allow-Methods':  'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Max-Age':        '86400',
};

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { status: 200, headers: corsHeaders });
  }
  return null;
}