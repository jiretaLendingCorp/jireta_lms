// supabase/functions/assignment-create/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { pushToUser, PushTemplates } from '../_shared/fcm.ts';
import { sendRiderAssigned } from '../_shared/sms.ts';
import { geocodeAddress } from '../_shared/maps.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*assignment-create/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/list') {
      const user = await requireRole(req, ['head_manager', 'employee', 'rider']);
      const status = url.searchParams.get('status');
      const scope = url.searchParams.get('scope');

      let query = svc
        .from('rider_assignments')
        .select(`
          *,
          rider:users!rider_assignments_rider_id_fkey(first_name, last_name),
          lender:users!rider_assignments_lender_id_fkey(first_name, last_name)
        `)
        .order('created_at', { ascending: false });

      if (user.role === 'rider' || scope === 'mine') {
        query = query.eq('rider_id', user.id);
      }

      if (status) query = query.eq('status', status);

      const { data, error } = await query;
      if (error) throw error;

      const assignments = (data ?? []).map((a: Record<string, unknown>) => ({
        ...a,
        rider_name: a.rider
          ? `${(a.rider as Record<string, string>).first_name} ${(a.rider as Record<string, string>).last_name}`
          : null,
        lender_name: a.lender
          ? `${(a.lender as Record<string, string>).first_name} ${(a.lender as Record<string, string>).last_name}`
          : null,
        rider: undefined,
        lender: undefined,
      }));

      return Response.json({ assignments }, { headers: corsHeaders });
    }

    if (req.method === 'GET' && path.startsWith('/list/')) {
      const user = await requireRole(req, ['head_manager', 'employee', 'rider']);
      const id = path.replace('/list/', '');

      const { data, error } = await svc
        .from('rider_assignments')
        .select(`
          *,
          rider:users!rider_assignments_rider_id_fkey(first_name, last_name),
          lender:users!rider_assignments_lender_id_fkey(first_name, last_name, address)
        `)
        .eq('id', id)
        .single();

      if (error) throw error;

      if (user.role === 'rider' && data.rider_id !== user.id) {
        return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders });
      }

      const assignment = {
        ...data,
        rider_name: data.rider
          ? `${(data.rider as Record<string, string>).first_name} ${(data.rider as Record<string, string>).last_name}`
          : null,
        lender_name: data.lender
          ? `${(data.lender as Record<string, string>).first_name} ${(data.lender as Record<string, string>).last_name}`
          : null,
        lender_address: (data.lender as Record<string, string | null>)?.address ?? data.lender_address,
        rider: undefined,
        lender: undefined,
      };

      return Response.json(assignment, { headers: corsHeaders });
    }

    if (req.method === 'POST') {
      const user = await requireRole(req, ['head_manager', 'employee']);
      const body = await req.json();

      const { loan_id, rider_id, amount_to_collect, collection_date } = body as Record<string, string>;

      if (!loan_id || !rider_id || !amount_to_collect || !collection_date) {
        return Response.json(
          { error: 'loan_id, rider_id, amount_to_collect, and collection_date are required' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: loan } = await svc
        .from('loans')
        .select('lender_id, status')
        .eq('id', loan_id)
        .single();

      if (!loan || loan.status !== 'active') {
        return Response.json(
          { error: 'Loan not found or not active' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: riderProfile } = await svc
        .from('users')
        .select('role, is_active, first_name, phone')
        .eq('id', rider_id)
        .single();

      if (!riderProfile || riderProfile.role !== 'rider' || !riderProfile.is_active) {
        return Response.json(
          { error: 'Invalid or inactive rider' },
          { status: 400, headers: corsHeaders },
        );
      }

      const { data: lenderProfile } = await svc
        .from('users')
        .select('address, first_name, last_name')
        .eq('id', loan.lender_id)
        .single();

      const { lat, lng } = body as Record<string, string>;
      let resolvedLat = lat ? parseFloat(lat) : null;
      let resolvedLng = lng ? parseFloat(lng) : null;

      // Staff did not provide live GPS coordinates — geocode the lender's
      // address on file so the rider still gets a navigable pin.
      if ((resolvedLat === null || resolvedLng === null) && lenderProfile?.address) {
        const geocoded = await geocodeAddress(lenderProfile.address);
        if (geocoded) {
          resolvedLat = geocoded.lat;
          resolvedLng = geocoded.lng;
        }
      }

      const { data: assignment, error: assignErr } = await svc
        .from('rider_assignments')
        .insert({
          loan_id,
          rider_id,
          lender_id: loan.lender_id,
          amount_to_collect: parseFloat(amount_to_collect),
          collection_date,
          lender_address: lenderProfile?.address ?? null,
          lender_lat: resolvedLat,
          lender_lng: resolvedLng,
          status: 'pending',
          created_by: user.id,
        })
        .select()
        .single();

      if (assignErr) throw assignErr;

      await svc.from('notifications').insert({
        user_id: rider_id,
        title: 'New Assignment',
        body: `You have a new collection assignment for ${collection_date}.`,
        category: 'assignment_new',
        reference_id: assignment.id,
      });

      const lenderFullName = lenderProfile
        ? `${lenderProfile.first_name ?? ''} ${lenderProfile.last_name ?? ''}`.trim()
        : 'a borrower';

      await pushToUser(svc, rider_id, PushTemplates.riderAssigned(lenderFullName), {
        type: 'assignment_new',
        assignment_id: assignment.id,
      });

      if (riderProfile?.phone) {
        await sendRiderAssigned(riderProfile.phone, {
          firstName: riderProfile.first_name ?? 'Rider',
          lenderName: lenderFullName,
          collectionDate: collection_date,
          amount: parseFloat(amount_to_collect),
        });
      }

      await svc.from('audit_logs').insert({
        user_id: user.id,
        action: 'insert',
        table_name: 'rider_assignments',
        record_id: assignment.id,
        new_values: { loan_id, rider_id, amount_to_collect, collection_date },
      });

      return Response.json(
        { message: 'Assignment created', assignment_id: assignment.id },
        { status: 201, headers: corsHeaders },
      );
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});