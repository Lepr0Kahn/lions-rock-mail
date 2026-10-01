create function public.reschedule_studio_booking(booking_id uuid,new_start timestamptz,new_minutes integer) returns uuid language plpgsql security definer set search_path='' as $$
declare b public.studio_bookings%rowtype;finish timestamptz;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_artist_access() or not private.has_active_studio_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
perform pg_advisory_xact_lock(hashtextextended('lions-rock-studio-calendar',0));
select * into b from public.studio_bookings where id=booking_id for update;
if b.id is null or b.status not in ('requested','confirmed') or b.starts_at<=now() or (b.status='requested' and b.hold_expires_at<=now()) then raise exception 'Choose an upcoming active booking';end if;
if new_minutes is null or new_minutes<15 or new_minutes>720 then raise exception 'Duration must be 15 to 720 minutes';end if;
finish:=new_start+make_interval(mins=>new_minutes);
if new_start is null or new_start<=now() or (new_start at time zone 'America/Barbados')::time<time '10:00' or (finish at time zone 'America/Barbados')::time>time '22:00' or (new_start at time zone 'America/Barbados')::date<>(finish at time zone 'America/Barbados')::date or extract(minute from new_start)<>0 or extract(second from new_start)<>0 then raise exception 'Choose a future hourly start between 10am and 10pm Barbados time';end if;
if exists(select 1 from public.studio_bookings x where x.id<>booking_id and x.starts_at<finish and x.ends_at>new_start and (x.status='confirmed' or(x.status='requested' and x.hold_expires_at>now()))) then raise exception 'That slot is no longer available';end if;
update public.studio_bookings set starts_at=new_start,ends_at=finish,hold_expires_at=case when b.status='requested' then least(b.hold_expires_at,new_start) else null end where id=booking_id;
return booking_id;
end;$$;
revoke all on function public.reschedule_studio_booking(uuid,timestamptz,integer) from public,anon;
grant execute on function public.reschedule_studio_booking(uuid,timestamptz,integer) to authenticated;