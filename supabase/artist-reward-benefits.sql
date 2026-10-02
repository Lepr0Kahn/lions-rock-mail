create table private.studio_rewards(id uuid primary key default gen_random_uuid(),title text not null check(length(btrim(title)) between 1 and 160),description text not null default '' check(length(description)<=3000),minimum_xp integer not null default 0 check(minimum_xp>=0),capacity integer not null default 1 check(capacity between 1 and 10000),active boolean not null default false,archived boolean not null default false,created_at timestamptz not null default now());
create table private.studio_reward_claims(id uuid primary key default gen_random_uuid(),reward_id uuid not null references private.studio_rewards(id),artist_id uuid not null references auth.users(id),title_snapshot text not null,description_snapshot text not null,minimum_xp_snapshot integer not null,status text not null default 'requested' check(status in('requested','approved','fulfilled','denied')),requested_at timestamptz not null default now(),updated_at timestamptz not null default now(),owner_note text not null default '' check(length(owner_note)<=2000),decided_by uuid references auth.users(id));
create unique index reward_once_per_artist on private.studio_reward_claims(reward_id,artist_id) where status<>'denied';
alter table private.studio_rewards enable row level security;alter table private.studio_reward_claims enable row level security;
revoke all on private.studio_rewards,private.studio_reward_claims from public,anon,authenticated;
insert into private.studio_rewards(title,description) values
('Creative studio session','A focused bonus session for an artist development goal. Duration and availability set by the studio.'),
('Promotional photo shoot','Artist brand photography; scope and deliverables agreed before scheduling.'),
('Filmed artist interview','An artist story interview; format and deliverables agreed before scheduling.'),
('Behind-the-scenes content session','Create promotional content around an artist project.'),
('Lions Rock artist spotlight','A studio-approved artist feature; timing and channel agreed before fulfilment.');
create function private.studio_reward_workspace(operation text,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare owner boolean;reward private.studio_rewards%rowtype;claim private.studio_reward_claims%rowtype;xp integer;rid uuid;used integer;
begin
if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active Artist access required' using errcode='42501';end if;
owner:=private.is_studio_owner() and private.has_active_studio_access();
if operation='save' then
if not owner then raise exception 'Owner required' using errcode='42501';end if;
rid:=nullif(payload->>'id','')::uuid;
if rid is null then insert into private.studio_rewards(title,description,minimum_xp,capacity,active,archived) values(btrim(payload->>'title'),coalesce(payload->>'description',''),(payload->>'minimum_xp')::int,(payload->>'capacity')::int,coalesce((payload->>'active')::boolean,false),coalesce((payload->>'archived')::boolean,false)) returning * into reward;
else select * into reward from private.studio_rewards where id=rid for update;if reward.id is null then raise exception 'Reward not found';end if;
select count(*) into used from private.studio_reward_claims where reward_id=rid and status<>'denied';
if (payload->>'capacity')::int<used then raise exception 'Capacity cannot be below existing claims';end if;
update private.studio_rewards set title=btrim(payload->>'title'),description=coalesce(payload->>'description',''),minimum_xp=(payload->>'minimum_xp')::int,capacity=(payload->>'capacity')::int,active=coalesce((payload->>'active')::boolean,false),archived=coalesce((payload->>'archived')::boolean,false) where id=rid returning * into reward;end if;
return to_jsonb(reward);
elsif operation='claim' then
if owner then raise exception 'Rewards are for Artist Members';end if;
select * into reward from private.studio_rewards where id=(payload->>'reward_id')::uuid for update;
if reward.id is null or not reward.active or reward.archived then raise exception 'Reward unavailable';end if;
select * into claim from private.studio_reward_claims where reward_id=reward.id and artist_id=auth.uid() and status<>'denied';
if claim.id is not null then return to_jsonb(claim);end if;
xp:=(private.artist_recognition(auth.uid())->>'xp')::int;
if xp<reward.minimum_xp then raise exception 'Required XP milestone not reached';end if;
if (select count(*) from private.studio_reward_claims where reward_id=reward.id and status<>'denied')>=reward.capacity then raise exception 'No reward places available';end if;
insert into private.studio_reward_claims(reward_id,artist_id,title_snapshot,description_snapshot,minimum_xp_snapshot) values(reward.id,auth.uid(),reward.title,reward.description,reward.minimum_xp) returning * into claim;return to_jsonb(claim);
elsif operation in('approve','deny','fulfil') then
if not owner then raise exception 'Owner required' using errcode='42501';end if;
select * into claim from private.studio_reward_claims where id=(payload->>'claim_id')::uuid;
if claim.id is null then raise exception 'Claim not found';end if;
perform 1 from private.studio_rewards where id=claim.reward_id for update;
select * into claim from private.studio_reward_claims where id=claim.id for update;
if (operation='approve' and claim.status='approved') or(operation='fulfil' and claim.status='fulfilled') or(operation='deny' and claim.status='denied') then return to_jsonb(claim);end if;
if operation in('approve','deny') and claim.status<>'requested' then raise exception 'Only requested claims can be approved or denied';end if;
if operation='fulfil' and claim.status<>'approved' then raise exception 'Approve before fulfilment';end if;
if operation in('approve','fulfil') then
xp:=(private.artist_recognition(claim.artist_id)->>'xp')::int;
if xp<claim.minimum_xp_snapshot then raise exception 'Artist no longer meets the claimed XP milestone';end if;end if;
if operation in('deny','fulfil') and length(btrim(coalesce(payload->>'note','')))<3 then raise exception 'Record the reason or fulfilment details';end if;
update private.studio_reward_claims set status=case operation when 'approve' then 'approved' when 'deny' then 'denied' else 'fulfilled' end,owner_note=coalesce(payload->>'note',''),decided_by=auth.uid(),updated_at=now() where id=claim.id returning * into claim;return to_jsonb(claim);
elsif operation='view' then
return jsonb_build_object('owner',owner,'xp',case when owner then null else (private.artist_recognition(auth.uid())->>'xp')::int end,'rewards',(select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('places_left',greatest(r.capacity-(select count(*) from private.studio_reward_claims c where c.reward_id=r.id and c.status<>'denied'),0)) order by r.created_at),'[]') from private.studio_rewards r where owner or(r.active and not r.archived)),'claims',(select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('artist_name',coalesce(m.business_name,m.email)) order by c.requested_at desc),'[]') from private.studio_reward_claims c join public.app_memberships m on m.user_id=c.artist_id where owner or c.artist_id=auth.uid()));
else raise exception 'Invalid reward operation';end if;
end;$$;
revoke all on function private.studio_reward_workspace(text,jsonb) from public,anon;
grant execute on function private.studio_reward_workspace(text,jsonb) to authenticated;
create function public.studio_reward_workspace(operation text default 'view',payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select private.studio_reward_workspace(operation,payload);$$;
revoke all on function public.studio_reward_workspace(text,jsonb) from public,anon;
grant execute on function public.studio_reward_workspace(text,jsonb) to authenticated;
