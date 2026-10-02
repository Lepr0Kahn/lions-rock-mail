# Cal.com integration preparation

Status: mapping prepared; no automatic calendar synchronization or booking writes enabled.

Account: https://cal.com/bookleprokahn
Timezone: America/Barbados. Public event mapping: config/cal-com.json.

The connected Cal.com plugin successfully returned five personal event types. All five are fixed at 60 minutes and marked paid; the plugin cannot create these paid bookings. Full mix must become 120 minutes, and Instrumental creation needs a new 180-minute event. No event settings have been changed.

## Integration boundary

Use API v2, server-side credentials, and signed webhook verification. The ChatGPT plugin connection does not provide credentials to the deployed application. Cal.com recommends OAuth; a single studio account may use an API key stored only in server secrets, subject to actual account permissions. Account API entitlement has not been verified. Never commit credentials or put them in browser code.

Keep OS services, adjustable booking durations, 50% deposit snapshots, existing shared invoice numbering, guardian checks and reward approval authoritative. Do not enable a second payment collection flow silently. Existing paid Cal.com events require an explicit payment-flow decision or separate non-payment integration events before OS-created booking synchronization.

Availability must intersect Cal.com conflicts with OS confirmed sessions and pending 48-hour holds. API availability alone does not reserve a slot. Persist unique provider booking UIDs and operation IDs; reconcile uncertain results before retrying booking creation. Reject unmapped event types and verify studio ownership. External bookings without trusted OS correlation must enter a review queue; never link an artist by email alone or automatically create a second invoice.

Webhook processing must verify raw-body signature, deduplicate deliveries, reconcile current provider state to resist stale/out-of-order events, and apply updates to the existing linked booking. Cancellation does not imply a refund. Reward scheduling must require approved claims and must not create service charges.

## Remaining acceptance checks

- Verify account API access through securely configured server credentials.
- Align event durations and create Instrumental creation.
- Map event IDs to actual OS offering IDs; do not infer by title during writes.
- Confirm paid-event strategy and connected calendar conflict settings.
- Test OS create/reschedule/cancel and external calendar changes in both directions.
- Test concurrent requests, timeout reconciliation, duplicate webhooks, stale events, invoice numbering and single invoice creation.
- Test adjustable durations, 50% deposits, Barbados timezone, guardian recipients and approved reward scheduling.

References:
https://cal.com/docs/api-reference/v2/introduction
https://cal.com/docs/api-reference/v2/bookings/create-a-booking
https://cal.com/docs/developing/guides/automation/webhooks
