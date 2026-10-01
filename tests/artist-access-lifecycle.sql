-- Each scenario rolls back all test data and membership state changes.
begin;
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=true,business_tools_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
insert into public.artist_projects(user_id,title) values('8da3fa1f-10ef-4fac-8294-279e6a9e61b1','Disposable access regression active'),('1204ab25-7433-43a5-80e1-7a66b2eee057','Disposable cross-artist access regression');
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $test$ declare rejected boolean:=false;begin
if not exists(select 1 from public.artist_projects where user_id=auth.uid()) then raise exception 'Own projects unavailable';end if;
if exists(select 1 from public.artist_projects where user_id<>auth.uid()) or exists(select 1 from public.artist_project_files where user_id<>auth.uid()) or exists(select 1 from public.studio_bookings where user_id<>auth.uid()) then raise exception 'Cross-artist data visible';end if;
perform public.artist_career_tracks();perform public.artist_career_history();
end $test$;
rollback;
begin;
update public.app_memberships set access_status='suspended',payment_status='comped',artist_member_enabled=true,business_tools_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
insert into public.artist_projects(user_id,title) values('8da3fa1f-10ef-4fac-8294-279e6a9e61b1','Disposable access regression suspended'),('1204ab25-7433-43a5-80e1-7a66b2eee057','Disposable cross-artist access regression');
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $test$ declare rejected boolean:=false;begin
if exists(select 1 from public.artist_projects) or exists(select 1 from public.artist_project_files) or exists(select 1 from public.studio_bookings) then raise exception 'suspended artist data visible';end if;
begin perform public.artist_career_tracks();exception when insufficient_privilege then rejected:=true;end;
if not rejected then raise exception 'suspended tracks access permitted';end if;
rejected:=false;
begin perform public.artist_career_history();exception when insufficient_privilege then rejected:=true;end;
if not rejected then raise exception 'suspended history access permitted';end if;
end $test$;
rollback;
begin;
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=true,business_tools_enabled=true,deleted_at=now(),expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
insert into public.artist_projects(user_id,title) values('8da3fa1f-10ef-4fac-8294-279e6a9e61b1','Disposable access regression removed'),('1204ab25-7433-43a5-80e1-7a66b2eee057','Disposable cross-artist access regression');
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $test$ declare rejected boolean:=false;begin
if exists(select 1 from public.artist_projects) or exists(select 1 from public.artist_project_files) or exists(select 1 from public.studio_bookings) then raise exception 'removed artist data visible';end if;
begin perform public.artist_career_tracks();exception when insufficient_privilege then rejected:=true;end;
if not rejected then raise exception 'removed tracks access permitted';end if;
rejected:=false;
begin perform public.artist_career_history();exception when insufficient_privilege then rejected:=true;end;
if not rejected then raise exception 'removed history access permitted';end if;
end $test$;
rollback;
begin;
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=true,business_tools_enabled=true,deleted_at=null,expires_at=now()-interval '1 second' where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
insert into public.artist_projects(user_id,title) values('8da3fa1f-10ef-4fac-8294-279e6a9e61b1','Disposable access regression expired'),('1204ab25-7433-43a5-80e1-7a66b2eee057','Disposable cross-artist access regression');
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $test$ declare rejected boolean:=false;begin
if exists(select 1 from public.artist_projects) or exists(select 1 from public.artist_project_files) or exists(select 1 from public.studio_bookings) then raise exception 'expired artist data visible';end if;
begin perform public.artist_career_tracks();exception when insufficient_privilege then rejected:=true;end;
if not rejected then raise exception 'expired tracks access permitted';end if;
rejected:=false;
begin perform public.artist_career_history();exception when insufficient_privilege then rejected:=true;end;
if not rejected then raise exception 'expired history access permitted';end if;
end $test$;
rollback;
begin;
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=false,business_tools_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
insert into public.artist_projects(user_id,title) values('8da3fa1f-10ef-4fac-8294-279e6a9e61b1','Disposable access regression business'),('1204ab25-7433-43a5-80e1-7a66b2eee057','Disposable cross-artist access regression');
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $test$ declare rejected boolean:=false;begin
if exists(select 1 from public.artist_projects) or exists(select 1 from public.artist_project_files) or exists(select 1 from public.studio_bookings) then raise exception 'business artist data visible';end if;
begin perform public.artist_career_tracks();exception when insufficient_privilege then rejected:=true;end;
if not rejected then raise exception 'business tracks access permitted';end if;
rejected:=false;
begin perform public.artist_career_history();exception when insufficient_privilege then rejected:=true;end;
if not rejected then raise exception 'business history access permitted';end if;
end $test$;
rollback;