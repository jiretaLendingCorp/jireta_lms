// supabase/functions/system-settings/index.ts
// Fixed: interest_rate and penalty_rate are now controllable by head manager.
// Added GET /public for lenders to see loan parameters.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, requireAuth, getServiceClient, errorResponse } from '../_shared/auth.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*system-settings/, '');
    const svc = getServiceClient();

    // Public endpoint: lenders/riders can read loan params (no admin data)
    if (req.method === 'GET' && path === '/public') {
      await requireAuth(req);
      const { data, error } = await svc
        .from('system_settings')
        .select('min_loan_amount,max_loan_amount,interest_rate,penalty_rate,penalty_grace_days')
        .single();
      if (error && error.code !== 'PGRST116') throw error;

      const { data: methods } = await svc
        .from('payment_methods')
        .select('method,display_name,description,is_enabled,sort_order')
        .eq('is_enabled', true)
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
        'interest_rate',
        'penalty_rate',
        'penalty_grace_days',
      ];

      const settingsUpdate: Record<string, unknown> = {
        updated_at: new Date().toISOString(),
        updated_by: user.id,
      };

      for (const key of allowedSettings) {
        if (body[key] !== undefined) {
          const val = Number(body[key]);
          if (isNaN(val)) continue;
          // Validate ranges
          if (key === 'interest_rate' || key === 'penalty_rate') {
            if (val < 0 || val > 1) continue; // must be 0.00–1.00
          }
          if (key === 'penalty_grace_days') {
            if (val < 0 || val > 365) continue;
          }
          settingsUpdate[key] = val;
        }
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
        description: 'Updated system settings',
      });

      return Response.json({ message: 'Settings updated' }, { headers: corsHeaders });
    }

    if (req.method === 'GET' && path === '/tiers') {
      await requireAuth(req);
      const { data, error } = await svc
        .from('loan_term_tiers')
        .select('*')
        .eq('is_active', true)
        .order('min_amount');
      if (error) throw error;
      return Response.json({ tiers: data ?? [] }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});