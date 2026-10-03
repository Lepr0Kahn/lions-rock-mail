# Next steps and deferred Owner work

## 3 October 2026 — final acceptance progress

- External Cal.com reschedule/cancel acceptance is now complete. Cal.com replacement UIDs are reconciled back to the same Lions Rock Studio booking, and external cancellation correctly marks the same booking cancelled.
- Fixed the Cal.com replacement-UID webhook path so a replacement booking can recover its Lions Rock booking from preserved `osBookingId` metadata.
- Guardian/minor rollback-only acceptance passed: minor financial masking, guardian invoice routing, consent, payment/release gating, forged/expired link rejection, cash-request semantics and automatic link invalidation all verified.
- Updated the guardian regression fixture to use the current calendar-ticket guard.
- Fixed the Artist "Your next actions" unread notification count so exact Supabase count metadata is preserved.
- Services & Bookings UI cleanup completed in source: Bookings now focuses on Booking Queue and Book Session. Service administration moved to Settings.
- Settings now separates **Invoice & Business Settings**, **Invoice Services & Prices**, and Owner-only **Artist Booking Services** so invoice catalogue controls and Artist-facing booking controls are visibly distinct.
- Artist Booking Services create/edit/import permissions were exercised against the live database in a rollback-only acceptance test; no disposable data remained.
- UI source acceptance completed across Studio shell, Member, Bookings, Documents, Mail, Admin, Hub, Rewards and Guardian surfaces. All current inline scripts parse cleanly.
- Mobile polish added: narrow Studio header, larger touch targets, Rewards breakpoint, non-sticky Mail preview below desktop width, Hub in-app notifications, Escape-to-close modal behavior and improved status announcements.
- Embedded cache versions were bumped for Documents, Hub, Member, Bookings and Rewards so the next deployment does not serve stale UI.
- Shared document numbering acceptance is green: rollback numbering regression passed; zero duplicate document numbers, zero duplicate booking invoices, zero duplicate number reservations; Owner counter is aligned with the highest invoice number at 6 / INV-0006.
- The numbering function uses a per-account transaction advisory lock and the database also enforces unique `(user_id, doc_number)`, unique reservation-number and unique booking-invoice constraints.
- Vercel production routes are currently reachable and showed no runtime-error cluster or production 4xx route failures in the checked 24-hour window.
- **Deployment blocker:** Vercel is currently rate-limiting new builds. GitHub reports: `Deployment rate limited — retry in 24 hours.` Newest UI commits are therefore source-ready but not all live yet.
- Guardian approval presentation polished in source: Lions Rock styling, clearer hierarchy, accessible status messaging and explicit Barbados-time link expiry.
- Admin Security now completes the safe Owner MFA sequence in source: primary authenticator enrollment, backup authenticator enrollment, session verification, then explicit enable/disable enforcement controls. Backend still requires two verified TOTP factors and aal2 before enabling.
- Rollback security guard test confirmed enforcement is rejected with zero verified factors. Current Owner state remains 0 factors / enforcement OFF.
- Supabase Security Advisor rechecked: leaked-password protection remains disabled; the available connected Supabase toolset exposes no hosted Auth-setting mutation, so this remains a deliberate Dashboard-level rollout rather than an unsafe workaround.

### Remaining acceptance / rollout
1. Deploy the accumulated UI batch once the Vercel build-rate limit clears, then perform the final Mac + iPhone walkthrough against production.
2. Run one live guardian-page/email walkthrough after deployment to confirm presentation and handoff, not backend logic (backend guardian workflow already passed).
3. Owner security rollout remains deliberate and interactive: enroll/verify Owner TOTP before MFA enforcement; separately decide whether to enable leaked-password protection / stronger Auth password policy.
4. Final documentation closeout after production UI verification.

Updated 2 October 2026, following the user's instruction to continue independent work and save approval/sign-in steps until they are available.

## Current work order — user decision, 2 October 2026

The user has deferred verification until all implementation work is complete after repeated message-stream errors during the verification workflow. Do not retry live booking/browser/device/security acceptance or use those checks as a prerequisite for independent implementation. This is a scheduling decision, not a passing test result or a confirmed diagnosis of the stream error.

- Continue remaining migration implementation from the current source and feature requirements.
- Keep all unfinished acceptance items in MANUAL_TEST_CHECKLIST.md for one final testing phase after implementation.
- Do not repeat Owner sign-in or create disposable live bookings merely to resume the build.
- Keep existing security controls in place; MFA enforcement remains off pending the previously required final acceptance.
- Online payment integration still depends on the user's provider/business-account selection; do not choose a provider, enable charges or purchase a paid AI service automatically.
- No historical import/export is required.
- Distinguish implemented features from verified behavior in progress reports. Do not mark deferred checks as passed.

## Completed without requiring a reply

- Calendar synchronization activation and actual server-role permission fix.
- Live read-only verification of account, six hidden zero-payment events and signed webhook configuration.
- Live read-only availability returned eight Cal.com slots on each of 5, 6 and 7 October; seven Monday slots match the OS 10am–10pm rules. No slot reserved.
- Scheduler reports successful runs; synchronization active, no test operations left in the queue.
- Rollback-only database integration: create booking, generate/reopen exactly one invoice, preserve price and 50% deposit, change time/duration, cancel, retain invoice identity.
- Shared invoice sequence verified generator reservation → OS invoice → next generator reservation; quote retry stable.
- Fixed rescheduling availability to exclude only the server-verified current provider UID, so the session does not block itself. Mock reschedule and duration-replacement regressions passed; deployed worker includes the fix.
- Frontend allocation/mapping regressions passed; modified admin scripts parse.

## Live Owner work now completed

Owner sign-in, initial booking synchronization, linked invoice reuse, duration/time replacement and normal cancellation were exercised live. A delayed old-reservation cancellation race was found and fixed (worker v7 plus guarded reconciliation). The disposable session is cancelled in both systems and INV-0003 voided unpaid. Fresh replacement acceptance and external calendar edits remain pending; see CAL_COM_SYNC_STATUS.md.

## Deferred Owner acceptance — final testing phase

1. Real booking/notification lifecycle and browser acceptance. Candidate: Record an Ad, Monday 5 October 2026 at 10am Barbados, one hour; BBD100 with 50% deposit recorded in the OS. Use the Owner's own contact, not an external artist. Recheck the current catalogue and availability before creation. Move to an available Tuesday time, verify duration change, then cancel and verify both systems. No real payment is part of this test.
2. Secure Owner browser sign-in succeeded on 2 October. Preserve that session when available; never extract credentials or tokens. The live test above does not establish all external webhook changes or notification receipt.
3. Online payment provider/business account selection and secure merchant sign-in; no provider chosen automatically, no production charges/refunds enabled.
4. Any paid AI provider connection, if requested. Current Direction Engine uses the existing rule-based guidance; no paid provider purchase is required for that path.
5. Final security/MFA/invite/suspension/isolation acceptance, as deferred by the user.

## Deferred acceptance — final testing phase

Real calendar webhook delivery/rescheduling/cancellation, recovery under a real provider timeout, simultaneous committed orders, actual file playback/download, Mail sending and device checks remain on MANUAL_TEST_CHECKLIST.md. Database rollback tests and mocks do not establish those passes.

Historical import/export is out of scope: user explicitly has no old data to bring over. Preserve existing tools, catalogue edits, invoice sequence and Owner managerial landing.


## Migration hardening completed — 2 October 2026
- Re-audited Emergent progression/XP semantics against the Supabase implementation; no duplicate XP ledger was added because the current immutable career-event ledger already provides idempotency and reversible credit.
- Added Owner-configurable reward cost estimates and 90-day exposure planning. Live backend and deployed rewards UI verified present.
- Added a read-only Owner Assurance RPC and Admin tab. Current live database result is healthy: zero pending/failed calendar operations, zero stale leases, zero booking/invoice integrity exceptions and zero duplicate career source events.
- The remaining three Emergent badges tied to session/cycle completion stay intentionally disabled until authoritative completion evidence exists; elapsed time alone is not accepted as attendance.


## Authoritative session completion — completed 2 October 2026
- Owner can mark a past confirmed session completed from Studio Booking Queue.
- Completion is a separate one-per-booking record; booking/calendar status is not rewritten.
- Completion writes one idempotent `session_completed` career event, worth 200 XP.
- Emergent badges **In The Room** (1 completed session) and **Studio Regular** (5 completed sessions) are now available.
- Career track `sessions_completed` now uses Owner-confirmed records instead of elapsed confirmed bookings.
- Owner Assurance flags past confirmed sessions that still need completion review.
- Real acceptance of the completion button remains naturally deferred until there is an actual past confirmed session to complete.


## Release-cycle completion — completed 2 October 2026
- Project Released now records an idempotent `cycle_completed` event alongside `release_published`.
- Each completed cycle is worth 300 XP.
- **Repeat Cycle** now unlocks after two completed release cycles, matching the Emergent reference behavior.
- Rollback tests passed for event uniqueness, XP and badge eligibility.


## Live booking lifecycle acceptance — completed 2 October 2026
- Reused the two existing production Cal.com lifecycle test bookings rather than creating another notification-generating test event.
- Verified initial 60-minute Cal.com creation, replacement to a 120-minute duration/time, and final cancellation all reached synchronized state.
- Verified Cal.com still contains the original and replacement booking UIDs as cancelled records, matching the OS calendar aliases and final provider links.
- Verified each OS booking retained exactly one invoice throughout the lifecycle: INV-0003 and INV-0004 respectively.
- Verified the booking invoices retained the configured 50% deposit percentage after reschedule/duration replacement.
- Final cancellation leaves the linked invoice void, as intended, without creating a replacement invoice number.


## File / audio delivery acceptance — 2 October 2026
- Verified the private `artist-project-files` bucket and RLS read policy only expose registered project files to an active Artist owner of the file or the Studio Owner, and deny expired deliveries.
- Verified existing production delivery metadata matches the registered file record exactly (41-byte legacy text test master; no audio object existed yet for byte-level playback acceptance).
- Rollback-only production test: forced the existing master expiry into the past; storage visibility dropped to 0; called `reissue_artist_delivery`; storage visibility returned to 1; transaction rolled back so production expiry was unchanged.
- Verified master / MP3 registration receives a 30-day expiry and collection recording requires a currently available own delivery.
- Added inline audio playback for project files with common audio extensions (MP3, WAV, M4A, AAC, OGG/OGA, FLAC, WebM), using the same authenticated private-bucket download path.
- Added 15-second timeout/error exits for project audio playback and file downloads and object-URL cleanup when project/file context changes.
- Final actual audio-byte playback/download acceptance still requires at least one real audio project file in the bucket; the current production object is text/plain, not audio.
- Vercel production was still on commit `e81f47a...` when checked, so the latest Artist workspace audio UI and final cache/version bumps were in GitHub but not yet reflected by the production deployment.


## Mail sending / attachments acceptance — 2 October 2026
- Confirmed Mail sends through the Gmail API using the authenticated user's Gmail OAuth token and writes messages to Gmail Sent when successful.
- Confirmed real MIME attachments are included with `Content-Disposition: attachment` and per-file MIME types.
- Confirmed Documents/Invoices generates a real PDF attachment in-browser, base64-encodes it, and passes it to Mail via the Studio shell handoff.
- Hardened Gmail sends with a 20-second timeout and an explicit warning that a timed-out send may still have completed, so Sent should be checked before retrying.
- Unified the attachment limit at 20 MB and made the UI text match the actual guard.
- Added the same 20 MB total guard to Studio-generated PDF attachments so document handoff cannot bypass the manual attachment limit.
- Source-level regression check: no duplicate named functions introduced; MIME attachment construction and Studio document handoff remain present.
- Live Gmail-send acceptance still requires the Owner's interactive Google OAuth session; no real outbound message was sent automatically during this implementation pass.


## Access / security acceptance — 2 October 2026
- Verified workspace helpers under live account types: Artist-only => Artist access true / Business false; Business-only => Business true / Artist false; pending account => neither.
- RLS impersonation checks showed Artist-only cannot see Business clients/documents; Business-only cannot see Artist projects/files/bookings; pending account sees neither workspace.
- Membership visibility is isolated for non-Owners: Artist and Business members can only see their own membership row; Owner can see the full access list.
- Rollback-only suspension test: changing the active Artist to suspended immediately made both Artist and Business access helpers false; transaction rolled back.
- Rollback-only soft-removal test: deleted/suspended Business member lost both workspace helpers and could see zero clients/documents; transaction rolled back.
- Reviewed Owner MFA RLS policies: they are RESTRICTIVE, so they narrow access rather than widening it.
- Reviewed invite creation/claim Edge Functions: create requires active Owner + MFA; claim requires the authenticated invited user, matching pending invite/access type, rejects expiry and suspended accounts, and activates only the invited workspace.
- Reviewed password recovery: recovery link returns to Studio reset mode, password update preserves membership/workspace state, then local session is signed out and reauthentication is required.
- Added timeout protection to sign-in, reset request, password update, invite password setup, invite claim, and post-claim session refresh.
- Owner MFA enforcement is currently NOT enabled because `private.owner_mfa_settings` has no Owner row. Do not enable automatically without confirming an authenticator is enrolled, to avoid lockout.
- Supabase security advisor still reports leaked-password protection disabled; this is an account-level Auth hardening setting.


## Instrumental Vault acceptance — 2 October 2026
- Existing Nejes catalogue item verified published, non-archived, with stored clean master and watermarked preview.
- Existing Artist lease request verified in requested state at BBD 100.
- Artist without an Artist Name is now blocked at the database layer from creating new lease/exclusive requests.
- Owner approval is now blocked until the requesting Artist has an Artist Name; generated lease invoices use Artist Name as client_name.
- Owner UI marks legacy requests missing Artist Name with "Artist Name required before approval" and withholds the Approve button until identity is complete.
- Storage RLS acceptance: published preview visible to Artist; clean master hidden before release.
- Release guard acceptance: Owner cannot release before full invoice payment is recorded.
- Delete integrity acceptance: once lease/request history exists, the instrumental cannot be permanently deleted because the request FK protects history; use Archive instead.
- Live approval/payment/release was intentionally not committed while the requesting Artist has no Artist Name. Once that Artist signs in and completes onboarding, the existing request can continue normally without recreating it.


## PayPal sandbox acceptance — 2 October 2026
- Sandbox credentials verified in the secure Supabase payment worker.
- Artist checkout created a PayPal order for INV-0005 and captured USD 50.00 for BBD 100.00 at the configured 2.00 BBD/USD conversion.
- Verified capture recorded exactly one Lions Rock payment: receipt INV-0005-P001; invoice status paid; amount paid BBD 100.00; balance BBD 0.00.
- Nejes lease released only after full payment and the Artist gained clean-master access after release.
- PayPal webhook configuration repaired: one matching listener now subscribes to CHECKOUT.ORDER.APPROVED, PAYMENT.CAPTURE.COMPLETED, PAYMENT.CAPTURE.DENIED and PAYMENT.CAPTURE.REFUNDED.
- Real PAYMENT.CAPTURE.COMPLETED event replayed from PayPal and accepted with HTTP 200, stored once in studio_paypal_events.
- Same PayPal event replayed again; idempotency passed: one webhook row, one payment row, no duplicate invoice credit.
- PayPal health endpoint is read-only after testing. Refund semantics remain intentionally unimplemented pending business rules for refunded licences/releases.


## Real audio delivery acceptance — 2 October 2026
- Created a disposable Artist project for Lepr0Kahn and used a genuine 5.2 MB MP3 master from private Studio storage as the delivery payload.
- Registered the delivered file as kind=master with a 30-day expiry in artist-project-files.
- Authenticated Artist RLS could read the full object metadata as audio/mpeg; delivery collection RPC succeeded.
- Forced expiry removed Artist storage visibility immediately.
- Owner reissue RPC restored a fresh 30-day window.
- Repeated collection remained idempotent: exactly one artist_delivery_collections row.
- Disposable acceptance project archived after testing.
- Temporary server-copy endpoint was disabled immediately after the one-time copy and left JWT-protected/inert.


## Owner ↔ Artist relationship snapshot — 2 October 2026
- Added an Owner-only Artist Snapshot to the Management Dashboard.
- Owner can select an active Artist Member and see active/released projects, current unexpired master/MP3 delivery count, next requested/confirmed studio session, open Vault request count, XP/level and current career stage.
- Snapshot links directly to Artist career progress, studio bookings and projects.
- Adult Artist contact can open the existing Lions Rock Mail composer from the snapshot; no separate mail system was created.
- Minor Artist email action is disabled in the snapshot so guardian/financial communication continues through the guardian workflow.
- Artist permissions/RLS were not broadened by this UI change.
- Modified inline scripts parse successfully. Live browser acceptance remains in the final testing phase.


## Artist next-actions dashboard — 2 October 2026
- Added an Artist-only **Your next actions** panel on the Career Dashboard.
- The panel consolidates existing secure records instead of creating new workflow state.
- It prioritizes payable invoices, current master/MP3 deliveries, released/approved Vault requests, scheduled/approved rewards, upcoming/requested studio sessions and unread Studio notifications.
- Each item routes the Artist directly to the existing Billing, Project, Vault, Rewards, Bookings or Notifications surface.
- Minor Artist accounts do not receive direct payment prompts; guardian financial workflow remains separate.
- Owner accounts do not see this Artist action panel.
- Empty state explicitly tells the Artist when there is nothing urgent.
- Modified Studio member scripts parse successfully. Live browser/device acceptance remains in the final testing phase.


## Owner / Artist relationship activity timeline — 2 October 2026
- Added Artist-facing **Recent Studio Activity** beneath **Your next actions**.
- Artist activity is derived from existing career-history evidence and Studio notifications; no duplicate activity ledger or new permissions were introduced.
- Added Owner-facing **Relationship history** inside the Artist Snapshot.
- Owner history combines authoritative Artist career/studio events with the Artist's Studio notifications and shows the latest relationship activity in Barbados time.
- Reversed career events are excluded from both timeline views.
- Email drafts are deliberately not represented as sent mail unless separate delivery evidence exists.
- Minor Artist access continues to use the existing restricted notification path.
- Modified Studio member scripts parse successfully. Live browser/device acceptance remains in the final testing phase.


## Communication loop hardening — 2 October 2026
- Audited Owner actions against in-app notifications and existing email-draft actions.
- Existing database notifications already cover booking changes, master/MP3 delivery/reissue, Vault request state changes and payment ledger entries.
- Added database-triggered Reward notifications for request, approval, scheduling/rescheduling, fulfilment, decline and cancellation.
- Reward notifications go to the Artist and Owner and use deterministic event IDs so the same trigger event cannot duplicate.
- Added Rewards as a first-class notification destination in the Artist workspace.
- Extended payment notifications so booking invoice payments/refunds/corrections also notify the linked Artist in Bookings, while the Owner retains the Payments notification. Vault-linked invoice notifications remain routed to Vault.
- Rollback verification: reward request → approve → schedule produced six notifications total (Artist + Owner for each state change); booking payment verification produced exactly two notifications (Owner Payments + Artist Bookings).
- All rollback test rows and notifications were confirmed absent afterward.
- Existing email options remain paired with the major Owner actions: booking confirmation, delivery, Vault approval/release, reward state, payment receipt/refund/correction and guardian approval.
- Security advisor was rerun after the DDL change. No new public/exposed notification function was added; the new trigger function is in private schema with execute revoked from anon/authenticated. Existing advisor items remain for the final security pass, including leaked-password protection and previously known SECURITY DEFINER/public-function findings.
- Studio member inline scripts parse successfully after adding the Rewards notification route.

## Final security hardening review — 2 October 2026
- Re-ran the Supabase Security Advisor after the communication-loop migrations.
- Verified all currently flagged public SECURITY DEFINER RPCs are not executable by anon. They are executable by authenticated users because the Studio UI requires them, and each reviewed function performs its own Owner / Artist / active-membership authorization before privileged work.
- Verified the flagged private tables (career state, reward, guardian, calendar and Owner MFA tables sampled in this pass) have no anon/authenticated table privileges. Their “RLS enabled, no policy” findings are therefore informational rather than browser exposure.
- Verified public PayPal event/intent/settings tables have no anon/authenticated select or write privileges despite the Advisor's no-policy informational finding.
- Owner application MFA remains not enforced. The current Owner account has no verified MFA factor, and private.owner_mfa_settings has no enforcement row. Do not enable enforcement until the Owner enrolls and verifies a TOTP factor through the existing MFA UI; otherwise Owner lockout is possible.
- Supabase Auth leaked-password protection remains disabled. Current Supabase documentation notes that enabling stronger password/leaked-password rules can surface weak-password errors for existing credentials. Treat this as an explicit Auth-setting rollout, not a silent database migration.
- pg_net remains installed in the public schema and is still reported by the Advisor. It was not moved during this pass because extension relocation can affect dependent functions and should be handled as a separate compatibility change.
- No functional database grants were broadened during this security review.
- Remaining final-security actions: Owner TOTP enrollment + MFA enforcement acceptance; deliberate Auth password-policy/leaked-password rollout; optional pg_net relocation compatibility review.
