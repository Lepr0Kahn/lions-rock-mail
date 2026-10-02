# Lions Rock OS migration status

Reviewed 2026-10-01 against Lepr0Kahn/LIONS-ROCK-OS-FOR-SAGE (main), especially memory/PRD.md, frontend/src/pages/ProjectDetail.jsx and frontend/src/components/NotificationBell.jsx. Source repository claims are historical; they are not verification of the merged app.

## Already represented in the merged app

- Separate Owner management and Artist Member surfaces, membership access controls and invite workflow.
- Projects, source uploads, Owner master/MP3 deliveries, expiration and reissue.
- Service catalogue and booking requests, Owner approval/rescheduling, invoice creation.
- Existing invoice/quote generator and email composer, shared document numbering and PDF handoff.
- Career profile, stages, evidence-based track calculations and milestone ledger/reversals.
- Owner action center with booking, invoice and expiring-delivery queues.

Database and source checks are recorded in FUNCTIONAL_TESTS.md. Current live browser authentication remains blocked; file byte transfer, live Gmail sending and simultaneous committed orders remain unverified. Apple Mail testing is skipped by user request.

## Recent completed integrations

- In-app notifications: booking request/confirmation/cancellation and delivery/reissue alerts, own-account read state and Owner/member destinations.
- Owner analytics: activity windows, evidence-stage roster, track averages, booking status and currency-separated recorded invoice balances.
- Recognition-only rewards: Owner approved XP, levels and badges on 2026-10-01. Implemented from new eligible evidence with corrections and per-project delivery caps. Discounts/free-service benefits remain disabled. Claim/fulfilment/capacity exposure remains outstanding.

## Remaining work

- Vault catalogue/lease request/invoice/release, recorded payments/refunds/corrections and printing are implemented. Actual byte playback/download and live printing remain unverified. Browser-generated BPM/bar-based custom-tag previews are implemented; actual playback/upload and phone performance remain unverified. Exclusive requests, reservation, separate terms/pricing, paid release and prior-lease preservation are implemented; final live checks remain pending.
- Guardian/minor invoice approval and financial projections are implemented. Cash intent and recorded settlement use existing invoice/payment systems. Guardian identity is bearer-link recipient asserted; guardian approval email drafts and payment/refund/correction receipt email drafts are implemented using the existing composer. Live sending, online checkout and dual formal receipts remain outstanding. Guardian booking approval is through invoice review after studio confirmation; it is not a separate approval gate before booking confirmation.
- Payment-provider selection/configuration and sandbox/production charges/refunds.
- Direction Engine rule-based fallback is implemented, using authoritative evidence with five explain-only actions. Live UI and AI provider-backed generation remain outstanding. External operational notifications still require configuration.
- Admin MFA enrollment/backup setup, inactive database/storage gates and caller-token invite guards are implemented. Enforcement remains off. User deferred remaining security acceptance tests to the final phase on 2026-10-01; no authenticator setup is required to continue build work.
- Original data reconciliation, genuinely simultaneous committed invoice orders and final live browser verification remain outstanding.
- Recognition-only XP/levels/badges remain enabled; monetary benefit claims/fulfilment/capacity remain disabled pending explicit approval.

Manual steps are maintained in MANUAL_TEST_CHECKLIST.md; database/source evidence remains in FUNCTIONAL_TESTS.md.

## Integration constraints

- Use the existing Supabase and static/Vercel app architecture. The source React/FastAPI/MongoDB app is a functional reference, not a drop-in replacement.
- Keep Owner landing on management and preserve the existing email/invoice tools.
- Preserve live catalogue edits. Defaults: Full Mix two hours, instrumental creation three hours, other initial defaults one hour, adjustable booking time/duration and 50 percent deposits; exclude membership packages from the service import.
- Reuse the shared account-scoped document allocator. Never create a second invoice numbering sequence for new OS modules.
- Verify source behavior and adapt deliberately; source settings such as VAT, reward prices and membership applications are not automatically approved settings for this deployment.


## Original data reconciliation
Source/schema comparison recorded in DATA_RECONCILIATION.md. Historical records and file bytes cannot be declared reconciled without an authoritative source database export and explicit account/file mapping. Demo seeds were identified and not imported. Beat mood/key metadata and exclusive pricing are confirmed source/target feature gaps; existing master/lease release controls must be preserved when extending the catalogue.
