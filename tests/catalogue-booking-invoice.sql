begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);set local role authenticated;
do $$ declare sid uuid;vid uuid;begin
select s.id into sid from public.studio_services s join public.services i on i.id=s.invoice_service_id where i.user_id=auth.uid() and i.name='Record a Song';
vid:=public.add_studio_service_offering(sid,'Rollback booking verification',60,100,'BBD',25);
update public.studio_services set active=true where id=sid;
perform set_config('test.offering',vid::text,true);
perform set_config('test.before_number',public.reserve_document_number(gen_random_uuid(),'invoice'),true);
end;$$;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
do $$ declare bid uuid;t timestamptz;begin
t:=(((now() at time zone 'America/Barbados')::date+10)+time '10:00') at time zone 'America/Barbados';
bid:=public.create_studio_booking(current_setting('test.offering')::uuid,t,'Rollback test only');
perform set_config('test.booking',bid::text,true);
if (select status from public.studio_bookings where id=bid)<>'requested' then raise exception 'Artist request not pending';end if;
begin perform public.create_studio_booking(current_setting('test.offering')::uuid,t,'Overlap test');raise exception 'Overlap accepted';exception when raise_exception then if sqlerrm='Overlap accepted' then raise;end if;end;
end;$$;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
do $$ declare r jsonb;r2 jsonb;nextnum text;begin
perform public.decide_studio_booking(current_setting('test.booking')::uuid,'confirmed');
r:=public.invoice_for_studio_booking(current_setting('test.booking')::uuid);
r2:=public.invoice_for_studio_booking(current_setting('test.booking')::uuid);
if r#>>'{document,id}'<>r2#>>'{document,id}' then raise exception 'Duplicate invoice';end if;
if (r#>>'{document,total}')::numeric<>100 or r#>>'{document,currency}'<>'BBD' or (r#>>'{document,deposit_pct}')::numeric<>25 then raise exception 'Invoice snapshot mismatch';end if;
if (substring(r#>>'{document,doc_number}' from '[0-9]+$'))::bigint<>(substring(current_setting('test.before_number') from '[0-9]+$'))::bigint+1 then raise exception 'Booking number sequence failed';end if;
nextnum:=public.reserve_document_number(gen_random_uuid(),'invoice');
if (substring(nextnum from '[0-9]+$'))::bigint<>(substring(r#>>'{document,doc_number}' from '[0-9]+$'))::bigint+1 then raise exception 'Generator number sequence failed';end if;
perform public.decide_studio_booking(current_setting('test.booking')::uuid,'cancelled');
end;$$;
rollback;