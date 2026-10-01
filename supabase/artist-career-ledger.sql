create table public.artist_career_events(
id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
event_key text not null check(event_key in ('membership_granted','profile_complete','project_created','material_uploaded','session_booked','master_delivered','master_collected','invoice_settled','release_published')),
source_id uuid not null,occurred_at timestamptz not null default now(),backfilled boolean not null default false,
unique(user_id,event_key,source_id));
create index artist_career_events_user_time on public.artist_career_events(user_id,occurred_at desc);
create table public.artist_career_event_reversals(event_id uuid primary key references public.artist_career_events(id),reversed_by uuid not null references auth.users(id),reason text not null check(length(btrim(reason)) between 1 and 2000),reversed_at timestamptz not null default now());
alter table public.artist_career_events enable row level security;
alter table public.artist_career_event_reversals enable row level security;
revoke all on public.artist_career_events,public.artist_career_event_reversals from anon,authenticated;
grant select on public.artist_career_events,public.artist_career_event_reversals to authenticated;
create policy career_events_read on public.artist_career_events for select to authenticated using(private.has_active_artist_access() and(user_id=auth.uid() or(private.is_studio_owner() and private.has_active_studio_access())));
create policy career_reversals_read on public.artist_career_event_reversals for select to authenticated using(exists(select 1 from public.artist_career_events e where e.id=event_id));
create function private.record_career_event(artist uuid,event_name text,source uuid) returns void language sql security definer set search_path='' as $$
insert into public.artist_career_events(user_id,event_key,source_id) values(artist,event_name,source) on conflict(user_id,event_key,source_id) do nothing;$$;
revoke all on function private.record_career_event(uuid,text,uuid) from public,anon,authenticated;
create function private.capture_career_event() returns trigger language plpgsql security definer set search_path='' as $$
begin
if tg_table_name='app_memberships' then
 if new.deleted_at is null and new.access_status='active' and new.payment_status in ('paid','comped') and(new.role='owner' or new.artist_member_enabled) and(new.expires_at is null or new.expires_at>now()) then perform private.record_career_event(new.user_id,'membership_granted',new.user_id);end if;
elsif tg_table_name='artist_career_profiles' then
 if btrim(new.artist_name)<>'' and btrim(new.genres)<>'' and btrim(new.goal_12_months)<>'' then perform private.record_career_event(new.user_id,'profile_complete',new.user_id);end if;
elsif tg_table_name='artist_projects' then
 if tg_op='INSERT' then perform private.record_career_event(new.user_id,'project_created',new.id);end if;
 if new.status='released' then perform private.record_career_event(new.user_id,'release_published',new.id);end if;
elsif tg_table_name='artist_project_files' then
 perform private.record_career_event(new.user_id,case when new.kind in ('master','mp3_delivery') then 'master_delivered' else 'material_uploaded' end,new.id);
elsif tg_table_name='studio_bookings' then
 if new.status='confirmed' then perform private.record_career_event(new.user_id,'session_booked',new.id);end if;
elsif tg_table_name='artist_delivery_collections' then
 perform private.record_career_event(new.user_id,'master_collected',new.file_id);
elsif tg_table_name='documents' then
 if new.doc_type='invoice' and new.status<>'void' and new.total>0 and new.amount_paid>=new.total and new.booking_id is not null and exists(select 1 from public.app_memberships m where m.user_id=new.user_id and m.role='owner') then
 perform private.record_career_event((select user_id from public.studio_bookings where id=new.booking_id),'invoice_settled',new.id);
 end if;
end if;
return new;
end;$$;
revoke all on function private.capture_career_event() from public,anon,authenticated;
create trigger career_membership_event after insert or update on public.app_memberships for each row execute function private.capture_career_event();
create trigger career_profile_event after insert or update on public.artist_career_profiles for each row execute function private.capture_career_event();
create trigger career_project_event after insert or update on public.artist_projects for each row execute function private.capture_career_event();
create trigger career_file_event after insert on public.artist_project_files for each row execute function private.capture_career_event();
create trigger career_booking_event after insert or update on public.studio_bookings for each row execute function private.capture_career_event();
create trigger career_collection_event after insert on public.artist_delivery_collections for each row execute function private.capture_career_event();
create trigger career_invoice_event after insert or update on public.documents for each row execute function private.capture_career_event();
create function public.reverse_artist_career_event(event_id uuid,reversal_reason text) returns boolean language plpgsql security definer set search_path='' as $$
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_artist_access() or not private.has_active_studio_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
if not exists(select 1 from public.artist_career_events e where e.id=event_id) then raise exception 'Milestone not found';end if;
insert into public.artist_career_event_reversals(event_id,reversed_by,reason) values(event_id,auth.uid(),btrim(reversal_reason)) on conflict(event_id) do nothing;
return found;
end;$$;
revoke all on function public.reverse_artist_career_event(uuid,text) from public,anon;
grant execute on function public.reverse_artist_career_event(uuid,text) to authenticated;
create function private.career_event_eligible(e public.artist_career_events) returns boolean language sql stable security definer set search_path='' as $$
select case
when e.event_key='membership_granted' then true
when e.event_key='profile_complete' then exists(select 1 from public.artist_career_profiles p where p.user_id=e.user_id and btrim(p.artist_name)<>'' and btrim(p.genres)<>'' and btrim(p.goal_12_months)<>'')
when e.event_key in ('project_created','release_published') then exists(select 1 from public.artist_projects p where p.id=e.source_id and p.user_id=e.user_id and p.status<>'archived' and(e.event_key<>'release_published' or p.status='released'))
when e.event_key in ('material_uploaded','master_delivered','master_collected') then exists(select 1 from public.artist_project_files f join public.artist_projects p on p.id=f.project_id where f.id=e.source_id and f.user_id=e.user_id and p.user_id=e.user_id and p.status<>'archived')
when e.event_key='session_booked' then exists(select 1 from public.studio_bookings b where b.id=e.source_id and b.user_id=e.user_id and b.status='confirmed')
when e.event_key='invoice_settled' then exists(select 1 from public.documents d join public.studio_bookings b on b.id=d.booking_id where d.id=e.source_id and b.user_id=e.user_id and d.doc_type='invoice' and d.status<>'void' and d.total>0 and d.amount_paid>=d.total)
else false end;$$;
revoke all on function private.career_event_eligible(public.artist_career_events) from public,anon,authenticated;
create function public.artist_career_history(artist_id uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare target uuid:=coalesce(artist_id,auth.uid());result jsonb;
begin
if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active Artist required' using errcode='42501';end if;
if target<>auth.uid() and(not private.is_studio_owner() or not private.has_active_studio_access()) then raise exception 'Owner required' using errcode='42501';end if;
if not exists(select 1 from public.app_memberships m where m.user_id=target and m.deleted_at is null and m.access_status='active' and m.payment_status in ('paid','comped') and(m.role='owner' or m.artist_member_enabled) and(m.expires_at is null or m.expires_at>now())) then raise exception 'Active artist required' using errcode='42501';end if;
select coalesce(jsonb_agg(x.item order by x.occurred_at desc,x.id),'[]') into result from
(select e.id,e.occurred_at,jsonb_build_object('id',e.id,'key',e.event_key,'occurred_at',e.occurred_at,'backfilled',e.backfilled,'counts_now',r.event_id is null and private.career_event_eligible(e),'reversed_at',r.reversed_at,'reason',r.reason) item from public.artist_career_events e left join public.artist_career_event_reversals r on r.event_id=e.id where e.user_id=target order by e.occurred_at desc,e.id limit 100)x;
return jsonb_build_object('artist_id',target,'events',result,'limit',100,'computed_at',now());
end;$$;
revoke all on function public.artist_career_history(uuid) from public,anon;
grant execute on function public.artist_career_history(uuid) to authenticated;
-- Backfill only signals with a genuine timestamp; no invented release/profile/confirmation time.
insert into public.artist_career_events(user_id,event_key,source_id,occurred_at,backfilled)
select p.user_id,'project_created',p.id,p.created_at,true from public.artist_projects p
union all select f.user_id,case when f.kind in ('master','mp3_delivery') then 'master_delivered' else 'material_uploaded' end,f.id,f.created_at,true from public.artist_project_files f
union all select c.user_id,'master_collected',c.file_id,c.collected_at,true from public.artist_delivery_collections c
on conflict(user_id,event_key,source_id) do nothing;

create or replace function public.artist_career_tracks(artist_id uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare target uuid:=coalesce(artist_id,auth.uid());sig jsonb;rules jsonb:='{"creative":[["projects",8,24],["uploads",4,28],["masters",12,36],["profile",12,12]],"momentum":[["active_days_30",3,30],["milestones_30",8,40],["sessions_completed",10,30]],"audience":[["releases",20,60],["masters_collected",8,24],["profile",16,16]],"network":[["sessions_completed",9,45],["bookings",5,25],["quotes",6,30]],"business":[["invoices_settled",14,42],["deposits_paid",8,24],["budget_defined",14,14],["profile",20,20]]}'::jsonb;track record;rule jsonb;parts jsonb;result jsonb:='{}';units integer;points integer;total integer;coverage integer;available boolean;
begin
if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active Artist access required' using errcode='42501';end if;
if target<>auth.uid() and (not private.is_studio_owner() or not private.has_active_studio_access()) then raise exception 'Owner access required' using errcode='42501';end if;
if not exists(select 1 from public.app_memberships m where m.user_id=target and m.deleted_at is null and m.access_status='active' and m.payment_status in ('paid','comped') and (m.role='owner' or m.artist_member_enabled) and (m.expires_at is null or m.expires_at>now())) then raise exception 'Active artist required' using errcode='42501';end if;
select jsonb_build_object(
'milestones_30',(select count(*) from public.artist_career_events e where e.user_id=target and not e.backfilled and e.occurred_at>=now()-interval '30 days' and not exists(select 1 from public.artist_career_event_reversals r where r.event_id=e.id) and private.career_event_eligible(e)),
'active_days_30',(select count(distinct (e.occurred_at at time zone 'America/Barbados')::date) from public.artist_career_events e where e.user_id=target and not e.backfilled and e.occurred_at>=now()-interval '30 days' and not exists(select 1 from public.artist_career_event_reversals r where r.event_id=e.id) and private.career_event_eligible(e)),
'projects',(select count(*) from public.artist_projects p where p.user_id=target and p.status<>'archived'),
'releases',(select count(*) from public.artist_projects p where p.user_id=target and p.status='released'),
'uploads',(select count(*) from public.artist_project_files f join public.artist_projects p on p.id=f.project_id where p.user_id=target and f.user_id=target and p.status<>'archived'),
'masters',(select count(*) from public.artist_project_files f join public.artist_projects p on p.id=f.project_id where p.user_id=target and f.user_id=target and p.status<>'archived' and f.kind in ('master','mp3_delivery')),
'masters_collected',(select count(distinct c.file_id) from public.artist_delivery_collections c join public.artist_project_files f on f.id=c.file_id join public.artist_projects p on p.id=f.project_id where c.user_id=target and f.user_id=target and p.user_id=target and p.status<>'archived' and f.kind in ('master','mp3_delivery')),
'bookings',(select count(*) from public.studio_bookings b where b.user_id=target and b.status='confirmed'),
'sessions_completed',(select count(*) from public.studio_bookings b where b.user_id=target and b.status='confirmed' and b.ends_at<now()),
'profile',case when exists(select 1 from public.artist_career_profiles p where p.user_id=target and btrim(p.artist_name)<>'' and btrim(p.genres)<>'' and btrim(p.goal_12_months)<>'') then 1 else 0 end,
'invoices_settled',(select count(*) from public.documents d join public.studio_bookings b on b.id=d.booking_id join public.app_memberships o on o.user_id=d.user_id and o.role='owner' where b.user_id=target and d.doc_type='invoice' and d.status<>'void' and d.total>0 and d.amount_paid>=d.total),
'deposits_paid',(select count(*) from public.documents d join public.studio_bookings b on b.id=d.booking_id join public.app_memberships o on o.user_id=d.user_id and o.role='owner' where b.user_id=target and d.doc_type='invoice' and d.status<>'void' and d.total>0 and d.amount_paid>0)) into sig;
for track in select * from jsonb_each(rules) loop
parts:='[]';total:=0;coverage:=0;
for rule in select value from jsonb_array_elements(track.value) loop
available:=sig ? (rule->>0);units:=coalesce((sig->>(rule->>0))::integer,0);points:=least(units*(rule->>1)::integer,(rule->>2)::integer);total:=total+points;
if available then coverage:=coverage+(rule->>2)::integer;end if;
parts:=parts||jsonb_build_array(jsonb_build_object('signal',rule->>0,'units',case when available then units else null end,'points',points,'max',rule->>2,'available',available));
end loop;
result:=result||jsonb_build_object(track.key,jsonb_build_object('score',least(100,total),'max_score',100,'available_max',coverage,'partial',coverage<100,'breakdown',parts));
end loop;
return jsonb_build_object('artist_id',target,'tracks',result,'signals',sig,'computed_at',now(),'computed_by','sage_track_rules_adapted_v1','notes',jsonb_build_array('Past confirmed sessions reflect elapsed scheduled time, not verified attendance.','Released projects are artist-reported.','Collection records download initiation, not proof of listening.','Financial signals use recorded amounts on Owner invoices linked to this artist booking; no payment processor verification.','Activity days come from eligible recorded career milestones, never logins or refreshes. Imported history is excluded from recent activity. Artist-linked quotes and explicit budgets are not integrated.'));
end;$$;
revoke all on function public.artist_career_tracks(uuid) from public,anon;
grant execute on function public.artist_career_tracks(uuid) to authenticated;
create or replace function public.reverse_artist_career_event(event_id uuid,reversal_reason text) returns boolean language plpgsql security definer set search_path='' as $$
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_artist_access() or not private.has_active_studio_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
if not exists(select 1 from public.artist_career_events e where e.id=reverse_artist_career_event.event_id) then raise exception 'Milestone not found';end if;
insert into public.artist_career_event_reversals(event_id,reversed_by,reason) values(reverse_artist_career_event.event_id,auth.uid(),btrim(reversal_reason)) on conflict on constraint artist_career_event_reversals_pkey do nothing;
return found;
end;$$;
create or replace function private.capture_career_event() returns trigger language plpgsql security definer set search_path='' as $$
declare was_eligible boolean:=false;
begin
if tg_table_name='app_memberships' then
 if tg_op='UPDATE' then was_eligible:=old.deleted_at is null and old.access_status='active' and old.payment_status in ('paid','comped') and(old.role='owner' or old.artist_member_enabled) and(old.expires_at is null or old.expires_at>now());end if;
 if not was_eligible and new.deleted_at is null and new.access_status='active' and new.payment_status in ('paid','comped') and(new.role='owner' or new.artist_member_enabled) and(new.expires_at is null or new.expires_at>now()) then perform private.record_career_event(new.user_id,'membership_granted',new.user_id);end if;
elsif tg_table_name='artist_career_profiles' then
 if tg_op='UPDATE' then was_eligible:=btrim(old.artist_name)<>'' and btrim(old.genres)<>'' and btrim(old.goal_12_months)<>'';end if;
 if not was_eligible and btrim(new.artist_name)<>'' and btrim(new.genres)<>'' and btrim(new.goal_12_months)<>'' then perform private.record_career_event(new.user_id,'profile_complete',new.user_id);end if;
elsif tg_table_name='artist_projects' then
 if tg_op='INSERT' then perform private.record_career_event(new.user_id,'project_created',new.id);else was_eligible:=old.status='released';end if;
 if not was_eligible and new.status='released' then perform private.record_career_event(new.user_id,'release_published',new.id);end if;
elsif tg_table_name='artist_project_files' then
 perform private.record_career_event(new.user_id,case when new.kind in ('master','mp3_delivery') then 'master_delivered' else 'material_uploaded' end,new.id);
elsif tg_table_name='studio_bookings' then
 if tg_op='UPDATE' then was_eligible:=old.status='confirmed';end if;
 if not was_eligible and new.status='confirmed' then perform private.record_career_event(new.user_id,'session_booked',new.id);end if;
elsif tg_table_name='artist_delivery_collections' then
 perform private.record_career_event(new.user_id,'master_collected',new.file_id);
elsif tg_table_name='documents' then
 if tg_op='UPDATE' then was_eligible:=old.doc_type='invoice' and old.status<>'void' and old.total>0 and old.amount_paid>=old.total and old.booking_id is not null;end if;
 if not was_eligible and new.doc_type='invoice' and new.status<>'void' and new.total>0 and new.amount_paid>=new.total and new.booking_id is not null and exists(select 1 from public.app_memberships m where m.user_id=new.user_id and m.role='owner') then
 perform private.record_career_event((select user_id from public.studio_bookings where id=new.booking_id),'invoice_settled',new.id);
 end if;
end if;
return new;
end;$$;