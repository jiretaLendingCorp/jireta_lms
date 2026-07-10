// supabase/functions/assignment-update/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*assignment-update/, '');
    const svc = getServiceClient();

    if (req.method === 'POST' && path === '/cancel') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const { assignment_id, reason } = await req.json();

      await svc.from('rider_assignments').update({
        status: 'cancelled',
        cancellation_reason: reason,
        updated_at: new Date().toISOString(),
      }).eq('id', assignment_id);

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'cancel',
        table_name: 'rider_assignments',
        record_id: assignment_id,
        new_values: { status: 'cancelled', reason },
      });

      return Response.json({ message: 'Assignment cancelled' }, { headers: corsHeaders });
    }

    if (req.method === 'POST') {
      const user = await requireRole(req, ['rider', 'head_manager', 'employee']);

      let body: Record<string, unknown>;
      const contentType = req.headers.get('content-type') ?? '';

      if (contentType.includes('multipart/form-data')) {
        const formData = await req.formData();
        body = Object.fromEntries(formData.entries());

        const receiptFile = formData.get('receipt') as File | null;
        if (receiptFile) {
          const bytes = await receiptFile.arrayBuffer();
          const ext = receiptFile.name.split('.').pop() ?? 'jpg';
          const storagePath = `receipts/${body.assignment_id}/${Date.now()}.${ext}`;
          await svc.storage.from('receipts').upload(storagePath, bytes, {
            contentType: receiptFile.type,
            upsert: true,
          });
          body.receipt_url = svc.storage.from('receipts').getPublicUrl(storagePath).data.publicUrl;
        }
      } else {
        body = await req.json();
      }

      const { assignment_id, status, failure_reason, amount_collected, receipt_url, notes } = body as Record<string, unknown>;

      if (!assignment_id || !status) {
        return Response.json(
          { error: 'assignment_id and status are required' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: assignment } = await svc
        .from('rider_assignments')
        .select('rider_id, lender_id, loan_id, amount_to_collect, status')
        .eq('id', assignment_id)
        .single();

      if (!assignment) {
        return Response.json({ error: 'Assignment not found' }, { status: 404, headers: corsHeaders });
      }

      if (user.role === 'rider' && assignment.rider_id !== user.id) {
        return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders });
      }

      const { data: riderProfile } = await svc
        .from('users')
        .select('first_name, last_name')
        .eq('id', assignment.rider_id)
        .single();

      const riderFullName = riderProfile
        ? `${riderProfile.first_name ?? ''} ${riderProfile.last_name ?? ''}`.trim()
        : 'Your rider';

      const updates: Record<string, unknown> = {
        status,
        updated_at: new Date().toISOString(),
      };

      if (failure_reason) updates.failure_reason = failure_reason;
      if (receipt_url) updates.receipt_url = receipt_url;
      if (notes) updates.notes = notes;

      if (status === 'in_progress') {
        await svc.from('notifications').insert({
          user_id: assignment.lender_id,
          title: 'Rider On The Way',
          body: `${riderFullName} is on the way to collect your payment.`,
          category: 'assignment_update',
          reference_id: assignment_id as string,
        });

        await pushToUser(svc, assignment.lender_id, PushTemplates.riderOnTheWay(riderFullName), {
          type: 'rider_on_the_way',
          assignment_id: assignment_id as string,
        });
      }

      if (status === 'completed') {
        const collected = parseFloat(amount_collected as string) || assignment.amount_to_collect;
        updates.amount_collected = collected;
        updates.completed_at = new Date().toISOString();

        await svc.from('payments').insert({
          loan_id: assignment.loan_id,
          lender_id: assignment.lender_id,
          amount: collected,
          method: 'cash',
          status: 'pending',
          notes: notes ?? null,
          receipt_url: receipt_url ?? null,
          reference_number: `CASH-${Date.now()}`,
        });

        await svc.from('notifications').insert({
          user_id: assignment.lender_id,
          title: 'Cash Collected',
          body: `₱${collected.toLocaleString()} has been collected. Payment is pending verification.`,
          category: 'payment_confirmed',
          reference_id: assignment_id as string,
        });

        await pushToUser(svc, assignment.rider_id, PushTemplates.collectionCompleted(), {
          type: 'collection_completed',
          assignment_id: assignment_id as string,
        });
      }

      await svc.from('rider_assignments')
        .update(updates)
        .eq('id', assignment_id);

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'update',
        table_name: 'rider_assignments',
        record_id: assignment_id as string,
        new_values: { status, amount_collected },
      });

      return Response.json({ message: `Assignment ${status}` }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});