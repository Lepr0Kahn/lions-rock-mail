# Next steps and deferred Owner work

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
