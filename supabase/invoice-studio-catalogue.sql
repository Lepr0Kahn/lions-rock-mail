alter table public.studio_services add column invoice_service_id uuid unique references public.services(id),add column catalogue_price numeric check(catalogue_price>=0),add column catalogue_currency text check(catalogue_currency in ('BBD','USD'));
create function public.import_invoice_studio_services() returns integer language plpgsql security invoker set search_path='' as $$
declare n integer;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
insert into public.studio_services(invoice_service_id,name,category,description,catalogue_price,catalogue_currency,active)
select id,name,category,coalesce(description,''),price,currency,false from public.services where user_id=auth.uid() and is_active=true
on conflict(invoice_service_id) do update set name=excluded.name,category=excluded.category,description=excluded.description,catalogue_price=excluded.catalogue_price,catalogue_currency=excluded.catalogue_currency;
get diagnostics n=row_count;return n;
end;$$;
create function public.add_studio_service_offering(service_id uuid,offering_name text,minutes integer,offering_price numeric,offering_currency text,deposit integer) returns uuid language plpgsql security invoker set search_path='' as $$
declare vid uuid;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
perform 1 from public.studio_services s where s.id=service_id for update;if not found then raise exception 'Service not found';end if;
if offering_name is null or minutes is null or offering_price is null or offering_currency is null or deposit is null then raise exception 'Complete all offering fields';end if;
insert into public.studio_service_variants(service_id,name,duration_minutes,price,currency,deposit_percent) values(service_id,offering_name,minutes,offering_price,offering_currency,deposit) returning id into vid;return vid;
end;$$;
revoke all on function public.import_invoice_studio_services() from public,anon;
revoke all on function public.add_studio_service_offering(uuid,text,integer,numeric,text,integer) from public,anon;
grant execute on function public.import_invoice_studio_services() to authenticated;
grant execute on function public.add_studio_service_offering(uuid,text,integer,numeric,text,integer) to authenticated;