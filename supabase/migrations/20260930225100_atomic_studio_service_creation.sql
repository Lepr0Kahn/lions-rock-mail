create function public.create_studio_service(service_name text,offering_name text,minutes integer,offering_price numeric,offering_currency text,deposit integer) returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
 if not private.has_active_artist_access() or not private.is_studio_owner() then raise exception 'Owner access required' using errcode='42501';end if;
 insert into public.studio_services(name) values(service_name) returning id into sid;
 insert into public.studio_service_variants(service_id,name,duration_minutes,price,currency,deposit_percent) values(sid,offering_name,minutes,offering_price,offering_currency,deposit);
 return sid;
end;$$;
revoke all on function public.create_studio_service(text,text,integer,numeric,text,integer) from public;
grant execute on function public.create_studio_service(text,text,integer,numeric,text,integer) to authenticated;