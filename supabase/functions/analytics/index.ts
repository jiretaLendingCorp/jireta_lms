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

      const [activeLoans, portfolioData, newLoans, pendingPayments, overdueLoans] =
        await Promise.all([
          svc.from('loans').select('id', { count: 'exact' }).eq('status', 'active'),
          svc.from('loans').select('outstanding_balance').eq('status', 'active'),
          svc.from('loans').select('id', { count: 'exact' }).gte('created_at', startOfMonth),
          svc.from('payments').select('amount').eq('status', 'verified').gte('verified_at', startOfMonth),
          svc.from('loans').select('id', { count: 'exact' }).eq('status', 'active').lt(
            'maturity_date',
            new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
          ),
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

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});