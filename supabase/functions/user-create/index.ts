// supabase/functions/user-create/index.ts

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

    const { role, first_name, last_name, email, phone } = body as Record<string, string>;

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
    if (!allowedRoles.includes(role)) {
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

    // NOTE: the on_auth_user_created trigger (see migrations/005) already
    // inserted a row into `users` synchronously as part of admin.createUser()
    // above, using role/first_name/last_name from user_metadata. We only
    // need to UPDATE it here to set the fields the trigger doesn't know
    // about (phone, force_password_change=true for staff-created accounts).
    // Using INSERT here (the old behavior) duplicate-keyed against the
    // trigger's row and always failed.
    const { error: profileErr } = await svc
      .from('users')
      .update({
        phone: phone?.trim() ?? null,
        force_password_change: true,
        is_active: true,
      })
      .eq('id', authUser.user!.id);

    if (profileErr) {
      await svc.auth.admin.deleteUser(authUser.user!.id);
      throw profileErr;
    }

    await svc.from('audit_logs').insert({
      user_id: user.id,
      action: 'create',
      table_name: 'users',
      record_id: authUser.user!.id,
      new_values: { email, role, first_name, last_name },
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
        user_id: authUser.user!.id,
      },
      { status: 201, headers: corsHeaders },
    );
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});