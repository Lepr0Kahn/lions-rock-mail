# Artist development reward benefits

Implemented: separate custom catalogue, inactive draft studio session/photo shoot/interview/behind-the-scenes/spotlight rewards, Owner scope/XP/capacity editing and active/archive controls, Artist claims, Owner approval/decline and recorded fulfilment. All seeded rewards inactive. Paid services, prices, invoice allocator and booking charges are untouched.

Rules: XP is a non-spendable eligibility milestone. Capacity counts requested, approved and fulfilled claims; denied claims release a place. One successful claim per artist per reward; repeated requests reuse the current claim. Claim snapshots protect agreed scope against later catalogue edits. Approval/fulfilment check current active Artist eligibility and snapshot XP requirement. Owner must record decline reason or fulfilment detail. Scheduling is arranged by studio; marking fulfilled records an experience already delivered and does not create a booking, publication or invoice.

Future rewards are configurable by Owner. No historical import is required per user decision. No discounts, cash credits, automatic free service conversion or provider billing are enabled.

Verification: rollback custom save/claim retry/capacity/approval/fulfilment checks passed, documents count unchanged. Current UI scripts parse. Schema advisor review found only existing public definer/leaked-password warnings and intentional private deny-by-default tables without policies (new rewards/claims tables have no client grants). Live UI, eligibility changes, concurrent requests, cross-account/security and device checks stay in the final phase.

Remaining limitations: no reward expiry scheduling, no approved-claim cancellation flow, no automatic service booking/calendar/email fulfilment. Owner supplies exact duration/deliverables in scope before activation. Existing recognition projection still labels benefits_enabled false; the separate Rewards tab is authoritative for availability until that display is updated.
