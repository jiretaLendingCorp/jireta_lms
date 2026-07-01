// supabase/functions/_shared/auth.ts

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export type UserRole = 'head_manager' | 'employee' | 'rider' | 'lender';

export interface AuthUser {
  id: string;
  email: string;
  role: UserRole;
}

export function getServiceClient() {
  const url = Deno.env.get('SUPABASE_URL')!;
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  console.log('[getServiceClient] url:', url);
  console.log('[getServiceClient] key length:', key?.length, 'prefix:', key?.substring(0, 15));
  return createClient(
    url,
    key,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
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
  const client = getAnonClient(authHeader);

  const { data: { user }, error } = await client.auth.getUser(token);
  if (error || !user) {
    console.log('[requireAuth] getUser error:', JSON.stringify(error));
    throw new AuthError('Invalid or expired token', 401);
  }

  console.log('[requireAuth] authenticated user id:', user.id, 'email:', user.email);

  const svc = getServiceClient();
  const { data: profile, error: profileError } = await svc
    .from('users')
    .select('role')
    .eq('id', user.id)
    .single();

  console.log('[requireAuth] profile query result:', JSON.stringify({ profile, profileError }));

  if (profileError || !profile) {
    throw new AuthError('User profile not found', 403);
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
    throw new AuthError(
      `Access denied. Required role: ${allowedRoles.join(' or ')}`,
      403,
    );
  }
  return user;
}

export class AuthError extends Error {
  constructor(message: string, public status: number = 403) {
    super(message);
    this.name = 'AuthError';
  }
}

export function errorResponse(error: unknown, corsHeaders: Record<string, string>) {
  if (error instanceof AuthError) {
    return Response.json(
      { error: error.message },
      { status: error.status, headers: corsHeaders },
    );
  }
  console.error('Unexpected error:', error);
  return Response.json(
    { error: 'Internal server error' },
    { status: 500, headers: corsHeaders },
  );
}