# Next steps and deferred Owner work

Updated 2 October 2026, following the user's instruction to continue independent work and save approval/sign-in steps until they are available.

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

## Remaining Owner acceptance

1. Real booking/notification lifecycle and browser acceptance. Candidate: Record an Ad, Monday 5 October 2026 at 10am Barbados, one hour; BBD100 with 50% deposit recorded in the OS. Use the Owner's own contact, not an external artist. Recheck the current catalogue and availability before creation. Move to an available Tuesday time, verify duration change, then cancel and verify both systems. No real payment is part of this test.
2. Secure Owner browser sign-in succeeded on 2 October. Preserve that session when available; never extract credentials or tokens. The live test above does not establish all external webhook changes or notification receipt.
3. Online payment provider/business account selection and secure merchant sign-in; no provider chosen automatically, no production charges/refunds enabled.
4. Any paid AI provider connection, if requested. Current Direction Engine uses the existing rule-based guidance; no paid provider purchase is required for that path.
5. Final security/MFA/invite/suspension/isolation acceptance, as deferred by the user.

## Remaining acceptance

Real calendar webhook delivery/rescheduling/cancellation, recovery under a real provider timeout, simultaneous committed orders, actual file playback/download, Mail sending and device checks remain on MANUAL_TEST_CHECKLIST.md. Database rollback tests and mocks do not establish those passes.

Historical import/export is out of scope: user explicitly has no old data to bring over. Preserve existing tools, catalogue edits, invoice sequence and Owner managerial landing.
