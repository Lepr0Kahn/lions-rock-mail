# Online checkout migration review

Prepared 2026-10-01. Review-only; no checkout, processor charge, refund or provider credential has been enabled.

## Current evidence

The original OS uses PayPal in backend/paypal_client.py and backend/routes_payments.py. Its configuration reads PAYPAL_CLIENT_ID, PAYPAL_SECRET, PAYPAL_MODE (sandbox by default), PAYPAL_CHARGE_CURRENCY (USD default) and PAYPAL_FX_BBD_PER_USD (2.0 default). These are original source defaults, not approved settings or evidence that credentials exist in this deployment.

Current Supabase Edge Function inventory contains invite/application endpoints only; no checkout/capture/webhook function. Available connector inventory does not establish whether any provider secret is configured. No secret values were requested or read.

Official references checked:
- https://developer.paypal.com/api/codes/currency/
- https://developer.paypal.com/checkout/integrate
- https://developer.paypal.com/v5/checkout/fx/currency-codes

The Currency Exchange quote/presentment list includes BBD; it is separate from ordinary supported transaction/settlement currencies. Merchant-specific availability and eligibility must be verified against the actual business account. Do not assume BBD checkout or transplant the source USD conversion automatically.

## Proposed implementation once provider/account is confirmed

1. Start with sandbox. Keep live charging disabled.
2. Create server-side orders from a saved issued invoice and its current outstanding/deposit amount. Never accept price, beneficiary or settlement currency from the browser.
3. Bind each intent to invoice account, invoice revision, amount/currency, payer type and (for a minor) current approved guardian link. Minors cannot initiate payment; preserve figure-free responses.
4. Store provider order/capture IDs and immutable provenance separately from manually recorded cash/bank entries. A success redirect is not settlement proof.
5. Capture/verify on the server, verify provider webhook authenticity, and reconcile provider status/amount/currency/payee before updating the existing invoice ledger. Grant no public receipt/capture creation rights.
6. Use unique provider-event/capture constraints, per-invoice locking and stable idempotency keys. Repeated capture/webhook delivery records one payment and keeps the existing invoice number.
7. Handle partial/deposit/balance, cancelled/expired intent, pending/failed capture, amount/currency mismatch, account suspension, stale guardian approval, concurrent manual payment and refund events.
8. Show any conversion and payable provider currency before approval. Invoice currency remains unchanged; rate/rounding policy needs Owner confirmation.
9. Issue guardian full receipt and minor figure-free acknowledgement only after verified capture. Keep operational email delivery separately configured and tested.
10. Test refund authorization/idempotency and reconciliation in sandbox; no automatic real refund during testing.
11. Enable production only after merchant connection, receiving preferences, currency policy and sandbox checks are reviewed.

## Required Owner input

Confirm the provider and business account to use. PayPal is the original OS path, not a binding choice. Merchant sign-in and secure credential configuration will be needed if that path is chosen. Do not paste provider secrets into chat.
