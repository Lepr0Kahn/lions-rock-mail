-- Release-cycle completion parity with the Emergent reference.
-- A cycle closes once per project when that project first enters Released status.
alter table public.artist_career_events drop constraint artist_career_events_event_key_check;
alter table public.artist_career_events add constraint artist_career_events_event_key_check check(event_key in ('membership_granted','profile_complete','project_created','material_uploaded','session_booked','session_completed','master_delivered','master_collected','invoice_settled','release_published','cycle_completed'));

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
 if not was_eligible and new.status='released' then
   perform private.record_career_event(new.user_id,'release_published',new.id);
   perform private.record_career_event(new.user_id,'cycle_completed',new.id);
 end if;
elsif tg_table_name='artist_project_files' then
 perform private.record_career_event(new.user_id,case when new.kind in ('master','mp3_delivery') then 'master_delivered' else 'material_uploaded' end,new.id);
elsif tg_table_name='studio_bookings' then
 if tg_op='UPDATE' then was_eligible:=old.status='confirmed';end if;
 if not was_eligible and new.status='confirmed' then perform private.record_career_event(new.user_id,'session_booked',new.id);end if;
elsif tg_table_name='artist_delivery_collections' then
 perform private.record_career_event(new.user_id,'master_collected',new.file_id);
elsif tg_table_name='documents' then
 if tg_op='UPDATE' then was_eligible:=old.doc_type='invoice' and old.status<>'void' and old.total>0 and old.amount_paid>=old.total and (old.booking_id is not null or old.artist_project_id is not null);end if;
 if not was_eligible and new.doc_type='invoice' and new.status<>'void' and new.total>0 and new.amount_paid>=new.total and (new.booking_id is not null or new.artist_project_id is not null) and exists(select 1 from public.app_memberships m where m.user_id=new.user_id and m.role='owner') then
 perform private.record_career_event(coalesce((select user_id from public.studio_bookings where id=new.booking_id),(select user_id from public.artist_projects where id=new.artist_project_id)),'invoice_settled',new.id);
 end if;
end if;
return new;
end;$$;
revoke all on function private.capture_career_event() from public,anon,authenticated;

create or replace function private.career_event_eligible(e public.artist_career_events) returns boolean language sql stable security definer set search_path='' as $$
select case
when e.event_key='membership_granted' then true
when e.event_key='profile_complete' then exists(select 1 from public.artist_career_profiles p where p.user_id=e.user_id and btrim(p.artist_name)<>'' and btrim(p.genres)<>'' and btrim(p.goal_12_months)<>'')
when e.event_key in ('project_created','release_published','cycle_completed') then exists(select 1 from public.artist_projects p where p.id=e.source_id and p.user_id=e.user_id and p.status<>'archived' and(e.event_key not in ('release_published','cycle_completed') or p.status='released'))
when e.event_key in ('material_uploaded','master_delivered','master_collected') then exists(select 1 from public.artist_project_files f join public.artist_projects p on p.id=f.project_id where f.id=e.source_id and f.user_id=e.user_id and p.user_id=e.user_id and p.status<>'archived')
when e.event_key='session_booked' then exists(select 1 from public.studio_bookings b where b.id=e.source_id and b.user_id=e.user_id and b.status='confirmed')
when e.event_key='session_completed' then exists(select 1 from private.studio_session_completions c join public.studio_bookings b on b.id=c.booking_id where c.booking_id=e.source_id and c.artist_id=e.user_id and b.user_id=e.user_id and b.status='confirmed')
when e.event_key='invoice_settled' then exists(select 1 from public.documents d where d.id=e.source_id and coalesce((select b.user_id from public.studio_bookings b where b.id=d.booking_id),(select p.user_id from public.artist_projects p where p.id=d.artist_project_id))=e.user_id and exists(select 1 from public.app_memberships m where m.user_id=d.user_id and m.role='owner') and d.doc_type='invoice' and d.status<>'void' and d.total>0 and d.amount_paid>=d.total)
else false end;$$;
revoke all on function private.career_event_eligible(public.artist_career_events) from public,anon,authenticated;

do $$declare d text;begin
select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='artist_recognition' limit 1;
d:=replace(d,'when ''release_published'' then 500 else 0 end points','when ''release_published'' then 500 when ''cycle_completed'' then 300 else 0 end points');
d:=replace(d,'(''studio_regular'',''Studio Regular'',''session_completed'',5))b(id,name,key,need);','(''studio_regular'',''Studio Regular'',''session_completed'',5),(''repeat_cycle'',''Repeat Cycle'',''cycle_completed'',2))b(id,name,key,need);');
execute d;end;$$;