# Separate OS calendar events

User approved keeping existing five paid public events unchanged and preparing separate hidden non-payment events for OS bookings. Owner Calendar Connection offers Prepare OS calendar events through the authenticated server.

Creates/reuses exact slugs os-record-an-ad (60), os-record-a-song (60), os-instrumental-mix (60), os-vocal-mix (60), os-full-mix (120). Instrumental creation already exists separately at 180 minutes. All prepared events are hidden, have confirmation policy always, and must verify zero price, ownership and duration. No payment app is configured. Same schedule ID as the corresponding public event is carried when present. Hidden is profile visibility, not access protection. Do not distribute these links as paid service purchase links.

No public event PATCH, booking creation, invoice or deposit mutation occurs. Before create, matching slug is checked; conflicting existing settings are rejected. Each result is reread. Partial progress is returned on failure; no automatic mutation retry. Subsequent explicit invocation reuses already verified events. Provider slug uniqueness must prevent concurrent duplicates.

Syntax and mock create/reuse/payment-conflict tests passed. Live event preparation requires Owner button invocation. API permissions, actual response shape and calendar conflict settings need verification. Booking/reservation synchronization, durable operations, external webhook changes, adjustable-duration support and live acceptance tests remain pending. Availability preview still maps to original public events until new event IDs are verified.
