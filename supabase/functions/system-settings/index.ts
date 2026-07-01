// supabase/functions/system-settings/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, requireAuth, getServiceClient, errorResponse } from '../_shared/auth.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*system-settings/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/payment-methods') {
      await requireAuth(req);
      const { data, error } = await svc
        .from('payment_methods')
        .select('*')
        .order('sort_order');
      if (error) throw error;
      return Response.json({ methods: data ?? [] }, { headers: corsHeaders });
    }

    if (req.method === 'GET') {
      await requireRole(req, ['head_manager']);
      const { data, error } = await svc
        .from('system_settings')
        .select('*')
        .single();
      if (error && error.code !== 'PGRST116') throw error;

      const { data: methods } = await svc
        .from('payment_methods')
        .select('*')
        .order('sort_order');

      return Response.json(
        {
          ...(data ?? {
            min_loan_amount: 3000,
            max_loan_amount: 500000,
            interest_rate: 0.20,
            penalty_rate: 0.20,
            penalty_grace_days: 30,
          }),
          payment_methods: methods ?? [],
        },
        { headers: corsHeaders },
      );
    }

    if (req.method === 'POST' && path === '/update') {
      const user = await requireRole(req, ['head_manager']);
      const body = await req.json();

      const allowedSettings = [
        'min_loan_amount',
        'max_loan_amount',
      ];

      const settingsUpdate: Record<string, unknown> = {
        updated_at: new Date().toISOString(),
        updated_by: user.id,
      };

      for (const key of allowedSettings) {
        if (body[key] !== undefined) settingsUpdate[key] = body[key];
      }

      const { data: existing } = await svc
        .from('system_settings')
        .select('id')
        .maybeSingle();

      if (existing) {
        await svc.from('system_settings').update(settingsUpdate).eq('id', existing.id);
      } else {
        await svc.from('system_settings').insert({
          min_loan_amount: 3000,
          max_loan_amount: 500000,
          interest_rate: 0.20,
          penalty_rate: 0.20,
          penalty_grace_days: 30,
          ...settingsUpdate,
        });
      }

      if (Array.isArray(body.payment_methods)) {
        await svc.from('payment_methods').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        const methods = body.payment_methods.map(
          (m: Record<string, unknown>, idx: number) => ({
            method: m.method,
            display_name: m.display_name,
            description: m.description ?? null,
            is_enabled: m.is_enabled ?? false,
            sort_order: m.sort_order ?? idx,
          }),
        );
        if (methods.length > 0) {
          await svc.from('payment_methods').insert(methods);
        }
      }

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'update',
        table_name: 'system_settings',
        new_values: settingsUpdate,
      });

      return Response.json({ message: 'Settings updated' }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});