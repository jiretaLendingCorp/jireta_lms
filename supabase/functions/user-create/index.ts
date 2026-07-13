// supabase/functions/user-create/index.ts
//
// SECURITY FIXES vs previous version:
//   • Replaced hardcoded `'12345678'` default password with a cryptographically
//     random 16-char temporary password generated server-side. The previous
//     value was a known constant — anyone who knew the pattern could log in
//     to any newly created account before the legitimate user did.
//   • Default password is NO LONGER returned in the API response. The temp
//     password is delivered only via the welcome email.
//   • `email_confirm: true` kept (admin-created accounts are pre-verified)
//     but `force_password_change: true` guarantees the user must rotate the
//     password on first login.
//   • Removed `address` from `rider_info` insert — that column was dropped in
//     03_fixes.sql for 3NF (address lives on `users`).

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse, AuthError } from '../_shared/auth.ts';
import { emailAccountCreated } from '../_shared/email.ts';

// Generate a strong temporary password: 16 chars from [A-Za-z0-9].
// Uses crypto.getRandomValues — never Math.random() for secrets.
function generateTempPassword(length = 16): string {
  const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let out = '';
  for (let i = 0; i < length; i++) {
    out += charset[bytes[i] % charset.length];
  }
  return out;
}

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const user = await requireRole(req, ['head_manager', 'employee']);
    const svc = getServiceClient();
    const body = await req.json();

    const {
      role,
      first_name,
      last_name,
      middle_name,
      email,
      phone,
      address,
      // rider-specific
      driver_license,
      vehicle_info,
      // lender-specific
      employer,
      monthly_income,
      birthday,
    } = body as Record<string, string>;

    if (!role || !first_name || !last_name || !email) {
      return Response.json(
        { error: 'role, first_name, last_name, and email are required' },
        { status: 400, headers: corsHeaders },
      );
    }

    const allowedRoles = ['employee', 'rider', 'lender'];
    if (user.role === 'employee' && !['rider', 'lender'].includes(role)) {
      throw new AuthError('Employees can only create rider or lender accounts', 403);
    }
    if (user.role === 'head_manager') {
      if (!['employee', 'rider', 'lender', 'head_manager'].includes(role)) {
        return Response.json(
          { error: 'Invalid role' },
          { status: 400, headers: corsHeaders },
        );
      }
    } else if (!allowedRoles.includes(role)) {
      return Response.json(
        { error: `Invalid role. Allowed: ${allowedRoles.join(', ')}` },
        { status: 400, headers: corsHeaders },
      );
    }

    // SECURITY: generate a per-user random temp password instead of the
    // hardcoded `'12345678'` constant used previously.
    const tempPassword = generateTempPassword();

    const { data: authUser, error: createErr } = await svc.auth.admin.createUser({
      email: email.trim().toLowerCase(),
      password: tempPassword,
      email_confirm: true,
      user_metadata: {
        first_name: first_name.trim(),
        last_name: last_name.trim(),
        middle_name: middle_name?.trim() ?? null,
        role,
      },
    });

    if (createErr) {
      if (createErr.message.includes('already registered')) {
        return Response.json(
          { error: 'A user with this email already exists' },
          { status: 409, headers: corsHeaders },
        );
      }
      throw createErr;
    }

    const uid = authUser.user!.id;

    // Update base user fields in `users` table
    const userUpdate: Record<string, unknown> = {
      phone: phone?.trim() ?? null,
      middle_name: middle_name?.trim() ?? null,
      force_password_change: true,
      is_active: true,
      updated_at: new Date().toISOString(),
    };

    // `address` lives on `users` for ALL roles (3NF — see 03_fixes.sql).
    if (address?.trim()) userUpdate.address = address.trim();

    const { error: profileErr } = await svc
      .from('users')
      .update(userUpdate)
      .eq('id', uid);

    if (profileErr) {
      // Roll back the auth user so we don't leave an orphan account.
      await svc.auth.admin.deleteUser(uid);
      throw profileErr;
    }

    // Save rider-specific info into rider_info table.
    // NOTE: `address` is intentionally NOT written here — it lives on `users`.
    if (role === 'rider') {
      const riderInfo: Record<string, unknown> = {
        user_id: uid,
        driver_license: driver_license?.trim() ?? null,
        vehicle_info: vehicle_info?.trim() ?? null,
      };
      const { error: riErr } = await svc.from('rider_info').insert(riderInfo);
      if (riErr) console.error('[user-create] rider_info insert error:', riErr.message);
    }

    if (role === 'lender') {
      const lenderInfo: Record<string, unknown> = {
        user_id: uid,
        employer: employer?.trim() ?? null,
        monthly_income: monthly_income ? parseFloat(monthly_income) : null,
        birthday: birthday?.trim() ?? null,
      };
      const { error: liErr } = await svc.from('lender_info').insert(lenderInfo);
      if (liErr) console.error('[user-create] lender_info insert error:', liErr.message);
    }

    await svc.from('audit_logs').insert({
      user_id: user.id,
      action: 'create',
      table_name: 'users',
      record_id: uid,
      new_values: { email, role, first_name, last_name },
      description: `Created ${role.replace('_', ' ')} account for ${first_name.trim()} ${last_name.trim()}`,
    });

    // Deliver the temp password ONLY via email — never in the API response.
    await emailAccountCreated({
      to: email.trim().toLowerCase(),
      firstName: first_name.trim(),
      role,
      defaultPassword: tempPassword,
    });

    return Response.json(
      {
        message: 'User created. Temporary password sent to the user\'s email.',
        user_id: uid,
        // Intentionally do NOT return `temp_password` here.
      },
      { status: 201, headers: corsHeaders },
    );
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});
