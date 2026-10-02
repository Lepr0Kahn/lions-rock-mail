-- Reject callbacks whose durable calendar link changed after their read.
do $migration$
declare definition text; needle text; replacement text;
begin
 definition:=pg_get_functiondef('private.studio_calendar_backend(text,jsonb)'::regprocedure);
 needle:=$old$  start_time:=(payload->>'start')::timestamptz;end_time:=(payload->>'end')::timestamptz;
  if payload->>'status'='accepted' then$old$;
 replacement:=$new$  perform 1 from private.studio_calendar_links where booking_id=b.id for update;
  if not exists(select 1 from private.studio_calendar_links where booking_id=b.id and provider_uid=payload->>'expectedProviderUid') then
   return jsonb_build_object('ignored',true);
  end if;
  start_time:=(payload->>'start')::timestamptz;end_time:=(payload->>'end')::timestamptz;
  if payload->>'status'='accepted' then$new$;
 if position(needle in definition)=0 then raise exception 'Reconciliation guard target missing';end if;
 execute replace(definition,needle,replacement);
end;$migration$;
