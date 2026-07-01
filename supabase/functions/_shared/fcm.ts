// supabase/functions/_shared/fcm.ts

const FCM_LEGACY_URL = 'https://fcm.googleapis.com/fcm/send';
const FCM_V1_BASE = 'https://fcm.googleapis.com/v1/projects';

export interface FcmNotification {
  title: string;
  body: string;
}

export interface FcmData {
  [key: string]: string;
}

function getLegacyKey(): string | null {
  return Deno.env.get('FCM_SERVER_KEY') ?? null;
}

function getProjectId(): string | null {
  return Deno.env.get('FCM_PROJECT_ID') ?? null;
}

async function sendLegacy(opts: {
  token: string;
  notification: FcmNotification;
  data?: FcmData;
  collapseKey?: string;
}): Promise<{ success: boolean; error?: string }> {
  const key = getLegacyKey();
  if (!key) return { success: false, error: 'FCM_SERVER_KEY not configured' };

  try {
    const res = await fetch(FCM_LEGACY_URL, {
      method: 'POST',
      headers: {
        Authorization: `key=${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: opts.token,
        notification: {
          title: opts.notification.title,
          body: opts.notification.body,
          sound: 'default',
        },
        data: opts.data ?? {},
        priority: 'high',
        collapse_key: opts.collapseKey,
        android: { priority: 'HIGH', notification: { sound: 'default', channel_id: 'jireta_alerts' } },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      }),
    });

    const result = await res.json();
    if (result.failure > 0) {
      const err = result.results?.[0]?.error ?? 'FCM delivery failed';
      console.warn('FCM failure:', err);
      return { success: false, error: err };
    }
    return { success: true };
  } catch (e) {
    console.error('FCM exception:', e);
    return { success: false, error: String(e) };
  }
}

async function sendToMultiple(opts: {
  tokens: string[];
  notification: FcmNotification;
  data?: FcmData;
}): Promise<{ success: boolean; successCount: number; failCount: number }> {
  const key = getLegacyKey();
  if (!key || opts.tokens.length === 0) {
    return { success: false, successCount: 0, failCount: opts.tokens.length };
  }

  try {
    const res = await fetch(FCM_LEGACY_URL, {
      method: 'POST',
      headers: {
        Authorization: `key=${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        registration_ids: opts.tokens,
        notification: {
          title: opts.notification.title,
          body: opts.notification.body,
          sound: 'default',
        },
        data: opts.data ?? {},
        priority: 'high',
        android: { priority: 'HIGH', notification: { sound: 'default', channel_id: 'jireta_alerts' } },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      }),
    });

    const result = await res.json();
    return {
      success: result.success > 0,
      successCount: result.success ?? 0,
      failCount: result.failure ?? 0,
    };
  } catch (e) {
    console.error('FCM multicast exception:', e);
    return { success: false, successCount: 0, failCount: opts.tokens.length };
  }
}

export async function pushToUser(
  svc: ReturnType<typeof import('./auth.ts').getServiceClient>,
  userId: string,
  notification: FcmNotification,
  data?: FcmData,
): Promise<void> {
  try {
    const { data: tokens } = await svc
      .from('fcm_tokens')
      .select('token')
      .eq('user_id', userId);

    if (!tokens || tokens.length === 0) return;

    const results = await Promise.allSettled(
      tokens.map((t: { token: string }) =>
        sendLegacy({ token: t.token, notification, data })
      ),
    );

    const staleTokens = results
      .map((r: PromiseSettledResult<{ success: boolean; error?: string }>, i: number) => ({ r, token: tokens[i].token }))
      .filter(({ r }) => r.status === 'fulfilled' &&
        (r as PromiseFulfilledResult<{ success: boolean; error?: string }>).value.error === 'NotRegistered')
      .map(({ token }) => token);

    if (staleTokens.length > 0) {
      await svc
        .from('fcm_tokens')
        .delete()
        .in('token', staleTokens);
    }
  } catch (e) {
    console.error('pushToUser error:', e);
  }
}

export async function pushToUsers(
  svc: ReturnType<typeof import('./auth.ts').getServiceClient>,
  userIds: string[],
  notification: FcmNotification,
  data?: FcmData,
): Promise<void> {
  try {
    const { data: tokens } = await svc
      .from('fcm_tokens')
      .select('token')
      .in('user_id', userIds);

    if (!tokens || tokens.length === 0) return;

    await sendToMultiple({
      tokens: tokens.map((t: { token: string }) => t.token),
      notification,
      data,
    });
  } catch (e) {
    console.error('pushToUsers error:', e);
  }
}

export const PushTemplates = {
  loanApproved: (amount: number): FcmNotification => ({
    title: '🎉 Loan Approved!',
    body: `Your loan of ₱${amount.toLocaleString()} has been approved. Awaiting disbursement.`,
  }),
  loanRejected: (): FcmNotification => ({
    title: 'Loan Application Update',
    body: 'Your loan application was not approved. Tap for details.',
  }),
  loanDisbursed: (amount: number): FcmNotification => ({
    title: '💸 Funds Disbursed!',
    body: `₱${amount.toLocaleString()} has been sent to your GCash/Maya account.`,
  }),
  paymentDue: (amount: number, daysLeft: number): FcmNotification => ({
    title: `⏰ Payment Due in ${daysLeft} Day${daysLeft > 1 ? 's' : ''}`,
    body: `Your payment of ₱${amount.toLocaleString()} is coming up. Pay now to avoid penalties.`,
  }),
  paymentConfirmed: (amount: number): FcmNotification => ({
    title: '✅ Payment Confirmed',
    body: `Your payment of ₱${amount.toLocaleString()} has been verified.`,
  }),
  paymentOverdue: (daysOverdue: number): FcmNotification => ({
    title: '⚠️ Payment Overdue',
    body: `Your loan is ${daysOverdue} days overdue. Please pay immediately to avoid penalties.`,
  }),
  penaltyApplied: (penalty: number): FcmNotification => ({
    title: '⚠️ Penalty Applied',
    body: `A penalty of ₱${penalty.toLocaleString()} has been added to your outstanding balance.`,
  }),
  kycApproved: (): FcmNotification => ({
    title: '✅ KYC Verified!',
    body: 'Your identity has been verified. You can now apply for a loan.',
  }),
  kycRejected: (): FcmNotification => ({
    title: 'KYC Update',
    body: 'Your KYC documents need resubmission. Tap for details.',
  }),
  riderAssigned: (lenderName: string): FcmNotification => ({
    title: '📋 New Assignment',
    body: `You have a new collection assignment for ${lenderName}.`,
  }),
  collectionCompleted: (): FcmNotification => ({
    title: '✅ Collection Recorded',
    body: 'Your cash collection has been submitted and is pending verification.',
  }),
  riderOnTheWay: (riderName: string): FcmNotification => ({
    title: '🛵 Rider On The Way',
    body: `${riderName} is on the way to collect your payment.`,
  }),
};