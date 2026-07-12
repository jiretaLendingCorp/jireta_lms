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

    const termDaysNum = parseInt(String(term_days));
    if (isNaN(termDaysNum) || termDaysNum <= 0 || termDaysNum > 730) {
      return Response.json(
        { error: 'term_days must be a positive integer ≤ 730' },
        { status: 400, headers: corsHeaders },
      );
    }

    // Fetch loan
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
        { error: `Loan cannot be approved in its current status: ${loan.status}` },
        { status: 400, headers: corsHeaders },
      );
    }

    // Recompute installment server-side from the approved term_days
    // (HM/employee may choose different term_days than the tier default)
    const installment = calculateInstallment(loan.total_payable, termDaysNum, payment_frequency);

    const maturityDate = computeMaturityDate(termDaysNum);

    const { error: updateErr } = await svc
      .from('loans')
      .update({
        status:             'approved',
        term_days:          termDaysNum,
        payment_frequency,
        installment_amount: installment,
        approved_by_id:     user.id,
        approved_at:        new Date().toISOString(),
        maturity_date:      maturityDate.toISOString(),
        updated_at:         new Date().toISOString(),
      })
      .eq('id', loan_id);

    if (updateErr) throw updateErr;

    const { data: lenderProfile } = await svc
      .from('users')
      .select('first_name, last_name, email, phone')
      .eq('id', loan.lender_id)
      .single();

    // In-app notification
    await svc.from('notifications').insert({
      user_id:      loan.lender_id,
      title:        'Loan Approved! 🎉',
      body:         `Your loan of ₱${Number(loan.principal_amount).toLocaleString()} has been approved. `
                  + `${payment_frequency.charAt(0).toUpperCase() + payment_frequency.slice(1)} installment: `
                  + `₱${installment.toLocaleString()}`,
      category:     'loan_approved',
      reference_id: loan_id,
    });

    const { data: actorProfile } = await svc
      .from('users')
      .select('first_name, last_name')
      .eq('id', user.id)
      .single();

    const actorName = actorProfile
      ? `${actorProfile.first_name ?? ''} ${actorProfile.last_name ?? ''}`.trim()
      : user.email ?? user.id;

    await svc.from('audit_logs').insert({
      user_id:     user.id,
      action:      'approve',
      table_name:  'loans',
      record_id:   loan_id,
      new_values: {
        status:             'approved',
        term_days:          termDaysNum,
        payment_frequency,
        installment_amount: installment,
        approved_by:        actorName,
      },
      description: `Loan ₱${Number(loan.principal_amount).toLocaleString()} approved by `
                 + `${actorName} — ${payment_frequency} ₱${installment.toLocaleString()} × ${termDaysNum}d`,
    });

    // Push / SMS / Email (non-blocking)
    if (lenderProfile) {
      const lenderName = `${lenderProfile.first_name} ${lenderProfile.last_name}`;
      await Promise.allSettled([
        pushToUser(svc, loan.lender_id, PushTemplates.loanApproved(lenderName, loan.principal_amount)),
        lenderProfile.phone
          ? sendLoanApproved(lenderProfile.phone, lenderName, loan.principal_amount)
          : Promise.resolve(),
        lenderProfile.email
          ? emailLoanApproved(lenderProfile.email, lenderName, loan.principal_amount)
          : Promise.resolve(),
      ]);
    }

    return Response.json(
      {
        message:          'Loan approved successfully',
        loan_id,
        term_days:        termDaysNum,
        payment_frequency,
        installment_amount: installment,
        maturity_date:    maturityDate.toISOString(),
      },
      { headers: corsHeaders },
    );
  } catch (error) {
    console.error('[loan-approve]', error);
    return errorResponse(error, corsHeaders);
  }
});

// ── Helpers ────────────────────────────────────────────────────────────────────

function calculateInstallment(
  totalPayable: number,
  termDays: number,
  frequency: string,
): number {
  const daily   = Math.round((totalPayable / termDays) * 100) / 100;
  const weekly  = Math.round((daily * 7) * 100) / 100;
  const monthly = Math.round((totalPayable / Math.ceil(termDays / 30)) * 100) / 100;

  switch (frequency) {
    case 'daily':   return daily;
    case 'weekly':  return weekly;
    case 'monthly': return monthly;
    default:        return monthly;
  }
}

function computeMaturityDate(termDays: number): Date {
  const d = new Date();
  d.setDate(d.getDate() + termDays);
  return d;
}