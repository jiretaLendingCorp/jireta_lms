// supabase/functions/xendit-webhook/index.ts
// Public webhook endpoint configured in Xendit Dashboard > Settings > Webhooks
// Verifies x-callback-token header against XENDIT_WEBHOOK_TOKEN before processing.
// Handles: invoice.paid (auto-fills the lender's bill/payment) and disbursement events.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getServiceClient } from '../_shared/auth.ts';
import { verifyWebhookToken } from '../_shared/xendit.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendPaymentConfirmed } from '../_shared/sms.ts';
import { emailPaymentConfirmed } from '../_shared/email.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  }

  if (!verifyWebhookToken(req)) {
    return Response.json({ error: 'Invalid webhook token' }, { status: 401, headers: corsHeaders });
  }

  try {
    const svc = getServiceClient();
    const event = await req.json();

    // ─── Invoice events (GCash / Maya / QR payment via Payment Link) ──────────
    // Xendit sends the full invoice object directly as the webhook body for
    // invoice callbacks, with a `status` field of PAID, EXPIRED, etc.
    if (event.external_id && event.status) {
      const externalId = event.external_id as string;
      const status = event.status as string;

      const { data: payment } = await svc
        .from('payments')
        .select('id, loan_id, lender_id, amount, status')
        .eq('reference_number', externalId)
        .maybeSingle();

      if (!payment) {
        console.warn('xendit-webhook: no matching payment for external_id', externalId);
        return Response.json({ received: true, matched: false }, { headers: corsHeaders });
      }

      if (status === 'PAID' || status === 'SETTLED') {
        if (payment.status === 'verified') {
          return Response.json({ received: true, already_processed: true }, { headers: corsHeaders });
        }

        // Auto-fill the bill: mark payment verified immediately (Xendit already
        // confirmed funds via GCash/Maya — no manual staff verification needed).
        await svc.from('payments').update({
          status: 'verified',
          verified_at: new Date().toISOString(),
          xendit_payment_id: event.id ?? event.payment_id ?? null,
        }).eq('id', payment.id);

        const { data: loan } = await svc
          .from('loans')
          .select('outstanding_balance, lender_id')
          .eq('id', payment.loan_id)
          .single();

        const newBalance = Math.max(0, (loan?.outstanding_balance ?? 0) - (payment.amount as number));
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
          .from('users')
          .select('first_name, email, phone')
          .eq('id', payment.lender_id)
          .single();

        await svc.from('notifications').insert({
          user_id: payment.lender_id,
          title: 'Payment Confirmed',
          body: `Your payment of ₱${(payment.amount as number).toLocaleString()} via GCash/Maya has been received.`,
          category: 'payment_confirmed',
          reference_id: payment.loan_id,
        });

        await pushToUser(svc, payment.lender_id, PushTemplates.paymentConfirmed(payment.amount as number), {
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
            referenceNumber: externalId,
            newBalance,
          });
        }

        await svc.from('audit_logs').insert({
          user_id: payment.lender_id,
          action: 'xendit_invoice_paid',
          table_name: 'payments',
          record_id: payment.id,
          new_values: { status: 'verified', xendit_status: status, new_balance: newBalance },
        });
      } else if (status === 'EXPIRED') {
        await svc.from('payments').update({
          status: 'rejected',
          rejection_reason: 'Xendit invoice expired',
        }).eq('id', payment.id);
      }

      return Response.json({ received: true, matched: true }, { headers: corsHeaders });
    }

    // ─── Disbursement events ───────────────────────────────────────────────────
    if (event.external_id && event.amount && (event.status === 'COMPLETED' || event.status === 'FAILED')) {
      const externalId = event.external_id as string;
      const loanIdMatch = externalId.match(/^disbursement_(.+)$/);

      if (loanIdMatch) {
        const loanId = loanIdMatch[1];

        const { data: loan } = await svc
          .from('loans')
          .select('lender_id')
          .eq('id', loanId)
          .maybeSingle();

        if (loan) {
          await svc.from('audit_logs').insert({
            user_id: loan.lender_id,
            action: 'xendit_disbursement_callback',
            table_name: 'loans',
            record_id: loanId,
            new_values: { xendit_status: event.status, disbursement_id: event.id },
          });

          if (event.status === 'FAILED') {
            await svc.from('notifications').insert({
              user_id: loan.lender_id,
              title: 'Disbursement Issue',
              body: 'There was an issue disbursing your loan. Our team has been notified.',
              category: 'general',
              reference_id: loanId,
            });
          }
        } else {
          console.warn('xendit-webhook: no loan found for disbursement external_id', externalId);
        }
      }

      return Response.json({ received: true }, { headers: corsHeaders });
    }

    return Response.json({ received: true, unhandled: true }, { headers: corsHeaders });
  } catch (error) {
    console.error('xendit-webhook error:', error);
    return Response.json({ error: 'Webhook processing failed' }, { status: 500, headers: corsHeaders });
  }
});