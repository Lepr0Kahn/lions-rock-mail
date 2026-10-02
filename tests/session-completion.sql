begin;
select set_config('test.booking_id',(select id::text from public.studio_bookings limit 1),true);
select set_config('test.artist_id',(select user_id::text from public.studio_bookings where id=current_setting('test.booking_id')::uuid),true);

insert into private.studio_session_completions(booking_id,artist_id,completed_by,note)
values(current_setting('test.booking_id')::uuid,current_setting('test.artist_id')::uuid,'1204ab25-7433-43a5-80e1-7a66b2eee057','rollback evidence');
insert into public.artist_career_events(user_id,event_key,source_id)
values(current_setting('test.artist_id')::uuid,'session_completed',current_setting('test.booking_id')::uuid)
on conflict(user_id,event_key,source_id) do nothing;
insert into public.artist_career_events(user_id,event_key,source_id)
values(current_setting('test.artist_id')::uuid,'session_completed',current_setting('test.booking_id')::uuid)
on conflict(user_id,event_key,source_id) do nothing;

do $$
begin
 if (select count(*) from private.studio_session_completions where booking_id=current_setting('test.booking_id')::uuid)<>1 then raise exception 'Completion must be one per booking';end if;
 if (select count(*) from public.artist_career_events where event_key='session_completed' and source_id=current_setting('test.booking_id')::uuid)<>1 then raise exception 'Completion event retry must be idempotent';end if;
end;$$;
rollback;

select has_function_privilege('anon','public.complete_studio_session(uuid,text)','EXECUTE') anon_complete,
       has_function_privilege('authenticated','public.complete_studio_session(uuid,text)','EXECUTE') auth_complete,
       has_function_privilege('anon','public.studio_session_completions()','EXECUTE') anon_list;