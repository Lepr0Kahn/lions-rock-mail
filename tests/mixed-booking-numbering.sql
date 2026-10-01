begin;
update public.studio_bookings set status='confirmed' where id='9e76ee44-6f2c-4717-b213-44bfa29b9c7d' and status='cancelled';
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);set local role authenticated;
do $test$ declare a uuid:=gen_random_uuid();z uuid:=gen_random_uuid();n1 text;n2 text;n3 text;r jsonb;r2 jsonb; bid uuid:='9e76ee44-6f2c-4717-b213-44bfa29b9c7d';begin
if not exists(select 1 from public.studio_bookings where id=bid) then raise exception 'Disposable fixture missing';end if;
if exists(select 1 from public.documents where booking_id=bid) then raise exception 'Fixture already invoiced; test stopped';end if;
insert into public.documents(id,user_id,doc_type,doc_number,status,doc_date) values(a,auth.uid(),'invoice','INV-9999','open',current_date) returning doc_number into n1;
r:=public.invoice_for_studio_booking(bid);n2:=r->'document'->>'doc_number';
if substring(n2 from '[0-9]+$')::bigint<>substring(n1 from '[0-9]+$')::bigint+1 then raise exception 'Booking sequence out of order';end if;
r2:=public.invoice_for_studio_booking(bid);
if r2->'document'->>'id'<>r->'document'->>'id' or r2->'document'->>'doc_number'<>n2 then raise exception 'Booking reopen changed invoice';end if;
insert into public.documents(id,user_id,doc_type,doc_number,status,doc_date) values(z,auth.uid(),'invoice','INV-9999','open',current_date) returning doc_number into n3;
if substring(n3 from '[0-9]+$')::bigint<>substring(n2 from '[0-9]+$')::bigint+1 then raise exception 'Generator follow-up sequence out of order';end if;
end;$test$;
rollback;