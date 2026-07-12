// supabase/functions/loan-reject/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendLoanRejected } from '../_shared/sms.ts';
import { emailLoanRejected } from '../_shared/email.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const user = await requireRole(req, ['head_manager', 'employee']);
    const svc = getServiceClient();
    const { loan_id, reason } = await req.json();

    if (!loan_id || !reason?.trim()) {
      return Response.json(
        { error: 'loan_id and reason are required' },
        { status: 400, headers: corsHeaders },
      );
    }

    const { data: loan } = await svc
      .from('loans')
      .select('status, lender_id, principal_amount')
      .eq('id', loan_id)
      .single();

    if (!loan) {
      return Response.json({ error: 'Loan not found' }, { status: 404, headers: corsHeaders });
    }

    if (!['pending', 'under_review'].includes(loan.status)) {
      return Response.json(
        { error: 'Loan cannot be rejected in its current status' },
        { status: 400, headers: corsHeaders },
      );
    }

    await svc.from('loans').update({
      status: 'rejected',
      rejection_reason: reason.trim(),
      updated_at: new Date().toISOString(),
    }).eq('id', loan_id);

    const { data: lenderProfile } = await svc
      .from('users')
      .select('first_name, email, phone')
      .eq('id', loan.lender_id)
      .single();

    await svc.from('notifications').insert({
      user_id: loan.lender_id,
      title: 'Loan Application Rejected',
      body: `Your loan application has been rejected. Reason: ${reason.trim()}`,
      category: 'loan_rejected',
      reference_id: loan_id,
    });

    await pushToUser(svc, loan.lender_id, PushTemplates.loanRejected(), {
      type: 'loan_rejected',
      loan_id,
    });

    if (lenderProfile?.phone) {
      await sendLoanRejected(lenderProfile.phone, {
        firstName: lenderProfile.first_name ?? 'Borrower',
        reason: reason.trim(),
      });
    }

    if (lenderProfile?.email) {
      await emailLoanRejected({
        to: lenderProfile.email,
        firstName: lenderProfile.first_name ?? 'Borrower',
        amount: loan.principal_amount,
        reason: reason.trim(),
      });
    }

    await svc.from('audit_logs').insert({
      user_id: user.id,
      action: 'reject',
      table_name: 'loans',
      record_id: loan_id,
      new_values: { status: 'rejected', rejection_reason: reason.trim() },
    });

    return Response.json({ message: 'Loan rejected' }, { headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});