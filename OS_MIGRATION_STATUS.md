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

The first two items below are retained as original scope references; their implemented checks are in FUNCTIONAL_TESTS.md.

## Migration scope and remaining work

1. **In-app notifications.** Adapt event title/body/action and unread/read behavior from the source bell to the existing app. Start with booking requested, confirmed/cancelled, and delivery available/reissued. Use account-scoped records, enforce ownership on reads/updates, and retain separate Owner/member destinations. Create events transactionally and idempotently; do not send external emails as part of this work. Test cross-account denial and duplicate-event prevention before UI integration.
2. **Owner analytics.** Add date-window milestone counts, stage distribution and member progress using existing authoritative records. Distinguish elapsed session time from verified attendance and recorded payment from processor-confirmed settlement. Keep currencies separate.
3. **Rewards and benefits.** Source includes XP, levels, badges, claim/fulfil/deny and capacity exposure. Adapt only after reviewing award definitions, capacity, monetary value and expiry. Existing career tracks/milestones are not the complete rewards economy. Do not automatically promise or activate discounts/free studio time from source defaults.
4. **Instrumental vault.** Catalogue, protected clean masters, generated preview assets, lease requests and Owner release after verified recorded settlement. Requires explicit ownership/license terms and a supported preview-generation/storage path. Browser playback cannot guarantee copying prevention.
5. **Guardian and payment workflows.** Source includes minor/guardian views, cash confirmation, PayPal, refunds, receipts and admin MFA. These need an explicit deployment design with Supabase Auth and the existing invoice system; do not copy legacy authentication or assume provider credentials/configuration are present.
6. **Direction Engine and operational notifications.** Source AI recommendations must remain explain-only; authoritative scores/stages come from server rules. Provider configuration and delivery infrastructure must be verified before enabling calls or outbound messages.

## Integration constraints

- Use the existing Supabase and static/Vercel app architecture. The source React/FastAPI/MongoDB app is a functional reference, not a drop-in replacement.
- Keep Owner landing on management and preserve the existing email/invoice tools.
- Preserve live catalogue edits. Defaults: Full Mix two hours, instrumental creation three hours, other initial defaults one hour, adjustable booking time/duration and 50 percent deposits; exclude membership packages from the service import.
- Reuse the shared account-scoped document allocator. Never create a second invoice numbering sequence for new OS modules.
- Verify source behavior and adapt deliberately; source settings such as VAT, reward prices and membership applications are not automatically approved settings for this deployment.
