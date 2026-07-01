// supabase/functions/kyc-review/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*kyc-review/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/list') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const status = url.searchParams.get('status');

      let query = svc
        .from('kyc_submissions')
        .select('*, lender:users!kyc_submissions_lender_id_fkey(first_name, last_name)')
        .order('created_at', { ascending: false });

      if (status) query = query.eq('status', status);

      const { data, error } = await query;
      if (error) throw error;

      const kyc = (data ?? []).map((k: Record<string, unknown>) => ({
        ...k,
        id_number: undefined,
        id_number_encrypted: undefined,
        employer_encrypted: undefined,
        lender_name: k.lender
          ? `${(k.lender as Record<string, string>).first_name} ${(k.lender as Record<string, string>).last_name}`
          : null,
        lender: undefined,
      }));

      return Response.json({ kyc }, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/approve') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const { kyc_id } = await req.json();

      const { data: kyc } = await svc
        .from('kyc_submissions')
        .select('lender_id')
        .eq('id', kyc_id)
        .single();

      if (!kyc) {
        return Response.json({ error: 'KYC submission not found' }, { status: 404, headers: corsHeaders });
      }

      await svc.from('kyc_submissions').update({
        status: 'approved',
        reviewed_by_id: user.id,
        reviewed_at: new Date().toISOString(),
      }).eq('id', kyc_id);

      await svc.from('notifications').insert({
        user_id: kyc.lender_id,
        title: 'KYC Approved',
        body: 'Your identity verification has been approved. You can now apply for a loan.',
        category: 'kyc_status',
        reference_id: kyc_id,
      });

      await pushToUser(svc, kyc.lender_id, PushTemplates.kycApproved(), {
        type: 'kyc_approved',
        kyc_id,
      });

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'approve',
        table_name: 'kyc_submissions',
        record_id: kyc_id,
        new_values: { status: 'approved' },
      });

      return Response.json({ message: 'KYC approved' }, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/reject') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const { kyc_id, reason } = await req.json();

      if (!kyc_id || !reason?.trim()) {
        return Response.json(
          { error: 'kyc_id and reason are required' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: kyc } = await svc
        .from('kyc_submissions')
        .select('lender_id')
        .eq('id', kyc_id)
        .single();

      if (!kyc) {
        return Response.json({ error: 'KYC submission not found' }, { status: 404, headers: corsHeaders });
      }

      await svc.from('kyc_submissions').update({
        status: 'rejected',
        rejection_reason: reason.trim(),
        reviewed_by_id: user.id,
        reviewed_at: new Date().toISOString(),
      }).eq('id', kyc_id);

      await svc.from('notifications').insert({
        user_id: kyc.lender_id,
        title: 'KYC Rejected',
        body: `Your KYC was rejected. Reason: ${reason.trim()}. Please resubmit with correct documents.`,
        category: 'kyc_status',
        reference_id: kyc_id,
      });

      await pushToUser(svc, kyc.lender_id, PushTemplates.kycRejected(), {
        type: 'kyc_rejected',
        kyc_id,
      });

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'reject',
        table_name: 'kyc_submissions',
        record_id: kyc_id,
        new_values: { status: 'rejected', reason: reason.trim() },
      });

      return Response.json({ message: 'KYC rejected' }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});