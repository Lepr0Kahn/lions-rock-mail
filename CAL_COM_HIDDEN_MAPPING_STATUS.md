# Verified hidden OS event mapping

Live Cal.com plugin read verified OS events: Record an Ad 7314681 (60), Record a Song 7314682 (60), Instrumental Mix 7314683 (60), Vocal Mix 7314684 (60), Full Mix 7314685 (120), plus Instrumental creation 7314363 (180). Owner preparation screenshot confirmed hidden events with no provider payment. config/cal-com.json now uses these event IDs and preserves original public event IDs separately.

Server availability preview now uses hidden events and rejects nonzero provider price, unexpected duration/ownership, non-hidden status or missing studio confirmation. Caller-scoped OS slots and Cal slots still intersect. Owner preview defaults to tomorrow in Barbados; changing service/date clears old results.

Mock tests passed for matching slots, OS held slots, provider failure, duration mismatch and paid event rejection. Source parses. Normal booking flow still OS-only. No provider booking/reservation writes, automatic rescheduling/cancellation, durable recovery or webhooks implemented yet; synchronization remains off. Integration activation must wait for those flows to prevent divergent bookings. Final live/security test checklist remains deferred.
