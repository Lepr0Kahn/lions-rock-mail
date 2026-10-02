# Artist development reward benefits

Implemented: separate custom catalogue, inactive draft studio session/photo shoot/interview/behind-the-scenes/spotlight rewards, Owner scope/XP/capacity editing and active/archive controls, Artist claims, Owner approval/decline and recorded fulfilment. All seeded rewards inactive. Paid services, prices, invoice allocator and booking charges are untouched.

Rules: XP is a non-spendable eligibility milestone. Capacity counts requested, approved and fulfilled claims; denied claims release a place. One successful claim per artist per reward; repeated requests reuse the current claim. Claim snapshots protect agreed scope against later catalogue edits. Approval/fulfilment check current active Artist eligibility and snapshot XP requirement. Owner must record decline reason or fulfilment detail. Scheduling is arranged by studio; marking fulfilled records an experience already delivered and does not create a booking, publication or invoice.

Future rewards are configurable by Owner. No historical import is required per user decision. No discounts, cash credits, automatic free service conversion or provider billing are enabled.

Verification: rollback custom save/claim retry/capacity/approval/fulfilment checks passed, documents count unchanged. Current UI scripts parse. Schema advisor review found only existing public definer/leaked-password warnings and intentional private deny-by-default tables without policies (new rewards/claims tables have no client grants). Live UI, eligibility changes, concurrent requests, cross-account/security and device checks stay in the final phase.

Remaining limitations: no automatic service booking/calendar conflict detection or automatic email sending. Approved experience scheduling/rescheduling and unfulfilled claim cancellation are now supported. Owner supplies exact duration/deliverables in scope before activation. Recognition now derives benefit availability from the active reward catalogue.


Scheduling/cancellation/email update: Owner can schedule future experiences with Barbados date/time, duration and location. Cancellation retains the record, requires a reason, frees capacity and allows a fresh request; fulfilled claims cannot be cancelled. Notice payload uses current artist/guardian contact and keeps manual review/send in existing Mail. Rollback schedule, notice, cancellation retry and re-claim checks passed. Reward email checks passed recipient, scheduled subject/time/newlines and missing contact rejection; page scripts parse. Live handoff, real email send, calendar availability and phone input checks remain final-phase tests.
