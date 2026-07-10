// supabase/functions/send-notification/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireAuth, requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { pushToUser } from '../_shared/fcm.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*send-notification/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/list') {
      const user = await requireAuth(req);
      const page = parseInt(url.searchParams.get('page') ?? '1');
      const limit = 30;

      const { data, error } = await svc
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .range((page - 1) * limit, page * limit - 1);

      if (error) throw error;

      return Response.json({ notifications: data ?? [] }, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/mark-read') {
      const user = await requireAuth(req);
      const body = await req.json();

      if (body.all) {
        await svc
          .from('notifications')
          .update({ is_read: true, read_at: new Date().toISOString() })
          .eq('user_id', user.id)
          .eq('is_read', false);
      } else if (body.id) {
        await svc
          .from('notifications')
          .update({ is_read: true, read_at: new Date().toISOString() })
          .eq('id', body.id)
          .eq('user_id', user.id);
      }

      return Response.json({ message: 'Marked as read' }, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/send') {
      await requireRole(req, ['head_manager', 'employee']);
      const { user_id, title, body: msgBody, category, reference_id } = await req.json();

      if (!user_id || !title || !msgBody) {
        return Response.json(
          { error: 'user_id, title, and body are required' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: notification, error } = await svc
        .from('notifications')
        .insert({
          user_id,
          title,
          body: msgBody,
          category: category ?? 'general',
          reference_id: reference_id ?? null,
        })
        .select()
        .single();

      if (error) throw error;

      await pushToUser(
        svc,
        user_id,
        { title, body: msgBody },
        { category: category ?? 'general', reference_id: reference_id ?? '' },
      );

      return Response.json(
        { message: 'Notification sent', notification_id: notification.id },
        { status: 201, headers: corsHeaders },
      );
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});