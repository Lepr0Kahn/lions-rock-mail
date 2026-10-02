begin;
select set_config('test.project_id',(select id::text from public.artist_projects order by created_at limit 1),true);
select set_config('test.artist_id',(select user_id::text from public.artist_projects where id=current_setting('test.project_id')::uuid),true);
update public.artist_projects set status='active' where id=current_setting('test.project_id')::uuid;
update public.artist_projects set status='released' where id=current_setting('test.project_id')::uuid;
do $$
begin
 if (select count(*) from public.artist_career_events where user_id=current_setting('test.artist_id')::uuid and event_key='cycle_completed' and source_id=current_setting('test.project_id')::uuid)<>1 then raise exception 'Cycle completion event missing or duplicated'; end if;
 if (select count(*) from public.artist_career_events where user_id=current_setting('test.artist_id')::uuid and event_key='release_published' and source_id=current_setting('test.project_id')::uuid)<>1 then raise exception 'Release event missing or duplicated'; end if;
end;$$;
rollback;