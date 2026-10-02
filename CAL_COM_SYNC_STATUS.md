# Cal.com booking synchronization

Implemented and activated 2 October 2026; live booking lifecycle acceptance remains pending.

The server worker, private durable outbox, one-use availability tickets, signed webhook receiver, one-minute scheduler, booking status labels and Owner activation/pause/recovery controls are implemented. Synchronization is now enabled in the database after the Owner activation attempt and permission fix below. No real Cal.com bookings or notifications were created during the automated checks.

Six verified hidden services are mapped. New confirmed sessions enqueue creation; changes enqueue rescheduling or cancellation. Invoice generation and document-number allocation stay in their existing path. The worker never creates invoices, alters prices, collects deposits or issues refunds. Artist requests hold only OS availability until Owner confirmation.

The worker verifies the host, event, OS metadata, start/end and provider status before marking an operation synchronized. It checks provider availability again before mutations. Duration changes use a separate hidden event and a verified cancellation/replacement because Cal.com rescheduling does not change duration. The existing provider reservation can block a same-time duration expansion; choosing another available time is currently required.

A timeout after a provider mutation becomes uncertain. Recovery reads the known booking/reschedule chain or scans operation metadata; it never automatically recreates an unverified booking. Ambiguous outcomes require Owner review. The Recheck calendar control can verify an existing accepted booking after the Owner resolves it in Cal.com.

Webhook payloads are HMAC-SHA256 authenticated over their raw bytes. The receiver fetches current provider state rather than trusting payload fields, ignores unknown/public bookings and deduplicates processed requests. Conflicts enter review. Pending local changes prevent delayed callbacks from overwriting a newer OS request.

The Edge Function has gateway JWT verification disabled because Cal.com callbacks and the scheduler use custom authentication. Interactive actions validate the Supabase user, current membership and Owner MFA gate. Scheduler capabilities are random, hashed in a private table, expire after two minutes and are consumed once. Service-role keys remain in the server environment.

Pausing stops scheduled dispatch but keeps availability checks and the queue active. Initial activation does not import or backfill any previous booking. A Cal.com webhook secret is derived server-side from the configured API key; rotating that key requires reactivating to update the webhook secret.

## Verification

Passed: worker mocks for creation, confirmation, cancellation, rescheduling, duration replacement, guardian contact, unavailable slots, ambiguous timeouts, recovery/no blind retries, event/booking isolation, signatures and authorization. Database checks passed in rolled-back transactions: atomic claims, concurrent edit guard, backend authorization, one-use availability tickets/replay rejection, one-use runner tokens and pause behavior. Modified HTML scripts parse successfully.

Pending: Owner activation against live Cal.com, real booking/notification lifecycle, actual webhook delivery, scheduler/provider integration and browser acceptance. These are explicitly recorded in MANUAL_TEST_CHECKLIST.md. This implementation is not yet a live end-to-end pass.

## Source / fresh installation

Apply supabase/calendar-sync.sql, supabase/calendar-runtime.sql, supabase/calendar-pause.sql, then supabase/calendar-scheduler.sql. Install the worker at supabase/functions/studio-calendar-worker/index.ts with custom authentication. Existing booking RPCs and guardian workflow are prerequisites. CAL_COM_API_KEY must remain an Edge Function secret.

Run node tests/calendar-worker.test.cjs.

Official API references: https://cal.com/docs/api-reference/v2/bookings/create-a-booking, https://cal.com/docs/api-reference/v2/bookings/reschedule-a-booking, https://cal.com/docs/api-reference/v2/bookings/get-a-booking, https://cal.com/docs/api-reference/v2/webhooks/update-a-webhook.


## Activation fix — 2 October 2026
The first real activation attempt registered its Cal.com webhook but could not enable the database flag: the service_role lacked USAGE on the private schema. Fixed with a server-role-only grant. Reproduced the error under SET LOCAL ROLE service_role and verified the actual role succeeds after the grant. Deployed worker diagnostics returned HTTP 200 and verified the account, all six hidden zero-price events and the installed webhook. Completed the previously requested activation: enabled=true, paused=false, with no operations or bookings generated. Live booking lifecycle acceptance is still pending.
