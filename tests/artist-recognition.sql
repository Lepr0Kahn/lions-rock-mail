begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $test$
declare p uuid;q uuid;a jsonb;b jsonb;initial_xp int;first_points int;e uuid;
begin
a:=public.artist_recognition();initial_xp:=(a->>'xp')::int;
first_points:=case when exists(select 1 from jsonb_array_elements(a->'awards') x where x->>'key'='project_created') then 50 else 150 end;
insert into public.artist_projects(title) values('Disposable recognition first project') returning id into p;
insert into public.artist_projects(title) values('Disposable recognition second project') returning id into q;
b:=public.artist_recognition();
if (b->>'xp')::int<>initial_xp+first_points+50 then raise exception 'Project XP mismatch';end if;
if public.artist_recognition()->'xp'<>b->'xp' then raise exception 'Read replay changed XP';end if;
update public.artist_projects set status='released' where id=p;
if (public.artist_recognition()->>'xp')::int<>initial_xp+first_points+550 then raise exception 'Release XP mismatch';end if;
update public.artist_projects set status='active' where id=p;
if (public.artist_recognition()->>'xp')::int<>initial_xp+first_points+50 then raise exception 'Release correction retained XP';end if;
update public.artist_projects set status='released' where id=p;
if (public.artist_recognition()->>'xp')::int<>initial_xp+first_points+550 then raise exception 'Release replay duplicated XP';end if;
select id into e from public.artist_career_events where source_id=p and event_key='release_published';
perform public.reverse_artist_career_event(e,'Disposable recognition test reversal');
if (public.artist_recognition()->>'xp')::int<>initial_xp+first_points+50 then raise exception 'Reversal did not remove XP';end if;
update public.artist_projects set status='archived' where id=q;
if (public.artist_recognition()->>'xp')::int<>initial_xp+first_points then raise exception 'Archived project retained XP';end if;
if (public.artist_recognition()->>'benefits_enabled')::boolean then raise exception 'Tangible rewards enabled';end if;
end $test$;
reset role;
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $test$ begin
perform public.artist_recognition();
begin perform public.artist_recognition('1204ab25-7433-43a5-80e1-7a66b2eee057');raise exception 'Cross Artist read allowed';exception when insufficient_privilege then null;end;
end $test$;
reset role;
update public.app_memberships set access_status='suspended' where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
set local role authenticated;
do $test$ begin begin perform public.artist_recognition();raise exception 'Suspended Artist read allowed';exception when insufficient_privilege then null;end;end $test$;
rollback;
select 'PASS project/release points, replay, correction, reversal, archive, own/cross/suspended access; benefits disabled; fixtures rolled back' result;
begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
do $test$
declare p uuid;f uuid;g uuid;before_xp int;after_project int;
begin
before_xp:=(public.artist_recognition()->>'xp')::int;
insert into public.artist_projects(user_id,title) values(auth.uid(),'Disposable recognition delivery cap') returning id into p;
after_project:=(public.artist_recognition()->>'xp')::int;
insert into public.artist_project_files(project_id,user_id,uploaded_by,object_path,filename,kind,size_bytes)
values(p,auth.uid(),auth.uid(),'recognition-fixture/'||gen_random_uuid(),'master.wav','master',1) returning id into f;
insert into public.artist_project_files(project_id,user_id,uploaded_by,object_path,filename,kind,size_bytes)
values(p,auth.uid(),auth.uid(),'recognition-fixture/'||gen_random_uuid(),'delivery.mp3','mp3_delivery',1) returning id into g;
if (public.artist_recognition()->>'xp')::int<>after_project+250 then raise exception 'WAV/MP3 duplicated XP';end if;
update public.artist_project_files set expires_at=now()+interval '30 days' where id=f;
if (public.artist_recognition()->>'xp')::int<>after_project+250 then raise exception 'Reissue duplicated XP';end if;
update public.artist_career_events set backfilled=true where source_id in(f,g);
if (public.artist_recognition()->>'xp')::int<>after_project then raise exception 'Backfill credited XP';end if;
update public.artist_career_events set backfilled=false,occurred_at=now()+interval '1 day' where source_id in(f,g);
if (public.artist_recognition()->>'xp')::int<>after_project then raise exception 'Future event credited XP';end if;
end $test$;
rollback;
select 'PASS WAV/MP3 project cap, reissue, backfill/future exclusions; metadata fixtures only, rolled back' result;