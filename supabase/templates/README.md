# Lions Rock Auth Email Templates

These templates are for Supabase Auth.

## Subjects
- Invite: **You’re invited to Lions Rock Studio**
- Magic Link: **Your secure Lions Rock sign-in link**
- Password Recovery: **Change your Lions Rock password**

## Dashboard mapping
Authentication → Email Templates:
- Invite User → `invite.html`
- Magic Link → `magic_link.html`
- Reset Password → `recovery.html`

All templates use Supabase's `{{ .ConfirmationURL }}` variable.

## Sender branding
Template HTML controls the content, but the sender identity is controlled under:
Authentication → Emails → SMTP Settings.

For production, use a Lions Rock sender name/address through custom SMTP so recipients see a trusted Lions Rock identity instead of Supabase's default email infrastructure.

Recommended sender display:
**Lions Rock Studio**

Recommended sender address:
**access@your-lions-rock-domain**
(or another verified Lions Rock domain address)

Disable link tracking at the SMTP provider for auth emails so one-time Supabase links are not rewritten.
