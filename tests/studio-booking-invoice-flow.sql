-- Regression checks use transaction rollback: no bookings, invoices, payments or access changes persist.
begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $test$
declare mix uuid;instrumental uuid;b1 uuid;b2 uuid;d1 uuid:=gen_random_uuid();d2 uuid;d3 uuid:=gen_random_uuid();n1 text;n2 text;n3 text;r jsonb;r2 jsonb;rejected boolean:=false;booked public.studio_bookings%rowtype;starttime timestamptz:='2030-01-08 10:00:00-04';
begin
select v.id into mix from public.studio_service_variants v join public.studio_services s on s.id=v.service_id where s.active and s.name='Full Mix' and v.duration_minutes=120 and v.deposit_percent=50 limit 1;
select v.id into instrumental from public.studio_service_variants v join public.studio_services s on s.id=v.service_id where s.active and s.name='Create Instrumental' and v.duration_minutes=180 and v.deposit_percent=50 limit 1;
if mix is null or instrumental is null then raise exception 'Duration/deposit setup mismatch';end if;
b1:=public.create_studio_booking(mix,starttime,'Disposable booking regression test');
select * into booked from public.studio_bookings where id=b1;
if booked.ends_at-booked.starts_at<>interval '2 hours' or booked.price<>350 or booked.deposit_percent<>50 or booked.status<>'confirmed' then raise exception 'Full Mix snapshot mismatch';end if;
begin perform public.create_studio_booking(instrumental,starttime+interval '1 hour','Disposable overlap');exception when others then if sqlerrm<>'That slot is no longer available' then raise;end if;rejected:=true;end;
if not rejected then raise exception 'Overlap accepted';end if;
b2:=public.create_studio_booking(instrumental,starttime+interval '2 hours','Disposable adjacent booking');
select * into booked from public.studio_bookings where id=b2;
if booked.ends_at-booked.starts_at<>interval '3 hours' or booked.price<>500 or booked.price*booked.deposit_percent/100<>250 then raise exception 'Instrumental/deposit mismatch';end if;
n1:=public.reserve_document_number(d1,'invoice');
insert into public.documents(id,user_id,doc_type,status,doc_number,doc_date,currency) values(d1,auth.uid(),'invoice','draft',n1,current_date,'BBD');
r:=public.invoice_for_studio_booking(b1);r2:=public.invoice_for_studio_booking(b1);
d2:=(r->'document'->>'id')::uuid;n2:=r->'document'->>'doc_number';
if d2 is distinct from (r2->'document'->>'id')::uuid then raise exception 'Duplicate booking invoice';end if;
if (r->'document'->>'total')::numeric<>350 or (r->'document'->>'deposit_pct')::numeric<>50 or jsonb_array_length(r->'document'->'items')<>1 then raise exception 'Booking invoice amount/deposit mismatch';end if;
n3:=public.reserve_document_number(d3,'invoice');
if substring(n2 from '([0-9]+)$')::bigint<>substring(n1 from '([0-9]+)$')::bigint+1 or substring(n3 from '([0-9]+)$')::bigint<>substring(n2 from '([0-9]+)$')::bigint+1 then raise exception 'Generator/booking/generator numbering mismatch: %, %, %',n1,n2,n3;end if;
perform public.reschedule_studio_booking(b1,starttime+interval '6 hours',90);
select * into booked from public.studio_bookings where id=b1;
if booked.starts_at<>starttime+interval '6 hours' or booked.ends_at-booked.starts_at<>interval '90 minutes' or booked.price<>350 or booked.deposit_percent<>50 then raise exception 'Reschedule snapshot mismatch';end if;
rejected:=false;
begin perform public.reschedule_studio_booking(b1,starttime+interval '3 hours',90);exception when others then if sqlerrm<>'That slot is no longer available' then raise;end if;rejected:=true;end;
if not rejected then raise exception 'Reschedule overlap accepted';end if;
if (select total from public.documents where id=d2)<>350 then raise exception 'Reschedule changed invoice';end if;
raise notice 'PASS durations, 50%% deposits, adjacent/overlap checks, invoice reuse, shared numbering, time/duration edits and price preservation';
end $test$;
rollback;
begin;
-- Temporary eligibility for the existing test account; rollback restores its current access.
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
select set_config('test.booking_id',public.create_studio_booking('196c7505-e8e8-4638-b0bb-83b6b2adf4c6','2030-01-09 10:00:00-04','Disposable requested booking')::text,true);
do $t$ begin
if not exists(select 1 from public.studio_bookings where id=current_setting('test.booking_id')::uuid and status='requested' and hold_expires_at>now() and hold_expires_at<=now()+interval '48 hours') then raise exception 'Artist request/hold mismatch';end if;
begin perform public.invoice_for_studio_booking(current_setting('test.booking_id')::uuid);raise exception 'Artist invoice permitted';exception when insufficient_privilege then null;end;
end $t$;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
do $t$ declare rejected boolean:=false;r jsonb;begin
begin perform public.invoice_for_studio_booking(current_setting('test.booking_id')::uuid);exception when others then if sqlerrm<>'Confirm the booking before creating its invoice' then raise;end if;rejected:=true;end;
if not rejected then raise exception 'Requested booking invoice accepted';end if;
perform public.decide_studio_booking(current_setting('test.booking_id')::uuid,'confirmed');
r:=public.invoice_for_studio_booking(current_setting('test.booking_id')::uuid);
if r->'document'->>'booking_id'<>current_setting('test.booking_id') then raise exception 'Confirmed booking invoice link mismatch';end if;
end $t$;
rollback;