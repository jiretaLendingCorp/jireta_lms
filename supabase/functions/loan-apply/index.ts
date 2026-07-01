// supabase/functions/loan-apply/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { encrypt } from '../_shared/encryption.ts';

const MIN_AMOUNT = 3000;
const MAX_AMOUNT = 500000;
const INTEREST_RATE = 0.20;

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*loan-apply/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/list') {
      const user = await requireRole(req, ['head_manager', 'employee', 'lender']);
      const status = url.searchParams.get('status');
      const scope = url.searchParams.get('scope');
      const page = parseInt(url.searchParams.get('page') ?? '1');
      const limit = 20;
      const offset = (page - 1) * limit;

      let query = svc
        .from('loans')
        .select(`
          *,
          lender:users!loans_lender_id_fkey(first_name, last_name)
        `)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (scope === 'mine' || user.role === 'lender') {
        query = query.eq('lender_id', user.id);
      }
      if (status) query = query.eq('status', status);

      const { data, error } = await query;
      if (error) throw error;

      const loans = data.map((l: Record<string, unknown>) => ({
        ...l,
        lender_name: l.lender
          ? `${(l.lender as Record<string, string>).first_name} ${(l.lender as Record<string, string>).last_name}`
          : null,
        lender: undefined,
      }));

      return Response.json({ loans }, { headers: corsHeaders });
    }

    if (req.method === 'GET' && path.startsWith('/get/')) {
      const user = await requireRole(req, ['head_manager', 'employee', 'lender']);
      const id = path.replace('/get/', '');

      const { data, error } = await svc
        .from('loans')
        .select(`*, lender:users!loans_lender_id_fkey(first_name, last_name), comakers(*)`)
        .eq('id', id)
        .single();
      if (error) throw error;

      if (user.role === 'lender' && data.lender_id !== user.id) {
        return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders });
      }

      const loan = {
        ...data,
        lender_name: data.lender ? `${data.lender.first_name} ${data.lender.last_name}` : null,
        lender: undefined,
      };

      return Response.json(loan, { headers: corsHeaders });
    }

    if (req.method === 'POST') {
      const user = await requireRole(req, ['lender']);
      const body = await req.json();

      const { data: kyc } = await svc
        .from('kyc_submissions')
        .select('status')
        .eq('lender_id', user.id)
        .eq('status', 'approved')
        .maybeSingle();

      if (!kyc) {
        return Response.json(
          { error: 'KYC approval required before applying for a loan' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: activeLoans } = await svc
        .from('loans')
        .select('id')
        .eq('lender_id', user.id)
        .in('status', ['pending', 'under_review', 'approved', 'active']);

      if (activeLoans && activeLoans.length > 0) {
        return Response.json(
          { error: 'You already have an active or pending loan application' },
          { status: 400, headers: corsHeaders },
        );
      }

      const amount = parseFloat(body.principal_amount);
      if (isNaN(amount) || amount < MIN_AMOUNT || amount > MAX_AMOUNT) {
        return Response.json(
          { error: `Loan amount must be between ₱${MIN_AMOUNT.toLocaleString()} and ₱${MAX_AMOUNT.toLocaleString()}` },
          { status: 400, headers: corsHeaders },
        );
      }

      const interest = amount * INTEREST_RATE;
      const total = amount + interest;

      // total_payable is a GENERATED ALWAYS column (principal + interest) as
      // of migration 005 — Postgres computes it; do not insert it explicitly
      // or the insert is rejected outright.
      const { data: loan, error: loanErr } = await svc.from('loans').insert({
        lender_id: user.id,
        principal_amount: amount,
        interest_amount: interest,
        outstanding_balance: total,
        status: 'pending',
        preferred_frequency: body.preferred_frequency ?? 'monthly',
        purpose: body.purpose,
      }).select().single();

      if (loanErr) throw loanErr;

      if (body.comaker) {
        const cm = body.comaker;
        const encFirstName = await encrypt(cm.first_name);
        const encLastName = await encrypt(cm.last_name);
        const encMiddleName = cm.middle_name ? await encrypt(cm.middle_name) : null;

        await svc.from('comakers').insert({
          loan_id: loan.id,
          first_name_encrypted: encFirstName,
          last_name_encrypted: encLastName,
          middle_name_encrypted: encMiddleName,
          relationship: cm.relationship,
        });
      }

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'insert',
        table_name: 'loans',
        record_id: loan.id,
        new_values: { amount, status: 'pending' },
      });

      return Response.json(
        { message: 'Loan application submitted', loan_id: loan.id },
        { status: 201, headers: corsHeaders },
      );
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});