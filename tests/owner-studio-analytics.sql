-- Disposable analytics regression: all records and number reservations roll back.
begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $test$
declare before_data jsonb;after_data jsonb;before_total numeric;after_total numeric;before_paid numeric;after_paid numeric;before_balance numeric;after_balance numeric;
begin
before_data:=public.studio_analytics(30);
if (before_data->>'days')::int<>30 then raise exception 'Window mismatch';end if;
if (select sum(value::int) from jsonb_each_text(before_data->'evidence_stages'))<>(before_data->>'active_artists')::int then raise exception 'Stage roster mismatch';end if;
select coalesce(sum((f->>'invoiced')::numeric),0),coalesce(sum((f->>'recorded_paid')::numeric),0),coalesce(sum((f->>'outstanding')::numeric),0) into before_total,before_paid,before_balance from jsonb_array_elements(before_data->'finance_snapshot') f where f->>'currency'='USD';
insert into public.documents(user_id,doc_type,status,doc_date,currency,total,amount_paid,deposit_pct) values
(auth.uid(),'invoice','open',current_date,'USD',100,50,50),
(auth.uid(),'invoice','void',current_date,'USD',999,0,50),
(auth.uid(),'invoice','draft',current_date,'USD',777,0,50);
after_data:=public.studio_analytics(7);
select coalesce(sum((f->>'invoiced')::numeric),0),coalesce(sum((f->>'recorded_paid')::numeric),0),coalesce(sum((f->>'outstanding')::numeric),0) into after_total,after_paid,after_balance from jsonb_array_elements(after_data->'finance_snapshot') f where f->>'currency'='USD';
if after_total<>before_total+100 or after_paid<>before_paid+50 or after_balance<>before_balance+50 then raise exception 'Currency totals/draft/void exclusion failed';end if;
if (public.studio_analytics(90)->>'days')::int<>90 then raise exception '90-day window failed';end if;
begin perform public.studio_analytics(8);raise exception 'Invalid window allowed';exception when raise_exception then if sqlerrm='Invalid window allowed' then raise;end if;end;
end $test$;
reset role;
select set_config('request.jwt.claim.sub','72c9afac-875f-460b-aa30-0e70b0cbaddc',true);
set local role authenticated;
do $deny$ begin
begin perform public.studio_analytics(30);raise exception 'Non-Owner allowed';exception when insufficient_privilege then null;end;
end $deny$;
reset role;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $deny$ begin
begin perform public.studio_analytics(30);raise exception 'Member allowed';exception when insufficient_privilege then null;end;
end $deny$;
rollback;
select 'PASS Owner windows, roster consistency, USD totals, partial payment, draft/void exclusion, non-Owner denial; all fixtures rolled back' result;
begin;
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $check$ declare d jsonb;begin
d:=public.studio_analytics(30);
if (d->>'active_artists')::int<1 then raise exception 'Eligible Artist not included';end if;
if (select sum(value::int) from jsonb_each_text(d->'evidence_stages'))<>(d->>'active_artists')::int then raise exception 'Eligible stage mismatch';end if;
end $check$;
reset role;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $deny$ begin begin perform public.studio_analytics(30);raise exception 'Active Artist allowed';exception when insufficient_privilege then null;end;end $deny$;
reset role;
update public.app_memberships set access_status='suspended' where user_id='1204ab25-7433-43a5-80e1-7a66b2eee057';
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $deny$ begin begin perform public.studio_analytics(30);raise exception 'Suspended Owner allowed';exception when insufficient_privilege then null;end;end $deny$;
rollback;
select 'PASS active Artist roster, active Artist denial, suspended Owner denial; membership states restored' result;