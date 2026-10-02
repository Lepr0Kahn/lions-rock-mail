alter table private.studio_reward_claims drop constraint studio_reward_claims_status_check;
alter table private.studio_reward_claims add constraint studio_reward_claims_status_check check(status in('requested','approved','fulfilled','denied','cancelled'));
alter table private.studio_reward_claims add column scheduled_at timestamptz,add column duration_minutes integer check(duration_minutes between 1 and 480),add column location text not null default '' check(length(location)<=400);
drop index private.reward_once_per_artist;
create unique index reward_once_per_artist on private.studio_reward_claims(reward_id,artist_id) where status not in('denied','cancelled');
do $$declare d text;begin
select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='studio_reward_workspace';
d:=replace(d,'status<>''denied''','status not in(''denied'',''cancelled'')');
d:=replace(d,'elsif operation in(''approve'',''deny'',''fulfil'') then', $branch$
elsif operation in('schedule','cancel') then
if not owner then raise exception 'Owner required' using errcode='42501';end if;
select * into claim from private.studio_reward_claims where id=(payload->>'claim_id')::uuid;
if claim.id is null then raise exception 'Claim not found';end if;
perform 1 from private.studio_rewards where id=claim.reward_id for update;
select * into claim from private.studio_reward_claims where id=claim.id for update;
if operation='cancel' then
if claim.status='cancelled' then return to_jsonb(claim);end if;
if claim.status not in('requested','approved') then raise exception 'Only unfulfilled claims can be cancelled';end if;
if length(btrim(coalesce(payload->>'note','')))<3 then raise exception 'Record the cancellation reason';end if;
update private.studio_reward_claims set status='cancelled',owner_note=payload->>'note',decided_by=auth.uid(),updated_at=now() where id=claim.id returning * into claim;
else
if claim.status<>'approved' then raise exception 'Approve before scheduling';end if;
xp:=(private.artist_recognition(claim.artist_id)->>'xp')::int;
if xp<claim.minimum_xp_snapshot then raise exception 'Artist no longer meets the claimed XP milestone';end if;
if nullif(payload->>'scheduled_at','') is null or(payload->>'scheduled_at')::timestamptz<=now() or nullif(payload->>'duration_minutes','') is null then raise exception 'Enter a future date and duration';end if;
update private.studio_reward_claims set scheduled_at=(payload->>'scheduled_at')::timestamptz,duration_minutes=(payload->>'duration_minutes')::int,location=coalesce(payload->>'location',''),decided_by=auth.uid(),updated_at=now() where id=claim.id returning * into claim;
end if;return to_jsonb(claim);
elsif operation='notice' then
if not owner then raise exception 'Owner required' using errcode='42501';end if;
select * into claim from private.studio_reward_claims where id=(payload->>'claim_id')::uuid;
if claim.id is null or claim.status not in('approved','fulfilled','denied','cancelled') then raise exception 'Decide the claim before preparing a notice';end if;
return jsonb_build_object('claim',to_jsonb(claim),'recipient',(select case when m.is_minor then (select jsonb_build_object('name',g.guardian_name,'email',g.guardian_email) from private.studio_guardian_contacts g where g.artist_id=m.user_id) else jsonb_build_object('name',coalesce(m.business_name,'Artist'),'email',m.email) end from public.app_memberships m where m.user_id=claim.artist_id and m.access_status='active' and m.deleted_at is null and m.artist_member_enabled and m.payment_status in('paid','comped') and(m.expires_at is null or m.expires_at>now())));
elsif operation in('approve','deny','fulfil') then
$branch$);
execute d;end;$$;