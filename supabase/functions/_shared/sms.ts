// supabase/functions/_shared/sms.ts

const SEMAPHORE_BASE = 'https://api.semaphore.co/api/v4';

function getApiKey(): string {
  const key = Deno.env.get('SEMAPHORE_API_KEY');
  if (!key) throw new Error('SEMAPHORE_API_KEY not configured');
  return key;
}

function getSenderName(): string {
  return Deno.env.get('SEMAPHORE_SENDER_NAME') ?? 'JiretaLoan';
}

function normalizePH(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  if (digits.startsWith('63')) return digits;
  if (digits.startsWith('0')) return '63' + digits.slice(1);
  if (digits.startsWith('9')) return '63' + digits;
  return digits;
}

export async function sendSms(
  number: string,
  message: string,
  senderName?: string,
): Promise<{ success: boolean; error?: string }> {
  try {
    const normalized = normalizePH(number);
    const res = await fetch(`${SEMAPHORE_BASE}/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        apikey: getApiKey(),
        number: normalized,
        message,
        sendername: senderName ?? getSenderName(),
      }),
    });
    if (!res.ok) {
      const err = await res.text();
      console.error('Semaphore SMS error:', err);
      return { success: false, error: err };
    }
    return { success: true };
  } catch (e) {
    console.error('Semaphore SMS exception:', e);
    return { success: false, error: String(e) };
  }
}

export async function sendOtp(
  number: string,
  otp: string,
): Promise<{ success: boolean; error?: string }> {
  const message = `Your Jireta Loans verification code is: ${otp}. Valid for 10 minutes. Do not share this with anyone.`;
  return sendSms(number, message);
}

export async function sendLoanApproved(
  number: string,
  opts: { firstName: string; amount: number; frequency: string },
): Promise<void> {
  const msg =
    `Hi ${opts.firstName}! Your Jireta Loans application for ₱${opts.amount.toLocaleString()} has been APPROVED. ` +
    `Payment frequency: ${opts.frequency}. Log in to view your disbursement details.`;
  await sendSms(number, msg);
}

export async function sendLoanRejected(
  number: string,
  opts: { firstName: string; reason: string },
): Promise<void> {
  const msg =
    `Hi ${opts.firstName}, your Jireta Loans application was not approved. ` +
    `Reason: ${opts.reason}. Contact us for assistance.`;
  await sendSms(number, msg);
}

export async function sendLoanDisbursed(
  number: string,
  opts: { firstName: string; amount: number },
): Promise<void> {
  const msg =
    `Hi ${opts.firstName}! ₱${opts.amount.toLocaleString()} has been disbursed to your GCash/Maya. ` +
    `Please log in to Jireta Loans to view your payment schedule.`;
  await sendSms(number, msg);
}

export async function sendPaymentDueReminder(
  number: string,
  opts: { firstName: string; amount: number; dueDate: string; daysLeft: number },
): Promise<void> {
  const msg =
    `Hi ${opts.firstName}, your Jireta Loans payment of ₱${opts.amount.toLocaleString()} ` +
    `is due on ${opts.dueDate} (${opts.daysLeft} day${opts.daysLeft > 1 ? 's' : ''} left). ` +
    `Pay via the app to avoid penalties.`;
  await sendSms(number, msg);
}

export async function sendPaymentConfirmed(
  number: string,
  opts: { firstName: string; amount: number; newBalance: number },
): Promise<void> {
  const msg =
    `Hi ${opts.firstName}, your payment of ₱${opts.amount.toLocaleString()} has been confirmed. ` +
    `Remaining balance: ₱${opts.newBalance.toLocaleString()}. Thank you!`;
  await sendSms(number, msg);
}

export async function sendPenaltyApplied(
  number: string,
  opts: { firstName: string; penalty: number; daysOverdue: number },
): Promise<void> {
  const msg =
    `Hi ${opts.firstName}, a penalty of ₱${opts.penalty.toLocaleString()} has been added to your Jireta Loan ` +
    `(${opts.daysOverdue} days overdue). Please settle immediately to avoid further charges.`;
  await sendSms(number, msg);
}

export async function sendAssignmentNotification(
  number: string,
  opts: { riderName: string; collectionDate: string },
): Promise<void> {
  const msg =
    `Hi! Your Jireta Loans collector ${opts.riderName} will visit you on ${opts.collectionDate} ` +
    `to collect your payment. Please prepare the exact amount.`;
  await sendSms(number, msg);
}

export async function sendRiderAssigned(
  number: string,
  opts: { firstName: string; lenderName: string; collectionDate: string; amount: number },
): Promise<void> {
  const msg =
    `Hi ${opts.firstName}, you have a new collection assignment for ${opts.lenderName} ` +
    `on ${opts.collectionDate}. Amount: ₱${opts.amount.toLocaleString()}. Log in for details.`;
  await sendSms(number, msg);
}