begin;
select set_config('test.reward_id',(select id::text from private.studio_rewards order by created_at limit 1),true);
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $$
declare x jsonb; y jsonb;
begin
  x:=public.studio_reward_exposure();
  if x is null then raise exception 'Exposure unavailable'; end if;
  perform public.set_studio_reward_cost(current_setting('test.reward_id')::uuid,1.5,200);
  y:=public.studio_reward_exposure(20);
  if (y->>'planning_hours_90d')::numeric<>20 then raise exception 'Planning hours not saved'; end if;
  if (select estimated_hours from private.studio_rewards where id=current_setting('test.reward_id')::uuid)<>1.5 then raise exception 'Estimated hours not saved'; end if;
end;$$;
rollback;

select has_function_privilege('anon','public.studio_reward_exposure(numeric)','EXECUTE') anon_exposure,
       has_function_privilege('anon','public.set_studio_reward_cost(uuid,numeric,numeric)','EXECUTE') anon_cost;