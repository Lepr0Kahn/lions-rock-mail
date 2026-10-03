
create table private.artist_recognition_settings(singleton boolean primary key default true check(singleton),starts_at timestamptz not null default now());
alter table private.artist_recognition_settings enable row level security;
revoke all on private.artist_recognition_settings from public,anon,authenticated;
insert into private.artist_recognition_settings(singleton) values(true) on conflict do nothing;
create or replace function private.artist_recognition(artist_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare target uuid:=coalesce(artist_id,auth.uid());start_at timestamptz;total integer;awards jsonb;badges jsonb;lv integer;title text;threshold integer;next_at integer;
begin
if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active Artist access required' using errcode='42501';end if;
if target<>auth.uid() and(not private.is_studio_owner() or not private.has_active_studio_access()) then raise exception 'Owner access required' using errcode='42501';end if;
if not exists(select 1 from public.app_memberships m where m.user_id=target and m.deleted_at is null and m.access_status='active' and m.payment_status in('paid','comped') and(m.role='owner' or m.artist_member_enabled) and(m.expires_at is null or m.expires_at>now())) then raise exception 'Active Artist required' using errcode='42501';end if;
select starts_at into start_at from private.artist_recognition_settings where singleton;
with ranked as(
select e.*,row_number() over(partition by e.event_key order by e.occurred_at,e.id) seq,
coalesce(f.project_id,e.source_id) unit_id
from public.artist_career_events e left join public.artist_project_files f on f.id=e.source_id and e.event_key in('master_delivered','master_collected')
where e.user_id=target and e.occurred_at>=start_at and e.occurred_at<=now() and not e.backfilled
), scored as(
select r.id,r.event_key,r.occurred_at,r.unit_id,
case r.event_key when 'membership_granted' then case when seq=1 then 50 else 0 end
when 'profile_complete' then case when seq=1 then 100 else 0 end
when 'project_created' then case when seq=1 then 150 else 50 end
when 'material_uploaded' then case when seq=1 then 100 else 0 end
when 'session_booked' then 75 when 'master_delivered' then 250 when 'master_collected' then 100 when 'invoice_settled' then 75 when 'release_published' then 500 else 0 end points
from ranked r join public.artist_career_events e on e.id=r.id
where private.career_event_eligible(e) and not exists(select 1 from public.artist_career_event_reversals rev where rev.event_id=r.id)
), unique_units as(
select distinct on(event_key,unit_id) * from scored where points>0 order by event_key,unit_id,occurred_at,id
)
select coalesce(sum(points),0)::int,coalesce(jsonb_agg(jsonb_build_object('event_id',id,'key',event_key,'points',points,'occurred_at',occurred_at) order by occurred_at desc,id),'[]') into total,awards from unique_units;
select v.level,v.name,v.floor into lv,title,threshold from(values
(1,'Initiate',0),(2,'First Step',100),(3,'Apprentice',250),(4,'Builder',450),(5,'Contender',700),
(6,'Craftsman',1000),(7,'Studio Regular',1350),(8,'Professional',1750),(9,'Momentum',2200),(10,'Rising',2700),
(11,'Headliner',3250),(12,'Standout',3850),(13,'Catalyst',4500),(14,'Cornerstone',5200),(15,'Prime',5950),
(16,'Elite',6750),(17,'Lion',7500),(18,'Vanguard',8500),(19,'Icon',9450),(20,'Legacy',10500)
)v(level,name,floor) where floor<=total order by floor desc limit 1;
select v.floor into next_at from(values(100),(250),(450),(700),(1000),(1350),(1750),(2200),(2700),(3250),(3850),(4500),(5200),(5950),(6750),(7500),(8500),(9450),(10500))v(floor) where floor>total order by floor limit 1;
select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'earned',(select count(*) from jsonb_array_elements(awards)a where a->>'key'=b.key)>=b.need,'requirement',b.need||' × '||replace(b.key,'_',' '))),'[]') into badges from(values
('identity_locked','Identity Locked','profile_complete',1),('first_blueprint','First Blueprint','project_created',1),('tape_rolling','Tape Rolling','material_uploaded',1),('first_master','First Master','master_delivered',1),('five_masters','Five Masters','master_delivered',5),('delivered','Delivered','master_collected',1),('first_release','First Release','release_published',1),('catalogue_builder','Catalogue Builder','release_published',5),('straight_business','Straight Business','invoice_settled',3))b(id,name,key,need);
return jsonb_build_object('artist_id',target,'xp',total,'level',lv,'title',title,'tier',case when lv<=4 then 'Foundation' when lv<=8 then 'Momentum' when lv<=12 then 'Spotlight' when lv<=16 then 'Prestige' else 'Legacy' end,'level_floor',threshold,'next_at',next_at,'xp_to_next',case when next_at is null then 0 else next_at-total end,'badges',badges,'awards',awards,'starts_at',start_at,'benefits_enabled',false,'computed_at',now());
end;$$;
revoke all on function private.artist_recognition(uuid) from public,anon,authenticated;
grant execute on function private.artist_recognition(uuid) to authenticated;
create or replace function public.artist_recognition(artist_id uuid default null) returns jsonb language sql security invoker set search_path='' as $$select private.artist_recognition(artist_id);$$;
revoke all on function public.artist_recognition(uuid) from public,anon;
grant execute on function public.artist_recognition(uuid) to authenticated;
