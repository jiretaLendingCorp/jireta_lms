// supabase/functions/payment-verify/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendPaymentConfirmed } from '../_shared/sms.ts';
import { emailPaymentConfirmed } from '../_shared/email.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*payment-verify/, '');
    const svc = getServiceClient();

    if (req.method === 'POST' && path === '/reject') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const { payment_id, reason } = await req.json();

      const { data: payment } = await svc
        .from('payments')
        .select('loan_id, lender_id, amount')
        .eq('id', payment_id)
        .single();

      await svc.from('payments').update({
        status: 'rejected',
        rejection_reason: reason,
        verified_by_id: user.id,
        verified_at: new Date().toISOString(),
      }).eq('id', payment_id);

      if (payment) {
        await svc.from('notifications').insert({
          user_id: payment.lender_id,
          title: 'Payment Rejected',
          body: `Your payment of ₱${(payment.amount as number).toLocaleString()} was rejected. Reason: ${reason}`,
          category: 'payment_overdue',
          reference_id: payment.loan_id,
        });
      }

      await svc.from('audit_logs').insert({
        user_id: user.id, action: 'reject', table_name: 'payments', record_id: payment_id,
        new_values: { status: 'rejected', reason },
      });

      return Response.json({ message: 'Payment rejected' }, { headers: corsHeaders });
    }

    if (req.method === 'POST') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const { payment_id } = await req.json();

      const { data: payment } = await svc
        .from('payments')
        .select('*, loans(outstanding_balance, total_payable, lender_id)')
        .eq('id', payment_id)
        .single();

      if (!payment || payment.status !== 'pending') {
        return Response.json({ error: 'Payment not found or not pending' }, { status: 400, headers: corsHeaders });
      }

      await svc.from('payments').update({
        status: 'verified',
        verified_by_id: user.id,
        verified_at: new Date().toISOString(),
      }).eq('id', payment_id);

      const loan = payment.loans;
      const newBalance = Math.max(0, (loan.outstanding_balance as number) - (payment.amount as number));
      const isFullyPaid = newBalance <= 0;

      await svc.from('loans').update({
        outstanding_balance: newBalance,
        status: isFullyPaid ? 'completed' : undefined,
        closed_at: isFullyPaid ? new Date().toISOString() : undefined,
        updated_at: new Date().toISOString(),
      }).eq('id', payment.loan_id);

      const matchingSchedule = await svc
        .from('payment_schedules')
        .select('id')
        .eq('loan_id', payment.loan_id)
        .eq('is_paid', false)
        .order('due_date')
        .limit(1);

      if (matchingSchedule.data?.length) {
        await svc.from('payment_schedules').update({
          is_paid: true,
          amount_paid: payment.amount,
          paid_at: new Date().toISOString(),
        }).eq('id', matchingSchedule.data[0].id);
      }

      const { data: lenderProfile } = await svc
        .from('profiles')
        .select('first_name, email, phone')
        .eq('id', loan.lender_id)
        .single();

      await svc.from('notifications').insert({
        user_id: loan.lender_id,
        title: 'Payment Confirmed',
        body: `Your payment of ₱${(payment.amount as number).toLocaleString()} has been verified.`,
        category: 'payment_confirmed',
        reference_id: payment.loan_id,
      });

      await pushToUser(svc, loan.lender_id, PushTemplates.paymentConfirmed(payment.amount as number), {
        type: 'payment_confirmed',
        loan_id: payment.loan_id,
      });

      if (lenderProfile?.phone) {
        await sendPaymentConfirmed(lenderProfile.phone, {
          firstName: lenderProfile.first_name ?? 'Borrower',
          amount: payment.amount as number,
          newBalance,
        });
      }

      if (lenderProfile?.email) {
        await emailPaymentConfirmed({
          to: lenderProfile.email,
          firstName: lenderProfile.first_name ?? 'Borrower',
          amount: payment.amount as number,
          referenceNumber: (payment.reference_number as string) ?? payment_id,
          newBalance,
        });
      }

      await svc.from('audit_logs').insert({
        user_id: user.id, action: 'verify', table_name: 'payments', record_id: payment_id,
        new_values: { status: 'verified', new_balance: newBalance },
      });

      return Response.json({ message: 'Payment verified', new_balance: newBalance }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});