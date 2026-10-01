begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
do $test$ declare base jsonb:=public.studio_management_overview();result jsonb;id1 uuid:=gen_random_uuid();id2 uuid:=gen_random_uuid();begin
 insert into public.documents(id,user_id,doc_type,doc_number,status,doc_date,due_date,currency,total,balance_due)
 values(id1,auth.uid(),'invoice','test','open',current_date,(now() at time zone 'America/Barbados')::date-1,'BBD',100,100),
 (id2,auth.uid(),'invoice','test','open',current_date,null,'USD',50,50);
 result:=public.studio_management_overview();
 if (result->>'outstanding_count')::int<>(base->>'outstanding_count')::int+2 then raise exception 'Unpaid count mismatch';end if;
 if (result->>'overdue_count')::int<>(base->>'overdue_count')::int+1 then raise exception 'Overdue count mismatch';end if;
 if not exists(select 1 from jsonb_array_elements(result->'currency_balances') x where x->>'currency'='BBD' and (x->>'balance_due')::numeric>=100) or not exists(select 1 from jsonb_array_elements(result->'currency_balances') x where x->>'currency'='USD' and (x->>'balance_due')::numeric>=50) then raise exception 'Currencies not separated';end if;
 update public.documents set status='void' where id=id1;update public.documents set status='paid' where id=id2;
 result:=public.studio_management_overview();
 if (result->>'outstanding_count')::int<>(base->>'outstanding_count')::int then raise exception 'Paid or void included';end if;
end;$test$;
update public.studio_bookings set status='requested',hold_expires_at=now()+interval '2 hours' where id='9e76ee44-6f2c-4717-b213-44bfa29b9c7d';
update public.studio_bookings set status='confirmed' where id='71c0ff73-8db9-4365-8f00-5e5067c8d9d6';
update public.artist_projects set status='active' where id='96a9335d-12c3-4a58-b122-757c3adc82ac';
update public.artist_project_files set expires_at=now()+interval '1 day' where id='34fb4134-8c1e-4f13-a36d-914535d45dec';
set local role authenticated;
do $test$ declare r jsonb:=public.studio_management_overview();begin
 if not exists(select 1 from jsonb_array_elements(r->'booking_requests') x where x->>'id'='9e76ee44-6f2c-4717-b213-44bfa29b9c7d') then raise exception 'Request missing';end if;
 if not exists(select 1 from jsonb_array_elements(r->'upcoming_sessions') x where x->>'id'='71c0ff73-8db9-4365-8f00-5e5067c8d9d6') then raise exception 'Session missing';end if;
 if not exists(select 1 from jsonb_array_elements(r->'expiring_deliveries') x where x->>'id'='34fb4134-8c1e-4f13-a36d-914535d45dec') then raise exception 'Delivery missing';end if;
end;$test$;
reset role;update public.studio_bookings set hold_expires_at=now()-interval '1 second' where id='9e76ee44-6f2c-4717-b213-44bfa29b9c7d';set local role authenticated;
do $test$ begin if exists(select 1 from jsonb_array_elements(public.studio_management_overview()->'booking_requests') x where x->>'id'='9e76ee44-6f2c-4717-b213-44bfa29b9c7d') then raise exception 'Expired hold shown';end if;end;$test$;
reset role;select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);set local role authenticated;
do $test$ begin begin perform public.studio_management_overview();raise exception 'Business got management data';exception when insufficient_privilege then null;end;end;$test$;
reset role;update public.app_memberships set business_tools_enabled=false,artist_member_enabled=true where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';set local role authenticated;
do $test$ begin begin perform public.studio_management_overview();raise exception 'Artist got management data';exception when insufficient_privilege then null;end;end;$test$;
rollback;select 'PASS: Owner queues, expiry, overdue and currency separation, paid/void exclusion, Business/Artist denial; all fixtures rolled back' result;
