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
