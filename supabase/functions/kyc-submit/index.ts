// supabase/functions/kyc-submit/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { requireRole, getServiceClient, errorResponse } from '../_shared/auth.ts';
import { encrypt } from '../_shared/encryption.ts';

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace(/.*kyc-submit/, '');
    const svc = getServiceClient();

    if (req.method === 'GET' && path === '/mine') {
      const user = await requireRole(req, ['lender']);
      const { data } = await svc
        .from('kyc_submissions')
        .select('*')
        .eq('lender_id', user.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      return Response.json({ kyc: data }, { headers: corsHeaders });
    }

    if (req.method === 'POST') {
      const user = await requireRole(req, ['lender']);
      const formData = await req.formData();

      const idType = formData.get('id_type') as string;
      const idNumber = formData.get('id_number') as string;
      const employer = formData.get('employer') as string | null;
      const monthlyIncome = formData.get('monthly_income') as string | null;

      if (!idType || !idNumber) {
        return Response.json(
          { error: 'id_type and id_number are required' },
          { status: 400, headers: corsHeaders },
        );
      }

      const encIdNumber = await encrypt(idNumber);
      const encEmployer = employer ? await encrypt(employer) : null;

      const { data: existing } = await svc
        .from('kyc_submissions')
        .select('id, status')
        .eq('lender_id', user.id)
        .neq('status', 'rejected')
        .maybeSingle();

      if (existing) {
        return Response.json(
          { error: 'You already have a KYC submission under review or approved' },
          { status: 400, headers: corsHeaders },
        );
      }

      const uploadFile = async (file: File | null, bucket: string, name: string) => {
        if (!file) return null;
        const bytes = await file.arrayBuffer();
        const ext = file.name.split('.').pop() ?? 'jpg';
        const path = `${user.id}/${name}.${ext}`;
        await svc.storage.from(bucket).upload(path, bytes, {
          contentType: file.type,
          upsert: true,
        });
        return svc.storage.from(bucket).getPublicUrl(path).data.publicUrl;
      };

      const idFront = formData.get('id_front') as File | null;
      const idBack = formData.get('id_back') as File | null;
      const selfie = formData.get('selfie') as File | null;

      const idFrontUrl = await uploadFile(idFront, 'kyc-documents', 'id_front');
      const idBackUrl = await uploadFile(idBack, 'kyc-documents', 'id_back');
      const selfieUrl = await uploadFile(selfie, 'kyc-documents', 'selfie');

      const { data: kyc, error } = await svc.from('kyc_submissions').insert({
        lender_id: user.id,
        id_type: idType,
        id_number_encrypted: encIdNumber,
        employer_encrypted: encEmployer,
        monthly_income: monthlyIncome ? parseFloat(monthlyIncome) : null,
        id_front_url: idFrontUrl,
        id_back_url: idBackUrl,
        selfie_url: selfieUrl,
        status: 'pending',
      }).select().single();

      if (error) throw error;

      await svc.from('audit_logs').insert({
        user_id: user.id, action: 'insert', table_name: 'kyc_submissions', record_id: kyc.id,
      });

      return Response.json({ message: 'KYC submitted', kyc_id: kyc.id }, { status: 201, headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    return errorResponse(error, corsHeaders);
  }
});