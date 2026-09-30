# Lions Rock Studio — Functional Test Record

Last updated: 2026-09-30

## Access separation

- Owner account: Business Tools access = true; Artist Member access = true.
- Business-only test account: Business Tools access = true; Artist Member access = false.
- Transactional RLS test with a temporary client row:
  - Business-only account could read its Business Tools client row.
  - The same account simulated as Artist-only could not read that client row.
  - Artist access remained true while Business Tools access became false.
- Temporary test rows were wrapped in database transactions and rolled back.

## Invite-only access

- Public application Edge Function is closed and returns invite-only status.
- Legacy application activation Edge Function is closed.
- Private invites are recorded in `studio_invites`.
- Invites have a 7-day expiry.
- A new user's workspace entitlement is not activated when the link is created.
- The entitlement is granted only when the authenticated invite is claimed.
- Existing users can receive a second workspace entitlement without losing their existing one.
- Suspended accounts cannot claim a new entitlement until reactivated.
- Supabase Auth action links remain one-time Auth links; the database separately tracks pending/claimed/revoked invite state.

## Static code checks

The following current files passed JavaScript syntax validation:

- `studio.html`
- `studio-admin.html`
- `studio-hub.html`
- `invoice-v2-embedded.html`
- `invoice-sync.js`
- `mail-v5-1-embedded.html`
- `studio-member.html`

## Database security checks

Business Tools tables continue to require `private.has_active_studio_access()`, which now requires a Business Tools entitlement (or Owner role).

Artist-only accounts therefore cannot query:

- clients
- business projects
- documents
- business settings
- services used by Business Tools

`studio_invites` is readable only by the invited user or the Owner.

Supabase security advisor currently reports only the pre-existing leaked-password-protection warning.

## Still requiring live browser testing

These need a real browser/Auth-session pass after the functional merge:

- clicking a generated invite link
- first-time password setup
- existing-account invite acceptance
- sign-out / sign-in persistence
- wrong-workspace login messaging
- iPhone/PWA visual behavior
- live Vercel deployment behavior

The user will handle visual review after the functional layers are complete.
