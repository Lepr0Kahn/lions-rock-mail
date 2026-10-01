# Rewards migration review — 2026-10-01

Status: review only. No reward, XP award, discount or free-service entitlement is active from this proposal.

## Recommendation
Migrate XP, levels and badges first. Keep all seven tangible benefits disabled until the Owner sets their capacity and terms. Existing career tracks remain separate from XP. No invoice discount, booking, lease or external message is created by unlocking a level.

## Source benefits requiring a business decision
| Benefit | Unlock | Source total capacity | Source validity | Source estimated value BBD | Adaptation |
|---|---:|---:|---:|---:|---|
| 10% off next mix | 2 | 20 | 60 days | 55 | At the current Full Mix 350 BBD reference price this is 35 BBD. Apply to an eligible mix line, never the entire invoice. |
| Instrumental lease | 3 | 10 | 90 days | 150 | Pending vault catalogue and approved licence terms; instrumental creation is a different service. |
| Priority booking | 4 | 10 | 180 days | 0 | Define priority window; must not displace confirmed bookings. |
| 2-hour recording block | 5 | 6 | 90 days | 350 | Confirm recording service, engineer inclusion and value from live service catalogue. |
| Free single mix | 6 | 4 | 120 days | 550 | Current Full Mix reference is 350 BBD and 2 hours, replacing source 550 BBD / 3 hours. |
| Showcase slot | 7 | 4 | 180 days | 250 | Requires an actual event and available slots. |
| Promotional feature | 8 | 2 | 365 days | 400 | Define deliverables and staffing capacity. |

Source values are historical estimates, not approved prices. Capacity is a total issuance pool in the source, not a monthly allowance. Fulfilled benefits consume capacity permanently. Denied/expired available benefits release capacity. Claimed benefits need an explicit fulfilment deadline rather than silently expiring.

## Recognition rules ready to adapt
Use source level thresholds 0, 250, 600, 1200, 2000, 3200, 5000 and 7500 XP, with source titles Initiate through Lion. Draft event-point mapping is in config/rewards-migration-proposal.json.
- First project earns 150 instead of stacking a separate first-project award on 50.
- First eligible upload earns 100 once; uploading extra copies is not an XP source.
- A confirmed booking earns 75 once; requested/cancelled holds are ineligible.
- Master delivery 250 and collection 100 should be capped per project so WAV, MP3 and reissue cannot multiply benefits.
- Fully paid, positive, eligible invoice earns 75 once; partial payment and void/corrected settlement are ineligible.
- Published release earns 500 once per project; repeated status toggles cannot multiply XP.
- Session-completed 200 and cycle-completed 300 remain disabled until authoritative completion records exist.
- Reversal/correction preserves the audit trail and removes credit. Recognition badges must show current eligibility after correction.
- No automatic legacy XP backfill. Define the start date separately, or review replayed historical evidence before enabling.
- Owner oversight only; active Artists see their own records. Business-only, suspended, deleted and expired members cannot claim.

## Implementation constraints
Use database uniqueness and row locks, rather than source read-then-write checks, for one award per event and finite-capacity reservations. Claims and fulfilment require atomic status transitions and an audit reason. Notifications stay transactional and in-app. A fulfilled reward must link to the existing booking/document system and preserve its shared numbering. Any monetary application is a separate explicit Owner action.

Source reviewed: backend/rewards.py, backend/routes_progression.py, backend/progression.py, backend/seed.py and frontend/src/pages/admin/AdminRewards.jsx. Source seed/demo accounts and authentication are not imported.

## Next decision
Approve recognition-only rollout with every tangible benefit disabled, or specify which benefits to activate and their total capacity. Recommended first rollout: recognition only.
