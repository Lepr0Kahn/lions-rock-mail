create or replace function public.import_invoice_studio_services() returns integer language plpgsql security invoker set search_path='' as $$
declare n integer;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
insert into public.studio_services(invoice_service_id,name,category,description,catalogue_price,catalogue_currency,active)
select id,name,category,coalesce(description,''),price,currency,false from public.services where user_id=auth.uid() and is_active=true and lower(btrim(coalesce(category,'')))<>'membership packages'
on conflict(invoice_service_id) do update set name=excluded.name,category=excluded.category,description=excluded.description,catalogue_price=excluded.catalogue_price,catalogue_currency=excluded.catalogue_currency;
get diagnostics n=row_count;return n;
end;$$;

delete from public.studio_services s using public.services i where s.invoice_service_id=i.id and lower(btrim(i.category))='membership packages' and not s.active and not exists(select 1 from public.studio_service_variants v where v.service_id=s.id);