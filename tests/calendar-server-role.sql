-- Regression: use the actual database role, not just simulated JWT claims.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
do $$ begin
 if not has_schema_privilege(current_user,'private','usage') then raise exception 'Server cannot reach private calendar backend';end if;
 if (public.studio_calendar_backend('runner','{"digest":"regression-nonexistent-token"}')->>'allowed')::boolean then raise exception 'Unknown runner token accepted';end if;
end;$$;
reset role;
do $$ begin
 if has_function_privilege('authenticated','public.studio_calendar_backend(text,jsonb)','execute') then raise exception 'Member can call calendar backend';end if;
 if has_table_privilege('authenticated','private.studio_calendar_operations','select') then raise exception 'Member can read private queue';end if;
end;$$;
rollback;
