-- Communication-loop hardening: rewards + booking payment notifications.
-- Applied to production Supabase on 2 October 2026.

alter table public.studio_notifications
  drop constraint if exists studio_notifications_action_kind_check;
alter table public.studio_notifications
  add constraint studio_notifications_action_kind_check
  check(action_kind in('bookings','project','vault','payments','rewards'));

create or replace function private.capture_reward_notification() returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  event uuid;
  seed text;
  h text;
  heading text;
  detail text;
begin
  if tg_op='UPDATE'
     and new.status is not distinct from old.status
     and new.scheduled_at is not distinct from old.scheduled_at
     and new.duration_minutes is not distinct from old.duration_minutes
     and new.location is not distinct from old.location
  then
    return new;
  end if;

  seed:=new.id::text||'|'||new.status||'|'||
        coalesce(new.scheduled_at::text,'')||'|'||
        coalesce(new.duration_minutes::text,'')||'|'||
        coalesce(new.location,'')||'|'||
        new.updated_at::text;
  h:=md5(seed);
  event:=(substr(h,1,8)||'-'||substr(h,9,4)||'-'||substr(h,13,4)||'-'||substr(h,17,4)||'-'||substr(h,21,12))::uuid;

  heading:=case
    when new.status='requested' then 'Artist reward requested'
    when new.status='approved' and new.scheduled_at is not null then 'Artist reward scheduled'
    when new.status='approved' then 'Artist reward approved'
    when new.status='fulfilled' then 'Artist reward fulfilled'
    when new.status='denied' then 'Artist reward declined'
    when new.status='cancelled' then 'Artist reward cancelled'
    else 'Artist reward updated'
  end;

  detail:=new.title_snapshot||
    case
      when new.status='approved' and new.scheduled_at is not null
        then ' · '||to_char(new.scheduled_at at time zone 'America/Barbados','DD Mon YYYY HH24:MI')||' Barbados time.'
      when new.status='approved' then '. The studio will arrange scheduling.'
      when new.status='fulfilled' then '. The studio recorded this reward as fulfilled.'
      when new.status='denied' then '. Open Rewards for the current status.'
      when new.status='cancelled' then '. Open Rewards for the cancellation details.'
      else '. Open Rewards for the current status.'
    end;

  insert into public.studio_notifications(user_id,event_id,title,body,action_kind)
  select m.user_id,event,heading,detail,'rewards'
  from public.app_memberships m
  where m.user_id=new.artist_id or m.role='owner'
  on conflict(user_id,event_id) do nothing;

  return new;
end;
$$;

revoke all on function private.capture_reward_notification() from public,anon,authenticated;

drop trigger if exists studio_reward_notifications on private.studio_reward_claims;
create trigger studio_reward_notifications
after insert or update on private.studio_reward_claims
for each row execute function private.capture_reward_notification();

create or replace function private.capture_vault_payment_notification() returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  event uuid:=gen_random_uuid();
  heading text;
  detail text;
  recipient uuid;
  owner_id uuid;
  destination text;
begin
  if tg_table_name='studio_instrumental_requests' then
    if tg_op='UPDATE' and new.status is not distinct from old.status then return new; end if;
    recipient:=new.user_id;
    destination:='vault';
    heading:=case new.status
      when 'requested' then 'Instrumental lease requested'
      when 'approved' then 'Instrumental lease approved'
      when 'released' then 'Instrumental master released'
      when 'denied' then 'Instrumental lease declined'
      else 'Instrumental lease updated'
    end;
    detail:=new.title_snapshot||'. Open the vault for current terms, payment and download status.';

    insert into public.studio_notifications(user_id,event_id,title,body,action_kind)
    select m.user_id,event,heading,detail,destination
    from public.app_memberships m
    where m.user_id=recipient or m.role='owner'
    on conflict(user_id,event_id) do nothing;

  elsif tg_table_name='payments' then
    if new.kind='opening' then return new; end if;
    event:=new.id;
    owner_id:=new.user_id;
    heading:=case new.kind
      when 'payment' then 'Invoice payment recorded'
      when 'refund' then 'Invoice refund recorded'
      else 'Invoice payment corrected'
    end;

    select d.doc_number||' · '||d.currency||' '||abs(new.amount)::text||'. Recorded entry; open for current status.'
      into detail
    from public.documents d
    where d.id=new.document_id and d.user_id=owner_id;
    if detail is null then return new; end if;

    insert into public.studio_notifications(user_id,event_id,title,body,action_kind)
    values(owner_id,event,heading,detail,'payments')
    on conflict(user_id,event_id) do nothing;

    insert into public.studio_notifications(user_id,event_id,title,body,action_kind)
    select distinct r.user_id,event,heading,detail,'vault'
    from public.studio_instrumental_requests r
    where r.invoice_id=new.document_id and r.user_id<>owner_id
    on conflict(user_id,event_id) do nothing;

    insert into public.studio_notifications(user_id,event_id,title,body,action_kind)
    select distinct b.user_id,event,heading,detail,'bookings'
    from public.documents d
    join public.studio_bookings b on b.id=d.booking_id
    where d.id=new.document_id
      and d.user_id=owner_id
      and b.user_id<>owner_id
    on conflict(user_id,event_id) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function private.capture_vault_payment_notification() from public,anon,authenticated;
