// supabase/functions/fcm-register/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireAuth, getServiceClient, errorResponse } from '../_shared/auth.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const user = await requireAuth(req);
    const svc = getServiceClient();
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*fcm-register/, '');

    if (req.method === 'POST' && path === '') {
      const { token, platform } = await req.json();

      if (!token || !platform) {
        return Response.json(
          { error: 'token and platform are required' },
          { status: 400, headers: corsHeaders },
        );
      }

      if (!['android', 'ios', 'web'].includes(platform)) {
        return Response.json(
          { error: 'platform must be android, ios, or web' },
          { status: 400, headers: corsHeaders },
        );
      }

      // Remove any existing row with this exact token (could belong to a
      // previously logged-out user on the same device) then upsert for this user+platform.
      await svc.from('fcm_tokens').delete().eq('token', token);

      const { error } = await svc
        .from('fcm_tokens')
        .upsert(
          {
            user_id: user.id,
            token,
            platform,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'user_id,platform' },
        );

      if (error) throw error;

      return Response.json({ message: 'Push token registered' }, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/unregister') {
      const { token } = await req.json();
      if (token) {
        await svc.from('fcm_tokens').delete().eq('token', token).eq('user_id', user.id);
      } else {
        await svc.from('fcm_tokens').delete().eq('user_id', user.id);
      }
      return Response.json({ message: 'Push token unregistered' }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});