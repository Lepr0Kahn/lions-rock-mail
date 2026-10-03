-- Business email branding
-- Business logo continues to use public.business_settings.logo_data.
-- Optional email footer is stored separately for Business Tools mail.
alter table public.business_settings
add column if not exists email_footer text;
