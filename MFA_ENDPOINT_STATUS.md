# MFA endpoint status

Reviewed live source: studio-activate-member v2 and studio-apply v2 are closed, return HTTP 410 and perform no activation or application writes. OPTIONS remains available.

studio-create-invite v5 and studio-claim-invite v3 now use caller-token-scoped owner_mfa_status RPC before service-role mutations. Failed checks and disallowed sessions return 403. Existing Auth getUser verification remains. Both deployed successfully. Normal members with no required setting remain allowed by this gate and retain the original invitation checks.

node tests/mfa-endpoints.cjs passes source-extracted guard tests for denied, lookup-error and permitted statuses and verifies token-scoped authorization. This is a mock guard test, not a live invite creation/claim test. No real invites were sent or claimed during testing.

No Owner MFA requirement has been enabled. Live primary/backup enrollment, fresh login, invitation flows, remaining privileged RPC coverage and activation/recovery controls remain pending. Do not enable the private setting manually before those checks pass.
