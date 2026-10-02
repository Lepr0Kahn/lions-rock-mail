-- Read-only Owner assurance dashboard for calendar, booking/invoice, career, notification and reward integrity.
create or replace function private.studio_assurance()
returns jsonb language plpgsql security definer set search_path='' as $$
declare reward jsonb; cal jsonb; issues jsonb; inv jsonb; bookings jsonb;
begin
  if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access()
    then raise exception 'Active Owner access required' using errcode='42501'; end if;
  reward:=private.studio_reward_exposure(null);
  select jsonb_build_object(
    'enabled',coalesce((select enabled from private.studio_calendar_settings where singleton=true),false),
    'paused',coalesce((select paused from private.studio_calendar_settings where singleton=true),false),
    'pending_operations',(select count(*) from private.studio_calendar_operations where state not in('synced','done','completed')),
    'failed_operations',(select count(*) from private.studio_calendar_operations where error_code is not null and state not in('synced','done','completed')),
    'stale_leases',(select count(*) from private.studio_calendar_operations where lease_until is not null and lease_until<now() and state not in('synced','done','completed')),
    'last_operation_at',(select max(updated_at) from private.studio_calendar_operations),
    'last_webhook_at',(select max(processed_at) from private.studio_calendar_receipts)
  ) into cal;
  select jsonb_build_object(
    'nonvoid_invoices',count(*) filter(where status<>'void'),'paid_invoices',count(*) filter(where status='paid'),
    'open_balance_count',count(*) filter(where status not in('paid','void') and balance_due>0),
    'overdue_count',count(*) filter(where status not in('paid','void') and balance_due>0 and due_date<(now() at time zone 'America/Barbados')::date),
    'arithmetic_mismatches',count(*) filter(where status<>'void' and abs(coalesce(balance_due,0)-greatest(coalesce(total,0)-coalesce(amount_paid,0),0))>.01),
    'negative_amounts',count(*) filter(where coalesce(total,0)<0 or coalesce(amount_paid,0)<0 or coalesce(balance_due,0)<0)
  ) into inv from public.documents where user_id=auth.uid() and doc_type='invoice';
  select jsonb_build_object(
    'requested_holds',count(*) filter(where status='requested' and hold_expires_at>now()),
    'expired_requested_holds',count(*) filter(where status='requested' and hold_expires_at<=now()),
    'confirmed_without_invoice',count(*) filter(where status='confirmed' and not exists(select 1 from public.documents d where d.booking_id=b.id and d.user_id=auth.uid() and d.doc_type='invoice' and d.status<>'void')),
    'confirmed_calendar_mismatch',count(*) filter(where status='confirmed' and exists(select 1 from private.studio_calendar_links l where l.booking_id=b.id and(l.synchronized_status is distinct from b.status or l.synchronized_start is distinct from b.starts_at or l.synchronized_end is distinct from b.ends_at))),
    'confirmed_without_calendar_link',count(*) filter(where status='confirmed' and coalesce((select enabled from private.studio_calendar_settings where singleton=true),false) and not exists(select 1 from private.studio_calendar_links l where l.booking_id=b.id))
  ) into bookings from public.studio_bookings b;
  select coalesce(jsonb_agg(jsonb_build_object('severity',q.severity,'label',q.label,'count',q.n) order by q.severity desc,q.label),'[]'::jsonb)
  into issues from (
    select 3 severity,'Calendar operation failed or needs recovery' label,(cal->>'failed_operations')::int n where (cal->>'failed_operations')::int>0
    union all select 3,'Calendar worker lease is stale',(cal->>'stale_leases')::int where (cal->>'stale_leases')::int>0
    union all select 3,'Invoice arithmetic mismatch',(inv->>'arithmetic_mismatches')::int where (inv->>'arithmetic_mismatches')::int>0
    union all select 3,'Negative invoice amount',(inv->>'negative_amounts')::int where (inv->>'negative_amounts')::int>0
    union all select 2,'Confirmed booking has no invoice',(bookings->>'confirmed_without_invoice')::int where (bookings->>'confirmed_without_invoice')::int>0
    union all select 2,'Confirmed booking does not match synchronized calendar record',(bookings->>'confirmed_calendar_mismatch')::int where (bookings->>'confirmed_calendar_mismatch')::int>0
    union all select 2,'Confirmed booking has no calendar link',(bookings->>'confirmed_without_calendar_link')::int where (bookings->>'confirmed_without_calendar_link')::int>0
    union all select 2,'Requested booking hold has expired',(bookings->>'expired_requested_holds')::int where (bookings->>'expired_requested_holds')::int>0
    union all select 2,'Reward commitments exceed configured hours',1 where coalesce((reward->>'live_over_budget')::boolean,false)
    union all select 1,'Reward theoretical capacity exceeds configured hours',1 where coalesce((reward->>'worst_case_over_budget')::boolean,false)
  ) q;
  return jsonb_build_object(
    'healthy',jsonb_array_length(issues)=0,'issues',issues,'calendar',cal,'invoices',inv,'bookings',bookings,'rewards',reward,
    'career',jsonb_build_object('events',(select count(*) from public.artist_career_events),'reversals',(select count(*) from public.artist_career_event_reversals),'duplicate_source_events',(select count(*) from(select user_id,event_key,source_id from public.artist_career_events group by user_id,event_key,source_id having count(*)>1)d)),
    'notifications',jsonb_build_object('owner_unread',(select count(*) from public.studio_notifications where user_id=auth.uid() and read_at is null)),
    'computed_at',now());
end;$$;
revoke all on function private.studio_assurance() from public,anon,authenticated;
grant execute on function private.studio_assurance() to authenticated;
create or replace function public.studio_assurance()
returns jsonb language sql security invoker set search_path='' as $$select private.studio_assurance();$$;
revoke all on function public.studio_assurance() from public,anon;
grant execute on function public.studio_assurance() to authenticated;