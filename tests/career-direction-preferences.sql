begin;
create temporary table direction_fixture as
select m.user_id artist,
 (select user_id from public.app_memberships where role='owner' and access_status='active' limit 1) owner_id,
 (select user_id from public.app_memberships where role='member' and business_tools_enabled and not artist_member_enabled and access_status='active' limit 1) business_id,
 (select count(*) from public.artist_career_events) event_count
from public.app_memberships m join public.artist_career_profiles p on p.user_id=m.user_id
where m.role='member' and m.artist_member_enabled and m.access_status='active' and m.payment_status in ('paid','comped')
limit 1;
do $$ begin if (select count(*) from direction_fixture)<>1 then raise exception 'Existing Artist profile fixture required';end if;end $$;
select set_config('test.direction_artist',(select artist::text from direction_fixture),true),
 set_config('test.direction_owner',(select owner_id::text from direction_fixture),true),
 set_config('test.direction_business',(select business_id::text from direction_fixture),true);
-- Prepare the existing Artist fixture for the required first-entry setup inside this rollback.
update public.artist_career_profiles set username='test_'||substr(replace(user_id::text,'-',''),1,20),goal_key='custom',artist_name=coalesce(nullif(btrim(artist_name),''),'Test Artist'),genres=coalesce(nullif(btrim(genres),''),'Soca'),goal_12_months=coalesce(nullif(btrim(goal_12_months),''),'My goal') where user_id=(select artist from direction_fixture);
update direction_fixture set event_count=(select count(*) from public.artist_career_events);
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.direction_artist'),'role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select set_config('test.direction_tracks',(public.artist_career_tracks()-'computed_at')::text,true);
update public.artist_career_profiles set direction_focus='release',direction_obstacle='time' where user_id=auth.uid();
do $$ declare changed integer; begin
 if not exists(select 1 from public.artist_career_profiles where user_id=auth.uid() and direction_focus='release' and direction_obstacle='time') then raise exception 'Own preferences did not save';end if;
 if (public.artist_career_tracks()-'computed_at')<>current_setting('test.direction_tracks')::jsonb then raise exception 'Preferences changed track scores';end if;
 update public.artist_career_profiles set direction_focus='business' where user_id=current_setting('test.direction_owner')::uuid;
 get diagnostics changed=row_count;
 if changed<>0 then raise exception 'Artist changed another profile';end if;
 if exists(select 1 from public.artist_career_profiles where user_id<>auth.uid()) then raise exception 'Artist read another profile';end if;
 begin
  update public.artist_career_profiles set direction_focus='unknown' where user_id=auth.uid();
  raise exception 'Unknown focus accepted';
 exception when check_violation then null;end;
 begin
  update public.artist_career_profiles set direction_obstacle='unknown' where user_id=auth.uid();
  raise exception 'Unknown obstacle accepted';
 exception when check_violation then null;end;
end $$;
reset role;
do $$ begin if (select count(*) from public.artist_career_events)<>(select event_count from direction_fixture) then raise exception 'Preferences awarded a career event';end if;end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.direction_business'),'role','authenticated','aal','aal1')::text,true);
set local role authenticated;
do $$ begin if exists(select 1 from public.artist_career_profiles) then raise exception 'Business member read Artist preferences';end if;end $$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.direction_owner'),'role','authenticated','aal','aal2')::text,true);
set local role authenticated;
do $$ begin if not exists(select 1 from public.artist_career_profiles where user_id=current_setting('test.direction_artist')::uuid and direction_focus='release' and direction_obstacle='time') then raise exception 'Owner cannot review Artist preferences';end if;end $$;
reset role;
select 'PASS: preferences save; unchanged tracks and career events; invalid choices rejected; Artist isolation; Business denied; Owner review' as result;
rollback;
