-- Calendar synchronization is disabled until the Owner explicitly activates it.
grant usage on schema private to service_role;
create table private.studio_calendar_settings (
 singleton boolean primary key default true check(singleton), enabled boolean not null default false,
 updated_at timestamptz not null default now()
);
insert into private.studio_calendar_settings(singleton) values(true);
create table private.studio_calendar_links (
 booking_id uuid primary key references public.studio_bookings(id),
 provider_uid text unique, event_type_id bigint, synchronized_start timestamptz,
 synchronized_end timestamptz, synchronized_status text,
 updated_at timestamptz not null default now()
);
create table private.studio_calendar_operations (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null references public.studio_bookings(id),
 desired_start timestamptz not null, desired_end timestamptz not null,
 desired_status text not null check(desired_status in ('confirmed','cancelled')),
 state text not null default 'pending' check(state in ('pending','running','uncertain','synced','review','superseded')),
 phase text not null default 'ready', provider_uid text,
 lease_until timestamptz, attempts integer not null default 0,
 error_code text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index studio_calendar_operations_pending on private.studio_calendar_operations(created_at) where state in ('pending','running','uncertain');
create unique index studio_calendar_operations_active on private.studio_calendar_operations(booking_id) where state in ('pending','running','uncertain');
alter table private.studio_calendar_settings enable row level security;
alter table private.studio_calendar_links enable row level security;
alter table private.studio_calendar_operations enable row level security;
revoke all on private.studio_calendar_settings,private.studio_calendar_links,private.studio_calendar_operations from public,anon,authenticated;

create function private.capture_studio_calendar_operation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not (select enabled from private.studio_calendar_settings where singleton) then return new;end if;
 if auth.jwt()->>'role'='service_role' and current_setting('studio.calendar_reconcile',true)='on' then return new;end if;
 if tg_op='UPDATE' and new.starts_at=old.starts_at and new.ends_at=old.ends_at and new.status=old.status then return new;end if;
 if exists(select 1 from private.studio_calendar_operations where booking_id=new.id and (state in ('running','uncertain') or(state='review' and phase<>'ready'))) then
  raise exception 'Calendar synchronization is being reconciled. Try again after it finishes.';
 end if;
 update private.studio_calendar_operations set state='superseded',updated_at=now() where booking_id=new.id and state='pending';
 if new.status='confirmed' or (new.status='cancelled' and exists(select 1 from private.studio_calendar_links where booking_id=new.id and provider_uid is not null)) then
  insert into private.studio_calendar_operations(booking_id,desired_start,desired_end,desired_status)
  values(new.id,new.starts_at,new.ends_at,new.status);
 end if;
 return new;
end;$$;
revoke all on function private.capture_studio_calendar_operation() from public,anon,authenticated;
create trigger studio_calendar_outbox after insert or update on public.studio_bookings for each row execute function private.capture_studio_calendar_operation();

create function private.studio_calendar_backend(command text,payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare op private.studio_calendar_operations%rowtype; b public.studio_bookings%rowtype; answer jsonb;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Server access required' using errcode='42501';end if;
 if command='claim' then
  if not (select enabled from private.studio_calendar_settings where singleton) then return jsonb_build_object('enabled',false);end if;
  update private.studio_calendar_operations set state='uncertain',lease_until=null,error_code='worker_lease_expired',updated_at=now() where state='running' and lease_until<now();
  select * into op from private.studio_calendar_operations where state='pending' order by created_at for update skip locked limit 1;
  if op.id is null then return '{}'::jsonb;end if;
  update private.studio_calendar_operations set state='running',lease_until=now()+interval '2 minutes',attempts=attempts+1,updated_at=now() where id=op.id returning * into op;
  select * into b from public.studio_bookings where id=op.booking_id;
  return jsonb_build_object('operation',to_jsonb(op),'booking',to_jsonb(b),'link',(select to_jsonb(l) from private.studio_calendar_links l where booking_id=b.id));
 elsif command='checkpoint' then
  select * into op from private.studio_calendar_operations where id=(payload->>'id')::uuid for update;
  if op.id is null or op.state<>'running' or op.lease_until<now() then raise exception 'Operation lease is no longer active';end if;
  update private.studio_calendar_operations set phase=coalesce(payload->>'phase',phase),provider_uid=coalesce(payload->>'providerUid',provider_uid),updated_at=now() where id=op.id;
  return jsonb_build_object('ok',true);
 elsif command='finish' then
  select * into op from private.studio_calendar_operations where id=(payload->>'id')::uuid for update;
  if op.id is null or op.state<>'running' or op.lease_until<now() then raise exception 'Operation lease is no longer active';end if;
  if payload->>'state' not in ('synced','uncertain','review') then raise exception 'Invalid operation outcome';end if;
  if payload->>'state'='synced' then
   if nullif(payload->>'providerUid','') is null then raise exception 'Verified provider booking required';end if;
   insert into private.studio_calendar_links(booking_id,provider_uid,event_type_id,synchronized_start,synchronized_end,synchronized_status)
   values(op.booking_id,payload->>'providerUid',(payload->>'eventTypeId')::bigint,op.desired_start,op.desired_end,op.desired_status)
   on conflict(booking_id) do update set provider_uid=excluded.provider_uid,event_type_id=excluded.event_type_id,synchronized_start=excluded.synchronized_start,synchronized_end=excluded.synchronized_end,synchronized_status=excluded.synchronized_status,updated_at=now();
  end if;
  update private.studio_calendar_operations set state=payload->>'state',error_code=left(payload->>'errorCode',80),lease_until=null,updated_at=now() where id=op.id;
  return jsonb_build_object('ok',true);
 else raise exception 'Unknown server command';end if;
end;$$;
revoke all on function private.studio_calendar_backend(text,jsonb) from public,anon,authenticated;
grant execute on function private.studio_calendar_backend(text,jsonb) to service_role;
create function public.studio_calendar_backend(command text,payload jsonb default '{}'::jsonb) returns jsonb language sql security invoker set search_path='' as $$ select private.studio_calendar_backend(command,payload);$$;
revoke all on function public.studio_calendar_backend(text,jsonb) from public,anon,authenticated;
grant execute on function public.studio_calendar_backend(text,jsonb) to service_role;

create function private.studio_calendar_status() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active workspace access required' using errcode='42501';end if;
 return jsonb_build_object('enabled',(select enabled from private.studio_calendar_settings where singleton),'bookings',coalesce((select jsonb_agg(jsonb_build_object('bookingId',b.id,'state',o.state,'updatedAt',o.updated_at)) from public.studio_bookings b join lateral (select state,updated_at from private.studio_calendar_operations where booking_id=b.id order by created_at desc,id desc limit 1) o on true where b.user_id=auth.uid() or private.is_studio_owner()),'[]'::jsonb));
end;$$;
revoke all on function private.studio_calendar_status() from public,anon;
grant execute on function private.studio_calendar_status() to authenticated;
create function public.studio_calendar_status() returns jsonb language sql security invoker set search_path='' as $$ select private.studio_calendar_status();$$;
revoke all on function public.studio_calendar_status() from public,anon;
grant execute on function public.studio_calendar_status() to authenticated;
