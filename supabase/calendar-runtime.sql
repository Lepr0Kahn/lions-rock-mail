create table private.studio_calendar_tickets (
 id uuid primary key default gen_random_uuid(), actor_id uuid not null, booking_id uuid,
 variant_id uuid not null, starts_at timestamptz not null, ends_at timestamptz not null,
 expires_at timestamptz not null default now()+interval '60 seconds', consumed_at timestamptz
);
create table private.studio_calendar_aliases (
 provider_uid text primary key, booking_id uuid not null references public.studio_bookings(id)
);
create table private.studio_calendar_receipts (
 digest text primary key, processed_at timestamptz not null default now()
);
create table private.studio_calendar_runner_tokens (
 digest text primary key, expires_at timestamptz not null
);
alter table private.studio_calendar_tickets enable row level security;
alter table private.studio_calendar_aliases enable row level security;
alter table private.studio_calendar_receipts enable row level security;
alter table private.studio_calendar_runner_tokens enable row level security;
revoke all on private.studio_calendar_tickets,private.studio_calendar_aliases,private.studio_calendar_receipts,private.studio_calendar_runner_tokens from public,anon,authenticated;
alter function private.studio_calendar_backend(text,jsonb) rename to studio_calendar_backend_queue;
create function private.studio_calendar_backend(command text,payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.studio_bookings%rowtype;m public.app_memberships%rowtype;op private.studio_calendar_operations%rowtype;uid uuid; ticket uuid; row_count int; start_time timestamptz;end_time timestamptz;result jsonb;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Server access required' using errcode='42501';end if;
 if command in ('claim','checkpoint','finish') then
  if command='finish' and coalesce(payload->>'state','') not in ('synced','uncertain','review') then raise exception 'Invalid outcome';end if;
  result:=private.studio_calendar_backend_queue(command,payload);
  if command='finish' and payload->>'state'='synced' then
   select booking_id into uid from private.studio_calendar_operations where id=(payload->>'id')::uuid;
   insert into private.studio_calendar_aliases(provider_uid,booking_id) values(payload->>'providerUid',uid) on conflict do nothing;
  end if;
  return result;
 elsif command='contact' then
  select * into b from public.studio_bookings where id=(payload->>'bookingId')::uuid;
  select * into m from public.app_memberships where user_id=b.user_id;
  if m.user_id is null or m.deleted_at is not null or m.access_status<>'active' or not m.artist_member_enabled or m.payment_status not in ('paid','comped') or m.expires_at<=now() then raise exception 'Artist access is inactive';end if;
  if m.is_minor then
   select jsonb_build_object('name',guardian_name,'email',guardian_email) into result from private.studio_guardian_contacts where artist_id=b.user_id;
  else result:=jsonb_build_object('name',coalesce(nullif(m.business_name,''),'Studio artist'),'email',m.email);end if;
  if result is null or nullif(result->>'email','') is null then raise exception 'Booking contact required';end if;
  return result;
 elsif command='context' then
  select * into b from public.studio_bookings where id=(payload->>'bookingId')::uuid;
  return jsonb_build_object('booking',to_jsonb(b),'enabled',(select enabled from private.studio_calendar_settings where singleton),'link',(select to_jsonb(l) from private.studio_calendar_links l where booking_id=b.id));
 elsif command='ticket' then
  uid:=(payload->>'actorId')::uuid;start_time:=(payload->>'start')::timestamptz;end_time:=(payload->>'end')::timestamptz;
  select * into m from public.app_memberships where user_id=uid;
  if m.user_id is null or m.deleted_at is not null or m.access_status<>'active' or not m.artist_member_enabled or m.payment_status not in ('paid','comped') or m.expires_at<=now() then raise exception 'Active Artist access required';end if;
  perform pg_advisory_xact_lock(hashtextextended('lions-rock-studio-calendar',0));
  if exists(select 1 from public.studio_bookings x where x.id is distinct from nullif(payload->>'bookingId','')::uuid and x.starts_at<end_time and x.ends_at>start_time and (x.status='confirmed' or(x.status='requested' and x.hold_expires_at>now()))) then raise exception 'That slot is no longer available';end if;
  delete from private.studio_calendar_tickets where expires_at<now();
  insert into private.studio_calendar_tickets(actor_id,booking_id,variant_id,starts_at,ends_at) values(uid,nullif(payload->>'bookingId','')::uuid,(payload->>'variantId')::uuid,start_time,end_time) returning id into ticket;
  return jsonb_build_object('ticket',ticket);
 elsif command='external-review' then
 select * into b from public.studio_bookings where id=(payload->>'bookingId')::uuid for update;
 if exists(select 1 from private.studio_calendar_operations where booking_id=b.id and state in ('pending','running','uncertain')) then raise exception 'Calendar operation busy';end if;
 if not exists(select 1 from private.studio_calendar_operations where booking_id=b.id and state='review' and error_code='external_calendar_change_needs_review') then
  insert into private.studio_calendar_operations(booking_id,desired_start,desired_end,desired_status,state,provider_uid,error_code) values(b.id,b.starts_at,b.ends_at,case when b.status='cancelled' then 'cancelled' else 'confirmed' end,'review',payload->>'providerUid','external_calendar_change_needs_review');
 end if;
 insert into private.studio_calendar_receipts(digest) values(payload->>'digest') on conflict do nothing;
 return jsonb_build_object('review',true);
elsif command='recover-review' then
 select * into op from private.studio_calendar_operations where booking_id=(payload->>'bookingId')::uuid and state='review' order by created_at desc limit 1 for update;
 if op.id is null then return '{}'::jsonb;end if;
 if exists(select 1 from private.studio_calendar_operations where booking_id=op.booking_id and state in ('pending','running','uncertain')) then raise exception 'Calendar operation busy';end if;
 update private.studio_calendar_operations set state='running',lease_until=now()+interval '2 minutes',updated_at=now() where id=op.id returning * into op;
 select * into b from public.studio_bookings where id=op.booking_id;
 return jsonb_build_object('operation',to_jsonb(op),'booking',to_jsonb(b),'link',(select to_jsonb(l) from private.studio_calendar_links l where booking_id=b.id));
elsif command='recover-claim' then
  if not (select enabled from private.studio_calendar_settings where singleton) then return '{}'::jsonb;end if;
  update private.studio_calendar_operations set state='uncertain',lease_until=null,error_code='worker_lease_expired',updated_at=now() where state='running' and lease_until<now();
  select * into op from private.studio_calendar_operations where state='uncertain' order by created_at for update skip locked limit 1;
  if op.id is null then return '{}'::jsonb;end if;
  update private.studio_calendar_operations set state='running',lease_until=now()+interval '2 minutes',updated_at=now() where id=op.id returning * into op;
  select * into b from public.studio_bookings where id=op.booking_id;
  return jsonb_build_object('operation',to_jsonb(op),'booking',to_jsonb(b),'link',(select to_jsonb(l) from private.studio_calendar_links l where booking_id=b.id));
 elsif command='lookup' then
  select booking_id into uid from private.studio_calendar_aliases where provider_uid=payload->>'providerUid';
  if uid is null then select booking_id into uid from private.studio_calendar_links where provider_uid=payload->>'providerUid';end if;
  if uid is null then select booking_id into uid from private.studio_calendar_operations where provider_uid=payload->>'providerUid' order by created_at desc limit 1;end if;
  return jsonb_build_object('bookingId',uid,'seen',exists(select 1 from private.studio_calendar_receipts where digest=payload->>'digest'));
 elsif command='reconcile' then
  perform pg_advisory_xact_lock(hashtextextended('lions-rock-studio-calendar',0));
  select * into b from public.studio_bookings where id=(payload->>'bookingId')::uuid for update;
  if b.id is null then raise exception 'Booking missing';end if;
  if exists(select 1 from private.studio_calendar_operations where booking_id=b.id and state in ('pending','running','uncertain')) then raise exception 'Calendar operation busy';end if;
  start_time:=(payload->>'start')::timestamptz;end_time:=(payload->>'end')::timestamptz;
  if payload->>'status'='accepted' then
   if b.status<>'confirmed' or start_time<=now() or end_time<=start_time or end_time-start_time>interval '12 hours' or (start_time at time zone 'America/Barbados')::time<time '10:00' or (end_time at time zone 'America/Barbados')::time>time '22:00' or (start_time at time zone 'America/Barbados')::date<>(end_time at time zone 'America/Barbados')::date or extract(minute from start_time)<>0 or extract(second from start_time)<>0 then raise exception 'Calendar change needs Owner review';end if;
   if exists(select 1 from public.studio_bookings x where x.id<>b.id and x.starts_at<end_time and x.ends_at>start_time and (x.status='confirmed' or(x.status='requested' and x.hold_expires_at>now()))) then raise exception 'Calendar change conflicts with an OS session';end if;
   perform set_config('studio.calendar_reconcile','on',true);
   update public.studio_bookings set starts_at=start_time,ends_at=end_time where id=b.id and (starts_at is distinct from start_time or ends_at is distinct from end_time);
  elsif payload->>'status'='cancelled' then
   perform set_config('studio.calendar_reconcile','on',true);
   update public.studio_bookings set status='cancelled',hold_expires_at=null where id=b.id and status in ('requested','confirmed');
  else raise exception 'Provider state needs review';end if;
  update private.studio_calendar_operations set state='superseded',updated_at=now() where booking_id=b.id and state='pending';
  update private.studio_calendar_links set provider_uid=payload->>'providerUid',synchronized_start=start_time,synchronized_end=end_time,synchronized_status=case when payload->>'status'='accepted' then 'confirmed' else 'cancelled' end,updated_at=now() where booking_id=b.id;
  insert into private.studio_calendar_aliases(provider_uid,booking_id) values(payload->>'providerUid',b.id) on conflict do nothing;
  insert into private.studio_calendar_receipts(digest) values(payload->>'digest') on conflict do nothing;
  return jsonb_build_object('ok',true);
 elsif command='configure' then
  update private.studio_calendar_settings set enabled=case when (payload->>'enabled')::boolean then true else enabled end,paused=not coalesce((payload->>'enabled')::boolean,false),updated_at=now() where singleton;
  return jsonb_build_object('ok',true);
 elsif command='runner' then
  delete from private.studio_calendar_runner_tokens where digest=payload->>'digest' and expires_at>now();
  get diagnostics row_count=row_count;return jsonb_build_object('allowed',row_count=1);
 else return private.studio_calendar_backend_queue(command,payload);end if;
end;$$;
revoke all on function private.studio_calendar_backend(text,jsonb) from public,anon,authenticated;
grant execute on function private.studio_calendar_backend(text,jsonb) to service_role;

create function private.guard_studio_calendar_ticket() returns trigger language plpgsql security definer set search_path='' as $$
declare tid uuid;valid uuid;
begin
 if not (select enabled from private.studio_calendar_settings where singleton) then return new;end if;
 if auth.jwt()->>'role'='service_role' and current_setting('studio.calendar_reconcile',true)='on' then return new;end if;
 if tg_op='UPDATE' then
  if new.status='cancelled' or (new.starts_at=old.starts_at and new.ends_at=old.ends_at and (new.status=old.status or new.status<>'confirmed')) then return new;end if;
 end if;
 if new.status not in ('requested','confirmed') then return new;end if;
 tid:=nullif(current_setting('studio.calendar_ticket',true),'')::uuid;
 update private.studio_calendar_tickets set consumed_at=now() where id=tid and actor_id=auth.uid() and variant_id=new.variant_id and starts_at=new.starts_at and ends_at=new.ends_at and expires_at>now() and consumed_at is null and (booking_id is null or booking_id=new.id) returning id into valid;
 if valid is null then raise exception 'Check calendar availability again before saving the session';end if;
 return new;
end;$$;
revoke all on function private.guard_studio_calendar_ticket() from public,anon,authenticated;
create trigger studio_calendar_availability_guard before insert or update on public.studio_bookings for each row execute function private.guard_studio_calendar_ticket();
create function public.create_calendar_studio_booking(ticket uuid,offering_id uuid,session_start timestamptz,booking_notes text default '',artist_id uuid default null,artist_project uuid default null) returns uuid language plpgsql security invoker set search_path='' as $$ begin perform set_config('studio.calendar_ticket',ticket::text,true);return public.create_studio_booking(offering_id,session_start,booking_notes,artist_id,artist_project);end;$$;
create function public.decide_calendar_studio_booking(ticket uuid,booking_id uuid,decision text) returns void language plpgsql security invoker set search_path='' as $$ begin perform set_config('studio.calendar_ticket',ticket::text,true);perform public.decide_studio_booking(booking_id,decision);end;$$;
create function public.reschedule_calendar_studio_booking(ticket uuid,booking_id uuid,new_start timestamptz,new_minutes int) returns uuid language plpgsql security invoker set search_path='' as $$ begin perform set_config('studio.calendar_ticket',ticket::text,true);return public.reschedule_studio_booking(booking_id,new_start,new_minutes);end;$$;
revoke all on function public.create_calendar_studio_booking(uuid,uuid,timestamptz,text,uuid,uuid),public.decide_calendar_studio_booking(uuid,uuid,text),public.reschedule_calendar_studio_booking(uuid,uuid,timestamptz,int) from public,anon;
grant execute on function public.create_calendar_studio_booking(uuid,uuid,timestamptz,text,uuid,uuid),public.decide_calendar_studio_booking(uuid,uuid,text),public.reschedule_calendar_studio_booking(uuid,uuid,timestamptz,int) to authenticated;
