// supabase/functions/kyc-review/index.ts
//
// FIXES:
//   • Added GET /pending-lenders for Credit Investigation assignment dropdown.
//   • Added GET /get/:id for full KYC detail view (HM/employee issue 10).
//   • approve/reject now writes approved_by field to audit_logs.
//   • All existing /list/mine, /list, /approve, /reject routes preserved.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireAuth, requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const url  = new URL(req.url);
    const path = url.pathname.replace(/.*kyc-review/, '');
    const svc  = getServiceClient();

    // ── GET /list/mine — lender sees their own KYC ────────────────────────────
    if (req.method === 'GET' && path === '/list/mine') {
      const user = await requireRole(req, ['lender']);

      const { data, error } = await svc
        .from('kyc_submissions')
        .select('*')
        .eq('lender_id', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return Response.json({ kycs: data ?? [] }, { headers: corsHeaders });
    }

    // ── GET /list — HM/employee list all KYCs ─────────────────────────────────
    if (req.method === 'GET' && path === '/list') {
      await requireRole(req, ['head_manager','employee']);

      const status = url.searchParams.get('status');
      const page   = parseInt(url.searchParams.get('page') ?? '1');
      const limit  = 20;
      const offset = (page - 1) * limit;

      let query = svc
        .from('kyc_submissions')
        .select(`
          *,
          lender:lender_id(id, first_name, last_name, email, avatar_url)
        `)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (status && status !== 'all') query = query.eq('status', status);

      const { data, error } = await query;
      if (error) throw error;

      const kycs = (data ?? []).map((k: Record<string,unknown>) => ({
        ...k,
        lender_name:   k.lender
          ? `${(k.lender as Record<string,string>).first_name} ${(k.lender as Record<string,string>).last_name}`
          : null,
        lender_email:  (k.lender as Record<string,string>|null)?.email      ?? null,
        lender_avatar: (k.lender as Record<string,string>|null)?.avatar_url ?? null,
        lender: undefined,
        // Never expose encrypted id_number
        id_number:           undefined,
        id_number_encrypted: undefined,
      }));

      return Response.json({ kycs }, { headers: corsHeaders });
    }

    // ── GET /get/:id — full KYC detail for HM/employee (Issue 10) ────────────
    if (req.method === 'GET' && path.startsWith('/get/')) {
      const user = await requireRole(req, ['head_manager','employee']);
      const id   = path.replace('/get/','');

      const { data, error } = await svc
        .from('kyc_submissions')
        .select(`
          *,
          lender:lender_id(id, first_name, last_name, email, phone, avatar_url, address)
        `)
        .eq('id', id)
        .single();

      if (error) throw error;

      return Response.json({
        ...data,
        lender_name:   data.lender
          ? `${data.lender.first_name} ${data.lender.last_name}`
          : null,
        lender_email:  data.lender?.email     ?? null,
        lender_phone:  data.lender?.phone     ?? null,
        lender_avatar: data.lender?.avatar_url ?? null,
        lender_address: data.lender?.address  ?? null,
        lender: undefined,
        // Strip encrypted raw PII from response
        id_number:           undefined,
        id_number_encrypted: undefined,
        employer_encrypted:  undefined,
      }, { headers: corsHeaders });
    }

    // ── GET /pending-lenders — for CI assignment dropdown ─────────────────────
    if (req.method === 'GET' && path === '/pending-lenders') {
      await requireRole(req, ['head_manager','employee']);

      const { data, error } = await svc
        .from('kyc_submissions')
        .select(`
          id, status, lender_id, created_at,
          lender:lender_id(first_name, last_name, email)
        `)
        .in('status', ['pending','under_review'])
        .order('created_at', { ascending: false });

      if (error) throw error;

      const lenders = (data ?? []).map((k: Record<string,unknown>) => ({
        kyc_id:       k.id,
        kyc_status:   k.status,
        lender_id:    k.lender_id,
        lender_name: k.lender
          ? `${(k.lender as Record<string,string>).first_name} ${(k.lender as Record<string,string>).last_name}`
          : 'Unknown',
        lender_email:  (k.lender as Record<string,string>|null)?.email ?? null,
        submitted_at:  k.created_at,
      }));

      return Response.json({ lenders }, { headers: corsHeaders });
    }

    // ── POST /approve ─────────────────────────────────────────────────────────
    if (req.method === 'POST' && path === '/approve') {
      const user = await requireRole(req, ['head_manager','employee']);
      const { kyc_id } = await req.json();

      if (!kyc_id) {
        return Response.json({ error: 'kyc_id is required' }, { status: 400, headers: corsHeaders });
      }

      // Fetch lender name for audit
      const { data: kyc, error: kycErr } = await svc
        .from('kyc_submissions')
        .select('lender_id, status, lender:lender_id(first_name, last_name)')
        .eq('id', kyc_id)
        .single();

      if (kycErr || !kyc) throw kycErr ?? new Error('KYC not found');
      if (kyc.status === 'approved') {
        return Response.json({ error: 'KYC is already approved' }, { status: 400, headers: corsHeaders });
      }

      const { error: updateErr } = await svc
        .from('kyc_submissions')
        .update({ status: 'approved', reviewed_by: user.id, reviewed_at: new Date().toISOString() })
        .eq('id', kyc_id);

      if (updateErr) throw updateErr;

      const lenderName = kyc.lender
        ? `${(kyc.lender as Record<string,string>).first_name} ${(kyc.lender as Record<string,string>).last_name}`
        : 'Unknown';

      await svc.from('notifications').insert({
        user_id:      kyc.lender_id,
        title:        'KYC Approved ✅',
        body:         'Your KYC has been approved. You can now apply for a loan.',
        category:     'kyc_status',
        reference_id: kyc_id,
      });

      await pushToUser(svc, kyc.lender_id, PushTemplates.kycApproved(), {
        type: 'kyc_approved', kyc_id,
      });

      await svc.from('audit_logs').insert({
        user_id:     user.id,
        action:      'approve',
        table_name:  'kyc_submissions',
        record_id:   kyc_id,
        new_values:  { status: 'approved' },
        description: `KYC approved for ${lenderName} by ${user.role}`,
        approved_by: `${user.id}`,
      });

      return Response.json({ message: 'KYC approved' }, { headers: corsHeaders });
    }

    // ── POST /reject ──────────────────────────────────────────────────────────
    if (req.method === 'POST' && path === '/reject') {
      const user              = await requireRole(req, ['head_manager','employee']);
      const { kyc_id, reason } = await req.json();

      if (!kyc_id || !reason?.trim()) {
        return Response.json(
          { error: 'kyc_id and reason are required' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: kyc, error: kycErr } = await svc
        .from('kyc_submissions')
        .select('lender_id, lender:lender_id(first_name, last_name)')
        .eq('id', kyc_id)
        .single();

      if (kycErr || !kyc) throw kycErr ?? new Error('KYC not found');

      const { error: updateErr } = await svc
        .from('kyc_submissions')
        .update({
          status:           'rejected',
          rejection_reason: reason.trim(),
          reviewed_by:      user.id,
          reviewed_at:      new Date().toISOString(),
        })
        .eq('id', kyc_id);

      if (updateErr) throw updateErr;

      const lenderName = kyc.lender
        ? `${(kyc.lender as Record<string,string>).first_name} ${(kyc.lender as Record<string,string>).last_name}`
        : 'Unknown';

      await svc.from('notifications').insert({
        user_id:      kyc.lender_id,
        title:        'KYC Rejected',
        body:         `Your KYC was rejected. Reason: ${reason.trim()}. Please resubmit with correct documents.`,
        category:     'kyc_status',
        reference_id: kyc_id,
      });

      await pushToUser(svc, kyc.lender_id, PushTemplates.kycRejected(), {
        type: 'kyc_rejected', kyc_id,
      });

      await svc.from('audit_logs').insert({
        user_id:     user.id,
        action:      'reject',
        table_name:  'kyc_submissions',
        record_id:   kyc_id,
        new_values:  { status: 'rejected', reason: reason.trim() },
        description: `KYC rejected for ${lenderName}: ${reason.trim()}`,
      });

      return Response.json({ message: 'KYC rejected' }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    console.error('[kyc-review]', error);
    return errorResponse(error, corsHeaders);
  }
});