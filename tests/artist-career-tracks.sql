begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
do $$ declare pid uuid;fid uuid;r jsonb;k text;begin
insert into public.artist_career_profiles(user_id,artist_name,genres,goal_12_months) values(auth.uid(),'Rollback artist','Test','Test goal') on conflict(user_id) do update set artist_name='Rollback artist',genres='Test',goal_12_months='Test goal';
for i in 1..4 loop
insert into public.artist_projects(user_id,title,kind,status) values(auth.uid(),'Rollback track fixture','single','released') returning id into pid;
for j in 1..3 loop
insert into public.artist_project_files(project_id,user_id,uploaded_by,object_path,filename,kind,size_bytes,expires_at) values(pid,auth.uid(),auth.uid(),auth.uid()||'/'||pid||'/master/'||gen_random_uuid()||'/fixture.txt','fixture.txt','master',1,now()+interval '1 day') returning id into fid;
insert into public.artist_delivery_collections(file_id,user_id) values(fid,auth.uid());
end loop;end loop;
end;$$;
set local role authenticated;
do $$ declare r jsonb;begin
r:=public.artist_career_tracks();
if (r#>>'{tracks,creative,score}')::int<>100 or(r#>>'{tracks,audience,score}')::int<>100 then raise exception 'Track caps failed %',r;end if;
if (r#>>'{tracks,network,available_max}')::int<>70 or(r#>>'{tracks,business,available_max}')::int<>86 or(r#>>'{tracks,momentum,available_max}')::int<>30 then raise exception 'Missing signal coverage incorrect';end if;
if r#>>'{tracks,business,breakdown,2,available}'<>'false' then raise exception 'Budget signal invented';end if;
r:=public.artist_career_tracks('8da3fa1f-10ef-4fac-8294-279e6a9e61b1');
if r->>'artist_id'<>'8da3fa1f-10ef-4fac-8294-279e6a9e61b1' then raise exception 'Owner target mismatch';end if;
end;$$;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
do $$ declare r jsonb;begin
r:=public.artist_career_tracks();
if (r#>>'{tracks,creative,score}')::int=100 then raise exception 'Owner fixtures leaked';end if;
begin perform public.artist_career_tracks('1204ab25-7433-43a5-80e1-7a66b2eee057');raise exception 'CrossArtist read allowed';exception when insufficient_privilege then null;end;
end;$$;
select set_config('request.jwt.claim.sub','72c9afac-875f-460b-aa30-0e70b0cbaddc',true);
do $$ begin begin perform public.artist_career_tracks();raise exception 'Business read allowed';exception when insufficient_privilege then null;end;end;$$;
rollback;