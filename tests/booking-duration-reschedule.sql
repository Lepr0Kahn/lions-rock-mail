begin;select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);set local role authenticated;
do $$ declare vid uuid;bid uuid;other uuid;t timestamptz;begin
if (select count(*) from public.studio_services s join public.studio_service_variants v on v.service_id=s.id where s.invoice_service_id is not null and s.active and v.duration_minutes=case s.name when 'Full Mix' then 120 when 'Create Instrumental' then 180 else 60 end and v.deposit_percent=50)<>8 then raise exception 'Default offering mismatch';end if;
select v.id into vid from public.studio_service_variants v join public.studio_services s on s.id=v.service_id where s.invoice_service_id is not null limit 1;
t:=(((now() at time zone 'America/Barbados')::date+12)+time '10:00') at time zone 'America/Barbados';
bid:=public.create_studio_booking(vid,t,'Rollback reschedule verification');
other:=public.create_studio_booking(vid,t+interval '4 hours','Rollback conflict');
perform public.reschedule_studio_booking(bid,t+interval '1 hour',90);
if not exists(select 1 from public.studio_bookings where id=bid and starts_at=t+interval '1 hour' and ends_at=t+interval '150 minutes' and deposit_percent=50) then raise exception 'Reschedule mismatch';end if;
begin perform public.reschedule_studio_booking(bid,t+interval '3 hours',120);raise exception 'Overlap accepted';exception when raise_exception then if sqlerrm='Overlap accepted' then raise;end if;end;
begin perform public.reschedule_studio_booking(bid,t,0);raise exception 'Invalid duration accepted';exception when raise_exception then if sqlerrm='Invalid duration accepted' then raise;end if;end;
perform set_config('test.booking',bid::text,true);
update public.studio_service_variants set duration_minutes=120 where id=vid;
if not exists(select 1 from public.studio_bookings where id=bid and ends_at-starts_at=interval '90 minutes') then raise exception 'Offering edit changed booking';end if;
end;$$;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
do $$ begin begin perform public.reschedule_studio_booking(current_setting('test.booking')::uuid,now()+interval '12 days',60);raise exception 'NonOwner reschedule allowed';exception when insufficient_privilege then null;end;end;$$;rollback;