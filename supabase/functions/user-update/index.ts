// supabase/functions/user-update/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse, AuthError } from '../_shared/auth.ts';
import { decryptObject } from '../_shared/encryption.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*user-update/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/list') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const role = url.searchParams.get('role');
      const search = url.searchParams.get('search');
      const page = parseInt(url.searchParams.get('page') ?? '1');
      const limit = 20;

      let query = svc
        .from('users')
        .select('*')
        .order('created_at', { ascending: false })
        .range((page - 1) * limit, page * limit - 1);

      if (role) query = query.eq('role', role);
      if (search) {
        query = query.or(
          `first_name.ilike.%${search}%,last_name.ilike.%${search}%,email.ilike.%${search}%`,
        );
      }

      const { data, error } = await query;
      if (error) throw error;

      return Response.json({ users: data ?? [] }, { headers: corsHeaders });
    }

    if (req.method === 'GET' && path.startsWith('/list/')) {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const targetId = path.replace('/list/', '');
      const { data, error } = await svc
        .from('users')
        .select('*')
        .eq('id', targetId)
        .single();
      if (error) throw error;

      // `employer` / `monthly_income` live on kyc_submissions, not on
      // `users` (see migration 004) — pull the lender's most recent KYC
      // submission so the user-detail screen can still show them.
      if (data.role === 'lender') {
        const { data: kyc } = await svc
          .from('kyc_submissions')
          .select('employer_encrypted, monthly_income')
          .eq('lender_id', targetId)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (kyc) {
          const decrypted = await decryptObject(kyc, ['employer_encrypted']);
          data.employer = decrypted.employer_encrypted ?? null;
          data.monthly_income = kyc.monthly_income ?? null;
        }
      }

      return Response.json(data, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/deactivate') {
      const user = await requireRole(req, ['head_manager']);
      const { id } = await req.json();

      const { data: target } = await svc
        .from('users')
        .select('role, is_active')
        .eq('id', id)
        .single();

      if (!target) {
        return Response.json({ error: 'User not found' }, { status: 404, headers: corsHeaders });
      }

      if (id === user.id) {
        throw new AuthError('Cannot deactivate your own account', 400);
      }

      const newStatus = !target.is_active;

      await svc.from('users').update({
        is_active: newStatus,
        updated_at: new Date().toISOString(),
      }).eq('id', id);

      if (!newStatus) {
        await svc.auth.admin.updateUserById(id, { ban_duration: '876600h' });
      } else {
        await svc.auth.admin.updateUserById(id, { ban_duration: 'none' });
      }

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: newStatus ? 'reactivate' : 'deactivate',
        table_name: 'users',
        record_id: id,
        new_values: { is_active: newStatus },
      });

      return Response.json(
        { message: `User ${newStatus ? 'reactivated' : 'deactivated'}` },
        { headers: corsHeaders },
      );
    }

    if (req.method === 'PATCH') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const body = await req.json();
      const { id, ...updates } = body as Record<string, unknown>;

      if (!id) {
        return Response.json({ error: 'id is required' }, { status: 400, headers: corsHeaders });
      }

      const allowedFields = [
        'first_name', 'last_name', 'phone', 'address',
        'is_active', 'avatar_url', 'force_password_change',
      ];

      const safeUpdates: Record<string, unknown> = {
        updated_at: new Date().toISOString(),
      };

      for (const field of allowedFields) {
        if (updates[field] !== undefined) {
          safeUpdates[field] = updates[field];
        }
      }

      const { error } = await svc
        .from('users')
        .update(safeUpdates)
        .eq('id', id);

      if (error) throw error;

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'update',
        table_name: 'users',
        record_id: id as string,
        new_values: safeUpdates,
      });

      return Response.json({ message: 'User updated' }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});