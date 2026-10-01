begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true); set local role authenticated;
do $test$ declare id1 uuid:=gen_random_uuid();id2 uuid:=gen_random_uuid();q uuid:=gen_random_uuid();a text;b text;c text; begin
 a:=public.reserve_document_number(id1,'invoice'); if a<>public.reserve_document_number(id1,'invoice') then raise exception 'Not idempotent';end if;
 b:=public.reserve_document_number(id2,'invoice');if substring(b from '[0-9]+$')::bigint<>substring(a from '[0-9]+$')::bigint+1 then raise exception 'Counter did not advance';end if;
 c:=public.reserve_document_number(q,'quote');if c!~'^QUO-' then raise exception 'Quote prefix';end if;
 insert into public.documents(id,user_id,doc_type,doc_number,status,doc_date) values(id1,auth.uid(),'invoice','INV-9999','open',current_date);
 if (select doc_number from public.documents where id=id1)<>a then raise exception 'Reservation not enforced';end if;
 update public.documents set status='paid',doc_number='RCP-9999' where id=id1;
 if (select doc_number from public.documents where id=id1)<>a then raise exception 'Paid number changed';end if;
end;$test$;
rollback;
