begin;
update public.artist_projects set status='active' where id='96a9335d-12c3-4a58-b122-757c3adc82ac';
update public.app_memberships set artist_member_enabled=true where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);set local role authenticated;
do $$ declare r jsonb; n bigint;begin
r:=public.artist_career_milestones();
if jsonb_array_length(r->'milestones')<>6 then raise exception 'Missing milestones';end if;
select count(*) into n from public.studio_bookings where user_id=auth.uid() and status='confirmed';
if (r->'milestones'->2->>'count')::bigint<>n then raise exception 'Cancelled booking counted';end if;
if (r->'milestones'->0->>'count')::bigint<1 or (r->'milestones'->4->>'count')::bigint<1 then raise exception 'Project or delivery evidence missing';end if;
perform public.artist_career_milestones('8da3fa1f-10ef-4fac-8294-279e6a9e61b1');
end;$$;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
do $$ declare r jsonb;n bigint;begin
r:=public.artist_career_milestones();select count(*) into n from public.artist_projects where user_id=auth.uid() and status<>'archived';
if (r->'milestones'->0->>'count')::bigint<>n then raise exception 'Artist counts leaked';end if;
begin perform public.artist_career_milestones('1204ab25-7433-43a5-80e1-7a66b2eee057');raise exception 'Cross-artist read permitted';exception when insufficient_privilege then null;end;
end;$$;
reset role;
update public.app_memberships set artist_member_enabled=false where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
set local role authenticated;
do $$ begin begin perform public.artist_career_milestones();raise exception 'Business-only access allowed';exception when insufficient_privilege then null;end;end;$$;
rollback;