-- Run inside a transaction with the onboarding migration, then roll back.
create temporary table goal_fixture as
select (select user_id from public.app_memberships where role='member' and artist_member_enabled and access_status='active' and payment_status in ('paid','comped') order by user_id limit 1) artist,
 (select user_id from public.app_memberships where role='member' and artist_member_enabled and access_status='active' and payment_status in ('paid','comped') order by user_id offset 1 limit 1) other_artist,
 (select user_id from public.app_memberships where role='owner' and access_status='active' limit 1) owner_id,
 (select user_id from public.app_memberships where role='member' and business_tools_enabled and not artist_member_enabled and access_status='active' limit 1) business_id;
do $$ begin if exists(select 1 from goal_fixture where artist is null or other_artist is null or owner_id is null or business_id is null) then raise exception 'Existing role fixtures required';end if;end $$;
select set_config('test.goal_artist',(select artist::text from goal_fixture),true),
 set_config('test.goal_other',(select other_artist::text from goal_fixture),true),
 set_config('test.goal_owner',(select owner_id::text from goal_fixture),true),
 set_config('test.goal_business',(select business_id::text from goal_fixture),true),
 set_config('test.goal_username','test_'||(select substr(replace(artist::text,'-',''),1,20) from goal_fixture),true);
update public.artist_career_profiles set username='',goal_key='' where user_id=(select artist from goal_fixture);
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.goal_artist'),'role','authenticated','aal','aal1')::text,true);
set local role authenticated;
do $$ begin
 if not private.has_artist_setup_access() then raise exception 'Setup access denied';end if;
 if private.has_active_artist_access() then raise exception 'Incomplete setup opened Artist access';end if;
 if exists(select 1 from public.artist_projects) then raise exception 'Projects exposed before setup';end if;
 begin perform public.artist_career_tracks();raise exception 'Career RPC bypassed setup';exception when insufficient_privilege then null;end;
end $$;
insert into public.artist_career_profiles(user_id,username,artist_name,genres,goal_key,goal_12_months,direction_focus,direction_obstacle)
values(auth.uid(),current_setting('test.goal_username'),'Test Artist','Soca','release_ep','Release my EP','release','time')
on conflict(user_id) do update set username=excluded.username,artist_name=excluded.artist_name,genres=excluded.genres,goal_key=excluded.goal_key,goal_12_months=excluded.goal_12_months,direction_focus=excluded.direction_focus,direction_obstacle=excluded.direction_obstacle;
do $$ begin
 if not private.has_active_artist_access() then raise exception 'Complete setup did not unlock Artist';end if;
 perform public.artist_career_tracks();
 if exists(select 1 from public.artist_career_profiles where user_id<>auth.uid()) then raise exception 'Artist profile isolation failed';end if;
 begin update public.artist_career_profiles set username='UpperCase' where user_id=auth.uid();raise exception 'Noncanonical username accepted';exception when check_violation then null;end;
 begin update public.artist_career_profiles set goal_key='unknown' where user_id=auth.uid();raise exception 'Unknown goal accepted';exception when check_violation then null;end;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.goal_other'),'role','authenticated','aal','aal1')::text,true);
set local role authenticated;
do $$ begin
 begin
  insert into public.artist_career_profiles(user_id,username) values(auth.uid(),current_setting('test.goal_username'))
  on conflict(user_id) do update set username=excluded.username;
  raise exception 'Duplicate username accepted';
 exception when unique_violation then null;end;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.goal_business'),'role','authenticated','aal','aal1')::text,true);
set local role authenticated;
do $$ begin
 if private.has_artist_setup_access() or private.has_active_artist_access() then raise exception 'Business gained Artist setup/access';end if;
 if not private.has_active_studio_access() then raise exception 'Business access changed';end if;
 if exists(select 1 from public.artist_career_profiles) then raise exception 'Business read Artist answers';end if;
end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.goal_owner'),'role','authenticated','aal','aal2')::text,true);
set local role authenticated;
do $$ begin
 if not private.has_active_artist_access() then raise exception 'Owner gated on Artist setup';end if;
 if not exists(select 1 from public.artist_career_profiles where user_id=current_setting('test.goal_artist')::uuid and username=current_setting('test.goal_username') and goal_key='release_ep') then raise exception 'Owner cannot review setup';end if;
end $$;
reset role;
select 'PASS: profile-only access before setup, protected Artist records/RPC, unlock after save, username uniqueness, valid goal constraints, Artist isolation, Business intact and Owner exempt' as result;
