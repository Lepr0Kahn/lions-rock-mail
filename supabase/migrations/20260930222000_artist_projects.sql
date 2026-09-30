create table public.artist_projects (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 title text not null check (length(btrim(title)) between 1 and 200),
 kind text not null default 'single' check (kind in ('single','ep','album','mixtape','sync')),
 brief text not null default '' check (length(brief)<=10000),
 target_date date,
 status text not null default 'active' check (status in ('active','released','archived')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index artist_projects_user_created_idx on public.artist_projects(user_id,created_at desc);
alter table public.artist_projects enable row level security;
revoke all on public.artist_projects from anon,authenticated;
grant select,insert on public.artist_projects to authenticated;
grant update(title,kind,brief,target_date,status) on public.artist_projects to authenticated;
create policy artist_projects_read on public.artist_projects for select to authenticated
 using ((select private.has_active_artist_access()) and (user_id=(select auth.uid()) or (select private.is_studio_owner())));
create policy artist_projects_create on public.artist_projects for insert to authenticated
 with check ((select private.has_active_artist_access()) and user_id=(select auth.uid()));
create policy artist_projects_edit on public.artist_projects for update to authenticated
 using ((select private.has_active_artist_access()) and (user_id=(select auth.uid()) or (select private.is_studio_owner())))
 with check ((select private.has_active_artist_access()) and (user_id=(select auth.uid()) or (select private.is_studio_owner())));
create function private.artist_project_timestamp() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=now(); return new; end; $$;
create trigger artist_project_timestamp before update on public.artist_projects for each row execute function private.artist_project_timestamp();