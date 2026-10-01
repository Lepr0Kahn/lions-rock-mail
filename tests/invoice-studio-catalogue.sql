begin;select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);set local role authenticated;
do $$ declare n integer;sid uuid;vid uuid;begin
n:=public.import_invoice_studio_services();if n<>8 then raise exception 'Catalogue count mismatch %',n;end if;
perform public.import_invoice_studio_services();
if (select count(*) from public.studio_services where invoice_service_id is not null)<>8 then raise exception 'Duplicate import';end if;
if exists(select 1 from public.studio_services where invoice_service_id is not null and category='Membership Packages') then raise exception 'Package imported';end if;
if exists(select 1 from public.studio_services s join public.services i on i.id=s.invoice_service_id where s.name<>i.name or s.catalogue_price<>i.price or s.catalogue_currency<>i.currency or s.description<>coalesce(i.description,'')) then raise exception 'Catalogue differs';end if;
select id into sid from public.studio_services where invoice_service_id is not null limit 1;
vid:=public.add_studio_service_offering(sid,'Rollback test',60,100,'BBD',25);
if (select active from public.studio_services where id=sid) then raise exception 'Offering unexpectedly activated';end if;
begin perform public.add_studio_service_offering(sid,'Invalid',0,100,'BBD',25);raise exception 'Invalid duration accepted';exception when check_violation then null;end;
end;$$;
select set_config('request.jwt.claim.sub','72c9afac-875f-460b-aa30-0e70b0cbaddc',true);
do $$ begin begin perform public.import_invoice_studio_services();raise exception 'NonOwner import permitted';exception when insufficient_privilege then null;end;begin perform public.add_studio_service_offering(gen_random_uuid(),'Invalid',60,0,'BBD',0);raise exception 'NonOwner offering permitted';exception when insufficient_privilege then null;end;end;$$;
rollback;