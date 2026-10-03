# Lions Rock Artist Level System

Updated 3 October 2026.

## Design principle

Career Stage and XP Level are separate systems.

- **Career Stage** is evidence-based and follows the existing eight-step lifecycle: Join → Discover → Plan → Create → Produce → Prepare → Release → Grow.
- **XP Level** is the motivational recognition layer. XP is earned only from recorded studio/career evidence. It is not spent and does not replace Career Stage.

## Level 1–20 ladder

| Level | Title | Tier | XP floor |
|---:|---|---|---:|
| 1 | Initiate | Foundation | 0 |
| 2 | First Step | Foundation | 100 |
| 3 | Apprentice | Foundation | 250 |
| 4 | Builder | Foundation | 450 |
| 5 | Contender | Momentum | 700 |
| 6 | Craftsman | Momentum | 1,000 |
| 7 | Studio Regular | Momentum | 1,350 |
| 8 | Professional | Momentum | 1,750 |
| 9 | Momentum | Spotlight | 2,200 |
| 10 | Rising | Spotlight | 2,700 |
| 11 | Headliner | Spotlight | 3,250 |
| 12 | Standout | Spotlight | 3,850 |
| 13 | Catalyst | Prestige | 4,500 |
| 14 | Cornerstone | Prestige | 5,200 |
| 15 | Prime | Prestige | 5,950 |
| 16 | Elite | Prestige | 6,750 |
| 17 | Lion | Legacy | 7,500 |
| 18 | Vanguard | Legacy | 8,500 |
| 19 | Icon | Legacy | 9,450 |
| 20 | Legacy | Legacy | 10,500 |

## Existing authoritative XP awards

These are unchanged by the 20-level expansion.

| Recorded evidence | XP |
|---|---:|
| Membership granted — first eligible event | +50 |
| Career profile completed — first eligible event | +100 |
| First project created | +150 |
| Additional unique projects | +50 each |
| First material upload | +100 |
| Confirmed session booked | +75 |
| Studio master / MP3 delivered | +250 |
| Studio delivery collected | +100 |
| Linked invoice settled | +75 |
| Release published | +500 |

Duplicate/replayed evidence is deduplicated by the existing career ledger rules. Reversed or ineligible evidence does not count. Backfilled history does not count toward recognition XP.

## Existing badges

- Identity Locked
- First Blueprint
- Tape Rolling
- First Master
- Five Masters
- Delivered
- First Release
- Catalogue Builder
- Straight Business

## Member-facing game UI

The member Development area shows:

- large circular Level badge with XP-ring progress
- current Level number
- recognition title
- tier name
- animated XP progress bar
- total XP
- XP earned within the current level
- XP remaining to the next level
- earned/unearned badge chips
- recent XP evidence

### Reward interaction rules

- A page refresh does not repeatedly trigger reward effects.
- The browser stores the last XP/Level the member has already seen.
- If XP increases, a subtle floating **+XP** chip appears.
- If the new XP also crosses a level threshold, a restrained **Level Up** modal appears.
- The modal has no forced sound.
- Reduced-motion preferences disable the animations.
- Owner view stays calmer and shows the same authoritative XP data without the game animation.

## Tier visual language

- **Foundation** — bronze
- **Momentum** — silver
- **Spotlight** — gold
- **Prestige** — crimson
- **Legacy** — pale platinum

These tiers are visual recognition bands only. They do not change permissions, pricing, rewards, or Career Stage.
