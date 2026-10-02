begin;
update public.app_memberships set access_status='active',payment_status='comped',deleted_at=null,expires_at=null,artist_member_enabled=true where user_id in('8da3fa1f-10ef-4fac-8294-279e6a9e61b1','72c9afac-875f-460b-aa30-0e70b0cbaddc');
do $$declare reward uuid;claim uuid;retry uuid;count_before bigint;begin
select count(*) into count_before from public.documents;
perform set_config('request.jwt.claims','{"sub":"1204ab25-7433-43a5-80e1-7a66b2eee057","role":"authenticated","aal":"aal2"}',true);
reward:=(public.studio_reward_workspace('save','{"title":"Rollback brand reward","description":"One focused studio experience","minimum_xp":0,"capacity":1,"active":true}'::jsonb)->>'id')::uuid;
perform set_config('request.jwt.claims','{"sub":"8da3fa1f-10ef-4fac-8294-279e6a9e61b1","role":"authenticated","aal":"aal1"}',true);
claim:=(public.studio_reward_workspace('claim',jsonb_build_object('reward_id',reward))->>'id')::uuid;retry:=(public.studio_reward_workspace('claim',jsonb_build_object('reward_id',reward))->>'id')::uuid;if claim<>retry then raise exception 'Duplicate reward claim';end if;
perform set_config('request.jwt.claims','{"sub":"72c9afac-875f-460b-aa30-0e70b0cbaddc","role":"authenticated","aal":"aal1"}',true);
begin perform public.studio_reward_workspace('claim',jsonb_build_object('reward_id',reward));raise exception 'Capacity exceeded';exception when raise_exception then if sqlerrm<>'No reward places available' then raise;end if;end;
perform set_config('request.jwt.claims','{"sub":"1204ab25-7433-43a5-80e1-7a66b2eee057","role":"authenticated","aal":"aal2"}',true);
perform public.studio_reward_workspace('approve',jsonb_build_object('claim_id',claim));
perform public.studio_reward_workspace('fulfil',jsonb_build_object('claim_id',claim,'note','Delivered brand experience in fixture'));
perform public.studio_reward_workspace('fulfil',jsonb_build_object('claim_id',claim,'note','Retry'));
if (select status from private.studio_reward_claims where id=claim)<>'fulfilled' then raise exception 'Not fulfilled';end if;
if (select count(*) from public.documents)<>count_before then raise exception 'Reward touched invoice menu';end if;
end;$$;
select 'Custom reward save, claim retry, capacity, approval and fulfilment passed without invoices' result;
rollback;