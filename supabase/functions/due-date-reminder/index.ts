// supabase/functions/due-date-reminder/index.ts
// Triggered by external cron daily (e.g. cron-job.org, Supabase Cron)
// hitting this endpoint with Authorization: Bearer <CRON_SECRET>
// Sends a reminder exactly 2 days before each unpaid schedule's due_date.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getServiceClient } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendPaymentDueReminder } from '../_shared/sms.ts';
import { emailPaymentDueReminder } from '../_shared/email.ts';

const REMINDER_DAYS_BEFORE = 2;

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  const authHeader = req.headers.get('Authorization');
  const cronSecret = Deno.env.get('CRON_SECRET');
  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders });
  }

  try {
    const svc = getServiceClient();
    const now = new Date();
    const targetDate = new Date(now);
    targetDate.setDate(targetDate.getDate() + REMINDER_DAYS_BEFORE);
    const targetDateStr = targetDate.toISOString().substring(0, 10);

    // Find unpaid schedules due exactly REMINDER_DAYS_BEFORE from now,
    // for loans that are still active, that haven't already been reminded today.
    const { data: schedules, error } = await svc
      .from('payment_schedules')
      .select(`
        id, loan_id, amount_due, due_date, reminder_sent_at,
        loans!inner(lender_id, status, outstanding_balance)
      `)
      .eq('due_date', targetDateStr)
      .eq('is_paid', false)
      .eq('loans.status', 'active');

    if (error) throw error;

    let sent = 0;

    for (const schedule of schedules ?? []) {
      // Skip if a reminder was already sent for this schedule today
      if (schedule.reminder_sent_at) {
        const lastSent = new Date(schedule.reminder_sent_at as string);
        if (lastSent.toISOString().substring(0, 10) === now.toISOString().substring(0, 10)) {
          continue;
        }
      }

      const loan = schedule.loans as unknown as {
        lender_id: string;
        status: string;
        outstanding_balance: number;
      };

      const { data: lenderProfile } = await svc
        .from('users')
        .select('first_name, email, phone')
        .eq('id', loan.lender_id)
        .single();

      const dueDateFormatted = new Date(schedule.due_date as string).toLocaleDateString('en-PH', {
        year: 'numeric', month: 'long', day: 'numeric',
      });

      await svc.from('notifications').insert({
        user_id: loan.lender_id,
        title: `Payment Due in ${REMINDER_DAYS_BEFORE} Days`,
        body: `Your payment of ₱${(schedule.amount_due as number).toLocaleString()} is due on ${dueDateFormatted}.`,
        category: 'payment_due',
        reference_id: schedule.loan_id as string,
      });

      await pushToUser(
        svc,
        loan.lender_id,
        PushTemplates.paymentDue(schedule.amount_due as number, REMINDER_DAYS_BEFORE),
        { type: 'payment_due', loan_id: schedule.loan_id as string },
      );

      if (lenderProfile?.phone) {
        await sendPaymentDueReminder(lenderProfile.phone, {
          firstName: lenderProfile.first_name ?? 'Borrower',
          amount: schedule.amount_due as number,
          dueDate: dueDateFormatted,
          daysLeft: REMINDER_DAYS_BEFORE,
        });
      }

      if (lenderProfile?.email) {
        await emailPaymentDueReminder({
          to: lenderProfile.email,
          firstName: lenderProfile.first_name ?? 'Borrower',
          amount: schedule.amount_due as number,
          dueDate: dueDateFormatted,
          daysLeft: REMINDER_DAYS_BEFORE,
          outstandingBalance: loan.outstanding_balance,
        });
      }

      await svc
        .from('payment_schedules')
        .update({ reminder_sent_at: now.toISOString() })
        .eq('id', schedule.id);

      sent++;
    }

    return Response.json(
      {
        message: `Due-date reminders complete. Sent ${sent} reminder(s).`,
        checked: (schedules ?? []).length,
        sent,
        target_date: targetDateStr,
        computed_at: now.toISOString(),
      },
      { headers: corsHeaders },
    );
  } catch (error) {
    console.error('Due-date reminder error:', error);
    return Response.json(
      { error: 'Due-date reminder job failed' },
      { status: 500, headers: corsHeaders },
    );
  }
});