// supabase/functions/penalty-compute/index.ts
// Triggered by external cron (e.g. cron-job.org, Supabase Cron, GitHub Actions schedule)
// hitting this endpoint with Authorization: Bearer <CRON_SECRET>
//
// FIXES vs previous version:
//   • Was querying `from('profiles')` — table does not exist; should be `users`.
//     Silent failure caused SMS step to be skipped for every overdue loan.
//   • Penalty rate / grace days were hardcoded; now sourced per-loan from the
//     `loan_term_tiers` table (joined via `loans.tier_label`) with a fallback
//     to `system_settings`.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getServiceClient } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendPenaltyApplied } from '../_shared/sms.ts';

const FALLBACK_PENALTY_RATE = 0.20;
const FALLBACK_GRACE_DAYS   = 30;

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

    // Pull grace-days fallback from system_settings (single-row table).
    const { data: settings } = await svc
      .from('system_settings')
      .select('penalty_rate, penalty_grace_days')
      .limit(1)
      .maybeSingle();
    const globalGraceDays = settings?.penalty_grace_days ?? FALLBACK_GRACE_DAYS;
    const globalPenaltyRate = settings?.penalty_rate ?? FALLBACK_PENALTY_RATE;

    const graceThreshold = new Date(now.getTime() - globalGraceDays * 24 * 60 * 60 * 1000);

    // Join tier so each loan uses its own penalty_rate / grace_days.
    const { data: overdueLoans, error } = await svc
      .from('loans')
      .select(`
        id, total_payable, outstanding_balance, penalty_amount,
        maturity_date, lender_id, tier_label,
        tier:loan_term_tiers!loans_tier_label_fkey(penalty_rate, penalty_grace_days)
      `)
      .eq('status', 'active')
      .lt('maturity_date', graceThreshold.toISOString());

    if (error) throw error;

    let processed = 0;

    for (const loan of overdueLoans ?? []) {
      const maturity = new Date(loan.maturity_date);
      const daysOverdue = Math.floor(
        (now.getTime() - maturity.getTime()) / (1000 * 60 * 60 * 24),
      );

      const tierRow = loan.tier as { penalty_rate?: number; penalty_grace_days?: number } | null;
      const graceDays = tierRow?.penalty_grace_days ?? globalGraceDays;
      const penaltyRate = tierRow?.penalty_rate ?? globalPenaltyRate;

      // Apply grace days per-tier
      const effectiveDaysOverdue = Math.max(0, daysOverdue - graceDays);
      const monthsOverdue = Math.floor(effectiveDaysOverdue / 30);
      if (monthsOverdue <= 0) continue;

      const newPenalty = Math.round(loan.total_payable * penaltyRate * monthsOverdue * 100) / 100;
      const currentPenalty = loan.penalty_amount ?? 0;
      if (newPenalty <= currentPenalty) continue;

      await svc.from('loans').update({
        penalty_amount: newPenalty,
        has_penalty: true,
        days_overdue: daysOverdue,
        outstanding_balance: loan.outstanding_balance + (newPenalty - currentPenalty),
        updated_at: now.toISOString(),
      }).eq('id', loan.id);

      // BUG FIX: table is `users`, not `profiles` (01_schema.sql line 20).
      const { data: lenderProfile } = await svc
        .from('users')
        .select('first_name, phone')
        .eq('id', loan.lender_id)
        .maybeSingle();

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
          tier_label: loan.tier_label,
          penalty_rate: penaltyRate,
          grace_days: graceDays,
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
