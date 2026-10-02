# Cal.com availability preview

Six real OS offering UUIDs mapped to Cal.com event IDs in config/cal-com.json. Full mix live duration is 120; Instrumental creation event 7314363 is live at 180, hidden and requiring confirmation. Other four events remain paid.

Owner Calendar Connection now offers a bounded single-date preview (within 180 days) combining server-side Cal slots with caller-scoped studio_availability. Enforces exact OS/provider duration and provider ownership. Compares normalized instants, excludes past times and OS unavailable slots. Provider failure returns an error without OS-only fallback. API secrets never reach browser. No reservation, payment, invoice or booking mutation occurs.

Mock intersection, held slot, provider failure and duration mismatch checks passed; scripts parse. Live Owner API preview not yet verified. The normal booking UI remains OS-only, and bypassing preview is possible; this is not full conflict prevention or synchronization. Dynamic durations, unmapped offerings (including Full Production Package), reward events, provider booking creation, operation reconciliation, webhooks and external cancellations are pending. Final live/security acceptance tests remain deferred per user instruction.
