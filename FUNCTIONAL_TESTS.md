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
- non-owner sign-out / sign-in persistence
- wrong-workspace login messaging
- iPhone/PWA visual behavior
- live Vercel deployment behavior

The user will handle visual review after the functional layers are complete.

## Production follow-up — 2026-09-30

- PR #2 merged as `a12469ff4345d27dad79ddbf26c790689e3f1107`.
- Production deployment `dpl_8sNXYdC4wHxzYMZHwPaD47Cu6qDk` reached READY.
- Production `studio-admin.html` returned HTTP 200 and contains the verified Auth state listener.
- Live create-invite and claim-invite endpoints both returned HTTP 401 for unauthenticated POST requests.
- Additional rolled-back database assertions passed: invited user can read only their own test invite, Owner can read both test invites, pending invite grants no Artist entitlement, and member membership rows are isolated.
- Authenticated invite creation/claim and wrong-workspace browser tests still require a dedicated non-owner test session.
- Build-log retrieval was unavailable through the connected Vercel tool; no clean build-log scan is claimed.


## Live Business account verification — 2026-09-30 22:10–22:13 UTC

- Claimed Business Tools invitation confirmed for tarikdelves@gmail.com (member, active, artist disabled).
- Password recovery request was recorded by Supabase; user completed the reset on their phone. New password sign-in passed in the production browser.
- Business workspace rendered with Admin, Mail, and Artist Member navigation hidden; Clients view contained no Owner clients.
- Database assertions passed for Business permission, Artist/Owner denial, cross-account clients/projects/documents/memberships isolation, suspension, and reactivation (rolled back).
- Live suspension test returned the browser to sign-in. Membership was restored to active immediately afterward.
- Artist-mode sign-in with the same Business-only account returned to the login gate, while subsequent Business-mode sign-in succeeded after reactivation.
- Usability issue: denial/suspension explanation is overwritten by the asynchronous signed-out callback with 'Sign in to continue.' Enforcement works, but the reason should persist.
- New-account first-password invite flow remains distinct from existing-account magic-link acceptance; do not mark it verified from an existing-account invite.


### Denial-message regression fix

Preserve the denial reason across the asynchronous SIGNED_OUT callback. Clear it before a fresh password sign-in and explicit Sign Out. Invalid/expired invite messages use the same preservation. JavaScript syntax passed. A regression harness exercised the actual setSession function with a queued signed-out callback: original failed; fixed version passed for suspension, unpaid account, and Artist workspace denial, repeated signed-out updates, and clearing the reason for ordinary sign-out.


## Services and bookings — 2026-09-30

- Supabase rollback assertions passed for Barbados hourly availability, rejection of overlapping sessions, cancellation freeing slots, Artist request holds, Owner confirmation, forbidden Artist catalogue creation/confirmation, and Business RPC/RLS denial.
- Owner preview browser: default Management Dashboard, service and offering creation, 12 one-hour slots from 10am to 9pm Barbados, confirmed session recorded with matching UTC times and snapshotted price, and cancellation through queue verified against Supabase.
- Disposable fixture retained: service 060535e7-0fa7-46d7-8f41-7980997b682a (deactivated), booking 525dcc45-3e54-4ff9-be15-fb6b7836f631 (cancelled). No real appointment or payment.
- Browser test found iframe height feedback; now measures body content, rather than iframe viewport height. Found existing missing deletion queue returning null; JSON fallback regression checks passed for missing/null/malformed queues and preserved populated JSON.
- Scope excludes payment collection, outbound booking notices, external calendar sync, rescheduling, and legacy data migration. Member booking flow verified at database level; distinct Artist browser flow remains unverified.
