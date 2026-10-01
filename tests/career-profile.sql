begin;
update public.app_memberships set artist_member_enabled=true where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);set local role authenticated;
insert into public.artist_career_profiles(user_id,artist_name,genres,goal_12_months) values(auth.uid(),'Disposable profile test','Reggae','Complete a single') on conflict(user_id) do update set artist_name=excluded.artist_name;
do $$ begin
if not exists(select 1 from public.artist_career_profiles where user_id=auth.uid()) then raise exception 'Own profile unreadable';end if;
begin insert into public.artist_career_profiles(user_id,artist_name) values('1204ab25-7433-43a5-80e1-7a66b2eee057','Forbidden');raise exception 'Cross-account write allowed';exception when insufficient_privilege then null;end;
begin update public.artist_career_profiles set user_id='72c9afac-875f-460b-aa30-0e70b0cbaddc' where user_id=auth.uid();raise exception 'Profile ownership reassignment allowed';exception when insufficient_privilege then null;end;
end;$$;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
do $$ begin if not exists(select 1 from public.artist_career_profiles where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1') then raise exception 'Owner review denied';end if;end;$$;
reset role;update public.app_memberships set artist_member_enabled=false where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);set local role authenticated;
do $$ begin if exists(select 1 from public.artist_career_profiles) then raise exception 'Business-only profile read allowed';end if;end;$$;
rollback;