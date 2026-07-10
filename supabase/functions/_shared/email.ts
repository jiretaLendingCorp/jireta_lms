// supabase/functions/_shared/email.ts

const RESEND_BASE = 'https://api.resend.com';

function getApiKey(): string {
  const key = Deno.env.get('RESEND_API_KEY');
  if (!key) throw new Error('RESEND_API_KEY not configured');
  return key;
}

function getFromAddress(): string {
  return Deno.env.get('RESEND_FROM') ?? 'Jireta Loans <noreply@jiretaloans.com>';
}

async function sendEmail(opts: {
  to: string | string[];
  subject: string;
  html: string;
  text?: string;
}): Promise<{ success: boolean; id?: string; error?: string }> {
  try {
    const res = await fetch(`${RESEND_BASE}/emails`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${getApiKey()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: getFromAddress(),
        to: Array.isArray(opts.to) ? opts.to : [opts.to],
        subject: opts.subject,
        html: opts.html,
        text: opts.text,
      }),
    });

    const data = await res.json();
    if (!res.ok) {
      console.error('Resend error:', data);
      return { success: false, error: data.message ?? 'Email failed' };
    }
    return { success: true, id: data.id };
  } catch (e) {
    console.error('Resend exception:', e);
    return { success: false, error: String(e) };
  }
}

function baseTemplate(content: string): string {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <style>
    body { font-family: Inter, Arial, sans-serif; background: #f8f9fa; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 40px auto; background: #fff; border-radius: 12px; overflow: hidden; border: 1px solid #e8eaed; }
    .header { background: linear-gradient(135deg, #5B4FE9, #3D33C5); padding: 32px 40px; }
    .header h1 { color: #fff; margin: 0; font-size: 22px; font-weight: 700; }
    .header p { color: rgba(255,255,255,0.8); margin: 6px 0 0; font-size: 14px; }
    .body { padding: 32px 40px; }
    .amount { font-family: 'JetBrains Mono', monospace; font-size: 28px; font-weight: 700; color: #5B4FE9; }
    .info-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #f0f0f0; font-size: 14px; }
    .info-label { color: #6B7280; }
    .info-value { font-weight: 500; color: #0F1117; }
    .btn { display: inline-block; background: #5B4FE9; color: #fff; padding: 14px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 15px; margin-top: 24px; }
    .footer { padding: 24px 40px; background: #f8f9fa; font-size: 12px; color: #9CA3AF; border-top: 1px solid #e8eaed; }
    .alert { background: #FFF7ED; border: 1px solid #FED7AA; border-radius: 8px; padding: 14px 18px; margin: 16px 0; font-size: 14px; color: #9A3412; }
    .success { background: #F0FDF4; border: 1px solid #BBF7D0; border-radius: 8px; padding: 14px 18px; margin: 16px 0; font-size: 14px; color: #14532D; }
  </style>
</head>
<body>
  <div class="container">
    ${content}
    <div class="footer">
      Jireta Loans &amp; Credit Corp Inc. &bull; This is an automated message. Please do not reply.<br/>
      &copy; ${new Date().getFullYear()} Jireta Loans. All rights reserved.
    </div>
  </div>
</body>
</html>`;
}

export async function emailLoanApproved(opts: {
  to: string;
  firstName: string;
  amount: number;
  totalPayable: number;
  frequency: string;
  termDays: number;
  installment: number;
}): Promise<void> {
  await sendEmail({
    to: opts.to,
    subject: '✅ Your Jireta Loan Application is Approved!',
    html: baseTemplate(`
      <div class="header">
        <h1>Loan Approved!</h1>
        <p>Congratulations, ${opts.firstName}</p>
      </div>
      <div class="body">
        <p style="font-size:15px;color:#374151;">Your loan application has been reviewed and approved. Here are your loan details:</p>
        <div class="success">✅ Your loan is approved and ready for disbursement.</div>
        <div class="info-row"><span class="info-label">Principal Amount</span><span class="info-value">₱${opts.amount.toLocaleString()}</span></div>
        <div class="info-row"><span class="info-label">Interest (20% flat)</span><span class="info-value">₱${(opts.amount * 0.20).toLocaleString()}</span></div>
        <div class="info-row"><span class="info-label">Total Payable</span><span class="info-value">₱${opts.totalPayable.toLocaleString()}</span></div>
        <div class="info-row"><span class="info-label">Payment Frequency</span><span class="info-value">${opts.frequency}</span></div>
        <div class="info-row"><span class="info-label">Term</span><span class="info-value">${opts.termDays} days</span></div>
        <div class="info-row"><span class="info-label">Installment Amount</span><span class="info-value">₱${opts.installment.toLocaleString()}</span></div>
        <p style="font-size:14px;color:#6B7280;margin-top:20px;">Log in to the Jireta Loans app to track your disbursement status.</p>
      </div>`),
  });
}

export async function emailLoanRejected(opts: {
  to: string;
  firstName: string;
  amount: number;
  reason: string;
}): Promise<void> {
  await sendEmail({
    to: opts.to,
    subject: 'Jireta Loans — Application Update',
    html: baseTemplate(`
      <div class="header">
        <h1>Application Update</h1>
        <p>Hi ${opts.firstName}</p>
      </div>
      <div class="body">
        <div class="alert">We regret to inform you that your loan application for ₱${opts.amount.toLocaleString()} was not approved at this time.</div>
        <div class="info-row"><span class="info-label">Reason</span><span class="info-value">${opts.reason}</span></div>
        <p style="font-size:14px;color:#374151;margin-top:20px;">You may reapply after addressing the reason above. Please contact our office if you need assistance.</p>
      </div>`),
  });
}

export async function emailLoanDisbursed(opts: {
  to: string;
  firstName: string;
  amount: number;
  maturityDate: string;
}): Promise<void> {
  await sendEmail({
    to: opts.to,
    subject: '💸 Your Jireta Loan has been Disbursed!',
    html: baseTemplate(`
      <div class="header">
        <h1>Funds Disbursed!</h1>
        <p>Hi ${opts.firstName}</p>
      </div>
      <div class="body">
        <div class="success">₱${opts.amount.toLocaleString()} has been sent to your registered GCash/Maya account.</div>
        <div class="info-row"><span class="info-label">Disbursed Amount</span><span class="info-value">₱${opts.amount.toLocaleString()}</span></div>
        <div class="info-row"><span class="info-label">Loan Maturity</span><span class="info-value">${opts.maturityDate}</span></div>
        <p style="font-size:14px;color:#374151;margin-top:20px;">Please check your GCash or Maya app for the credit. Log in to Jireta Loans to view your complete payment schedule.</p>
        <div class="alert">⚠️ Reminder: Penalty of 20% of total payable is charged after 30 days of non-payment.</div>
      </div>`),
  });
}

export async function emailPaymentDueReminder(opts: {
  to: string;
  firstName: string;
  amount: number;
  dueDate: string;
  daysLeft: number;
  outstandingBalance: number;
}): Promise<void> {
  await sendEmail({
    to: opts.to,
    subject: `⏰ Payment Due in ${opts.daysLeft} Day${opts.daysLeft > 1 ? 's' : ''} — Jireta Loans`,
    html: baseTemplate(`
      <div class="header">
        <h1>Payment Reminder</h1>
        <p>Hi ${opts.firstName}</p>
      </div>
      <div class="body">
        <div class="alert">Your payment is due in ${opts.daysLeft} day${opts.daysLeft > 1 ? 's' : ''}!</div>
        <div class="info-row"><span class="info-label">Amount Due</span><span class="info-value amount">₱${opts.amount.toLocaleString()}</span></div>
        <div class="info-row"><span class="info-label">Due Date</span><span class="info-value">${opts.dueDate}</span></div>
        <div class="info-row"><span class="info-label">Outstanding Balance</span><span class="info-value">₱${opts.outstandingBalance.toLocaleString()}</span></div>
        <p style="font-size:14px;color:#374151;margin-top:20px;">Pay now through the Jireta Loans app using GCash, Maya, QR, or request a cash collection.</p>
      </div>`),
  });
}

export async function emailPaymentConfirmed(opts: {
  to: string;
  firstName: string;
  amount: number;
  referenceNumber: string;
  newBalance: number;
}): Promise<void> {
  await sendEmail({
    to: opts.to,
    subject: '✅ Payment Confirmed — Jireta Loans',
    html: baseTemplate(`
      <div class="header">
        <h1>Payment Confirmed</h1>
        <p>Hi ${opts.firstName}</p>
      </div>
      <div class="body">
        <div class="success">Your payment has been verified!</div>
        <div class="info-row"><span class="info-label">Amount Paid</span><span class="info-value">₱${opts.amount.toLocaleString()}</span></div>
        <div class="info-row"><span class="info-label">Reference No.</span><span class="info-value">${opts.referenceNumber}</span></div>
        <div class="info-row"><span class="info-label">Remaining Balance</span><span class="info-value">₱${opts.newBalance.toLocaleString()}</span></div>
        <p style="font-size:14px;color:#374151;margin-top:20px;">Thank you for your payment. Keep up the good work!</p>
      </div>`),
  });
}

export async function emailAccountCreated(opts: {
  to: string;
  firstName: string;
  role: string;
  defaultPassword: string;
}): Promise<void> {
  await sendEmail({
    to: opts.to,
    subject: 'Welcome to Jireta Loans — Account Created',
    html: baseTemplate(`
      <div class="header">
        <h1>Welcome to Jireta Loans!</h1>
        <p>Your account has been created</p>
      </div>
      <div class="body">
        <p style="font-size:15px;color:#374151;">Hi ${opts.firstName}, a ${opts.role} account has been created for you.</p>
        <div class="info-row"><span class="info-label">Email</span><span class="info-value">${opts.to}</span></div>
        <div class="info-row"><span class="info-label">Default Password</span><span class="info-value" style="font-family:monospace;font-size:18px;font-weight:700;">${opts.defaultPassword}</span></div>
        <div class="alert">⚠️ You will be required to change your password on first login.</div>
      </div>`),
  });
}

export async function emailPasswordReset(opts: {
  to: string;
  firstName: string;
  resetLink: string;
}): Promise<void> {
  await sendEmail({
    to: opts.to,
    subject: 'Reset your Jireta Loans password',
    html: baseTemplate(`
      <div class="header">
        <h1>Password Reset</h1>
        <p>Hi ${opts.firstName}</p>
      </div>
      <div class="body">
        <p style="font-size:15px;color:#374151;">Use the secure link below to reset your password.</p>
        <a class="btn" href="${opts.resetLink}">Reset Password</a>
        <div class="alert">After reset, you will be required to change your password when you sign in.</div>
      </div>`),
  });
}
