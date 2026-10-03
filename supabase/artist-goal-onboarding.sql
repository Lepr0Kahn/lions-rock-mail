alter table public.artist_career_profiles
 add column if not exists username text not null default '' check(username='' or username ~ '^[a-z0-9][a-z0-9_]{2,29}$'),
 add column if not exists goal_key text not null default '' check(goal_key in ('','songwriting','record_single','release_single','release_ep','audience','collaboration','business','custom'));
create unique index if not exists artist_career_username_unique on public.artist_career_profiles(username) where username<>'';

-- Membership allows only profile setup until the required Artist identity/goal is saved.
-- Keep business access, Owner MFA, suspension and existing membership checks intact.
create or replace function private.has_artist_setup_access()
returns boolean language sql stable security definer set search_path='' as $$
 select private.owner_mfa_allowed() and exists(
  select 1 from public.app_memberships m where m.user_id=(select auth.uid())
  and m.deleted_at is null and m.access_status='active' and m.payment_status in ('paid','comped')
  and (m.role='owner' or m.artist_member_enabled=true) and (m.expires_at is null or m.expires_at>now())
 );
$$;
revoke all on function private.has_artist_setup_access() from public,anon;
grant execute on function private.has_artist_setup_access() to authenticated;
create or replace function private.has_active_artist_access()
returns boolean language sql stable security definer set search_path='' as $$
 select private.has_artist_setup_access() and (
  exists(select 1 from public.app_memberships m where m.user_id=(select auth.uid()) and m.role='owner')
  or exists(select 1 from public.artist_career_profiles p where p.user_id=(select auth.uid())
   and p.username<>'' and btrim(p.artist_name)<>'' and btrim(p.genres)<>''
   and p.goal_key<>'' and btrim(p.goal_12_months)<>'')
 );
$$;
alter policy career_profile_read on public.artist_career_profiles
 using(private.has_artist_setup_access() and (user_id=(select auth.uid()) or (private.is_studio_owner() and private.has_active_studio_access())));
alter policy career_profile_insert on public.artist_career_profiles
 with check(private.has_artist_setup_access() and user_id=(select auth.uid()));
alter policy career_profile_update on public.artist_career_profiles
 using(private.has_artist_setup_access() and user_id=(select auth.uid()))
 with check(private.has_artist_setup_access() and user_id=(select auth.uid()));
