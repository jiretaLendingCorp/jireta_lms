// supabase/functions/loan-disburse/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { createDisbursement, XENDIT_BANK_CODES } from '../_shared/xendit.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendLoanDisbursed } from '../_shared/sms.ts';
import { emailLoanDisbursed } from '../_shared/email.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*loan-disburse/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/schedule') {
      const user = await requireRole(req, ['head_manager', 'employee', 'lender']);
      const loanId = url.searchParams.get('loan_id');

      if (!loanId) {
        return Response.json(
          { error: 'loan_id is required' },
          { status: 400, headers: corsHeaders },
        );
      }

      if (user.role === 'lender') {
        const { data: loan } = await svc
          .from('loans')
          .select('lender_id')
          .eq('id', loanId)
          .maybeSingle();
        if (!loan || loan.lender_id !== user.id) {
          return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders });
        }
      }

      const { data, error } = await svc
        .from('payment_schedules')
        .select('*')
        .eq('loan_id', loanId)
        .order('installment_number');
      if (error) throw error;
      return Response.json({ schedule: data ?? [] }, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/close') {
      const user = await requireRole(req, ['head_manager']);
      const { loan_id } = await req.json();
      await svc.from('loans').update({
        status: 'completed',
        closed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq('id', loan_id);
      await svc.from('audit_logs').insert({
        user_id: user.id, action: 'close', table_name: 'loans', record_id: loan_id,
      });
      return Response.json({ message: 'Loan closed' }, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/default') {
      const user = await requireRole(req, ['head_manager']);
      const { loan_id } = await req.json();
      await svc.from('loans').update({
        status: 'defaulted',
        updated_at: new Date().toISOString(),
      }).eq('id', loan_id);
      return Response.json({ message: 'Loan marked as defaulted' }, { headers: corsHeaders });
    }

    if (req.method === 'POST' && path === '/waive-penalty') {
      const user = await requireRole(req, ['head_manager']);
      const { loan_id, reason } = await req.json();
      const { data: loan } = await svc
        .from('loans')
        .select('outstanding_balance, penalty_amount')
        .eq('id', loan_id)
        .single();

      await svc.from('loans').update({
        penalty_amount: 0,
        has_penalty: false,
        outstanding_balance: (loan?.outstanding_balance ?? 0) - (loan?.penalty_amount ?? 0),
        updated_at: new Date().toISOString(),
      }).eq('id', loan_id);

      await svc.from('audit_logs').insert({
        user_id: user.id, action: 'waive_penalty', table_name: 'loans',
        record_id: loan_id, new_values: { reason },
      });
      return Response.json({ message: 'Penalty waived' }, { headers: corsHeaders });
    }

    // POST / — disburse loan via Xendit (head_manager only)
    if (req.method === 'POST') {
      const user = await requireRole(req, ['head_manager']);
      const body = await req.json();
      const { loan_id, disbursement_channel, account_number, account_name } = body as Record<string, string>;

      if (!loan_id) {
        return Response.json({ error: 'loan_id is required' }, { status: 400, headers: corsHeaders });
      }

      const { data: loan } = await svc
        .from('loans')
        .select('*, lender:users!loans_lender_id_fkey(first_name, last_name, email, phone)')
        .eq('id', loan_id)
        .single();

      if (!loan || loan.status !== 'approved') {
        return Response.json(
          { error: 'Loan must be in approved status to disburse' },
          { status: 400, headers: corsHeaders },
        );
      }

      const lender = loan.lender as Record<string, string>;
      const lenderPhone = lender?.phone ?? '';
      const lenderEmail = lender?.email ?? '';
      const lenderName = `${lender?.first_name ?? ''} ${lender?.last_name ?? ''}`.trim();

      // Determine disbursement channel: use provided or fall back to phone (GCash default)
      const channel = disbursement_channel ?? 'gcash';
      const bankCode = XENDIT_BANK_CODES[channel] ?? 'GCASH';
      const recipientAccount = account_number ?? lenderPhone.replace(/^0/, '');
      const recipientName = account_name ?? lenderName;

      if (!recipientAccount) {
        return Response.json(
          { error: 'Lender account number is required for disbursement. Provide account_number in the request.' },
          { status: 400, headers: corsHeaders },
        );
      }

      const externalId = `disbursement_${loan_id}`;

      let xenditDisbursementId: string | null = null;

      try {
        const disbursement = await createDisbursement({
          externalId,
          bankCode,
          accountHolderName: recipientName,
          accountNumber: recipientAccount,
          description: `Jireta Loan Disbursement — ${loan_id.substring(0, 8).toUpperCase()}`,
          amount: loan.principal_amount,
          emailTo: lenderEmail ? [lenderEmail] : [],
        });
        xenditDisbursementId = disbursement.id;
      } catch (xenditErr) {
        console.error('Xendit disbursement error:', xenditErr);
        return Response.json(
          { error: `Disbursement failed: ${(xenditErr as Error).message}` },
          { status: 502, headers: corsHeaders },
        );
      }

      const disbursedAt = new Date();
      const termDays = loan.term_days ?? 30;
      const maturityDate = new Date(disbursedAt);
      maturityDate.setDate(maturityDate.getDate() + termDays);

      await svc.from('loans').update({
        status: 'active',
        disbursed_by_id: user.id,
        disbursed_at: disbursedAt.toISOString(),
        maturity_date: maturityDate.toISOString(),
        xendit_disbursement_id: xenditDisbursementId,
        disbursement_channel: channel,
        updated_at: new Date().toISOString(),
      }).eq('id', loan_id);

      const scheduleRows = generateSchedule(
        loan_id,
        loan.total_payable,
        loan.installment_amount,
        termDays,
        loan.payment_frequency,
        disbursedAt,
      );
      if (scheduleRows.length > 0) {
        await svc.from('payment_schedules').insert(scheduleRows);
      }

      await svc.from('notifications').insert({
        user_id: loan.lender_id,
        title: 'Loan Disbursed!',
        body: `₱${loan.principal_amount.toLocaleString()} has been sent to your ${channel.toUpperCase()} account.`,
        category: 'loan_disbursed',
        reference_id: loan_id,
      });

      await pushToUser(svc, loan.lender_id, PushTemplates.loanDisbursed(loan.principal_amount), {
        type: 'loan_disbursed',
        loan_id,
      });

      if (lenderPhone) {
        await sendLoanDisbursed(lenderPhone, {
          firstName: lender?.first_name ?? 'Borrower',
          amount: loan.principal_amount,
        });
      }

      if (lenderEmail) {
        await emailLoanDisbursed({
          to: lenderEmail,
          firstName: lender?.first_name ?? 'Borrower',
          amount: loan.principal_amount,
          maturityDate: maturityDate.toLocaleDateString('en-PH', {
            year: 'numeric', month: 'long', day: 'numeric',
          }),
        });
      }

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'disburse',
        table_name: 'loans',
        record_id: loan_id,
        new_values: {
          status: 'active',
          disbursed_at: disbursedAt.toISOString(),
          xendit_disbursement_id: xenditDisbursementId,
          channel,
        },
      });

      return Response.json({
        message: 'Loan disbursed successfully',
        xendit_disbursement_id: xenditDisbursementId,
        disbursement_channel: channel,
      }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});

function generateSchedule(
  loanId: string,
  totalPayable: number,
  installmentAmount: number,
  termDays: number,
  frequency: string,
  startDate: Date,
): Record<string, unknown>[] {
  const rows: Record<string, unknown>[] = [];

  if (frequency === 'daily') {
    for (let i = 1; i <= termDays; i++) {
      const due = new Date(startDate);
      due.setDate(due.getDate() + i);
      rows.push({ loan_id: loanId, installment_number: i, amount_due: installmentAmount, amount_paid: 0, due_date: due.toISOString().substring(0, 10), is_paid: false });
    }
  } else if (frequency === 'weekly') {
    const weeks = Math.ceil(termDays / 7);
    for (let i = 1; i <= weeks; i++) {
      const due = new Date(startDate);
      due.setDate(due.getDate() + i * 7);
      rows.push({ loan_id: loanId, installment_number: i, amount_due: installmentAmount, amount_paid: 0, due_date: due.toISOString().substring(0, 10), is_paid: false });
    }
  } else {
    const months = Math.ceil(termDays / 30);
    for (let i = 1; i <= months; i++) {
      const due = new Date(startDate);
      due.setMonth(due.getMonth() + i);
      const lastDay = new Date(due.getFullYear(), due.getMonth() + 1, 0);
      rows.push({ loan_id: loanId, installment_number: i, amount_due: installmentAmount, amount_paid: 0, due_date: lastDay.toISOString().substring(0, 10), is_paid: false });
    }
  }
  return rows;
}