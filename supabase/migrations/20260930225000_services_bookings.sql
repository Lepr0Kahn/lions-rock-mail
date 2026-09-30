create table public.studio_services(
 id uuid primary key default gen_random_uuid(),name text not null check(length(btrim(name)) between 1 and 200),
 category text not null default 'studio',description text not null default '',active boolean not null default true,created_at timestamptz not null default now());
create table public.studio_service_variants(
 id uuid primary key default gen_random_uuid(),service_id uuid not null references public.studio_services(id),
 name text not null check(length(btrim(name)) between 1 and 200),duration_minutes integer not null check(duration_minutes between 15 and 720),
 price numeric(12,2) not null check(price>=0),currency text not null default 'BBD' check(currency in ('BBD','USD')),
 deposit_percent integer not null default 50 check(deposit_percent between 0 and 100),created_at timestamptz not null default now());
create index studio_variants_service_idx on public.studio_service_variants(service_id);
create table public.studio_bookings(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
 variant_id uuid not null references public.studio_service_variants(id),project_id uuid references public.artist_projects(id),
 service_name text not null,variant_name text not null,starts_at timestamptz not null,ends_at timestamptz not null check(ends_at>starts_at),
 price numeric(12,2) not null,currency text not null,deposit_percent integer not null,
 status text not null check(status in ('requested','confirmed','cancelled','expired')),
 hold_expires_at timestamptz,notes text not null default '' check(length(notes)<=5000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now());
create index studio_bookings_user_start_idx on public.studio_bookings(user_id,starts_at);
create index studio_bookings_live_idx on public.studio_bookings(starts_at,ends_at) where status in ('requested','confirmed');
alter table public.studio_services enable row level security;
alter table public.studio_service_variants enable row level security;
alter table public.studio_bookings enable row level security;
revoke all on public.studio_services,public.studio_service_variants,public.studio_bookings from anon,authenticated;
grant select on public.studio_services,public.studio_service_variants,public.studio_bookings to authenticated;
grant insert,update on public.studio_services,public.studio_service_variants to authenticated;
create policy studio_services_read on public.studio_services for select to authenticated using((select private.has_active_artist_access()) and (active or (select private.is_studio_owner())));
create policy studio_services_insert on public.studio_services for insert to authenticated with check((select private.has_active_artist_access()) and (select private.is_studio_owner()));
create policy studio_services_update on public.studio_services for update to authenticated using((select private.has_active_artist_access()) and (select private.is_studio_owner())) with check((select private.has_active_artist_access()) and (select private.is_studio_owner()));
create policy studio_variants_read on public.studio_service_variants for select to authenticated using((select private.has_active_artist_access()) and exists(select 1 from public.studio_services s where s.id=service_id));
create policy studio_variants_insert on public.studio_service_variants for insert to authenticated with check((select private.has_active_artist_access()) and (select private.is_studio_owner()));
create policy studio_variants_update on public.studio_service_variants for update to authenticated using((select private.has_active_artist_access()) and (select private.is_studio_owner())) with check((select private.has_active_artist_access()) and (select private.is_studio_owner()));
create policy studio_bookings_read on public.studio_bookings for select to authenticated using((select private.has_active_artist_access()) and (user_id=(select auth.uid()) or (select private.is_studio_owner())));

create function public.studio_availability(booking_date date,offering_id uuid) returns table(starts_at timestamptz,ends_at timestamptz,available boolean)
language plpgsql security definer set search_path='' as $$
declare duration integer;
begin
 if not private.has_active_artist_access() then raise exception 'Artist access required' using errcode='42501';end if;
 select v.duration_minutes into duration from public.studio_service_variants v join public.studio_services s on s.id=v.service_id where v.id=offering_id and s.active;
 if duration is null then raise exception 'Active service not found';end if;
 return query select slot,slot+make_interval(mins=>duration),slot>now() and not exists(
 select 1 from public.studio_bookings b where b.starts_at<slot+make_interval(mins=>duration) and b.ends_at>slot and
 (b.status='confirmed' or (b.status='requested' and b.hold_expires_at>now())))
 from generate_series((booking_date+time '10:00') at time zone 'America/Barbados',(booking_date+time '22:00') at time zone 'America/Barbados'-make_interval(mins=>duration),interval '1 hour') slot;
end;$$;
create function public.create_studio_booking(offering_id uuid,session_start timestamptz,booking_notes text default '',artist_id uuid default null,artist_project uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare target uuid:=coalesce(artist_id,auth.uid()); v public.studio_service_variants%rowtype; s public.studio_services%rowtype; finish timestamptz; bookingid uuid;
begin
 if not private.has_active_artist_access() or (target<>auth.uid() and not private.is_studio_owner()) then raise exception 'Artist booking access required' using errcode='42501';end if;
 if target<>auth.uid() and not exists(select 1 from public.app_memberships m where m.user_id=target and m.access_status='active' and m.artist_member_enabled and m.payment_status in ('paid','comped') and (m.expires_at is null or m.expires_at>now())) then raise exception 'Active artist required';end if;
 if artist_project is not null and not exists(select 1 from public.artist_projects p where p.id=artist_project and p.user_id=target) then raise exception 'Project does not belong to artist' using errcode='42501';end if;
 select * into v from public.studio_service_variants where id=offering_id;
 select * into s from public.studio_services where id=v.service_id;
 if s.id is null or not s.active then raise exception 'Active service not found';end if;
 finish:=session_start+make_interval(mins=>v.duration_minutes);
 if session_start is null or session_start<=now() or (session_start at time zone 'America/Barbados')::time<time '10:00' or (finish at time zone 'America/Barbados')::time>time '22:00'
 or (session_start at time zone 'America/Barbados')::date<>(finish at time zone 'America/Barbados')::date
 or extract(minute from session_start)<>0 or extract(second from session_start)<>0 then raise exception 'Choose a future hourly slot between 10am and 10pm Barbados time';end if;
 perform pg_advisory_xact_lock(hashtextextended('lions-rock-studio-calendar',0));
 update public.studio_bookings set status='expired' where status='requested' and hold_expires_at<=now();
 if exists(select 1 from public.studio_bookings b where b.starts_at<finish and b.ends_at>session_start and b.status in ('requested','confirmed')) then raise exception 'That slot is no longer available';end if;
 insert into public.studio_bookings(user_id,variant_id,project_id,service_name,variant_name,starts_at,ends_at,price,currency,deposit_percent,status,hold_expires_at,notes,created_by)
 values(target,v.id,artist_project,s.name,v.name,session_start,finish,v.price,v.currency,v.deposit_percent,
 case when private.is_studio_owner() then 'confirmed' else 'requested' end,
 case when private.is_studio_owner() then null else least(now()+interval '48 hours',session_start) end,coalesce(booking_notes,''),auth.uid()) returning id into bookingid;
 return bookingid;
end;$$;
create function public.decide_studio_booking(booking_id uuid,decision text) returns void language plpgsql security definer set search_path='' as $$
declare b public.studio_bookings%rowtype;
begin
 if not private.has_active_artist_access() then raise exception 'Artist access required' using errcode='42501';end if;
 if decision not in ('confirmed','cancelled') then raise exception 'Invalid decision';end if;
 perform pg_advisory_xact_lock(hashtextextended('lions-rock-studio-calendar',0));
 select * into b from public.studio_bookings where id=booking_id for update;
 if b.id is null or (b.user_id<>auth.uid() and not private.is_studio_owner()) or (decision='confirmed' and not private.is_studio_owner()) then raise exception 'Booking access denied' using errcode='42501';end if;
 if b.status not in ('requested','confirmed') then raise exception 'Booking is already closed';end if;
 if decision='confirmed' and (b.starts_at<=now() or (b.status='requested' and b.hold_expires_at<=now())) then raise exception 'This hold has expired. Create a new booking';end if;
 update public.studio_bookings set status=decision,hold_expires_at=null where id=b.id;
end;$$;
revoke all on function public.studio_availability(date,uuid),public.create_studio_booking(uuid,timestamptz,text,uuid,uuid),public.decide_studio_booking(uuid,text) from public;
grant execute on function public.studio_availability(date,uuid),public.create_studio_booking(uuid,timestamptz,text,uuid,uuid),public.decide_studio_booking(uuid,text) to authenticated;