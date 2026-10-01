create table public.studio_notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 event_id uuid not null,
 title text not null,
 body text not null,
 action_kind text not null check(action_kind in ('bookings','project')),
 project_id uuid references public.artist_projects(id) on delete cascade,
 created_at timestamptz not null default now(),
 read_at timestamptz,
 unique(user_id,event_id)
);
create index studio_notifications_user_created on public.studio_notifications(user_id,created_at desc);
alter table public.studio_notifications enable row level security;
revoke all on public.studio_notifications from public,anon,authenticated;
grant select on public.studio_notifications to authenticated;
grant update(read_at) on public.studio_notifications to authenticated;
create policy notifications_own_read on public.studio_notifications for select to authenticated
 using(user_id=(select auth.uid()) and (select private.has_active_artist_access()));
create policy notifications_own_seen on public.studio_notifications for update to authenticated
 using(user_id=(select auth.uid()) and (select private.has_active_artist_access()))
 with check(user_id=(select auth.uid()) and (select private.has_active_artist_access()));
create function private.capture_studio_notification() returns trigger
language plpgsql security definer set search_path='' as $$
declare event uuid:=gen_random_uuid(); heading text; detail text; destination text; project uuid; recipient uuid;
begin
 if tg_table_name='studio_bookings' then
  if tg_op='UPDATE' then
   if new.status is not distinct from old.status and new.starts_at is not distinct from old.starts_at and new.ends_at is not distinct from old.ends_at then return new;end if;
  end if;
  destination:='bookings';recipient:=new.user_id;
  heading:=case new.status when 'requested' then 'Session request received' when 'confirmed' then 'Session confirmed' when 'cancelled' then 'Session cancelled' when 'rejected' then 'Session request declined' else 'Session updated' end;
  if tg_op='UPDATE' and new.status=old.status and new.status='confirmed' then heading:='Session time changed';end if;
  detail:=new.service_name||' · '||to_char(new.starts_at at time zone 'America/Barbados','DD Mon YYYY HH24:MI')||' Barbados time. '||
   case new.status when 'requested' then 'Awaiting studio approval. Open bookings for the current status.' when 'confirmed' then 'Open bookings to review your session.' else 'Open bookings for the current status.' end;
 elsif tg_table_name='artist_project_files' then
  if new.kind not in ('master','mp3_delivery') then return new;end if;
  if tg_op='UPDATE' then
   if new.expires_at is not distinct from old.expires_at then return new;end if;
   if new.expires_at is null or new.expires_at<=now() then return new;end if;
  end if;
  destination:='project';project:=new.project_id;recipient:=new.user_id;
  heading:=case when tg_op='INSERT' then 'Studio delivery available' else 'Studio delivery reissued' end;
  detail:=new.filename||'. Open your project to review and download the delivery.';
 else return new;
 end if;
 insert into public.studio_notifications(user_id,event_id,title,body,action_kind,project_id)
 select m.user_id,event,heading,detail,destination,project from public.app_memberships m
 where m.user_id=recipient or m.role='owner'
 on conflict(user_id,event_id) do nothing;
 return new;
end;$$;
revoke all on function private.capture_studio_notification() from public,anon,authenticated;
create trigger studio_booking_notifications after insert or update on public.studio_bookings
for each row execute function private.capture_studio_notification();
create trigger studio_delivery_notifications after insert or update on public.artist_project_files
for each row execute function private.capture_studio_notification();
