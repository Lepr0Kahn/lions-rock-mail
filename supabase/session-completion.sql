-- Authoritative studio session completion.
-- Completion is a separate Owner-confirmed record so calendar synchronization and invoice status remain unchanged.
alter table public.artist_career_events drop constraint artist_career_events_event_key_check;
alter table public.artist_career_events add constraint artist_career_events_event_key_check check(event_key in ('membership_granted','profile_complete','project_created','material_uploaded','session_booked','session_completed','master_delivered','master_collected','invoice_settled','release_published'));

create table private.studio_session_completions(
  booking_id uuid primary key references public.studio_bookings(id),
  artist_id uuid not null references auth.users(id),
  completed_at timestamptz not null default now(),
  completed_by uuid not null references auth.users(id),
  note text not null default '' check(length(note)<=2000)
);
alter table private.studio_session_completions enable row level security;
revoke all on private.studio_session_completions from public,anon,authenticated;

create or replace function private.complete_studio_session(booking_id uuid, completion_note text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.studio_bookings%rowtype; c private.studio_session_completions%rowtype;
begin
 if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access()
   then raise exception 'Active Owner access required' using errcode='42501'; end if;
 select * into b from public.studio_bookings where id=booking_id for update;
 if b.id is null then raise exception 'Booking not found'; end if;
 if b.status<>'confirmed' then raise exception 'Only confirmed sessions can be completed'; end if;
 if b.ends_at>now() then raise exception 'A session can only be completed after its scheduled end time'; end if;
 insert into private.studio_session_completions(booking_id,artist_id,completed_by,note)
 values(b.id,b.user_id,auth.uid(),btrim(coalesce(completion_note,'')))
 on conflict(booking_id) do nothing returning * into c;
 if c.booking_id is null then select * into c from private.studio_session_completions where booking_id=b.id; end if;
 perform private.record_career_event(b.user_id,'session_completed',b.id);
 return to_jsonb(c);
end;$$;
revoke all on function private.complete_studio_session(uuid,text) from public,anon,authenticated;
grant execute on function private.complete_studio_session(uuid,text) to authenticated;

create or replace function public.complete_studio_session(booking_id uuid, completion_note text default '')
returns jsonb language sql security invoker set search_path='' as $$select private.complete_studio_session(booking_id,completion_note);$$;
revoke all on function public.complete_studio_session(uuid,text) from public,anon;
grant execute on function public.complete_studio_session(uuid,text) to authenticated;

create or replace function private.studio_session_completions()
returns jsonb language plpgsql security definer set search_path='' as $$
declare owner boolean; result jsonb;
begin
 if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active Artist access required' using errcode='42501';end if;
 owner:=private.is_studio_owner() and private.has_active_studio_access();
 select coalesce(jsonb_agg(to_jsonb(c) order by c.completed_at desc),'[]'::jsonb) into result
 from private.studio_session_completions c where owner or c.artist_id=auth.uid();
 return result;
end;$$;
revoke all on function private.studio_session_completions() from public,anon,authenticated;
grant execute on function private.studio_session_completions() to authenticated;

create or replace function public.studio_session_completions()
returns jsonb language sql security invoker set search_path='' as $$select private.studio_session_completions();$$;
revoke all on function public.studio_session_completions() from public,anon;
grant execute on function public.studio_session_completions() to authenticated;

create or replace function private.career_event_eligible(e public.artist_career_events) returns boolean language sql stable security definer set search_path='' as $$
select case
when e.event_key='membership_granted' then true
when e.event_key='profile_complete' then exists(select 1 from public.artist_career_profiles p where p.user_id=e.user_id and btrim(p.artist_name)<>'' and btrim(p.genres)<>'' and btrim(p.goal_12_months)<>'')
when e.event_key in ('project_created','release_published') then exists(select 1 from public.artist_projects p where p.id=e.source_id and p.user_id=e.user_id and p.status<>'archived' and(e.event_key<>'release_published' or p.status='released'))
when e.event_key in ('material_uploaded','master_delivered','master_collected') then exists(select 1 from public.artist_project_files f join public.artist_projects p on p.id=f.project_id where f.id=e.source_id and f.user_id=e.user_id and p.user_id=e.user_id and p.status<>'archived')
when e.event_key='session_booked' then exists(select 1 from public.studio_bookings b where b.id=e.source_id and b.user_id=e.user_id and b.status='confirmed')
when e.event_key='session_completed' then exists(select 1 from private.studio_session_completions c join public.studio_bookings b on b.id=c.booking_id where c.booking_id=e.source_id and c.artist_id=e.user_id and b.user_id=e.user_id and b.status='confirmed')
when e.event_key='invoice_settled' then exists(select 1 from public.documents d where d.id=e.source_id and coalesce((select b.user_id from public.studio_bookings b where b.id=d.booking_id),(select p.user_id from public.artist_projects p where p.id=d.artist_project_id))=e.user_id and exists(select 1 from public.app_memberships m where m.user_id=d.user_id and m.role='owner') and d.doc_type='invoice' and d.status<>'void' and d.total>0 and d.amount_paid>=d.total)
else false end;$$;
revoke all on function private.career_event_eligible(public.artist_career_events) from public,anon,authenticated;

do $$declare d text;begin
select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='artist_recognition' limit 1;
d:=replace(d,'when ''session_booked'' then 75 when ''master_delivered'' then 250','when ''session_booked'' then 75 when ''session_completed'' then 200 when ''master_delivered'' then 250');
d:=replace(d,'(''straight_business'',''Straight Business'',''invoice_settled'',3))b(id,name,key,need);','(''straight_business'',''Straight Business'',''invoice_settled'',3),(''in_the_room'',''In The Room'',''session_completed'',1),(''studio_regular'',''Studio Regular'',''session_completed'',5))b(id,name,key,need);');
execute d;end;$$;

do $$declare d text;begin
select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='artist_career_tracks' limit 1;
d:=replace(d,'''sessions_completed'',(select count(*) from public.studio_bookings b where b.user_id=target and b.status=''confirmed'' and b.ends_at<now()),','''sessions_completed'',(select count(*) from private.studio_session_completions c where c.artist_id=target),');
d:=replace(d,'''Past confirmed sessions reflect elapsed scheduled time, not verified attendance.'',','''Completed sessions use Owner-confirmed completion records rather than elapsed calendar time.'',');
execute d;end;$$;