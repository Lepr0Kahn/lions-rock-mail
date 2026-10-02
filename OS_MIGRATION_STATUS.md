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
- Recognition-only rewards: Owner approved XP, levels and badges on 2026-10-01. Implemented from new eligible evidence with corrections and per-project delivery caps. Paid-menu discounts remain disabled. The separate artist-development benefit catalogue, claims, approval, capacity and fulfilment are implemented; Owner configuration and final live acceptance remain pending.

## Remaining work

- Vault catalogue/lease request/invoice/release, recorded payments/refunds/corrections and printing are implemented. Actual byte playback/download and live printing remain unverified. Browser-generated BPM/bar-based custom-tag previews are implemented; actual playback/upload and phone performance remain unverified. Exclusive requests, reservation, separate terms/pricing, paid release and prior-lease preservation are implemented; final live checks remain pending.
- Guardian/minor invoice approval and financial projections are implemented. Cash intent and recorded settlement use existing invoice/payment systems. Guardian identity is bearer-link recipient asserted; guardian approval email drafts and payment/refund/correction receipt email drafts are implemented using the existing composer. Live sending, online checkout and dual formal receipts remain outstanding. Guardian booking approval is through invoice review after studio confirmation; it is not a separate approval gate before booking confirmation.
- Payment-provider selection/configuration and sandbox/production charges/refunds.
- Direction Engine rule-based fallback is implemented, using authoritative evidence with five explain-only actions. Live UI and AI provider-backed generation remain outstanding. External operational notifications still require configuration.
- Admin MFA enrollment/backup setup, inactive database/storage gates and caller-token invite guards are implemented. Enforcement remains off. User deferred remaining security acceptance tests to the final phase on 2026-10-01; no authenticator setup is required to continue build work.
- Historical data import is explicitly out of scope by user decision: there are no old records to export. Genuinely simultaneous committed invoice orders and final live browser verification remain outstanding.
- Artist development reward catalogue and claim/approval/fulfilment queue are implemented separately from the paid menu. Five draft experiences remain inactive until Owner configures scope, XP milestone and capacity. XP is eligibility, not spent currency; no price discounts or automatic paid-menu bookings.

Manual steps are maintained in MANUAL_TEST_CHECKLIST.md; database/source evidence remains in FUNCTIONAL_TESTS.md.

## Integration constraints

- Use the existing Supabase and static/Vercel app architecture. The source React/FastAPI/MongoDB app is a functional reference, not a drop-in replacement.
- Keep Owner landing on management and preserve the existing email/invoice tools.
- Preserve live catalogue edits. Defaults: Full Mix two hours, instrumental creation three hours, other initial defaults one hour, adjustable booking time/duration and 50 percent deposits; exclude membership packages from the service import.
- Reuse the shared account-scoped document allocator. Never create a second invoice numbering sequence for new OS modules.
- Verify source behavior and adapt deliberately; source settings such as VAT, reward prices and membership applications are not automatically approved settings for this deployment.


## Historical data scope
Historical import/export is explicitly excluded by the user. DATA_RECONCILIATION.md remains a historical source/schema reference; no source export, demo seed import or reconciliation sign-off is required for this build. Mood/key metadata and exclusive handling are implemented and await their recorded live checks.

## Artist development reward benefits
Custom future rewards can be added, edited, activated and archived by Owner. Claims reserve catalogue capacity and preserve reward scope/XP snapshots; approval/fulfilment recheck Artist eligibility. Historical-data import is not required per user instruction. See REWARD_BENEFITS_STATUS.md for final-phase checks.

## Calendar synchronization and current next steps
Cal.com synchronization is active, with six hidden zero-payment services, a signed webhook and durable server queue. Server-role access and live read-only account/event/webhook/availability checks passed. Booking/invoice integration and shared sequence checks passed in rollback-only transactions. A self-conflict in rescheduling availability was fixed using the verified existing provider UID. Real booking, notifications, webhook lifecycle and browser acceptance remain pending. See CAL_COM_SYNC_STATUS.md and BUILD_NEXT_STEPS.md; approval/sign-in tasks are saved there while independent work proceeds.


## Emergent parity hardening — 2026-10-02
- Progression integrity was re-audited against the Emergent rewards implementation. The merged app intentionally computes XP from an immutable, idempotent career-event ledger rather than storing a second mutable XP total. Duplicate source events are prevented by database uniqueness, replay reads do not award XP, reversals preserve evidence while removing current credit, and per-project delivery scoring is capped.
- Emergent has 12 badges; the merged app currently exposes 9. The three intentionally omitted badges depend on authoritative `session_completed` / `cycle_completed` events. Elapsed calendar time is not treated as verified attendance, so those awards remain disabled until a trustworthy completion record exists.
- Owner reward exposure planning is implemented: configurable estimated hours/BBD value per reward, 90-day planning-hours budget, live/fulfilled/theoretical exposure and capacity warnings. It does not alter paid services or invoices.
- A read-only Owner Assurance tab is implemented in Admin. It checks calendar queue failures/stale leases, booking/calendar/invoice consistency, invoice arithmetic, career-event duplication, reward exposure and unread Owner notifications. The live database check on 2026-10-02 returned healthy with zero integrity exceptions.


## UI organization pass — 2026-10-02
- Studio OS now occupies the far-left position in the authenticated top navigation for Owner accounts.
- Owner Management Dashboard is compartmentalized into a first-priority Studio Action Center, a collapsible Artist Development & Career Progress section, and a separate Recent Work / Next Move section.
- Studio booking management is reordered for Owner workflow: booking queue first, create booking second, rescheduling third, service catalogue/configuration last.
- Booking queue now has at-a-glance counts and filters for Needs Action, Upcoming, Past and Cancelled/Expired, with active work shown by default.
- Embedded page versions were bumped to avoid stale cached UI.
- Authoritative session completion is now an explicit remaining implementation item; completion will be Owner-confirmed evidence rather than inferred from elapsed time.


## Mobile scrolling hardening — 2026-10-02
- Fixed Rewards on mobile: the rewards page now reports its actual content height to Studio OS instead of relying on a fixed 1600px iframe.
- Bookings and Rewards nested frames now resize dynamically and notify the outer Studio shell when their height changes.
- Removed the outer Studio shell's viewport-height/hidden-overflow frame trap so active embedded pages can grow with their content and the browser remains the primary scroll surface.
- Bumped embedded page versions to avoid stale cached layouts.
- Reviewed Mail, Documents, Clients/Projects and Admin for the same full-page clipping pattern. No equivalent page-level trap was found. Mail's 700px iPhone preview remains intentionally internally scrollable and does not limit page scrolling.


## Authoritative session completion — 2026-10-02
- Added a private one-to-one completion record for confirmed studio bookings, recorded only by active Owner access after the scheduled end time.
- Added an idempotent `session_completed` career event (200 XP), plus the **In The Room** and **Studio Regular** badges from the Emergent reference implementation.
- Replaced the previous elapsed-time approximation in career tracks with authoritative completion records.
- Booking Queue now separates **Needs completion** from **Completed** and provides the Owner-only completion action.
- Assurance now reports past confirmed sessions awaiting completion review.
