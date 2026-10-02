# PayPal Sandbox Setup — Lions Rock Studio OS

Status: code integrated; credentials intentionally not stored in GitHub or chat.

## What is already implemented
- Artist **Pay invoices** screen for booking and instrumental invoices.
- PayPal JavaScript SDK v6 checkout.
- Server-side order creation and capture in Supabase Edge Function `studio-paypal`.
- Invoice amount is calculated server-side from the saved Lions Rock invoice.
- Deposit and balance payments supported.
- Verified PayPal capture writes to the existing `payments` ledger and updates `documents.amount_paid`, `balance_due`, status and receipt number.
- Provider order/capture IDs are idempotent and protected against duplicate recording.
- Signature-verified PayPal webhook endpoint uses the same Edge Function.
- Published invoice/payment tables remain inaccessible directly to Artist clients.
- Minor accounts are blocked from initiating PayPal payment until the guardian payment flow is added.
- Refunds are not automatic in the first release.

## Required PayPal sandbox configuration
Create/use a PayPal Business Developer sandbox app and add these values under **Supabase Dashboard → Edge Functions → Secrets** for the Lions Rock project.

Do not put these values in GitHub and do not paste the secret into ChatGPT.

Required:
- `PAYPAL_CLIENT_ID` — sandbox app client ID.
- `PAYPAL_CLIENT_SECRET` — sandbox app secret.
- `PAYPAL_MODE=sandbox`
- `PAYPAL_CHARGE_CURRENCY=USD`
- `PAYPAL_FX_BBD_PER_USD=2.00`

After the Edge Function is live, create a PayPal webhook whose URL is:

`https://xsvczfqvscnvmngwcmtp.supabase.co/functions/v1/studio-paypal`

Subscribe at minimum to:
- `PAYMENT.CAPTURE.COMPLETED`
- `PAYMENT.CAPTURE.DENIED`
- `PAYMENT.CAPTURE.REFUNDED`
- `CHECKOUT.ORDER.APPROVED`

Then add the resulting webhook ID as:
- `PAYPAL_WEBHOOK_ID`

Supabase makes updated Edge Function secrets available without requiring a code redeploy.

## Sandbox acceptance
1. Sign in as an adult Artist with an Artist Name.
2. Open **Pay invoices**.
3. Confirm only that Artist's booking/instrumental invoices appear.
4. Pay a deposit with a PayPal sandbox buyer account.
5. Confirm exact USD charge is shown before approval.
6. Verify one PayPal payment ledger entry and one receipt number only.
7. Verify invoice amount paid / balance due update.
8. Repeat callback/webhook delivery and confirm no duplicate payment.
9. Pay remaining balance.
10. For an instrumental lease, release the master only after the invoice becomes fully paid.
11. Test cancellation and declined payment; neither may update the invoice.
12. Test refund separately before any live credential is enabled.

## Production switch
Only after sandbox acceptance:
- create/use the PayPal live app,
- replace sandbox credentials with live credentials,
- create a live webhook and store its webhook ID,
- set `PAYPAL_MODE=live`,
- rerun acceptance with a deliberately small real invoice before broad release.
