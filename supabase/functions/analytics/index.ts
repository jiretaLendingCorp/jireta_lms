// supabase/functions/analytics/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*analytics/, '');
    const svc = getServiceClient();

    if (path === '/kpi' && req.method === 'GET') {
      await requireRole(req, ['head_manager', 'employee']);

      const now = new Date();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

      const [activeLoans, portfolioData, newLoans, pendingPayments, overdueLoans,
             lifetimeCounts, lifetimeDisbursed, lifetimeCollected] =
        await Promise.all([
          svc.from('loans').select('id', { count: 'exact' }).eq('status', 'active'),
          svc.from('loans').select('outstanding_balance').eq('status', 'active'),
          svc.from('loans').select('id', { count: 'exact' }).gte('created_at', startOfMonth),
          svc.from('payments').select('amount').eq('status', 'verified').gte('verified_at', startOfMonth),
          svc.from('loans').select('id', { count: 'exact' }).eq('status', 'active').lt(
            'maturity_date',
            new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
          ),
          // Lifetime user counts
          Promise.all([
            svc.from('users').select('id', { count: 'exact' }).eq('role', 'lender'),
            svc.from('users').select('id', { count: 'exact' }).eq('role', 'rider'),
            svc.from('users').select('id', { count: 'exact' }).eq('role', 'employee'),
            svc.from('loans').select('id', { count: 'exact' }),
          ]),
          // Total disbursed (all-time principal_amount on active/closed loans)
          svc.from('loans').select('principal_amount').in_('status', ['active', 'closed', 'overdue']),
          // Total collected all-time
          svc.from('payments').select('amount').eq('status', 'verified'),
        ]);

      const portfolioValue = (portfolioData.data ?? []).reduce(
        (sum: number, l: Record<string, number>) => sum + l.outstanding_balance,
        0,
      );

      const revenueMtd = (pendingPayments.data ?? []).reduce(
        (sum: number, p: Record<string, number>) => sum + p.amount,
        0,
      );

      const par30 = activeLoans.count
        ? ((overdueLoans.count ?? 0) / activeLoans.count) * 100
        : 0;

      const collectionRate = activeLoans.count ? Math.max(0, 100 - par30) : 0;

      const [lenderCount, riderCount, employeeCount, allLoans] = lifetimeCounts;
      const totalDisbursed = (lifetimeDisbursed.data ?? []).reduce(
        (sum: number, l: Record<string, number>) => sum + (l.principal_amount ?? 0), 0,
      );
      const totalCollectedAllTime = (lifetimeCollected.data ?? []).reduce(
        (sum: number, p: Record<string, number>) => sum + (p.amount ?? 0), 0,
      );

      return Response.json(
        {
          active_loans: activeLoans.count ?? 0,
          portfolio_value: portfolioValue,
          collection_rate: collectionRate,
          par30,
          new_loans_mtd: newLoans.count ?? 0,
          revenue_mtd: revenueMtd,
          active_loans_change: 0,
          portfolio_change: 0,
          collection_rate_change: 0,
          par30_change: 0,
          new_loans_change: 0,
          revenue_change: 0,
          // ── Lifetime metrics ──────────────────────────────────────────────
          total_loans_ever: allLoans.count ?? 0,
          total_lenders: lenderCount.count ?? 0,
          total_riders: riderCount.count ?? 0,
          total_employees: employeeCount.count ?? 0,
          total_disbursed: totalDisbursed,
          total_collected: totalCollectedAllTime,
        },
        { headers: corsHeaders },
      );
    }

    if (path === '/charts' && req.method === 'GET') {
      await requireRole(req, ['head_manager', 'employee']);

      const now = new Date();
      const loanVolumeData = [];
      for (let i = 11; i >= 0; i--) {
        const month = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const nextMonth = new Date(now.getFullYear(), now.getMonth() - i + 1, 1);
        const { count } = await svc
          .from('loans')
          .select('id', { count: 'exact' })
          .gte('created_at', month.toISOString())
          .lt('created_at', nextMonth.toISOString());
        loanVolumeData.push({ month: 12 - i, count: count ?? 0 });
      }

      const [statusData, interestData, penaltyData] = await Promise.all([
        svc.from('loans').select('status'),
        svc.from('payments').select('amount').eq('status', 'verified').neq('method', 'cash'),
        svc.from('loans').select('penalty_amount').gt('penalty_amount', 0),
      ]);

      const statusCounts: Record<string, number> = {};
      (statusData.data ?? []).forEach((l: Record<string, string>) => {
        statusCounts[l.status] = (statusCounts[l.status] ?? 0) + 1;
      });
      const totalLoans = Object.values(statusCounts).reduce((a, b) => a + b, 0);
      const statusDistribution: Record<string, number> = {};
      for (const [status, count] of Object.entries(statusCounts)) {
        statusDistribution[status] = totalLoans > 0 ? (count / totalLoans) * 100 : 0;
      }

      const totalInterest = (interestData.data ?? []).reduce(
        (sum: number, p: Record<string, number>) => sum + p.amount,
        0,
      );
      const totalPenalty = (penaltyData.data ?? []).reduce(
        (sum: number, l: Record<string, number>) => sum + l.penalty_amount,
        0,
      );

      const userGrowth = [];
      for (let i = 5; i >= 0; i--) {
        const month = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const nextMonth = new Date(now.getFullYear(), now.getMonth() - i + 1, 1);
        const { count } = await svc
          .from('users')
          .select('id', { count: 'exact' })
          .eq('role', 'lender')
          .gte('created_at', month.toISOString())
          .lt('created_at', nextMonth.toISOString());
        userGrowth.push({ month: 6 - i, count: count ?? 0 });
      }

      return Response.json(
        {
          loan_volume: loanVolumeData,
          status_distribution: statusDistribution,
          collection_performance: [],
          total_interest: totalInterest,
          total_penalty: totalPenalty,
          user_growth: userGrowth,
          overdue_aging: { bucket_30: 0, bucket_60: 0, bucket_90: 0, bucket_over_90: 0 },
        },
        { headers: corsHeaders },
      );
    }

    if (path === '/audit' && req.method === 'GET') {
      await requireRole(req, ['head_manager']);
      const page = parseInt(url.searchParams.get('page') ?? '1');
      const limit = 50;

      let query = svc
        .from('audit_logs')
        .select(`*, actor:users!audit_logs_user_id_fkey(first_name, last_name)`)
        .order('created_at', { ascending: false })
        .range((page - 1) * limit, page * limit - 1);

      const userId = url.searchParams.get('user_id');
      const action = url.searchParams.get('action');
      const tableName = url.searchParams.get('table_name');
      const from = url.searchParams.get('from');
      const to = url.searchParams.get('to');

      if (userId) query = query.eq('user_id', userId);
      if (action) query = query.eq('action', action);
      if (tableName) query = query.eq('table_name', tableName);
      if (from) query = query.gte('created_at', from);
      if (to) query = query.lte('created_at', to);

      const { data, error } = await query;
      if (error) throw error;

      const logs = (data ?? []).map((l: Record<string, unknown>) => ({
        ...l,
        user_name: l.actor
          ? `${(l.actor as Record<string, string>).first_name} ${(l.actor as Record<string, string>).last_name}`
          : null,
        actor: undefined,
      }));

      return Response.json({ logs }, { headers: corsHeaders });
    }

    if (path === '/rider-stats' && req.method === 'GET') {
      const user = await requireRole(req, ['rider']);

      const [pending, completed, totalCollected] = await Promise.all([
        svc.from('rider_assignments').select('id', { count: 'exact' })
          .eq('rider_id', user.id).eq('status', 'pending'),
        svc.from('rider_assignments').select('id', { count: 'exact' })
          .eq('rider_id', user.id).eq('status', 'completed'),
        svc.from('rider_assignments').select('amount_collected')
          .eq('rider_id', user.id).eq('status', 'completed'),
      ]);

      const total = (totalCollected.data ?? []).reduce(
        (sum: number, a: Record<string, number | null>) =>
          sum + (a.amount_collected ?? 0),
        0,
      );

      return Response.json(
        {
          pending_count: pending.count ?? 0,
          completed_count: completed.count ?? 0,
          total_collected: total,
        },
        { headers: corsHeaders },
      );
    }

    // GET /report — generates a typed report for HM/employee
    if (path === '/report' && req.method === 'GET') {
      await requireRole(req, ['head_manager', 'employee']);
      const params = url.searchParams;
      const type     = params.get('type') ?? 'loans';
      const dateFrom = params.get('date_from');
      const dateTo   = params.get('date_to');

      const fromTs = dateFrom ? new Date(dateFrom).toISOString() : null;
      const toTs   = dateTo
        ? new Date(new Date(dateTo).setHours(23, 59, 59, 999)).toISOString()
        : null;

      let reportData: Record<string, unknown> = {};

      if (type === 'loans') {
        let q = svc.from('loans').select('id, status, principal_amount, created_at', { count: 'exact' });
        if (fromTs) q = q.gte('created_at', fromTs);
        if (toTs)   q = q.lte('created_at', toTs);
        const { data, count } = await q;
        const disbursed = (data ?? []).reduce((s: number, l: Record<string, number>) => s + (l.principal_amount ?? 0), 0);
        reportData = {
          total_loans: count ?? 0,
          total_disbursed: disbursed,
          active: (data ?? []).filter((l: Record<string, string>) => l.status === 'active').length,
          closed: (data ?? []).filter((l: Record<string, string>) => l.status === 'closed').length,
          pending: (data ?? []).filter((l: Record<string, string>) => l.status === 'pending').length,
          overdue: (data ?? []).filter((l: Record<string, string>) => l.status === 'overdue').length,
        };
      } else if (type === 'payments') {
        let q = svc.from('payments').select('id, status, amount, created_at', { count: 'exact' });
        if (fromTs) q = q.gte('created_at', fromTs);
        if (toTs)   q = q.lte('created_at', toTs);
        const { data, count } = await q;
        const verified = (data ?? []).filter((p: Record<string, string>) => p.status === 'verified');
        const collected = verified.reduce((s: number, p: Record<string, number>) => s + (p.amount ?? 0), 0);
        reportData = {
          total_payments: count ?? 0,
          total_collected: collected,
          verified: verified.length,
          pending: (data ?? []).filter((p: Record<string, string>) => p.status === 'pending').length,
          rejected: (data ?? []).filter((p: Record<string, string>) => p.status === 'rejected').length,
        };
      } else if (type === 'users') {
        const [lenders, riders, employees] = await Promise.all([
          svc.from('users').select('id', { count: 'exact' }).eq('role', 'lender'),
          svc.from('users').select('id', { count: 'exact' }).eq('role', 'rider'),
          svc.from('users').select('id', { count: 'exact' }).eq('role', 'employee'),
        ]);
        reportData = {
          total_lenders: lenders.count ?? 0,
          total_riders: riders.count ?? 0,
          total_employees: employees.count ?? 0,
          total_users: (lenders.count ?? 0) + (riders.count ?? 0) + (employees.count ?? 0),
        };
      } else if (type === 'collections') {
        let q = svc.from('payments').select('amount, status, created_at');
        if (fromTs) q = q.gte('created_at', fromTs);
        if (toTs)   q = q.lte('created_at', toTs);
        const { data } = await q;
        const verified = (data ?? []).filter((p: Record<string, string>) => p.status === 'verified');
        const collected = verified.reduce((s: number, p: Record<string, number>) => s + (p.amount ?? 0), 0);
        const expected_q = await svc.from('loans').select('outstanding_balance').eq('status', 'active');
        const expected = (expected_q.data ?? []).reduce((s: number, l: Record<string, number>) => s + (l.outstanding_balance ?? 0), 0);
        reportData = {
          total_collected: collected,
          total_expected: expected,
          collection_count: verified.length,
          collection_rate: expected > 0 ? ((collected / expected) * 100).toFixed(2) : '0.00',
        };
      } else if (type === 'overdue') {
        const now = new Date();
        const { data } = await svc.from('loans')
          .select('id, principal_amount, outstanding_balance, maturity_date')
          .eq('status', 'active')
          .lt('maturity_date', now.toISOString());
        const bucket30  = (data ?? []).filter((l: Record<string, string>) => daysDiff(now, l.maturity_date) <= 30);
        const bucket60  = (data ?? []).filter((l: Record<string, string>) => { const d = daysDiff(now, l.maturity_date); return d > 30 && d <= 60; });
        const bucket90  = (data ?? []).filter((l: Record<string, string>) => { const d = daysDiff(now, l.maturity_date); return d > 60 && d <= 90; });
        const bucketOvr = (data ?? []).filter((l: Record<string, string>) => daysDiff(now, l.maturity_date) > 90);
        reportData = {
          total_overdue: (data ?? []).length,
          bucket_1_30:   bucket30.length,
          bucket_31_60:  bucket60.length,
          bucket_61_90:  bucket90.length,
          bucket_over_90: bucketOvr.length,
          overdue_balance: (data ?? []).reduce((s: number, l: Record<string, number>) => s + (l.outstanding_balance ?? 0), 0),
        };
      }

      return Response.json(
        {
          report_type: type,
          date_from: dateFrom,
          date_to: dateTo,
          generated_at: new Date().toISOString(),
          data: reportData,
        },
        { headers: corsHeaders },
      );
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});

function daysDiff(now: Date, isoDate: string): number {
  return Math.floor((now.getTime() - new Date(isoDate).getTime()) / (1000 * 60 * 60 * 24));
}