# Cal.com account verification

Deployed studio-cal-connection v1 with gateway JWT validation and caller-scoped Owner membership and MFA checks. Reads CAL_COM_API_KEY only from server secrets. GET /v2/me must match bookleprokahn and account ID 2390745. Responses never include the key or raw provider errors. No booking/payment/calendar mutations and synchronization stays disabled.

Setup: Supabase project xsvczfqvscnvmngwcmtp > Edge Functions > Secrets. Add CAL_COM_API_KEY with the Cal.com API key. Do not place the value in GitHub, chat or frontend code.

Owner-session invocation: supabase.functions.invoke('studio-cal-connection', {body:{}}). Successful verification checks profile access only, not event/booking permissions. UI check control not yet added.

Validation: JavaScript syntax check passed and deployment returned ACTIVE v1. Authorized live verification awaits secret setup. Runtime and denial checks remain pending.
