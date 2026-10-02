# Owner MFA activation control

Guarded activation RPC deployed; it requires active, unexpired, undeleted paid/comped Owner membership and an aal2 session. Enabling requires two verified TOTP factors. Disabling also requires aal2. Client access to the private settings table remains revoked; no anonymous execution.

Rollback checks passed for password-only denial, non-Owner denial, verified disable and the backup prerequisite. No settings or enrollments changed. Successful real activation and fresh-login recovery still require live primary/backup testing; activation UI is not exposed yet.

Function audit: register_artist_file calls artist_upload_allowed, which uses the MFA-protected Artist/Owner helpers. is_minor_artist is a classification lookup. guardian_invoice_portal retains its private-link capability flow independently of management MFA.

Next: verify primary and backup authenticator enrollment and fresh session challenge, then expose the explicit activation control and finish live acceptance checks. Do not claim MFA rollout complete.
