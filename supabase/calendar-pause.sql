alter table private.studio_calendar_settings add column paused boolean not null default false;
create or replace function private.studio_calendar_status() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not private.has_active_artist_access() then raise exception 'Active workspace access required' using errcode='42501';end if;
 return jsonb_build_object('enabled',(select enabled from private.studio_calendar_settings where singleton),'paused',(select paused from private.studio_calendar_settings where singleton),'bookings',coalesce((select jsonb_agg(jsonb_build_object('bookingId',b.id,'state',o.state,'updatedAt',o.updated_at)) from public.studio_bookings b join lateral (select state,updated_at from private.studio_calendar_operations where booking_id=b.id order by created_at desc,id desc limit 1) o on true where b.user_id=auth.uid() or private.is_studio_owner()),'[]'::jsonb));
end;$$;

create index studio_calendar_operations_booking_history on private.studio_calendar_operations(booking_id,created_at desc,id desc);
create index studio_calendar_tickets_expiry on private.studio_calendar_tickets(expires_at);
create index studio_calendar_runner_tokens_expiry on private.studio_calendar_runner_tokens(expires_at);
