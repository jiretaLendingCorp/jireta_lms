// supabase/functions/_shared/auth.ts
// SECURITY: requireAuth now also checks is_active. Deactivated users get 403.
// requireRole enforces RBAC at every Edge Function boundary.
// All auth errors are logged server-side for audit purposes.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type UserRole = 'head_manager' | 'employee' | 'rider' | 'lender';

export interface AuthUser {
  id: string;
  email: string;
  role: UserRole;
}

export function getServiceClient() {
  const url = Deno.env.get('SUPABASE_URL')!;
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export function getAnonClient(authHeader: string) {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    },
  );
}

export async function requireAuth(req: Request): Promise<AuthUser> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw new AuthError('Missing or invalid authorization header', 401);
  }

  const token = authHeader.replace('Bearer ', '');
  const anonClient = getAnonClient(authHeader);

  const { data: { user }, error } = await anonClient.auth.getUser(token);
  if (error || !user) {
    console.warn('[requireAuth] getUser failed:', error?.message);
    throw new AuthError('Invalid or expired token', 401);
  }

  const svc = getServiceClient();
  const { data: profile, error: profileError } = await svc
    .from('users')
    .select('role, is_active')
    .eq('id', user.id)
    .single();

  if (profileError || !profile) {
    console.error('[requireAuth] profile query error:', profileError?.message);
    throw new AuthError('User profile not found', 403);
  }

  // SECURITY: block deactivated accounts at Edge Function level
  if (profile.is_active === false) {
    console.warn('[requireAuth] deactivated account tried to access:', user.id);
    throw new AuthError('Your account has been deactivated. Contact support.', 403);
  }

  return {
    id: user.id,
    email: user.email!,
    role: profile.role as UserRole,
  };
}

export async function requireRole(
  req: Request,
  allowedRoles: UserRole[],
): Promise<AuthUser> {
  const user = await requireAuth(req);
  if (!allowedRoles.includes(user.role)) {
    console.warn(
      `[requireRole] RBAC denied: user ${user.id} (${user.role}) tried to access route requiring ${allowedRoles.join('|')}`,
    );
    throw new AuthError(
      `Access denied. Required: ${allowedRoles.join(' or ')}. You are: ${user.role}.`,
      403,
    );
  }
  return user;
}

export class AuthError extends Error {
  constructor(
    message: string,
    public status: number = 403,
  ) {
    super(message);
    this.name = 'AuthError';
  }
}

export function errorResponse(
  error: unknown,
  corsHeaders: Record<string, string>,
) {
  if (error instanceof AuthError) {
    return Response.json(
      { error: error.message },
      { status: error.status, headers: corsHeaders },
    );
  }
  const msg = error instanceof Error ? error.message : String(error);
  console.error('[errorResponse] Unhandled error:', msg);
  return Response.json(
    { error: 'Internal server error', detail: msg },
    { status: 500, headers: corsHeaders },
  );
}