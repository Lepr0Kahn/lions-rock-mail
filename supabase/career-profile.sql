create table public.artist_career_profiles(
 user_id uuid primary key references auth.users(id) on delete cascade,
 artist_name text not null default '' check(length(artist_name)<=200),
 genres text not null default '' check(length(genres)<=500),
 goal_12_months text not null default '' check(length(goal_12_months)<=3000)
);
alter table public.artist_career_profiles enable row level security;
grant select,insert,update on public.artist_career_profiles to authenticated;
create policy career_profile_read on public.artist_career_profiles for select to authenticated using(private.has_active_artist_access() and (user_id=(select auth.uid()) or (private.is_studio_owner() and private.has_active_studio_access())));
create policy career_profile_insert on public.artist_career_profiles for insert to authenticated with check(private.has_active_artist_access() and user_id=(select auth.uid()));
create policy career_profile_update on public.artist_career_profiles for update to authenticated using(private.has_active_artist_access() and user_id=(select auth.uid())) with check(private.has_active_artist_access() and user_id=(select auth.uid()));