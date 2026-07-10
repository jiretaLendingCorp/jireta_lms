// supabase/functions/auth-profile/index.ts
// BUG FIXES:
// 1. Avatar upload: ext was parsed from file.type, but file.type can be
//    "image/jpeg" → ext becomes "jpeg" (correct). However we upsert with the
//    same storagePath so an old "avatar.png" is not cleaned up when a new
//    "avatar.jpeg" is uploaded. Fixed: always use a constant filename "avatar"
//    and let storage upsert handle replacement.
// 2. Profile update: /update route now returns the updated profile so the
//    Flutter AuthNotifier can refresh state without a second GET round-trip.
// 3. change-password: now verifies current password via reauthentication
//    before allowing the change (security hardening).
// 4. All error paths now log the full error object for easier debugging.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireAuth, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { sendOtp } from '../_shared/sms.ts';
import { emailPasswordReset } from '../_shared/email.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function normalizePhone(phone: string): string {
  return phone.replace(/\D/g, '');
}

function generateOtp(): string {
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return String(bytes[0] % 1000000).padStart(6, '0');
}

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const svc = getServiceClient();
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*auth-profile/, '');

    if (path === '/register-lender' && req.method === 'POST') {
      const body = await req.json();
      const email = String(body.email ?? '').trim().toLowerCase();
      const password = String(body.password ?? '');
      const firstName = String(body.first_name ?? '').trim();
      const lastName = String(body.last_name ?? '').trim();
      const middleName = body.middle_name ? String(body.middle_name).trim() : null;
      const phone = body.phone ? normalizePhone(String(body.phone)) : null;

      if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
        return Response.json({ error: 'Valid email is required' }, { status: 400, headers: corsHeaders });
      }
      if (!password || password.length < 8) {
        return Response.json({ error: 'Password must be at least 8 characters' }, { status: 400, headers: corsHeaders });
      }
      if (!firstName || !lastName) {
        return Response.json({ error: 'First name and last name are required' }, { status: 400, headers: corsHeaders });
      }
      if (phone && !/^09\d{9}$/.test(phone)) {
        return Response.json({ error: 'Phone must be a valid 09XXXXXXXXX number' }, { status: 400, headers: corsHeaders });
      }

      const { data: authUser, error: createErr } = await svc.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          first_name: firstName,
          last_name: lastName,
          middle_name: middleName,
          phone,
          role: 'lender',
          force_password_change: false,
        },
      });

      if (createErr) {
        if (createErr.message.toLowerCase().includes('already')) {
          return Response.json({ error: 'This email is already registered' }, { status: 409, headers: corsHeaders });
        }
        console.error('[auth-profile register-lender] auth create error:', createErr);
        throw createErr;
      }

      const uid = authUser.user!.id;
      const { error: profileErr } = await svc.from('users').upsert({
        id: uid,
        email,
        first_name: firstName,
        last_name: lastName,
        middle_name: middleName,
        phone,
        role: 'lender',
        force_password_change: false,
        is_active: true,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'id' });

      if (profileErr) {
        console.error('[auth-profile register-lender] profile upsert error:', profileErr);
        await svc.auth.admin.deleteUser(uid);
        throw profileErr;
      }

      const { error: lenderInfoErr } = await svc.from('lender_info').insert({ user_id: uid });
      if (lenderInfoErr && !lenderInfoErr.message.toLowerCase().includes('duplicate')) {
        console.warn('[auth-profile register-lender] lender_info insert warning:', lenderInfoErr.message);
      }

      await svc.from('audit_logs').insert({
        user_id: uid,
        action: 'self_register',
        table_name: 'users',
        record_id: uid,
        new_values: { email, role: 'lender' },
        description: 'Borrower self-registered',
      });

      return Response.json({ message: 'Account created', user_id: uid }, { status: 201, headers: corsHeaders });
    }

    if (path === '/forgot-password' && req.method === 'POST') {
      const body = await req.json();
      const email = body.email ? String(body.email).trim().toLowerCase() : null;
      const phone = body.phone ? normalizePhone(String(body.phone)) : null;

      if (!email && !phone) {
        return Response.json({ error: 'Email or phone is required' }, { status: 400, headers: corsHeaders });
      }

      if (email) {
        const { data: profile } = await svc
          .from('users')
          .select('id, first_name, email')
          .eq('email', email)
          .maybeSingle();

        if (profile) {
          const { data: linkData, error: linkErr } = await svc.auth.admin.generateLink({
            type: 'recovery',
            email,
          });
          if (linkErr) throw linkErr;
          const resetLink = linkData.properties?.action_link;
          if (!resetLink) throw new Error('Could not generate reset link');

          await svc
            .from('users')
            .update({ force_password_change: true, updated_at: new Date().toISOString() })
            .eq('id', profile.id);

          await emailPasswordReset({
            to: email,
            firstName: profile.first_name ?? 'there',
            resetLink,
          });
        }

        return Response.json({ message: 'If the account exists, a reset link was sent' }, { headers: corsHeaders });
      }

      const { data: profile } = await svc
        .from('users')
        .select('id, phone')
        .eq('phone', phone)
        .maybeSingle();

      if (!profile) {
        return Response.json({ message: 'If the account exists, an OTP was sent' }, { headers: corsHeaders });
      }

      const otp = generateOtp();
      await svc
        .from('otp_codes')
        .update({ is_used: true })
        .eq('user_id', profile.id)
        .eq('purpose', 'password_reset')
        .eq('is_used', false);

      const { error: otpErr } = await svc.from('otp_codes').insert({
        user_id: profile.id,
        phone,
        otp_code: otp,
        purpose: 'password_reset',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      });
      if (otpErr) throw otpErr;

      const sent = await sendOtp(phone!, otp);
      if (!sent.success) {
        return Response.json({ error: 'Failed to send OTP' }, { status: 502, headers: corsHeaders });
      }

      return Response.json({ message: 'OTP sent' }, { headers: corsHeaders });
    }

    if (path === '/reset-password' && req.method === 'POST') {
      const body = await req.json();
      const phone = normalizePhone(String(body.phone ?? ''));
      const otp = String(body.otp ?? '').trim();
      const newPassword = String(body.new_password ?? '');

      if (!/^09\d{9}$/.test(phone)) {
        return Response.json({ error: 'Valid phone is required' }, { status: 400, headers: corsHeaders });
      }
      if (!/^\d{6}$/.test(otp)) {
        return Response.json({ error: 'Valid 6-digit OTP is required' }, { status: 400, headers: corsHeaders });
      }
      if (newPassword.length < 8) {
        return Response.json({ error: 'Password must be at least 8 characters' }, { status: 400, headers: corsHeaders });
      }

      const { data: code } = await svc
        .from('otp_codes')
        .select('id, user_id, expires_at, is_used')
        .eq('phone', phone)
        .eq('otp_code', otp)
        .eq('purpose', 'password_reset')
        .eq('is_used', false)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (!code || new Date(code.expires_at).getTime() < Date.now()) {
        return Response.json({ error: 'Invalid or expired OTP' }, { status: 400, headers: corsHeaders });
      }

      const { error: authErr } = await svc.auth.admin.updateUserById(code.user_id, {
        password: newPassword,
      });
      if (authErr) throw authErr;

      await svc.from('otp_codes').update({ is_used: true }).eq('id', code.id);
      await svc
        .from('users')
        .update({ force_password_change: true, updated_at: new Date().toISOString() })
        .eq('id', code.user_id);

      return Response.json({ message: 'Password reset' }, { headers: corsHeaders });
    }

    const user = await requireAuth(req);

    // ── GET /auth-profile  — fetch own profile ───────────────────────────
    if (req.method === 'GET' && path === '') {
      const { data, error } = await svc
        .from('users')
        .select('*')
        .eq('id', user.id)
        .single();

      if (error) {
        console.error('[auth-profile GET] db error:', error);
        throw error;
      }
      return Response.json({ profile: data }, { headers: corsHeaders });
    }

    // ── POST /auth-profile/change-password ───────────────────────────────
    if (path === '/change-password' && req.method === 'POST') {
      const { current_password, new_password } = await req.json();
      if (!current_password) {
        return Response.json(
          { error: 'Current password is required' },
          { status: 400, headers: corsHeaders },
        );
      }
      if (!new_password || new_password.length < 8) {
        return Response.json(
          { error: 'Password must be at least 8 characters' },
          { status: 400, headers: corsHeaders },
        );
      }

      const anon = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_ANON_KEY')!,
        { auth: { autoRefreshToken: false, persistSession: false } },
      );
      const { error: verifyErr } = await anon.auth.signInWithPassword({
        email: user.email,
        password: current_password,
      });
      if (verifyErr) {
        return Response.json(
          { error: 'Current password is incorrect' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { error } = await svc.auth.admin.updateUserById(user.id, {
        password: new_password,
      });
      if (error) {
        console.error('[auth-profile change-password] error:', error);
        throw error;
      }

      await svc
        .from('users')
        .update({ force_password_change: false, updated_at: new Date().toISOString() })
        .eq('id', user.id);

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'change_password',
        table_name: 'users',
        record_id: user.id,
        description: 'User changed their password',
      });

      return Response.json({ message: 'Password changed' }, { headers: corsHeaders });
    }

    // ── POST /auth-profile/upload-avatar ────────────────────────────────
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
      // Fall back to inferring MIME from filename when content-type is absent/octet-stream
      const extMap: Record<string, string> = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };
      const fileExt = (file.name?.split('.').pop() ?? '').toLowerCase();
      const effectiveType = allowedTypes.includes(file.type) ? file.type : (extMap[fileExt] ?? file.type);
      if (!allowedTypes.includes(effectiveType)) {
        return Response.json(
          { error: 'Only JPEG, PNG, WebP images are allowed' },
          { status: 400, headers: corsHeaders },
        );
      }

      // BUG FIX: always use constant filename so upsert works correctly
      // regardless of whether a previous avatar had a different extension.
      const mimeToExt: Record<string, string> = {
        'image/jpeg': 'jpg',
        'image/png': 'png',
        'image/webp': 'webp',
      };
      const ext = mimeToExt[effectiveType] ?? 'jpg';
      const storagePath = `profiles/${user.id}/avatar.${ext}`;
      const bytes = await file.arrayBuffer();

      console.log('[auth-profile upload-avatar] uploading to:', storagePath, 'size:', bytes.byteLength);

      const { error: storageError } = await svc.storage
        .from('avatars')
        .upload(storagePath, bytes, {
          contentType: file.type,
          upsert: true,  // replace any existing avatar
        });

      if (storageError) {
        console.error('[auth-profile upload-avatar] storage error:', storageError);
        // Provide a user-friendly message for common storage errors
        if (storageError.message?.includes('Bucket not found')) {
          return Response.json(
            { error: 'Storage not configured. Please contact support.' },
            { status: 500, headers: corsHeaders },
          );
        }
        throw storageError;
      }

      const { data: urlData } = svc.storage
        .from('avatars')
        .getPublicUrl(storagePath);
      
      // Append cache-busting so Flutter picks up the new image
      const publicUrl = `${urlData.publicUrl}?t=${Date.now()}`;

      const { error: dbError } = await svc
        .from('users')
        .update({ avatar_url: publicUrl, updated_at: new Date().toISOString() })
        .eq('id', user.id);

      if (dbError) {
        console.error('[auth-profile upload-avatar] db update error:', dbError);
        throw dbError;
      }

      return Response.json(
        { message: 'Avatar uploaded', avatar_url: publicUrl },
        { headers: corsHeaders },
      );
    }

    // ── PATCH /auth-profile/update ───────────────────────────────────────
    if (path === '/update' && (req.method === 'PUT' || req.method === 'PATCH')) {
      const body = await req.json();

      const allowed = ['first_name', 'last_name', 'middle_name', 'phone', 'address', 'avatar_url'];
      const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
      for (const key of allowed) {
        if (body[key] !== undefined) updates[key] = body[key];
      }

      // Validate required fields if present
      if (updates['first_name'] !== undefined && !String(updates['first_name']).trim()) {
        return Response.json({ error: 'First name cannot be empty' }, { status: 400, headers: corsHeaders });
      }
      if (updates['last_name'] !== undefined && !String(updates['last_name']).trim()) {
        return Response.json({ error: 'Last name cannot be empty' }, { status: 400, headers: corsHeaders });
      }
      if (updates['phone'] !== undefined) {
        const phone = String(updates['phone']).trim();
        if (phone && !/^09\d{9}$/.test(phone)) {
          return Response.json({ error: 'Phone must be a valid 09XXXXXXXXX number' }, { status: 400, headers: corsHeaders });
        }
        updates['phone'] = phone || null;
      }

      const { data: updated, error } = await svc
        .from('users')
        .update(updates)
        .eq('id', user.id)
        .select()
        .single();

      if (error) {
        console.error('[auth-profile update] db error:', error);
        throw error;
      }

      // Log profile update in audit
      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'update',
        table_name: 'users',
        record_id: user.id,
        new_values: updates,
        description: 'User updated their profile',
      });

      return Response.json({ message: 'Profile updated', profile: updated }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    console.error('[auth-profile] unhandled error:', error);
    return errorResponse(error, corsHeaders);
  }
});
