// supabase/functions/loan-approve/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendLoanApproved } from '../_shared/sms.ts';
import { emailLoanApproved } from '../_shared/email.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const user = await requireRole(req, ['head_manager', 'employee']);
    const svc = getServiceClient();
    const body = await req.json();
    const { loan_id, term_days, payment_frequency } = body;

    if (!loan_id || !term_days || !payment_frequency) {
      return Response.json(
        { error: 'loan_id, term_days, and payment_frequency are required' },
        { status: 400, headers: corsHeaders },
      );
    }

    const validFrequencies = ['daily', 'weekly', 'monthly'];
    if (!validFrequencies.includes(payment_frequency)) {
      return Response.json(
        { error: 'payment_frequency must be daily, weekly, or monthly' },
        { status: 400, headers: corsHeaders },
      );
    }

    const { data: loan, error: fetchErr } = await svc
      .from('loans')
      .select('*')
      .eq('id', loan_id)
      .single();

    if (fetchErr || !loan) {
      return Response.json({ error: 'Loan not found' }, { status: 404, headers: corsHeaders });
    }

    if (!['pending', 'under_review'].includes(loan.status)) {
      return Response.json(
        { error: 'Loan cannot be approved in its current status' },
        { status: 400, headers: corsHeaders },
      );
    }

    const installment = calculateInstallment(loan.total_payable, term_days, payment_frequency);

    const { error: updateErr } = await svc
      .from('loans')
      .update({
        status: 'approved',
        term_days,
        payment_frequency,
        installment_amount: installment,
        approved_by_id: user.id,
        approved_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', loan_id);

    if (updateErr) throw updateErr;

    const { data: lenderProfile } = await svc
      .from('profiles')
      .select('first_name, email, phone')
      .eq('id', loan.lender_id)
      .single();

    await svc.from('notifications').insert({
      user_id: loan.lender_id,
      title: 'Loan Approved!',
      body: `Your loan of ₱${loan.principal_amount.toLocaleString()} has been approved.`,
      category: 'loan_approved',
      reference_id: loan_id,
    });

    await pushToUser(svc, loan.lender_id, PushTemplates.loanApproved(loan.principal_amount), {
      type: 'loan_approved',
      loan_id,
    });

    if (lenderProfile?.phone) {
      await sendLoanApproved(lenderProfile.phone, {
        firstName: lenderProfile.first_name ?? 'Borrower',
        amount: loan.principal_amount,
        frequency: payment_frequency,
      });
    }

    if (lenderProfile?.email) {
      await emailLoanApproved({
        to: lenderProfile.email,
        firstName: lenderProfile.first_name ?? 'Borrower',
        amount: loan.principal_amount,
        totalPayable: loan.total_payable,
        frequency: payment_frequency,
        termDays: term_days,
        installment,
      });
    }

    await svc.from('audit_logs').insert({
      user_id: user.id,
      action: 'approve',
      table_name: 'loans',
      record_id: loan_id,
      new_values: { status: 'approved', term_days, payment_frequency },
    });

    return Response.json({ message: 'Loan approved' }, { headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});

function calculateInstallment(
  totalPayable: number,
  termDays: number,
  frequency: string,
): number {
  switch (frequency) {
    case 'daily':
      return Math.ceil((totalPayable / termDays) * 100) / 100;
    case 'weekly':
      return Math.ceil((totalPayable / Math.ceil(termDays / 7)) * 100) / 100;
    case 'monthly':
      return Math.ceil((totalPayable / Math.ceil(termDays / 30)) * 100) / 100;
    default:
      return totalPayable;
  }
}