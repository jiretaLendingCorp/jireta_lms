// supabase/functions/payment-record/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, requireAuth, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { createInvoice, mapMethodToXendit } from '../_shared/xendit.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendSms } from '../_shared/sms.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*payment-record/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/list') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const status = url.searchParams.get('status');
      const loanId = url.searchParams.get('loan_id');
      const page = parseInt(url.searchParams.get('page') ?? '1');
      const limit = 20;

      let query = svc
        .from('payments')
        .select('*, lender:users!payments_lender_id_fkey(first_name, last_name)')
        .order('created_at', { ascending: false })
        .range((page - 1) * limit, page * limit - 1);

      if (status) query = query.eq('status', status);
      if (loanId) query = query.eq('loan_id', loanId);

      const { data, error } = await query;
      if (error) throw error;

      const payments = (data ?? []).map((p: Record<string, unknown>) => ({
        ...p,
        lender_name: p.lender
          ? `${(p.lender as Record<string, string>).first_name} ${(p.lender as Record<string, string>).last_name}`
          : null,
        lender: undefined,
      }));

      return Response.json({ payments }, { headers: corsHeaders });
    }

    if (req.method === 'GET' && path === '/history') {
      const user = await requireAuth(req);
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
        .from('payments')
        .select('*')
        .eq('loan_id', loanId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      return Response.json({ payments: data ?? [] }, { headers: corsHeaders });
    }

    if (req.method === 'POST') {
      const user = await requireRole(req, ['head_manager', 'employee', 'lender', 'rider']);

      let body: Record<string, unknown>;
      const contentType = req.headers.get('content-type') ?? '';

      if (contentType.includes('multipart/form-data')) {
        const formData = await req.formData();
        body = Object.fromEntries(formData.entries());
      } else {
        body = await req.json();
      }

      const { loan_id, method, amount, collection_date, lat, lng } =
        body as Record<string, string>;

      if (!loan_id || !method) {
        return Response.json(
          { error: 'loan_id and method are required' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: loan } = await svc
        .from('loans')
        .select('lender_id, status, outstanding_balance, installment_amount')
        .eq('id', loan_id)
        .single();

      if (!loan || loan.status !== 'active') {
        return Response.json(
          { error: 'Loan not found or not active' },
          { status: 400, headers: corsHeaders },
        );
      }

      if (user.role === 'lender' && loan.lender_id !== user.id) {
        return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders });
      }

      const payAmount =
        parseFloat(amount as string) ||
        loan.installment_amount ||
        loan.outstanding_balance;

      const { data: lenderProfile } = await svc
        .from('users')
        .select('first_name, last_name, email, phone')
        .eq('id', loan.lender_id)
        .single();

      let paymentUrl: string | null = null;
      let xenditInvoiceId: string | null = null;
      let xenditExternalId: string | null = null;
      let initialStatus = 'pending';

      const externalId = `payment_${loan_id}_${Date.now()}`;

      if (['gcash', 'maya', 'qr'].includes(method)) {
        try {
          const invoice = await createInvoice({
            externalId,
            amount: payAmount,
            description: `Jireta Loan Payment — Loan #${loan_id.substring(0, 8).toUpperCase()}`,
            customer: {
              given_names: lenderProfile
                ? `${lenderProfile.first_name} ${lenderProfile.last_name}`
                : 'Lender',
              email: lenderProfile?.email,
              mobile_number: lenderProfile?.phone
                ? `+63${lenderProfile.phone.replace(/^0/, '')}`
                : undefined,
            },
            paymentMethods: mapMethodToXendit(method),
            currency: 'PHP',
            durationSeconds: 86400,
          });

          paymentUrl = invoice.invoice_url;
          xenditInvoiceId = invoice.id;
          xenditExternalId = externalId;
          initialStatus = 'pending';
        } catch (xenditErr) {
          console.error('Xendit invoice error:', xenditErr);
          return Response.json(
            { error: `Payment gateway error: ${(xenditErr as Error).message}` },
            { status: 502, headers: corsHeaders },
          );
        }
      }

      const { data: payment, error: payErr } = await svc
        .from('payments')
        .insert({
          loan_id,
          lender_id: loan.lender_id,
          amount: payAmount,
          method,
          status: initialStatus,
          xendit_invoice_id: xenditInvoiceId,
          xendit_external_id: xenditExternalId,
          reference_number: externalId,
          created_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (payErr) throw payErr;

      if (method === 'cash') {
        const { data: lenderAddr } = await svc
          .from('users')
          .select('address')
          .eq('id', loan.lender_id)
          .single();

        await svc.from('rider_assignments').insert({
          loan_id,
          lender_id: loan.lender_id,
          payment_id: payment.id,
          amount_to_collect: payAmount,
          collection_date: collection_date ?? new Date().toISOString().substring(0, 10),
          lender_address: lenderAddr?.address ?? null,
          lender_lat: lat ? parseFloat(lat as string) : null,
          lender_lng: lng ? parseFloat(lng as string) : null,
          status: 'pending',
        });

        await svc.from('notifications').insert({
          user_id: loan.lender_id,
          title: 'Cash Collection Requested',
          body: 'A rider will be assigned to collect your payment. You will be notified when assigned.',
          category: 'assignment_new',
          reference_id: payment.id,
        });
      }

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'insert',
        table_name: 'payments',
        record_id: payment.id,
        new_values: { loan_id, method, amount: payAmount, xendit_invoice_id: xenditInvoiceId },
      });

      return Response.json(
        {
          message: 'Payment initiated',
          payment_id: payment.id,
          payment_url: paymentUrl,
          xendit_invoice_id: xenditInvoiceId,
        },
        { status: 201, headers: corsHeaders },
      );
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});