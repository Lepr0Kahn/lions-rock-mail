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
