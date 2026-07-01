// supabase/functions/penalty-compute/index.ts
// Triggered by external cron (e.g. cron-job.org, Supabase Cron, GitHub Actions schedule)
// hitting this endpoint with Authorization: Bearer <CRON_SECRET>

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getServiceClient } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendPenaltyApplied } from '../_shared/sms.ts';

const PENALTY_RATE = 0.20;
const GRACE_DAYS = 30;

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
    const graceThreshold = new Date(now.getTime() - GRACE_DAYS * 24 * 60 * 60 * 1000);

    const { data: overdueLoans, error } = await svc
      .from('loans')
      .select('id, total_payable, outstanding_balance, penalty_amount, maturity_date, lender_id')
      .eq('status', 'active')
      .lt('maturity_date', graceThreshold.toISOString());

    if (error) throw error;

    let processed = 0;

    for (const loan of overdueLoans ?? []) {
      const maturity = new Date(loan.maturity_date);
      const daysOverdue = Math.floor(
        (now.getTime() - maturity.getTime()) / (1000 * 60 * 60 * 24),
      );
      const monthsOverdue = Math.floor(daysOverdue / 30);

      if (monthsOverdue <= 0) continue;

      const newPenalty = loan.total_payable * PENALTY_RATE * monthsOverdue;
      const currentPenalty = loan.penalty_amount ?? 0;

      if (newPenalty <= currentPenalty) continue;

      await svc.from('loans').update({
        penalty_amount: newPenalty,
        has_penalty: true,
        days_overdue: daysOverdue,
        outstanding_balance: loan.outstanding_balance + (newPenalty - currentPenalty),
        updated_at: now.toISOString(),
      }).eq('id', loan.id);

      const { data: lenderProfile } = await svc
        .from('profiles')
        .select('first_name, phone')
        .eq('id', loan.lender_id)
        .single();

      await svc.from('notifications').insert({
        user_id: loan.lender_id,
        title: 'Penalty Applied',
        body: `Your loan is ${daysOverdue} days overdue. A penalty of ₱${newPenalty.toLocaleString()} has been applied.`,
        category: 'penalty_applied',
        reference_id: loan.id,
      });

      await pushToUser(svc, loan.lender_id, PushTemplates.penaltyApplied(newPenalty), {
        type: 'penalty_applied',
        loan_id: loan.id,
      });

      if (lenderProfile?.phone) {
        await sendPenaltyApplied(lenderProfile.phone, {
          firstName: lenderProfile.first_name ?? 'Borrower',
          penalty: newPenalty,
          daysOverdue,
        });
      }

      await svc.from('audit_logs').insert({
        user_id: loan.lender_id,
        action: 'penalty_applied',
        table_name: 'loans',
        record_id: loan.id,
        new_values: {
          penalty_amount: newPenalty,
          days_overdue: daysOverdue,
          months_overdue: monthsOverdue,
        },
      });

      processed++;
    }

    return Response.json(
      {
        message: `Penalty computation complete. Processed ${processed} loans.`,
        processed,
        checked: (overdueLoans ?? []).length,
        computed_at: now.toISOString(),
      },
      { headers: corsHeaders },
    );
  } catch (error) {
    console.error('Penalty compute error:', error);
    return Response.json(
      { error: 'Penalty computation failed' },
      { status: 500, headers: corsHeaders },
    );
  }
});