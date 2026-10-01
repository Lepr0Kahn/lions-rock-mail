# Owner MFA enforcement and recovery review

Status: enrollment, backup setup, a conditional sign-in challenge, private inactive enforcement settings, shared access-helper checks and restrictive public-table/storage gates are implemented. No Owner is enabled. Activation UI and service-role endpoint protection remain pending; this is not completed management-wide enforcement.

## Findings from the live authorization review
- private.is_studio_owner currently checks active Owner membership, without the JWT aal claim.
- private.has_active_studio_access and private.has_active_artist_access protect major workspace policies but currently accept aal1 Owner sessions.
- Membership self-select must remain available before MFA so the sign-in challenge can identify the account without unlocking management data.
- studio-create-invite version 4 verifies the caller through Auth getUser, then checks Owner membership with a service-role client. It bypasses RLS and needs its own MFA authorization gate before any link generation or membership/invite mutation.
- Storage cleanup has an own-object delete policy without the shared access guard. Management enforcement must cover this path as well.

## Required implementation before activation
1. Add a private, deny-by-default activation setting for each Owner. Only an active Owner at aal2 may activate or disable their own setting; require two verified TOTP factors before activation.
2. Centralize the enabled-Owner aal2 check in a guarded private helper; apply it to Owner, Artist and Business access helpers, restrictive table/storage policies and all privileged RPC paths. Preserve minimal own membership reads for challenge routing.
3. Add a pre-workspace challenge screen supporting either verified authenticator. Fail closed on assurance-level lookup errors; clear previous workspace frames while awaiting verification.
4. Add caller-token-scoped authorization to every service-role management endpoint. Never trust a decoded, unverified JWT or service-role membership lookup as proof of MFA.
5. Test aal1 denial and aal2 allowance across documents, bookings, services, memberships, payments, files and invite endpoints; verify non-Owner access remains unchanged. Include removed, suspended and expired Owners.
6. Exercise actual enrollment, backup verification, fresh sign-in and lost-primary-device recovery before exposing activation.

## Recovery
- Add and verify a backup authenticator on a separate device while the primary remains available.
- Password reset/email magic links do not bypass MFA.
- Do not allow removing the final verified factor through the app after activation.
- Losing every factor requires independent identity verification and intervention by the Supabase project administrator. No automated email-only recovery exists in this build.
- Keep QR/setup secrets and codes out of chat, logs and test fixtures.

No existing Owner has had enforcement enabled by this change. Backup enrollment and verification require the Owner to use their own authenticator; automated tests only cover mocked Auth flows.


## Foundation verification
Rollback database test passed: temporary required Owner at aal1 denied shared Owner/Business/Artist access and documents; own membership remains readable for challenge routing; aal2 permitted; inactive setting retains access. No settings persisted. UI mock tests cover inactive gate, primary/backup challenges, invalid code, resume, lookup error and stale checks. Private settings table has no client grants/policies by design. Existing security advisor warnings remain; the additional private RLS/no-policy notice is intentional deny-by-default protection. Live sign-in, all-table mutations and service-role invite protection remain pending.
