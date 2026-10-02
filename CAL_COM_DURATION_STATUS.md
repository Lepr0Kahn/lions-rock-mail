# Cal.com duration update

Owner Calendar Connection now offers Set Full mix to 2 hours. studio-cal-connection permits only the fixed duration change for event 5500456 after active Owner and MFA checks and Cal account verification. It reads the event before changing, patches lengthInMinutes only, and verifies by rereading. It skips a write if already 120 minutes. Uses API version 2026-06-12. No bookings, price, deposits or other events are edited. No automatic mutation retries.

Syntax and mocked duration-only/idempotent checks passed. Actual write and permissions require the Owner to invoke the control. Instrumental creation event setup, OS offering mapping, provider availability and booking synchronization remain outstanding.
