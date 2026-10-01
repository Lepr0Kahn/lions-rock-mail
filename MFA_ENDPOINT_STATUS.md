# MFA endpoint status

studio-create-invite v5 deployed: caller-scoped owner_mfa_status RPC checks the verified caller token before link generation and service-role mutations. Lookup errors and denied status return 403. Existing Auth getUser and active Owner checks remain. Function deployment succeeded; live authenticated request testing remains pending.

studio-activate-member v2 still needs review and caller MFA gate. studio-claim-invite and public studio-apply require separate review of their intended non-management flows. No Owner MFA requirement has been enabled. Activation UI remains unavailable until coverage and end-to-end testing are complete.
