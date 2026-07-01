# Third-Party Integration Setup — Jireta Loans

This document lists every external service wired into the codebase and the exact
steps needed to activate each one with your own credentials. All sensitive logic
(payment computation, disbursement, OTP verification, penalty calculation) lives
in the TypeScript Edge Functions under `supabase/functions/`. The Flutter app
never talks to these providers directly — it always goes through Dio →
Edge Function → provider API.

---

## 1. Xendit (GCash / Maya payments + disbursements)

**What's wired:** `supabase/functions/_shared/xendit.ts`, used by
`payment-record` (creates an Invoice for GCash/Maya/QR repayments — this is
what "auto-fills the lender's bill" when they tap Pay), `loan-disburse`
(sends the approved principal to the lender's GCash/Maya via Disbursement),
and `xendit-webhook` (receives payment confirmation and disbursement status).

**Steps:**
1. Create a Xendit account at https://dashboard.xendit.co (use **Test Mode**
   first — your test/secret keys are separate from live keys).
2. Dashboard → Settings → API Keys → copy your **Secret Key**.
3. Dashboard → Settings → Webhooks → add a webhook:
   - URL: `https://<your-project-ref>.supabase.co/functions/v1/xendit-webhook`
   - Events: `invoice.paid`, `invoice.expired`, `disbursement.completed`, `disbursement.failed`
   - Copy the **Verification Token** shown there.
4. Set these Supabase Edge Function secrets:
   ```
   supabase secrets set XENDIT_SECRET_KEY=xnd_development_xxxxx
   supabase secrets set XENDIT_WEBHOOK_TOKEN=your_webhook_verification_token
   ```
5. When you're ready for production, repeat with your **live** secret key and
   a separate live webhook, and swap the `XENDIT_SECRET_KEY` secret.

**Bank/e-wallet codes used for disbursement** (`_shared/xendit.ts → XENDIT_BANK_CODES`):
`gcash`, `maya`, plus standard PH bank codes (BDO, BPI, Metrobank, etc.) if you
want to support disbursing to a bank account instead of an e-wallet.

---

## 2. Semaphore PH (SMS — OTP, due reminders, payment/loan alerts)

**What's wired:** `supabase/functions/_shared/sms.ts`, used across
`loan-approve`, `loan-reject`, `loan-disburse`, `payment-verify`,
`penalty-compute`, `due-date-reminder`, `assignment-create`, and the
SMS-OTP forgot-password flow in `auth-profile`.

**Steps:**
1. Sign up at https://semaphore.co and load credits.
2. Dashboard → API Keys → copy your key.
3. (Optional) Register a custom Sender Name (e.g. `JiretaLoan`) — subject to
   Semaphore approval. Until approved, the default shared sender is used.
4. Set secrets:
   ```
   supabase secrets set SEMAPHORE_API_KEY=your_api_key
   supabase secrets set SEMAPHORE_SENDER_NAME=JiretaLoan
   ```

---

## 3. Resend (Transactional email)

**What's wired:** `supabase/functions/_shared/email.ts`, used by
`loan-approve`, `loan-reject`, `loan-disburse`, `payment-verify`,
`user-create` (welcome email with default password), and `due-date-reminder`.

**Steps:**
1. Sign up at https://resend.com.
2. Add and verify your sending domain (Domains → Add Domain → add the DNS
   records they give you). Until verified you can only send to your own
   account's email for testing.
3. API Keys → create a key.
4. Set secrets:
   ```
   supabase secrets set RESEND_API_KEY=re_xxxxxxxxxx
   supabase secrets set RESEND_FROM="Jireta Loans <noreply@yourdomain.com>"
   ```

---

## 4. Firebase Cloud Messaging (Push notifications)

**What's wired:** `supabase/functions/_shared/fcm.ts` (server-side send),
`supabase/functions/fcm-register` (token registration endpoint), and
`lib/core/services/push_notification_service.dart` (client-side init +
registration). The Flutter app degrades gracefully and simply won't deliver
push notifications until you complete this setup — it will not crash.

**Steps:**
1. Create a project at https://console.firebase.google.com.
2. Add an Android app (package name must match
   `android/app/build.gradle` → `applicationId`, currently `com.example.jireta_lms` —
   change this to your real package id first) and download
   `google-services.json` into `android/app/`.
3. Add an iOS app (bundle id must match `ios/Runner.xcodeproj`) and download
   `GoogleService-Info.plist` into `ios/Runner/`.
4. Install the FlutterFire CLI and run it from the project root to generate
   `lib/firebase_options.dart`:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
5. Project Settings → Cloud Messaging → under "Cloud Messaging API (Legacy)",
   enable it if disabled, and copy the **Server Key** (this project uses the
   legacy HTTP API for simplicity; migrating to the v1 API with a service
   account is a drop-in change in `_shared/fcm.ts` if you prefer).
6. Set the secret:
   ```
   supabase secrets set FCM_SERVER_KEY=your_legacy_server_key
   ```
7. Re-run `flutter pub get` and rebuild — `Firebase.initializeApp()` in
   `lib/main.dart` will now succeed and `PushNotificationService` will start
   registering device tokens automatically after login.

---

## 5. Google Maps (Geocoding + navigation)

**What's wired:** `supabase/functions/_shared/maps.ts`, used by
`assignment-create` as a fallback that converts the lender's text address
into lat/lng coordinates when the lender hasn't shared live GPS (the lender
app itself captures live GPS via `geolocator` when requesting a cash pickup —
see `lender_pay_screen.dart`). The rider app's "Navigate" button opens
Google Maps turn-by-turn directions using whichever coordinates are on file.

**Steps:**
1. Google Cloud Console → APIs & Services → enable **Geocoding API** (and
   **Maps Static API** if you want server-rendered map thumbnails — already
   supported via `staticMapUrl()` in `_shared/maps.ts` but not yet called
   from any screen).
2. Create an API key, restrict it to those two APIs and to your Supabase
   project's outbound IPs if you want tighter restriction (otherwise leave
   unrestricted for server-side use, since Edge Functions don't have stable
   IPs on the free tier).
3. Set the secret:
   ```
   supabase secrets set GOOGLE_MAPS_API_KEY=your_key
   ```
4. This integration degrades gracefully — if the key is missing, assignment
   creation still succeeds, it just won't have a geocoded pin until the rider
   or lender shares live GPS through the app.

---

## 6. AES-256-GCM encryption key (not third-party, but required)

`supabase/functions/_shared/encryption.ts` encrypts PII (co-maker names, KYC
ID numbers, employer info) before they touch PostgreSQL. Generate a 256-bit
key and set it as a hex string:

```bash
openssl rand -hex 32
supabase secrets set AES_ENCRYPTION_KEY=<the 64-char hex output>
```

---

## 7. The 2-day due-date reminder + penalty cron jobs

Both `due-date-reminder` and `penalty-compute` are plain HTTP Edge Functions
guarded by a shared secret — they are **not** scheduled by Supabase
automatically. Pick one of these to actually invoke them daily:

**Option A — Supabase's built-in pg_cron + pg_net** (if available on your plan):
```sql
select cron.schedule(
  'due-date-reminder-daily',
  '0 8 * * *',  -- 8 AM daily, server time
  $$
  select net.http_post(
    url := 'https://<your-project-ref>.supabase.co/functions/v1/due-date-reminder',
    headers := jsonb_build_object('Authorization', 'Bearer ' || '<CRON_SECRET>')
  );
  $$
);
-- repeat with a separate schedule for penalty-compute
```

**Option B — External scheduler** (cron-job.org, GitHub Actions schedule,
EasyCron): point a daily POST request at:
```
https://<your-project-ref>.supabase.co/functions/v1/due-date-reminder
https://<your-project-ref>.supabase.co/functions/v1/penalty-compute
```
with header `Authorization: Bearer <CRON_SECRET>`.

Set the shared secret first:
```
supabase secrets set CRON_SECRET=$(openssl rand -hex 24)
```
Use that same value in whichever scheduler you choose.

---

## 8. Google Sign-In (lender self sign-up/login)

Already wired through Supabase Auth's native Google provider
(`signInWithGoogle()` in `auth_provider.dart`), not a custom Edge Function.

**Steps:**
1. Supabase Dashboard → Authentication → Providers → Google → enable it.
2. Create OAuth credentials in Google Cloud Console (Web application type)
   and paste the Client ID / Secret into the Supabase provider settings.
3. Add the redirect URL Supabase gives you to your Google OAuth client's
   authorized redirect URIs.
4. The app already requests the `io.supabase.jireta://login-callback` deep
   link — register that scheme in `android/app/src/main/AndroidManifest.xml`
   and `ios/Runner/Info.plist` (`CFBundleURLTypes`) if not already present
   for the OAuth round-trip to return to the app correctly.

---

## Summary of all required secrets

```bash
supabase secrets set XENDIT_SECRET_KEY=...
supabase secrets set XENDIT_WEBHOOK_TOKEN=...
supabase secrets set SEMAPHORE_API_KEY=...
supabase secrets set SEMAPHORE_SENDER_NAME=JiretaLoan
supabase secrets set RESEND_API_KEY=...
supabase secrets set RESEND_FROM="Jireta Loans <noreply@yourdomain.com>"
supabase secrets set FCM_SERVER_KEY=...
supabase secrets set GOOGLE_MAPS_API_KEY=...
supabase secrets set AES_ENCRYPTION_KEY=...
supabase secrets set CRON_SECRET=...
```

Deploy all functions after setting secrets:
```bash
supabase functions deploy --no-verify-jwt
```
(`--no-verify-jwt` is required because `xendit-webhook`, `due-date-reminder`,
and `penalty-compute` are called by external systems without a Supabase user
JWT — they verify their own bearer tokens internally instead.)