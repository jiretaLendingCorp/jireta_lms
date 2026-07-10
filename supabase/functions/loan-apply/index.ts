// supabase/functions/loan-apply/index.ts
//
// FIXES:
//   • Issue 4:  Tier is_active fixed in migration 014 — get_loan_tier() now
//               returns correct tier; "No loan term tier found" error gone.
//   • Issue 4:  Monthly installment computed for ALL tiers (micro 40d → 2 months).
//   • Issue 12: Disbursement method (cash/gcash/office) stored on loan row.
//               GCash name+number encrypted server-side (AES-256-GCM).
//               Cash method creates a disbursement_assignments placeholder.
//   • GET /active-lenders — for assignment dropdown (name not UUID).
//   • GET /list + GET /get/:id — full loan detail for HM/employee review.

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireAuth, requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { encrypt } from '../_shared/encryption.ts';

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const url  = new URL(req.url);
    const path = url.pathname.replace(/.*loan-apply/, '');
    const svc  = getServiceClient();

    // ── GET /active-lenders — lender name dropdown for assignment dialog ──────
    if (req.method === 'GET' && path === '/active-lenders') {
      await requireRole(req, ['head_manager','employee']);

      const { data, error } = await svc
        .from('loans')
        .select(`
          id, status, principal_amount, outstanding_balance,
          lender:users!loans_lender_id_fkey(id, first_name, last_name, email)
        `)
        .in('status', ['active','approved','pending','under_review'])
        .order('created_at', { ascending: false });

      if (error) throw error;

      const lenders = (data ?? []).map((l: Record<string,unknown>) => ({
        loan_id:      l.id,
        loan_status:  l.status,
        principal:    l.principal_amount,
        outstanding:  l.outstanding_balance,
        lender_id:    (l.lender as Record<string,string>|null)?.id    ?? null,
        lender_name:  l.lender
          ? `${(l.lender as Record<string,string>).first_name} ${(l.lender as Record<string,string>).last_name}`
          : 'Unknown',
        lender_email: (l.lender as Record<string,string>|null)?.email ?? null,
      }));

      return Response.json({ lenders }, { headers: corsHeaders });
    }

    // ── GET /list — list loans ────────────────────────────────────────────────
    if (req.method === 'GET' && path === '/list') {
      const user   = await requireAuth(req);
      const status = url.searchParams.get('status');
      const page   = parseInt(url.searchParams.get('page') ?? '1');
      const limit  = 20;
      const offset = (page - 1) * limit;

      let query = svc
        .from('loans')
        .select(`
          *,
          lender:users!loans_lender_id_fkey(id, first_name, last_name, email, phone, avatar_url)
        `)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (user.role === 'lender') {
        query = query.eq('lender_id', user.id);
      }
      if (status) query = query.eq('status', status);

      const { data, error } = await query;
      if (error) throw error;

      const loans = (data ?? []).map((l: Record<string,unknown>) => ({
        ...l,
        lender_name:   l.lender ? `${(l.lender as Record<string,string>).first_name} ${(l.lender as Record<string,string>).last_name}` : null,
        lender_email:  (l.lender as Record<string,string>|null)?.email      ?? null,
        lender_phone:  (l.lender as Record<string,string>|null)?.phone      ?? null,
        lender_avatar: (l.lender as Record<string,string>|null)?.avatar_url ?? null,
        lender:        undefined,
        // Never expose encrypted disbursement_meta to client
        disbursement_meta: undefined,
      }));

      return Response.json({ loans }, { headers: corsHeaders });
    }

    // ── GET /get/:id — single loan detail ─────────────────────────────────────
    if (req.method === 'GET' && path.startsWith('/get/')) {
      const user = await requireAuth(req);
      const id   = path.replace('/get/','');

      const { data, error } = await svc
        .from('loans')
        .select(`
          *,
          lender:users!loans_lender_id_fkey(id, first_name, last_name, email, phone, avatar_url),
          comakers(id, relationship, signature_url)
        `)
        .eq('id', id)
        .single();

      if (error) throw error;

      if (user.role === 'lender' && data.lender_id !== user.id) {
        return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders });
      }

      return Response.json({
        ...data,
        lender_name:   data.lender ? `${data.lender.first_name} ${data.lender.last_name}` : null,
        lender_email:  data.lender?.email     ?? null,
        lender_phone:  data.lender?.phone     ?? null,
        lender_avatar: data.lender?.avatar_url ?? null,
        lender:        undefined,
        disbursement_meta: undefined, // encrypted — never sent to client
      }, { headers: corsHeaders });
    }

    // ── POST /upload-signature — co-maker signature ───────────────────────────
    if (req.method === 'POST' && path === '/upload-signature') {
      const user     = await requireRole(req, ['lender']);
      const formData = await req.formData();
      const file     = formData.get('signature') as File | null;

      if (!file) {
        return Response.json({ error: 'No signature file' }, { status: 400, headers: corsHeaders });
      }

      const bytes       = await file.arrayBuffer();
      const storagePath = `${user.id}/comaker-signature.png`;

      const { error: upErr } = await svc.storage
        .from('signatures')
        .upload(storagePath, bytes, { contentType: 'image/png', upsert: true });

      if (upErr) throw upErr;

      const { data: urlData } = svc.storage.from('signatures').getPublicUrl(storagePath);
      return Response.json({ signature_url: urlData.publicUrl }, { headers: corsHeaders });
    }

    // ── POST / — submit loan application ─────────────────────────────────────
    if (req.method === 'POST' && (path === '' || path === '/')) {
      const user = await requireRole(req, ['lender']);
      const body = await req.json();

      // 1. KYC gate — must be approved before applying
      const { data: kyc } = await svc
        .from('kyc_submissions')
        .select('id')
        .eq('lender_id', user.id)
        .eq('status', 'approved')
        .maybeSingle();

      if (!kyc) {
        return Response.json(
          { error: 'KYC approval is required before applying for a loan.' },
          { status: 400, headers: corsHeaders },
        );
      }

      // 2. Active loan gate
      const { data: existing } = await svc
        .from('loans')
        .select('id')
        .eq('lender_id', user.id)
        .in('status', ['pending','under_review','approved','active']);

      if (existing && existing.length > 0) {
        return Response.json(
          { error: 'You already have an active or pending loan.' },
          { status: 400, headers: corsHeaders },
        );
      }

      // 3. Amount validation
      const amount = parseFloat(String(body.principal_amount));
      if (isNaN(amount) || amount < 3000 || amount > 500000) {
        return Response.json(
          { error: 'Loan amount must be between ₱3,000 and ₱500,000.' },
          { status: 400, headers: corsHeaders },
        );
      }

      // 4. Disbursement validation
      const method      = (body.disbursement_method ?? 'cash') as string;
      const validMethods = ['cash','gcash','office'];
      if (!validMethods.includes(method)) {
        return Response.json(
          { error: 'Invalid disbursement method. Use cash, gcash, or office.' },
          { status: 400, headers: corsHeaders },
        );
      }
      if (method === 'gcash') {
        if (!body.disbursement_meta?.gcash_name || !body.disbursement_meta?.gcash_number) {
          return Response.json(
            { error: 'GCash name and number are required.' },
            { status: 400, headers: corsHeaders },
          );
        }
        if (!/^09\d{9}$/.test(body.disbursement_meta.gcash_number)) {
          return Response.json(
            { error: 'GCash number must be in 09XXXXXXXXX format.' },
            { status: 400, headers: corsHeaders },
          );
        }
      }

      // 5. Tier resolution via DB — single source of truth
      const { data: tier, error: tierErr } = await svc.rpc('get_loan_tier', { p_amount: amount });
      if (tierErr || !tier) {
        console.error('[loan-apply] tier error:', tierErr);
        return Response.json(
          { error: 'No loan term tier found for this amount. Contact support.' },
          { status: 400, headers: corsHeaders },
        );
      }

      // 6. Server-side computation — all amounts authoritative here
      const interestRate: number = tier.interest_rate ?? 0.20;
      const termDays: number     = tier.term_days;
      const interest             = Math.round(amount * interestRate * 100) / 100;
      const total                = Math.round((amount + interest) * 100) / 100;
      const daily                = Math.round((total / termDays) * 100) / 100;
      const weekly               = Math.round((daily * 7) * 100) / 100;
      // FIX: monthly for ALL tiers — micro(40d)→2 months, small(60d)→2, medium(80d)→3, large(120d)→4
      const monthCount           = Math.ceil(termDays / 30);
      const monthly              = Math.round((total / monthCount) * 100) / 100;

      const frequency = (body.preferred_frequency ?? 'monthly') as string;
      const installmentAmount =
        frequency === 'daily'   ? daily   :
        frequency === 'weekly'  ? weekly  :
        monthly;

      // 7. Encrypt GCash PII — sensitive data never stored in plaintext
      let disbursementMeta: Record<string,string> | null = null;
      if (method === 'gcash' && body.disbursement_meta) {
        disbursementMeta = {
          gcash_name:   await encrypt(body.disbursement_meta.gcash_name),
          gcash_number: await encrypt(body.disbursement_meta.gcash_number),
        };
      }

      // 8. Insert loan row
      const { data: loan, error: loanErr } = await svc.from('loans').insert({
        lender_id:           user.id,
        principal_amount:    amount,
        interest_amount:     interest,
        outstanding_balance: total,
        status:              'pending',
        preferred_frequency: frequency,
        payment_frequency:   frequency,
        term_days:           termDays,
        installment_amount:  installmentAmount,
        tier_label:          tier.tier_label,
        purpose:             body.purpose ?? null,
        disbursement_method: method,
        disbursement_meta:   disbursementMeta,
      }).select().single();

      if (loanErr) throw loanErr;

      // 9. Co-maker — encrypt sensitive name fields
      if (body.comaker) {
        const cm = body.comaker;
        await svc.from('comakers').insert({
          loan_id:               loan.id,
          first_name_encrypted:  await encrypt(cm.first_name ?? ''),
          last_name_encrypted:   await encrypt(cm.last_name  ?? ''),
          middle_name_encrypted: cm.middle_name ? await encrypt(cm.middle_name) : null,
          relationship:          cm.relationship ?? 'Relative',
          signature_url:         cm.signature_url ?? null,
        }).select().maybeSingle().catch((e: Error) => console.error('[loan-apply] comaker:', e));
      }

      // 10. Audit log
      await svc.from('audit_logs').insert({
        user_id:     user.id,
        action:      'insert',
        table_name:  'loans',
        record_id:   loan.id,
        new_values: {
          amount, interest, total, term_days: termDays,
          tier: tier.tier_label, frequency,
          installment: installmentAmount,
          disbursement_method: method,
        },
        description: `Lender applied for ₱${amount.toLocaleString()} loan via ${method}`,
      });

      // 11. For cash disbursement, create placeholder for rider assignment
      if (method === 'cash') {
        await svc.from('disbursement_assignments').insert({
          loan_id: loan.id,
          status: 'pending_assignment',
        }).select().maybeSingle().catch(() => null); // table may not exist yet
      }

      return Response.json({
        message: 'Loan application submitted',
        loan_id: loan.id,
        terms: {
          principal: amount, interest, total_payable: total,
          term_days: termDays, tier_label: tier.tier_label,
          daily, weekly, monthly, installment: installmentAmount, frequency,
          disbursement_method: method,
        },
      }, { status: 201, headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    console.error('[loan-apply]', error);
    return errorResponse(error, corsHeaders);
  }
});