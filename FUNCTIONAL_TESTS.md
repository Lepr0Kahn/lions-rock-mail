# Lions Rock Studio — Functional Test Record

Last updated: 2026-10-01

## Access separation

- Owner account: Business Tools access = true; Artist Member access = true.
- Business-only test account: Business Tools access = true; Artist Member access = false.
- Transactional RLS test with a temporary client row:
  - Business-only account could read its Business Tools client row.
  - The same account simulated as Artist-only could not read that client row.
  - Artist access remained true while Business Tools access became false.
- Temporary test rows were wrapped in database transactions and rolled back.

## Invite-only access

- Public application Edge Function is closed and returns invite-only status.
- Legacy application activation Edge Function is closed.
- Private invites are recorded in `studio_invites`.
- Invites have a 7-day expiry.
- A new user's workspace entitlement is not activated when the link is created.
- The entitlement is granted only when the authenticated invite is claimed.
- Existing users can receive a second workspace entitlement without losing their existing one.
- Suspended accounts cannot claim a new entitlement until reactivated.
- Supabase Auth action links remain one-time Auth links; the database separately tracks pending/claimed/revoked invite state.

## Static code checks

The following current files passed JavaScript syntax validation:

- `studio.html`
- `studio-admin.html`
- `studio-hub.html`
- `invoice-v2-embedded.html`
- `invoice-sync.js`
- `mail-v5-1-embedded.html`
- `studio-member.html`

## Database security checks

Business Tools tables continue to require `private.has_active_studio_access()`, which now requires a Business Tools entitlement (or Owner role).

Artist-only accounts therefore cannot query:

- clients
- business projects
- documents
- business settings
- services used by Business Tools

`studio_invites` is readable only by the invited user or the Owner.

Supabase security advisor currently reports only the pre-existing leaked-password-protection warning.

## Still requiring live browser testing

These need a real browser/Auth-session pass after the functional merge:

- clicking a generated invite link
- first-time password setup
- existing-account invite acceptance
- non-owner sign-out / sign-in persistence
- wrong-workspace login messaging
- iPhone/PWA visual behavior
- live Vercel deployment behavior

The user will handle visual review after the functional layers are complete.

## Production follow-up — 2026-09-30

- PR #2 merged as `a12469ff4345d27dad79ddbf26c790689e3f1107`.
- Production deployment `dpl_8sNXYdC4wHxzYMZHwPaD47Cu6qDk` reached READY.
- Production `studio-admin.html` returned HTTP 200 and contains the verified Auth state listener.
- Live create-invite and claim-invite endpoints both returned HTTP 401 for unauthenticated POST requests.
- Additional rolled-back database assertions passed: invited user can read only their own test invite, Owner can read both test invites, pending invite grants no Artist entitlement, and member membership rows are isolated.
- Authenticated invite creation/claim and wrong-workspace browser tests still require a dedicated non-owner test session.
- Build-log retrieval was unavailable through the connected Vercel tool; no clean build-log scan is claimed.


## Live Business account verification — 2026-09-30 22:10–22:13 UTC

- Claimed Business Tools invitation confirmed for tarikdelves@gmail.com (member, active, artist disabled).
- Password recovery request was recorded by Supabase; user completed the reset on their phone. New password sign-in passed in the production browser.
- Business workspace rendered with Admin, Mail, and Artist Member navigation hidden; Clients view contained no Owner clients.
- Database assertions passed for Business permission, Artist/Owner denial, cross-account clients/projects/documents/memberships isolation, suspension, and reactivation (rolled back).
- Live suspension test returned the browser to sign-in. Membership was restored to active immediately afterward.
- Artist-mode sign-in with the same Business-only account returned to the login gate, while subsequent Business-mode sign-in succeeded after reactivation.
- Usability issue: denial/suspension explanation is overwritten by the asynchronous signed-out callback with 'Sign in to continue.' Enforcement works, but the reason should persist.
- New-account first-password invite flow remains distinct from existing-account magic-link acceptance; do not mark it verified from an existing-account invite.


### Denial-message regression fix

Preserve the denial reason across the asynchronous SIGNED_OUT callback. Clear it before a fresh password sign-in and explicit Sign Out. Invalid/expired invite messages use the same preservation. JavaScript syntax passed. A regression harness exercised the actual setSession function with a queued signed-out callback: original failed; fixed version passed for suspension, unpaid account, and Artist workspace denial, repeated signed-out updates, and clearing the reason for ordinary sign-out.


## Services and bookings — 2026-09-30

- Supabase rollback assertions passed for Barbados hourly availability, rejection of overlapping sessions, cancellation freeing slots, Artist request holds, Owner confirmation, forbidden Artist catalogue creation/confirmation, and Business RPC/RLS denial.
- Owner preview browser: default Management Dashboard, service and offering creation, 12 one-hour slots from 10am to 9pm Barbados, confirmed session recorded with matching UTC times and snapshotted price, and cancellation through queue verified against Supabase.
- Disposable fixture retained: service 060535e7-0fa7-46d7-8f41-7980997b682a (deactivated), booking 525dcc45-3e54-4ff9-be15-fb6b7836f631 (cancelled). No real appointment or payment.
- Browser test found iframe height feedback; now measures body content, rather than iframe viewport height. Found existing missing deletion queue returning null; JSON fallback regression checks passed for missing/null/malformed queues and preserved populated JSON.
- Scope excludes payment collection, outbound booking notices, external calendar sync, rescheduling, and legacy data migration. Member booking flow verified at database level; distinct Artist browser flow remains unverified.


## Booking → invoice → email bridge — 2026-09-30

Implementation merged in PR #7 (bbb6524). Existing generator and Email PDF/composer flow reused. Owner booking action creates/reopens a saved document and line item; booking reference, price, currency, deposit and session notes persist. No automatic outbound email.

Passed checks:
- Authenticated Owner database rollback tests: one invoice and one line item per booking, repeated invocation returns identical document ID, USD 125 / 30% snapshot preserved, and reopening after cancellation preserves the existing invoice.
- Artist and Business-only RPC denial, cross-account invoice RLS denial, anonymous execute revoked, cancelled uninvoiced booking rejected.
- Final JavaScript parsing across all edited HTML scripts and invoice-sync.js.
- Executed production-source cloud mapping preserves booking ID, USD invoice currency with BBD default settings, total and deposit, and legacy currency fallback.

Deployment is blocked: GitHub Vercel status for merged commit points to upgradeToPro=build-rate-limit. Last successful production remains bab1aaf (services/bookings). Production HTML was fetched and does not contain the new booking document bridge. Browser invoice/PDF/composer handoff is pending deployment; do not report it verified or live.

Disposable new test service 0a4db48f-9a47-4ac9-bf60-ba94c90eb470 deactivated; booking 9e76ee44-6f2c-4717-b213-44bfa29b9c7d cancelled, zero associated invoices. Retained audit fixture; no real appointment, payment or email.


Deployment retry requested on 2026-09-30 at 19:18 Barbados time. Retriggering the GitHub production build with application code unchanged.

Deployment retry requested on 2026-09-30 at 20:21 Barbados time; application code unchanged.


## Live booking invoice bridge verification — 2026-10-01 UTC

Deployment retry succeeded: main 733f67a13a263a9a479ba4b814577e3ad5ae88e9 reached Vercel READY in dpl_Ff6svHwSeEsRBngLPj3vf4c4AFYb. This supersedes the build-rate-limit block above.

Authenticated Owner production browser opened a confirmed booking in the existing invoice generator. INV-0001 preserved booking reference, one-hour service, BBD currency, zero test price and 25% deposit. Email Client generated Lions-Rock-Invoice-INV-0001.pdf (140.8 KB) and opened the existing Mail composer with matching subject, body and recipient booklionsrock@gmail.com (visually verified). No Gmail send or payment performed.

Disposable service 6f10bebf-1b87-4e88-bb2f-5a48fc16ca98 deactivated; booking 71c0ff73-8db9-4365-8f00-5e5067c8d9d6 cancelled. Verification query confirmed cancelled booking, inactive service and exactly one retained zero-value invoice 7a80d820-a722-41e1-af1b-867553a1a6b0. Owner management default was verified in this production session. Distinct Artist browser flow and iPhone-specific behavior remain unverified.


## Numbering tests — 2026-09-30 Barbados / 2026-10-01 UTC

Executed actual nextDocNumber and resolveDocumentNumberConflicts functions fetched from main in isolated Node VM contexts. Authenticated Owner SQL test used a generator-shaped invoice insert followed by the real booking RPC; all database changes rolled back.

Passed: sequential INV-0001/0002 yields INV-0003; separate QUO-0004 yields QUO-0005; generator-shaped saved invoice then booking invoice advances once; reopening booking retains document ID; duplicate number rejected by database unique(user_id,doc_number).

Confirmed unresolved issues:
- Offline collision resolution with cloud INV-0002 and INV-0010 assigned INV-0001 instead of INV-0011. nextFor regex over-escapes the digit class, so maximum discovery fails.
- After an invoice is renamed from INV-0001 to RCP-0001 when marked paid, next invoice can reuse INV-0001. Both generator and booking allocator derive maximum only from current INV numbers; no durable high-water counter.
- Two isolated stale device stores both allocate INV-0001. Database uniqueness blocks persisting both unchanged, but this is not centralized allocation or guaranteed chronological numbering.

Limits: simultaneous/offline cases reproduced with production-source function execution, not two real browser sessions or a concurrent production load test. No payments, real orders, or outbound emails created. Application code unchanged; these failures require fixes and regression tests before strict monotonic numbering can be claimed.


## Shared document numbering fix — PR #8

Private per-account INV/QUO counters and idempotent document-ID reservations replace conflict regex numbering. Before-insert/update trigger enforces allocation and preserves existing numbers, including legacy RCP documents. Both generator and booking inserts use this allocator. Counter increases survive document deletion; reservations may leave gaps for abandoned drafts. Existing saved documents are not renumbered.

Frontend reserves offline draft numbers on sync. Print Preview, Save & PDF and Email Client await successful sync and confirm the saved number before output; offline drafts remain editable/savable. Mark Paid preserves the invoice number.

Passed: actual frontend allocator functions in isolated Node VM; HTML/JS syntax; SQL rollback tests before and after migration for idempotence, sequential counters, independent quote prefix, trigger enforcement, paid number preservation, cross-account/Artist denial, mixed generator insert→booking RPC→reopen, and high-water preservation after deletion. Anonymous execute revoked. Private tables have RLS and no direct grants; no-policy info is intentional. Authenticated definer allocator is intentional and checks live Business entitlement and account ownership.

Database migration applied. Preview build is currently blocked by Vercel build-rate-limit. Production frontend deployment and live browser regression for this fix remain pending; earlier booking/PDF verification belongs to PR #7. Two real concurrent browser sessions and iPhone-specific checks are not yet claimed.


### Signed-in preview and release attempt — 2026-10-01 UTC

Vercel Google sign-in and device verification completed. Promotion of READY preview dpl_EiaSh2XiDgUncijTuW2rqgwtsYGr (b785a4c) rejected with: Resource is limited - try again in 24 hours (more than 100, code api-deployments-young-hobby-team-24h). Production frontend release remains blocked; shared counter database migration is active.

Owner authenticated in the built preview. Default Management Dashboard verified. Existing INV-0001 opened in the readonly-number generator; Email Client completed online sync/final-number confirmation and attached Lions-Rock-Invoice-INV-0001.pdf (140.8 KB) with matching subject/body. No email sent. Zero-value Mark Paid resets to due on sync under existing total-based status logic; do not claim persisted paid browser test from it. SQL positive-path paid status number preservation already passed.

Source inspection additionally found that duplicating a booking invoice retained its unique booking_id. New copies now detach that link; actual duplicate branch regression passed. This follow-up is in main but absent from the earlier READY preview. Remaining: production frontend release, two real concurrent browser sessions, a distinct Artist sign-in flow and iPhone-specific visual checks.


## Owner management Action Center — PR #9

Adapted the role-aware Action Center concept from LIONS-ROCK-OS-FOR-SAGE (memory/PRD.md and admin analytics). Owner Management Dashboard now queues active booking requests, upcoming confirmed sessions, own unpaid invoices and non-archived-project studio deliveries expiring within seven days. Total balances are grouped by currency; expired holds, zero balances, paid and void invoices are excluded. Lists show up to five items with full counts; session timestamps use Barbados time. Actions open existing bookings, invoices and project deliveries, retaining the existing generator and Mail tools.

Data comes from public.studio_management_overview, SECURITY INVOKER with empty search_path and live Owner/Business/Artist guards. Anonymous execute is revoked. Member/Business accounts cannot call management data, and member UI keeps this section hidden. Invoice navigation validates originating frame, Owner role and database account ownership. No payment or outbound email action added.

Before/after-migration SQL rollback tests passed for pending/expired holds, upcoming sessions, expiring deliveries, overdue dates, BBD/USD separation, paid/void exclusions and Business/Artist denial. All existing fixture changes rolled back. Both page scripts parsed. Database function installed; frontend pending Vercel quota reset. New Action Center browser/mobile verification is not yet claimed.


## Distinct Artist browser verification — 2026-10-01 UTC

With explicit approval, temporarily enabled Artist Member for tarikdelves@gmail.com (existing Business-only account). Secure browser login confirmed that account. READY preview b785a4c showed the Artist career workspace, zero own projects, no Owner management controls, and its own Services & bookings screen with no bookings. No active offerings were available, so request submission, delivery upload/download and a populated cross-account browser comparison were not exercised.

Restored artist_member_enabled=false, preserving business_tools_enabled=true, and verified returned database flags. Full browser reload removed Member navigation and returned to Business clients. An already-open member frame did not visibly close after its Refresh action in this older preview; immediate revocation UI behavior remains unverified and should be retested against latest main. Database guards remain the authorization boundary. No emails, payments, or bookings were submitted. Management Action Center itself is not in this preview and remains pending deployment/browser verification.


## Evidence-backed career milestones — source OS integration

Adapted recorded-signal concepts from LIONS-ROCK-OS-FOR-SAGE/backend/progression.py into a live six-milestone checklist: non-archived project, reference/stem/demo material, confirmed session, confirmed session whose scheduled end has passed, recorded master/MP3 delivery, and project marked Released. Elapsed time does not verify attendance; Released is self-reported; expired deliveries still evidence a recorded delivery. Archived projects/files are excluded. This is not the source OS's persisted eight-stage lifecycle or five scored tracks. Profile completion, collection tracking, milestone audit history and stage persistence remain to be migrated.

Artist dashboard reads own milestones. Owner Management adds an artist progress selector without replacing the managerial dashboard. public.artist_career_milestones is SECURITY INVOKER with empty search_path and live membership checks. Cross-account requests require active Owner/Business access; Business-only and anonymous access denied. No financial records or invented quote/payment associations are included.

Rollback SQL test passed for Owner evidence, cancelled-booking exclusion, Owner artist review, own Artist counts, cross-account rejection and Business-only denial. Anonymous execute false; security_definer false. JavaScript syntax passed; advisor warning set unchanged. Fixture access/status changes rolled back. Frontend awaits Vercel deployment and browser/mobile verification.


## Owner Email visibility and artist career identity

Owner Email navigation no longer depends on choosing Business Tools at sign-in. It is labeled Email and remains Owner-only; the separate tarikdelves@gmail.com Business-only test account is not an Owner. Existing composer/Gmail behavior unchanged. Both Owner sign-in-mode visibility cases and non-Owner restriction checked from actual code; page scripts parse. Frontend awaits deployment.

Added artist_career_profiles with artist name, genres and 12-month goal. Active Artists can insert/update only their own identity, with WITH CHECK preventing ownership reassignment. Active Owner with Business access can read artist profiles for management; Owner dashboard remains managerial and has no self-profile form. Profiles appear alongside selected artist milestones. Database checks passed for own profile, cross-account insert denial, ownership-change denial, Owner review and Business-only read denial; all test changes rolled back. Advisor warning set unchanged.

Profile inputs are now available as progression evidence. Delivery collection, persisted eight-stage lifecycle and full track scores remain unfinished; no stage or score is claimed in this commit.


## Live production verification — 2026-10-01 02:08–02:13 UTC

Vercel Git deployment 7205ecf was READY and aliased to lions-rock-mail.vercel.app. Earlier manual-promotion quota failures did not stop subsequent Git deployments; previous pending-deployment notes are superseded for deployed commits. Secure Owner login booklionsrock@gmail.com opened Management Dashboard with Action Center and Artist progress. Email visible. Projects top navigation → Clients inside hub produced Client Profiles and a single red top Clients highlight (rgb 185,28,28).

Existing disposable zero-value booking invoice INV-0001 opened. It initially had no saved lines and correctly refused save/export. Added a zero-value disposable test line, then generated its PDF into Email. Follow-up database inspection found zero retained document_items: an earlier sync snapshot could overwrite the just-saved export draft. Commit ced29ca makes finalization wait for the earlier sync, restore the exact export draft, push it, and verify persisted line names, quantities and prices before export. Actual-function mocked earlier-sync overwrite regression passed; JavaScript parsed. Vercel production deployment dpl_HcFez27oNvzV8icgo86BzCvDXcZL READY. Reloaded live app and retested: document_items contained one line 'Disposable PDF verification — no charge', qty 1, unit price 0, and Email received Lions-Rock-Invoice-INV-0001.pdf (139 KB) with matching subject/body. Existing document number and booking link retained. No email sent, payment recorded, or new order created. Disposable test line retained for verification. This was reopening an existing cancelled booking's invoice, not creating a new confirmed booking. Simultaneous independent-device edits and true transaction-level item replacement remain untested.


## Delivery collection and eight-stage lifecycle

Adapted ordered lifecycle gates from LIONS-ROCK-OS-FOR-SAGE/backend/progression.py: Join → Discover (complete profile) → Plan (project) → Create (registered material) → Produce (confirmed booking) → Prepare (master/MP3 recorded) → Release (own delivery collection) → Grow (project marked Released). Cancelled requests and archived projects are excluded. All earlier gates must be satisfied; no AI or client supplies stage values. Persisted stage only advances. Dashboard exposes both retained stage and current evidenced stage when records become incomplete; next action follows current evidence. Owner artist selector shows stage/next action, keeping management as default. Five track scores are still pending.

Collection is recorded idempotently after the browser obtains a file and initiates the download. This is a client-reported download initiation, not proof that the operating system saved or the artist listened to the file. It applies only to own master/MP3 files, non-archived projects and unexpired deliveries; Owner previews of another artist's files do not count. Collection timestamp is server-default and clients cannot insert a chosen timestamp. Read RLS permits own active Artist or active Owner/Business review. Collection RPC is SECURITY INVOKER. Progress RPC is explicitly guarded SECURITY DEFINER because historical stage state is private and not client-writable; it validates auth.uid/live caller and target membership, owner cross-account scope, explicit ownership filters and uses an empty search_path plus per-artist advisory lock. Anon execution revoked. Advisor flags the intended guarded definer and private table with no policies; neither grants direct stage writes.

Rollback tests passed for all eight sequential gates (privileged fixture setup), expired-delivery rejection, idempotent collection, no regression, authenticated Owner and Artist execution, cross-artist read/collection rejection and Business-only denial. Temporary profile/project/booking/file/membership changes rolled back; no collection test records retained. Page JavaScript parsed. Browser integration and physical iPhone download behavior require live verification.


## Owner membership management

Owner Access List can switch a non-Owner exclusively between Artist Member and Business Tools. Switching preserves suspension/payment/expiry. Delete Membership revokes both workspaces and moves the membership to Removed Members while retaining account, invoices, projects and files. Restore chooses a type but leaves access suspended for explicit reactivation. Owners/self are protected; removed emails must be restored before reinviting.

Authenticated rollback tests passed for switches, preserved payment, removal, suspended restore, Owner protection, invalid type, and non-Owner denial. Positive workspace guard separation passed with the suspended test account temporarily activated inside a rolled-back transaction. Its original suspension and flags were preserved. Frontend syntax passed. Live browser controls await deployment; no actual member was removed or switched.


### Live membership controls — 2026-10-01 UTC

GitHub Vercel status for 4047f3a reported successful deployment. Fresh production Owner browser loaded studio-admin?v=4. Disposable pending account sage-access-test-20260930@example.com switched Artist then Business through Save Type; remained pending. Delete moved it to Removed Members; database confirmed suspended, both flags false and deleted_at set. Restore as Business cleared deleted_at, enabled only Business and kept suspended. Did not reactivate account. Restored original pending status and both flags false through Supabase, confirmed returned values and refreshed live Access List. Real member accounts were untouched. Existing email PDF draft was preserved in its original tab. Active-session login/revocation was not retested in this browser pass; workspace guards were tested transactionally earlier. Screenshot captured live controls.


## Invoice catalogue and booking integration — 2026-10-01 UTC

11 Owner invoice items imported into linked inactive OS services with exact names/categories/descriptions/BBD prices. Owner-only invoker import is idempotent; refresh preserves offerings and booking snapshots. Management setup controls configure duration/deposit before activation. SQL import and permission tests passed. New RPCs add no security advisor warning. Main 31af94494729b5210cc4f8b106bdb5ab647a12c4 Vercel status: Deployment rate limited — retry in 24 hours. UI controls not live verified.

Rolled-back authenticated test used imported Record a Song with a temporary 60-minute BBD100/25% offering: Artist request, overlap rejection, Owner confirmation, invoice creation/reopening idempotence, BBD100 total and25% deposit, sequential generator reservation → booking invoice → generator reservation, and cancellation passed. Temporary activation, offering, booking, invoice, client and number reservations all rolled back. No real appointment, charge or email. Real catalogue durations/deposits still require Owner decisions; package prices are not automatically charged per session. Live browser booking test awaits deployment/configuration.


## Service defaults and Owner rescheduling

Per user instruction, all eight nonmembership invoice services have a Standard session offering at the catalogue BBD price, 60 minutes, 50% deposit, and active=true. No membership packages included. Offering editing added for Owner; changes apply only to future bookings. New offering defaults 60/50. Booking date and available start selector retained. Owner can change time/date/duration of upcoming requested/confirmed bookings through guarded reschedule RPC; same calendar advisory lock, future hourly-start/day-hours constraints, overlap rejection excluding current booking and expired holds, price/deposit/status preserved. Requested hold cannot be extended. Linked invoices require review after session change; no automatic invoice rewrite/email.

Booking tables have no direct authenticated UPDATE, so rescheduling intentionally uses SECURITY DEFINER with empty search_path and active Owner/Business/Artist guards. Public/anon execute revoked. No direct booking writes granted. SQL rollback test passed: eight defaults, 90-minute reschedule, overlap/invalid duration denial, offering changes preserve booking snapshots and nonOwner denial. JavaScript parsed. Browser verification awaits deployment.


### Owner duration correction

Full Mix Standard session is now 120 minutes; Create Instrumental is 180 minutes; other six remain 60 minutes. All retain 50% deposit and catalogue prices. Updated authenticated rollback reschedule/defaults test passed. Existing bookings retain their own time snapshots. Owner change-time controls are implemented in the prior commit, awaiting deployment.


## Five career tracks from OS for Sage

Adapted exact capped weights from LIONS-ROCK-OS-FOR-SAGE/backend/progression.py for Creative, Momentum, Audience, Network and Business. Live scores and full per-signal breakdowns, not client/AI-written values. Creative/Audience support full100; Momentum currently supports30 (past confirmed sessions), Network70 (confirmed bookings/past sessions), Business86 (complete profile/recorded invoice payments). Missing milestone-ledger activity/quotes/budgets explicitly unavailable and zero points, never normalized upward. Excludes archived project/file evidence and cancelled/expired requests; releases self-reported; elapsed sessions do not prove attendance; collection is download initiation. Financial evidence uses positive-total nonvoid Owner invoices joined through booking.user_id to target artist, amount_paid for full/partial payment, no matching by email or arbitrary financial records and no processor verification. Only aggregate counts returned.

public.artist_career_tracks is guarded SECURITY DEFINER, empty search_path, active caller Artist guard, active target (including deleted_at) and cross-account Owner+Business guard. Definer required to return narrow financial aggregates to Artists without granting invoice-table reads. Public/anon revoked, scores not persisted or client-editable. Security advisor counts10 intentional guarded definers,3 private RLS infos, preexisting password warning. No direct grants added.

Rollback tests passed for100caps, explicit missing coverage, Owner selected-Artist review, ownArtist/crossArtist andBusiness restrictions, linked payment inclusion, void exclusion and removed-target denial. Privileged fixture setup then authenticated assertions; no fixtures/payments retained. UI syntax passed; Owner dashboard still managerial, selected artist shows score evidence. Live UI awaits deployment and browser login recovery.


## Automatic career milestone ledger

Adapted milestone history from OS for Sage/core.py. Server triggers record real state transitions: active Artist membership, completed profile, project creation, registered material/master, confirmed booking, delivery collection, recorded full invoice payment and project marked Released. Unique artist/key/source prevents repeated saves or replay inflation. No automatic elapsed-session attendance event, cycle award, XP/reward or login/click event. Only known creation/upload/collection timestamps backfilled; imported entries never contribute to recent Momentum. Old releases/profiles/confirmations lack authoritative event times and are not fabricated.

Append-only event and reversal tables have RLS and authenticated SELECT only; client UPDATE/INSERT/DELETE revoked. Private trigger record helper execute revoked. Owner reversal requires active Owner+Artist+Business and reason, preserves original event, one reversal per event. Artist reads own history; Owner selected artist review; anonymous and Business denied. History max100. Server checks live target access/deleted_at. Ineligible archived/released-reverted files/projects, cancelled bookings and void/unpaid invoices stop contributing to recent event activity. Reversal excludes milestone activity; base project/file/invoice evidence remains for other track signals.

Momentum now has all100 points supported: eligible recent milestones and Barbados distinct evidence days plus past confirmed sessions (attendance unverified). History loads with breakdowns; Owner can reverse with inline reason. Imported history does not pretend to be new activity. Network quotes and Business explicit budgets still unsupported.

Authenticated rollback tests passed: automatic project event, no duplicate on rename, recent Momentum increment, archive exclusion, idempotent reversal/original preserved, own/crossArtist/Business history permissions, no direct ledger write, repeated invoice settlement one event, reading history/tracks awards no events, anon/private execute false. Existing track caps test updated and passed. Test projects/events/payments all rolled back. JS syntax passed. Guarded history/reversal add intended SECURITY DEFINER advisor notices (12 total), private no-policy infos and preexisting password warning remain. Live UI pending deployment/browser recovery.


## Verification update — 2026-10-01

### Passed

- Current invoice/quote/receipt email handoff and composer regression suites, including finalized recipient and number, attachment replacement, CC/BCC reset, and error recovery.
- EML export now reuses the complete MIME builder used for Gmail. Regression checks preserve PDF/audio bytes, Unicode subject/body, recipients, inline image parts, and empty-attachment handling. Deployment of commit 676f47b7395849edb6daa65576983eac726c1dfe completed successfully.
- Transactional booking tests: Full Mix 120 minutes, instrumental creation 180 minutes, 50 percent deposits, overlap rejection, adjacent sessions, invoice reuse, generator/booking/generator numbering, and reschedule amount preservation.
- Active, suspended, removed, expired, and Business-only Artist access scenarios; cross-member isolation.
- Project quote reuse, budget validation, linked settlement counting and void exclusion.
- Recorded payment corrections: 175 paid on 350 leaves 175 due; full payment counts once; reducing/zeroing payment removes settled/deposit signals; void excludes financial credit; repeated settlement keeps one milestone and the document number. All database fixtures rolled back.
- Isolated sample preview rendered the Owner managerial dashboard and generated a real PDF attachment in the email composer. This is sample data, not live authentication verification.

### Concurrency evidence and limit

- Live database has unique constraints on (user_id, doc_number), document reservations, and one document per (user_id, booking_id).
- Both generator reservation and booking document insertion use reserve_document_number through the document trigger. Allocation holds a transaction advisory lock per account. Booking invoice creation also locks before checking/reusing the existing invoice.
- An attempted pair of concurrent connector requests did not overlap. The test correctly failed as inconclusive; no successful simultaneous transaction or browser test is claimed. Both disposable allocations were rolled back.
- Older tests/document-numbering.cjs and tests/duplicate-booking-invoice.cjs embed copied implementation snippets; their output alone is not evidence that current source was exercised.

### Still unverified

- Current cloud browser sign-in: secure submission reached the live app error “Could not reach the sign-in service.” No new authenticated session was verified.
- Apple Mail opening/importing the exported EML and displaying its PDF attachment.
- Authorized live Gmail send and receipt.
- Two genuinely simultaneous committed orders from separate authenticated sessions.

Prior historical observations above remain dated evidence, not a claim that every flow was retested today.


### Current-source regression coverage — 2026-10-01

The document-numbering and duplicate-booking-invoice Node tests now extract the relevant implementation from invoice-sync.js and invoice-v2-embedded.html rather than execute copied snippets. Both pass against current source. Controlled local mutations confirmed that ignoring the server number or retaining the duplicate booking link makes the respective test fail. The allocator test also checks RPC failure propagation. These are frontend tests with a mocked server, not simultaneous database transaction evidence.


### Artist workflow and Owner queues — 2026-10-01

- Apple Mail EML device test skipped at user request; compatibility remains unverified.
- Transactional project tests passed creation, own updates, cross-account denial, reassignment denial, suspension and Owner oversight.
- File policy tests passed artist reference registration, forbidden artist master/reissue actions, missing-object rejection, Business denial, delivery expiry, Owner reissue and suspended access. Storage rows were temporary metadata fixtures; no actual object bytes were uploaded or downloaded.
- Management overview tests passed booking requests, upcoming sessions, expiring deliveries, expired-hold exclusion, overdue counts, separate BBD/USD balances, paid/void exclusion, and denial for active Business-only and Artist-only accounts.
- Test membership setup is explicit and rolled back, preserving current account states. Project/file count assertions scope to fixtures rather than assume an empty account.
- Live member browser navigation and actual upload/download remain unverified because cloud sign-in is blocked. Prior transactional booking/request/Owner approval/invoice checks remain recorded above.


### In-app notifications — 2026-10-01

Added account-owned notifications for new/changed bookings and master/MP3 delivery/reissue events. Source triggers ignore no-op updates. RLS restricts inbox reads and read-status updates to the authenticated recipient with active Artist access; notification body/recipient/creation is not writable by clients. The OS has an unread count, latest-50 inbox, mark-all-read and booking/project actions with 45-second refresh while visible. No external email sending or historical backfill.

Transactional tests passed booking request/confirmation, no-op replay, Owner/member recipient isolation, content/insert denial, mark read, delivery/reissue and suspension; all fixtures rolled back. JavaScript syntax checks passed. Live authenticated browser behavior remains unverified. Security advisor reports existing private-table and guarded-RPC notices plus the existing leaked-password-protection setting; no new notification finding.

## Owner analytics — 2026-10-01

- Database regression tests/owner-studio-analytics.sql passed: Owner 7/30/90-day windows, invalid-window rejection, stage totals equal eligible roster, USD invoiced/recorded-paid/outstanding increments, draft/void exclusions, active Artist and other non-Owner denial, suspended Owner denial. All fixtures and number allocations rolled back.
- Analytics uses current evidence stages without advancing retained career stage; excludes Owner, backfilled, reversed and future milestones. Finance is Owner-account all-time and grouped by currency. Bookings show current status, not verified attendance.
- Inline JavaScript syntax checked. Live authenticated browser verification remains blocked by the previously recorded sign-in connection issue; no live UI pass claimed.
- Security advisor retains existing 12 guarded public SECURITY DEFINER RPC warnings, three private RLS-without-policy notices and disabled leaked-password protection; no analytics-specific finding in the preceding advisor scan.
