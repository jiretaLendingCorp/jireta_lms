// supabase/functions/_shared/xendit.ts

export interface XenditInvoice {
  id: string;
  external_id: string;
  invoice_url: string;
  status: string;
  amount: number;
  expiry_date: string;
}

export interface XenditDisbursement {
  id: string;
  external_id: string;
  status: string;
  amount: number;
  bank_code: string;
  account_number: string;
}

export interface XenditCustomer {
  given_names: string;
  email?: string;
  mobile_number?: string;
}

export type XenditPaymentMethod = 'GCASH' | 'MAYA' | 'QRPH' | 'GCASH_QR' | 'PAYMAYA';

function getXenditAuth(): string {
  const secretKey = Deno.env.get('XENDIT_SECRET_KEY');
  if (!secretKey) throw new Error('XENDIT_SECRET_KEY not configured');
  return 'Basic ' + btoa(secretKey + ':');
}

const XENDIT_BASE = 'https://api.xendit.co';

async function xenditRequest<T>(
  method: string,
  path: string,
  body?: Record<string, unknown>,
  idempotencyKey?: string,
): Promise<T> {
  const headers: Record<string, string> = {
    'Authorization': getXenditAuth(),
    'Content-Type': 'application/json',
  };
  if (idempotencyKey) {
    headers['Idempotency-key'] = idempotencyKey;
  }

  const res = await fetch(`${XENDIT_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const data = await res.json();
  if (!res.ok) {
    const errMsg = data.message ?? data.error_code ?? `Xendit error ${res.status}`;
    throw new Error(`Xendit: ${errMsg}`);
  }
  return data as T;
}

export async function createInvoice(opts: {
  externalId: string;
  amount: number;
  description: string;
  customer: XenditCustomer;
  paymentMethods?: XenditPaymentMethod[];
  successRedirectUrl?: string;
  failureRedirectUrl?: string;
  currency?: string;
  durationSeconds?: number;
}): Promise<XenditInvoice> {
  return xenditRequest<XenditInvoice>('POST', '/v2/invoices', {
    external_id: opts.externalId,
    amount: opts.amount,
    description: opts.description,
    customer: opts.customer,
    currency: opts.currency ?? 'PHP',
    payment_methods: opts.paymentMethods ?? ['GCASH', 'MAYA', 'QRPH'],
    invoice_duration: opts.durationSeconds ?? 86400,
    success_redirect_url: opts.successRedirectUrl,
    failure_redirect_url: opts.failureRedirectUrl,
    should_send_email: false,
  }, opts.externalId);
}

export async function getInvoice(invoiceId: string): Promise<XenditInvoice> {
  return xenditRequest<XenditInvoice>('GET', `/v2/invoices/${invoiceId}`);
}

export async function expireInvoice(invoiceId: string): Promise<XenditInvoice> {
  return xenditRequest<XenditInvoice>('POST', `/invoices/${invoiceId}/expire!`);
}

export async function createDisbursement(opts: {
  externalId: string;
  bankCode: string;
  accountHolderName: string;
  accountNumber: string;
  description: string;
  amount: number;
  emailTo?: string[];
}): Promise<XenditDisbursement> {
  return xenditRequest<XenditDisbursement>('POST', '/disbursements', {
    external_id: opts.externalId,
    bank_code: opts.bankCode,
    account_holder_name: opts.accountHolderName,
    account_number: opts.accountNumber,
    description: opts.description,
    amount: opts.amount,
    email_to: opts.emailTo ?? [],
  }, opts.externalId);
}

export async function getDisbursement(disbursementId: string): Promise<XenditDisbursement> {
  return xenditRequest<XenditDisbursement>('GET', `/disbursements/${disbursementId}`);
}

export function verifyWebhookToken(req: Request): boolean {
  const token = Deno.env.get('XENDIT_WEBHOOK_TOKEN');
  if (!token) return false;
  const incoming = req.headers.get('x-callback-token');
  return incoming === token;
}

export function mapMethodToXendit(method: string): XenditPaymentMethod[] {
  switch (method) {
    case 'gcash':
      return ['GCASH', 'GCASH_QR'];
    case 'maya':
      return ['MAYA', 'PAYMAYA'];
    case 'qr':
      return ['GCASH', 'GCASH_QR', 'MAYA'];
    default:
      return ['GCASH', 'MAYA', 'QRPH'];
  }
}

export const XENDIT_BANK_CODES: Record<string, string> = {
  gcash: 'GCASH',
  maya: 'PAYMAYA',
  bdo: 'BDO',
  bpi: 'BPI',
  metrobank: 'METRO',
  pnb: 'PNB',
  landbank: 'LBPHP',
  unionbank: 'UBP',
  security_bank: 'SECB',
};