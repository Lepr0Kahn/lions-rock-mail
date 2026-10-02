begin;
update public.app_memberships set access_status='active',payment_status='comped',deleted_at=null,expires_at=null,artist_member_enabled=true where user_id in('8da3fa1f-10ef-4fac-8294-279e6a9e61b1','72c9afac-875f-460b-aa30-0e70b0cbaddc');
select set_config('request.jwt.claims','{"sub":"1204ab25-7433-43a5-80e1-7a66b2eee057","role":"authenticated","aal":"aal2"}',true);
do $$declare beat uuid;r uuid;other uuid;invoice uuid;again uuid;begin
insert into public.studio_instrumentals(title,lease_price,currency,licence_terms,exclusive_price,exclusive_terms) values('Exclusive rollback',10,'BBD','Existing lease remains valid',100,'Exclusive terms agreed for fixture') returning id into beat;
insert into public.studio_instrumental_requests(instrumental_id,user_id,price_snapshot,currency,terms_snapshot,title_snapshot,licence_kind) values(beat,'8da3fa1f-10ef-4fac-8294-279e6a9e61b1',100,'BBD','Exclusive terms; existing leases remain valid','Exclusive rollback','exclusive') returning id into r;
insert into public.studio_instrumental_requests(instrumental_id,user_id,price_snapshot,currency,terms_snapshot,title_snapshot,licence_kind) values(beat,'72c9afac-875f-460b-aa30-0e70b0cbaddc',100,'BBD','Exclusive fixture','Exclusive rollback','exclusive') returning id into other;
invoice:=public.decide_instrumental_lease(r,'approve');again:=public.decide_instrumental_lease(r,'approve');if invoice<>again then raise exception 'Retry duplicated invoice';end if;
if not exists(select 1 from public.document_items where document_id=invoice and name like 'Exclusive instrumental%') then raise exception 'Wrong invoice label';end if;
begin perform public.decide_instrumental_lease(other,'approve');raise exception 'Competing approval allowed';exception when raise_exception then if sqlerrm<>'Resolve competing approved requests before this approval' then raise;end if;end;
begin perform public.decide_instrumental_lease(r,'release');raise exception 'Unpaid release allowed';exception when raise_exception then if sqlerrm<>'Full lease payment must be recorded on your invoice before release' then raise;end if;end;
update public.documents set amount_paid=total where id=invoice;
perform public.decide_instrumental_lease(r,'release');perform public.decide_instrumental_lease(r,'release');
if not exists(select 1 from public.studio_instrumentals where id=beat and sold_exclusive and archived and not published) then raise exception 'Not removed from sale';end if;
begin update public.studio_instrumentals set sold_exclusive=false where id=beat;raise exception 'Sale flag cleared';exception when raise_exception then if sqlerrm<>'Exclusive sale cannot be cleared' then raise;end if;end;
end;$$;
select 'Exclusive invoice retry, competing approval, unpaid release, paid release and sale permanence passed' result;
rollback;