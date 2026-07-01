// supabase/functions/auth-profile/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireAuth, getServiceClient, errorResponse } from '../_shared/auth.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const user = await requireAuth(req);
    const svc = getServiceClient();
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*auth-profile/, '');

    if (req.method === 'GET') {
      const { data, error } = await svc
        .from('users')
        .select('*')
        .eq('id', user.id)
        .single();

      if (error) throw error;
      return Response.json({ profile: data }, { headers: corsHeaders });
    }

    if (path === '/change-password' && req.method === 'POST') {
      const { new_password } = await req.json();
      if (!new_password || new_password.length < 8) {
        return Response.json(
          { error: 'Password must be at least 8 characters' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { error } = await svc.auth.admin.updateUserById(user.id, {
        password: new_password,
      });
      if (error) throw error;

      await svc
        .from('users')
        .update({ force_password_change: false, updated_at: new Date().toISOString() })
        .eq('id', user.id);

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'change_password',
        table_name: 'users',
        record_id: user.id,
      });

      return Response.json({ message: 'Password changed' }, { headers: corsHeaders });
    }

    if (path === '/upload-avatar' && req.method === 'POST') {
      const contentType = req.headers.get('content-type') ?? '';
      if (!contentType.includes('multipart/form-data')) {
        return Response.json(
          { error: 'Expected multipart/form-data' },
          { status: 400, headers: corsHeaders },
        );
      }

      const formData = await req.formData();
      const file = formData.get('avatar') as File | null;
      if (!file) {
        return Response.json(
          { error: 'No avatar file provided' },
          { status: 400, headers: corsHeaders },
        );
      }

      const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowedTypes.includes(file.type)) {
        return Response.json(
          { error: 'Only JPEG, PNG, WebP images are allowed' },
          { status: 400, headers: corsHeaders },
        );
      }

      const ext = file.type.split('/')[1];
      const storagePath = `profiles/${user.id}/avatar.${ext}`;
      const bytes = await file.arrayBuffer();

      const { error: storageError } = await svc.storage
        .from('avatars')
        .upload(storagePath, bytes, {
          contentType: file.type,
          upsert: true,
        });
      if (storageError) throw storageError;

      const { data: urlData } = svc.storage
        .from('avatars')
        .getPublicUrl(storagePath);
      const publicUrl = urlData.publicUrl;

      const { error: dbError } = await svc
        .from('users')
        .update({ avatar_url: publicUrl, updated_at: new Date().toISOString() })
        .eq('id', user.id);
      if (dbError) throw dbError;

      return Response.json(
        { message: 'Avatar uploaded', avatar_url: publicUrl },
        { headers: corsHeaders },
      );
    }

    if (path === '/update' && (req.method === 'PUT' || req.method === 'PATCH')) {
      const body = await req.json();
      const allowed = ['first_name', 'last_name', 'phone', 'address', 'avatar_url'];
      const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
      for (const key of allowed) {
        if (body[key] !== undefined) updates[key] = body[key];
      }

      const { error } = await svc
        .from('users')
        .update(updates)
        .eq('id', user.id);
      if (error) throw error;

      return Response.json({ message: 'Profile updated' }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});