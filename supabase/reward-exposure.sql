-- Owner-configurable reward cost estimates and exposure planning.
-- Planning values are informational only and never alter service prices, invoices or payments.
alter table private.studio_rewards
  add column if not exists estimated_hours numeric(8,2) not null default 0 check(estimated_hours>=0),
  add column if not exists estimated_value_bbd numeric(12,2) not null default 0 check(estimated_value_bbd>=0);

create table if not exists private.studio_reward_planning(
  singleton boolean primary key default true check(singleton),
  available_hours_90d numeric(8,2) not null default 0 check(available_hours_90d>=0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
alter table private.studio_reward_planning enable row level security;
revoke all on private.studio_reward_planning from public,anon,authenticated;
insert into private.studio_reward_planning(singleton) values(true) on conflict(singleton) do nothing;

create or replace function private.set_studio_reward_cost(reward_id uuid,hours numeric,value_bbd numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.studio_rewards%rowtype;
begin
  if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access()
    then raise exception 'Active Owner access required' using errcode='42501'; end if;
  if hours is null or hours<0 or value_bbd is null or value_bbd<0 then raise exception 'Estimated cost cannot be negative'; end if;
  update private.studio_rewards set estimated_hours=round(hours,2),estimated_value_bbd=round(value_bbd,2)
  where id=reward_id returning * into r;
  if r.id is null then raise exception 'Reward not found'; end if;
  return to_jsonb(r);
end;$$;
revoke all on function private.set_studio_reward_cost(uuid,numeric,numeric) from public,anon,authenticated;
grant execute on function private.set_studio_reward_cost(uuid,numeric,numeric) to authenticated;

create or replace function public.set_studio_reward_cost(reward_id uuid,hours numeric,value_bbd numeric)
returns jsonb language sql security invoker set search_path='' as $$select private.set_studio_reward_cost(reward_id,hours,value_bbd);$$;
revoke all on function public.set_studio_reward_cost(uuid,numeric,numeric) from public,anon;
grant execute on function public.set_studio_reward_cost(uuid,numeric,numeric) to authenticated;

create or replace function private.studio_reward_exposure(new_available_hours_90d numeric default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare budget numeric; result jsonb;
begin
  if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access()
    then raise exception 'Active Owner access required' using errcode='42501'; end if;
  if new_available_hours_90d is not null then
    if new_available_hours_90d<0 then raise exception 'Planning hours cannot be negative'; end if;
    insert into private.studio_reward_planning(singleton,available_hours_90d,updated_at,updated_by)
    values(true,round(new_available_hours_90d,2),now(),auth.uid())
    on conflict(singleton) do update set available_hours_90d=excluded.available_hours_90d,updated_at=now(),updated_by=auth.uid();
  end if;
  select available_hours_90d into budget from private.studio_reward_planning where singleton=true;
  with reward_usage as (
    select r.id,r.title,r.active,r.archived,r.capacity,r.estimated_hours,r.estimated_value_bbd,
      count(c.id) filter(where c.status not in('denied','cancelled'))::int used_places,
      count(c.id) filter(where c.status in('requested','approved'))::int live_claims,
      count(c.id) filter(where c.status='fulfilled')::int fulfilled_claims
    from private.studio_rewards r left join private.studio_reward_claims c on c.reward_id=r.id
    where not r.archived group by r.id
  ), totals as (
    select coalesce(sum(live_claims),0)::int live_claims,coalesce(sum(fulfilled_claims),0)::int fulfilled_claims,
      coalesce(sum(live_claims*estimated_hours),0)::numeric live_hours,
      coalesce(sum(live_claims*estimated_value_bbd),0)::numeric live_value,
      coalesce(sum(fulfilled_claims*estimated_hours),0)::numeric fulfilled_hours,
      coalesce(sum(fulfilled_claims*estimated_value_bbd),0)::numeric fulfilled_value,
      coalesce(sum(greatest(capacity-used_places,0)) filter(where active),0)::int places_left,
      coalesce(sum(greatest(capacity-used_places,0)*estimated_hours) filter(where active),0)::numeric unissued_hours,
      coalesce(sum(greatest(capacity-used_places,0)*estimated_value_bbd) filter(where active),0)::numeric unissued_value
    from reward_usage
  )
  select jsonb_build_object(
    'planning_hours_90d',budget,'live_claims',t.live_claims,'fulfilled_claims',t.fulfilled_claims,
    'live_hours',round(t.live_hours,2),'live_value_bbd',round(t.live_value,2),
    'fulfilled_hours',round(t.fulfilled_hours,2),'fulfilled_value_bbd',round(t.fulfilled_value,2),
    'active_places_left',t.places_left,'unissued_hours',round(t.unissued_hours,2),
    'unissued_value_bbd',round(t.unissued_value,2),'worst_case_hours',round(t.live_hours+t.unissued_hours,2),
    'worst_case_value_bbd',round(t.live_value+t.unissued_value,2),
    'live_over_budget',case when budget>0 then t.live_hours>budget else null end,
    'worst_case_over_budget',case when budget>0 then (t.live_hours+t.unissued_hours)>budget else null end,
    'rewards',coalesce((select jsonb_agg(jsonb_build_object(
      'id',u.id,'title',u.title,'active',u.active,'capacity',u.capacity,'used_places',u.used_places,
      'places_left',greatest(u.capacity-u.used_places,0),'live_claims',u.live_claims,'fulfilled_claims',u.fulfilled_claims,
      'estimated_hours',u.estimated_hours,'estimated_value_bbd',u.estimated_value_bbd
    ) order by u.title) from reward_usage u),'[]'::jsonb),'computed_at',now()
  ) into result from totals t;
  return result;
end;$$;
revoke all on function private.studio_reward_exposure(numeric) from public,anon,authenticated;
grant execute on function private.studio_reward_exposure(numeric) to authenticated;

create or replace function public.studio_reward_exposure(available_hours_90d numeric default null)
returns jsonb language sql security invoker set search_path='' as $$select private.studio_reward_exposure(available_hours_90d);$$;
revoke all on function public.studio_reward_exposure(numeric) from public,anon;
grant execute on function public.studio_reward_exposure(numeric) to authenticated;