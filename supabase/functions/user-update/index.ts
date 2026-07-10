// supabase/functions/user-update/index.ts
//
// FIXES (Issue 16):
//   • POST /reset-password now sets force_password_change=TRUE in DB so router
//     redirects the affected user to /force-change-password on next login.
//   • POST /force-change-password clears force_password_change after user
//     successfully changes their own password.
//   • Sends in-app notification to the user when their password is reset.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireAuth, requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { encrypt } from '../_shared/encryption.ts';

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const url  = new URL(req.url);
    const path = url.pathname.replace(/.*user-update/, '');
    const svc  = getServiceClient();

    // ── GET /list — list all users (HM/employee) ──────────────────────────────
    if (req.method === 'GET' && path === '/list') {
      await requireRole(req, ['head_manager','employee']);

      const role   = url.searchParams.get('role');
      const page   = parseInt(url.searchParams.get('page') ?? '1');
      const limit  = 20;
      const offset = (page - 1) * limit;

      let query = svc
        .from('users')
        .select('id, first_name, last_name, email, phone, role, is_active, avatar_url, force_password_change, created_at')
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (role) query = query.eq('role', role);

      const { data, error } = await query;
      if (error) throw error;

      return Response.json({ users: data ?? [] }, { headers: corsHeaders });
    }

    // ── GET /get/:id — single user ────────────────────────────────────────────
    if (req.method === 'GET' && path.startsWith('/get/')) {
      await requireRole(req, ['head_manager','employee']);
      const id = path.replace('/get/','');

      const { data, error } = await svc
        .from('users')
        .select('id, first_name, last_name, middle_name, email, phone, role, is_active, avatar_url, address, force_password_change, created_at, updated_at')
        .eq('id', id)
        .single();

      if (error) throw error;
      return Response.json(data, { headers: corsHeaders });
    }

    // ── POST /update — update user profile fields ─────────────────────────────
    if (req.method === 'POST' && (path === '' || path === '/update')) {
      const user = await requireAuth(req);
      const body = await req.json();

      const allowed = ['first_name','last_name','middle_name','phone','address'] as const;
      const updates: Record<string,unknown> = { updated_at: new Date().toISOString() };
      for (const key of allowed) {
        if (body[key] !== undefined) updates[key] = body[key];
      }

      if (body.employer)       updates['employer_encrypted'] = await encrypt(String(body.employer));
      if (body.monthly_income) updates['monthly_income']     = parseFloat(body.monthly_income);

      const { error } = await svc.from('users').update(updates).eq('id', user.id);
      if (error) throw error;

      await svc.from('audit_logs').insert({
        user_id:    user.id,
        action:     'update',
        table_name: 'users',
        record_id:  user.id,
        description: 'User updated own profile',
      });

      return Response.json({ message: 'Profile updated' }, { headers: corsHeaders });
    }

    // ── POST /deactivate — HM/employee deactivates a user ────────────────────
    if (req.method === 'POST' && path === '/deactivate') {
      const actor   = await requireRole(req, ['head_manager','employee']);
      const { user_id, reason } = await req.json();

      if (!user_id) {
        return Response.json({ error: 'user_id required' }, { status: 400, headers: corsHeaders });
      }

      const { data: target } = await svc
        .from('users')
        .select('first_name, last_name, role')
        .eq('id', user_id)
        .single();

      await svc.from('users')
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq('id', user_id);

      const targetName = target
        ? `${target.first_name} ${target.last_name} (${target.role})`
        : user_id;

      await svc.from('audit_logs').insert({
        user_id:     actor.id,
        action:      'deactivate',
        table_name:  'users',
        record_id:   user_id,
        new_values:  { is_active: false, reason: reason ?? null },
        description: `${actor.role} deactivated user ${targetName}`,
      });

      return Response.json({ message: 'User deactivated' }, { headers: corsHeaders });
    }

    // ── POST /reactivate ──────────────────────────────────────────────────────
    if (req.method === 'POST' && path === '/reactivate') {
      const actor     = await requireRole(req, ['head_manager']);
      const { user_id } = await req.json();
      if (!user_id) {
        return Response.json({ error: 'user_id required' }, { status: 400, headers: corsHeaders });
      }

      await svc.from('users')
        .update({ is_active: true, updated_at: new Date().toISOString() })
        .eq('id', user_id);

      await svc.from('audit_logs').insert({
        user_id:    actor.id,
        action:     'reactivate',
        table_name: 'users',
        record_id:  user_id,
        description: `head_manager reactivated user ${user_id}`,
      });

      return Response.json({ message: 'User reactivated' }, { headers: corsHeaders });
    }

    // ── POST /reset-password — HM/employee resets a user's password ──────────
    // FIX Issue 16: sets force_password_change=TRUE so the router forces a
    // password change screen on next login instead of going to the white URI login page.
    if (req.method === 'POST' && path === '/reset-password') {
      const actor              = await requireRole(req, ['head_manager','employee']);
      const { user_id, new_password } = await req.json();

      if (!user_id || !new_password) {
        return Response.json(
          { error: 'user_id and new_password are required' },
          { status: 400, headers: corsHeaders },
        );
      }
      if (String(new_password).length < 8) {
        return Response.json(
          { error: 'Temporary password must be at least 8 characters' },
          { status: 400, headers: corsHeaders },
        );
      }

      // Update password in Supabase Auth (admin API)
      const { error: authErr } = await svc.auth.admin.updateUserById(user_id, {
        password: String(new_password),
      });
      if (authErr) throw authErr;

      // FIX: Set force_password_change so router redirects to /force-change-password
      const { error: dbErr } = await svc.from('users')
        .update({
          force_password_change: true,
          updated_at: new Date().toISOString(),
        })
        .eq('id', user_id);
      if (dbErr) throw dbErr;

      // Fetch target for notification + audit
      const { data: target } = await svc
        .from('users')
        .select('first_name, last_name, role')
        .eq('id', user_id)
        .single();

      const targetName = target
        ? `${target.first_name} ${target.last_name} (${target.role})`
        : user_id;

      // Notify target user to change their password immediately
      await svc.from('notifications').insert({
        user_id: user_id,
        title:   'Password Reset',
        body:    'An administrator has reset your password. Please log in and change it immediately.',
        category: 'account',
      }).select().maybeSingle().catch(() => null);

      await svc.from('audit_logs').insert({
        user_id:     actor.id,
        action:      'change_password',
        table_name:  'users',
        record_id:   user_id,
        new_values:  { force_password_change: true },
        description: `${actor.role} reset password for ${targetName}`,
      });

      return Response.json({ message: 'Password reset. User must change password on next login.' }, { headers: corsHeaders });
    }

    // ── POST /complete-force-change — user clears force_password_change ───────
    // Called by ForceChangePasswordScreen after successful password change.
    if (req.method === 'POST' && path === '/complete-force-change') {
      const user = await requireAuth(req);

      const { error } = await svc.from('users')
        .update({ force_password_change: false, updated_at: new Date().toISOString() })
        .eq('id', user.id);
      if (error) throw error;

      await svc.from('audit_logs').insert({
        user_id:     user.id,
        action:      'change_password',
        table_name:  'users',
        record_id:   user.id,
        description: 'User completed forced password change',
      });

      return Response.json({ message: 'Password change complete' }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    console.error('[user-update]', error);
    return errorResponse(error, corsHeaders);
  }
});