-- Source lifecycle gates from LIONS-ROCK-OS-FOR-SAGE/backend/progression.py.
create table public.artist_delivery_collections(
 file_id uuid not null references public.artist_project_files(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 collected_at timestamptz not null default now(),
 primary key(file_id,user_id)
);
alter table public.artist_delivery_collections enable row level security;
grant select on public.artist_delivery_collections to authenticated;
grant insert(file_id,user_id) on public.artist_delivery_collections to authenticated;
create policy delivery_collection_read on public.artist_delivery_collections for select to authenticated using(private.has_active_artist_access() and (user_id=(select auth.uid()) or (private.is_studio_owner() and private.has_active_studio_access())));
create policy delivery_collection_insert on public.artist_delivery_collections for insert to authenticated with check(
 private.has_active_artist_access() and user_id=(select auth.uid()) and exists(
 select 1 from public.artist_project_files f join public.artist_projects p on p.id=f.project_id
 where f.id=file_id and f.user_id=(select auth.uid()) and p.user_id=(select auth.uid()) and p.status<>'archived' and f.kind in ('master','mp3_delivery') and f.expires_at>now()));
create table private.artist_career_stage_state(
 user_id uuid primary key references auth.users(id) on delete cascade,
 stage_index smallint not null check(stage_index between 1 and 8),
 computed_at timestamptz not null default now()
);
alter table private.artist_career_stage_state enable row level security;
revoke all on private.artist_career_stage_state from public,anon,authenticated;
create or replace function public.record_artist_delivery_collection(delivery_id uuid)
returns boolean language plpgsql security invoker set search_path='' as $$
begin
if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active Artist access required' using errcode='42501';end if;
if not exists(select 1 from public.artist_project_files f join public.artist_projects p on p.id=f.project_id where f.id=delivery_id and f.user_id=auth.uid() and p.user_id=auth.uid() and p.status<>'archived' and f.kind in ('master','mp3_delivery') and f.expires_at>now()) then raise exception 'Available own studio delivery required' using errcode='42501';end if;
insert into public.artist_delivery_collections(file_id,user_id) values(delivery_id,auth.uid()) on conflict(file_id,user_id) do nothing;
return true;
end;$$;
revoke all on function public.record_artist_delivery_collection(uuid) from public,anon;
grant execute on function public.record_artist_delivery_collection(uuid) to authenticated;
create or replace function public.artist_career_progress(artist_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target uuid:=coalesce(artist_id,auth.uid()); m public.app_memberships%rowtype; profile_ok boolean; projects bigint; uploads bigint; bookings bigint; masters bigint; collected bigint; releases bigint;
 gates boolean[]; names text[]:=array['join','discover','plan','create','produce','prepare','release','grow'];
 actions text[]:=array['Complete artist identity, genres and your 12-month goal.','Start a music project.','Upload material to a project.','Confirm a studio session.','Have the studio deliver a master or MP3.','Collect your studio delivery.','Mark a project Released when published.','Plan the next release cycle.'];
 reached integer:=1; stored integer:=1; current_stage integer; i integer; gate_rows jsonb:='[]';
begin
if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active Artist access required' using errcode='42501';end if;
if target<>auth.uid() and not (private.is_studio_owner() and private.has_active_studio_access()) then raise exception 'Own artist progress only' using errcode='42501';end if;
select * into m from public.app_memberships where user_id=target;
if m.id is null or m.access_status<>'active' or m.payment_status not in ('paid','comped') or (m.expires_at is not null and m.expires_at<=now()) or (m.role<>'owner' and not m.artist_member_enabled) then raise exception 'Active Artist membership required' using errcode='42501';end if;
perform pg_advisory_xact_lock(hashtextextended('artist-career-stage-'||target::text,0));
select exists(select 1 from public.artist_career_profiles where user_id=target and length(btrim(artist_name))>0 and length(btrim(genres))>0 and length(btrim(goal_12_months))>0) into profile_ok;
select count(*),count(*) filter(where status='released') into projects,releases from public.artist_projects where user_id=target and status<>'archived';
select count(*),count(*) filter(where f.kind in ('master','mp3_delivery')) into uploads,masters from public.artist_project_files f join public.artist_projects p on p.id=f.project_id where f.user_id=target and p.user_id=target and p.status<>'archived';
select count(*) into bookings from public.studio_bookings where user_id=target and status='confirmed';
select count(*) into collected from public.artist_delivery_collections c join public.artist_project_files f on f.id=c.file_id join public.artist_projects p on p.id=f.project_id where c.user_id=target and f.user_id=target and p.user_id=target and p.status<>'archived' and f.kind in ('master','mp3_delivery');
gates:=array[true,profile_ok,projects>0,uploads>0,bookings>0,masters>0,collected>0,releases>0];
for i in 2..8 loop if gates[i] then reached:=i;else exit;end if;end loop;
select stage_index into stored from private.artist_career_stage_state where user_id=target;
current_stage:=greatest(coalesce(stored,1),reached);
insert into private.artist_career_stage_state(user_id,stage_index,computed_at) values(target,current_stage,now()) on conflict(user_id) do update set stage_index=greatest(private.artist_career_stage_state.stage_index,excluded.stage_index),computed_at=excluded.computed_at;
for i in 1..8 loop gate_rows:=gate_rows||jsonb_build_array(jsonb_build_object('stage',names[i],'evidence_met',gates[i],'reached_now',i<=reached));end loop;
return jsonb_build_object('artist_id',target,'stage',names[current_stage],'stage_index',current_stage,'stage_count',8,'evidenced_stage',names[reached],'held',current_stage>reached,'next_action',actions[reached],'gates',gate_rows,'computed_at',now(),'computed_by','deterministic_stage_rules_v1','signals',jsonb_build_object('profile',profile_ok,'projects',projects,'uploads',uploads,'confirmed_bookings',bookings,'masters',masters,'masters_collected',collected,'releases',releases));
end;$$;
revoke all on function public.artist_career_progress(uuid) from public,anon;
grant execute on function public.artist_career_progress(uuid) to authenticated;