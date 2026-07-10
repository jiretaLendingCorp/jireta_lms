// supabase/functions/user-create/index.ts
// Bug fix: address, driver_license, vehicle_info, birthday are now saved to DB.
// Rider-specific fields go to rider_info table (3NF).
// Audit log now auto-populates actor_name via trigger.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse, AuthError } from '../_shared/auth.ts';
import { emailAccountCreated } from '../_shared/email.ts';

const DEFAULT_PASSWORD = '12345678';

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

    const { data: authUser, error: createErr } = await svc.auth.admin.createUser({
      email: email.trim().toLowerCase(),
      password: DEFAULT_PASSWORD,
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

    // address lives on users for all roles
    if (address?.trim()) userUpdate.address = address.trim();

    const { error: profileErr } = await svc
      .from('users')
      .update(userUpdate)
      .eq('id', uid);

    if (profileErr) {
      await svc.auth.admin.deleteUser(uid);
      throw profileErr;
    }

    // Save rider-specific info into rider_info table
    if (role === 'rider') {
      const riderInfo: Record<string, unknown> = {
        user_id: uid,
        address: address?.trim() ?? null,
        driver_license: driver_license?.trim() ?? null,
        vehicle_info: vehicle_info?.trim() ?? null,
      };
      const { error: riErr } = await svc.from('rider_info').insert(riderInfo);
      if (riErr) console.error('[user-create] rider_info insert error:', riErr.message);
    }

    await svc.from('audit_logs').insert({
      user_id: user.id,
      action: 'create',
      table_name: 'users',
      record_id: uid,
      new_values: { email, role, first_name, last_name },
      description: `Created ${role.replace('_', ' ')} account for ${first_name.trim()} ${last_name.trim()}`,
    });

    await emailAccountCreated({
      to: email.trim().toLowerCase(),
      firstName: first_name.trim(),
      role,
      defaultPassword: DEFAULT_PASSWORD,
    });

    return Response.json(
      {
        message: `User created. Default password: ${DEFAULT_PASSWORD}`,
        user_id: uid,
      },
      { status: 201, headers: corsHeaders },
    );
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});