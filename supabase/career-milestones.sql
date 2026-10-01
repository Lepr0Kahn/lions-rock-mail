-- Evidence-backed career milestones adapted from LIONS-ROCK-OS-FOR-SAGE/backend/progression.py.
-- This is a live checklist, not the source OS's persisted eight-stage progression or five track scores.
create or replace function public.artist_career_milestones(artist_id uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare target uuid:=coalesce(artist_id,auth.uid()); m public.app_memberships%rowtype; p bigint; u bigint; b bigint; c bigint; d bigint; r bigint;
begin
if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active Artist access required' using errcode='42501';end if;
if target<>auth.uid() and not (private.is_studio_owner() and private.has_active_studio_access()) then raise exception 'Own artist progress only' using errcode='42501';end if;
select * into m from public.app_memberships where user_id=target;
if m.id is null or m.access_status<>'active' or m.payment_status not in ('paid','comped') or (m.expires_at is not null and m.expires_at<=now()) or (m.role<>'owner' and not m.artist_member_enabled) then raise exception 'Active Artist membership required' using errcode='42501';end if;
select count(*),count(*) filter(where status='released') into p,r from public.artist_projects where user_id=target and status<>'archived';
select count(*) filter(where f.kind in ('reference','stem','demo')),count(*) filter(where f.kind in ('master','mp3_delivery')) into u,d from public.artist_project_files f join public.artist_projects a on a.id=f.project_id where a.user_id=target and f.user_id=target and a.status<>'archived';
select count(*),count(*) filter(where ends_at<now()) into b,c from public.studio_bookings where user_id=target and status='confirmed';
return jsonb_build_object('artist_id',target,'computed_at',now(),'computed_by','recorded_milestones_v1','milestones',jsonb_build_array(
jsonb_build_object('key','project','label','Project started','count',p,'complete',p>0,'evidence','Non-archived music projects'),
jsonb_build_object('key','material','label','Material uploaded','count',u,'complete',u>0,'evidence','Reference, stem or demo files'),
jsonb_build_object('key','booking','label','Session confirmed','count',b,'complete',b>0,'evidence','Confirmed bookings; cancelled requests do not count'),
jsonb_build_object('key','session','label','Studio session elapsed','count',c,'complete',c>0,'evidence','Confirmed sessions whose scheduled end has passed; attendance is not verified'),
jsonb_build_object('key','master','label','Studio delivery recorded','count',d,'complete',d>0,'evidence','Recorded master or MP3 deliveries, including expired deliveries'),
jsonb_build_object('key','release','label','Release marked','count',r,'complete',r>0,'evidence','Projects marked Released; publication is self-reported')));
end;$$;
revoke all on function public.artist_career_milestones(uuid) from public,anon;
grant execute on function public.artist_career_milestones(uuid) to authenticated;