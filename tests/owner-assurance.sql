begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $$declare d jsonb;begin
 d:=public.studio_assurance();
 if d is null or not (d ? 'calendar') or not (d ? 'invoices') or not (d ? 'career') then raise exception 'Assurance payload incomplete';end if;
 if (d#>>'{career,duplicate_source_events}')::int<>0 then raise exception 'Duplicate career source events detected';end if;
end;$$;
rollback;
select has_function_privilege('anon','public.studio_assurance()','EXECUTE') anon_assurance;