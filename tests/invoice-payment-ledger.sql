begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $test$
declare d uuid;n text;r jsonb;p uuid;key uuid:=gen_random_uuid();second uuid;
begin
insert into public.documents(user_id,doc_type,status,doc_date,currency,total,amount_paid,deposit_pct) values(auth.uid(),'invoice','open',current_date,'BBD',350,100,50) returning id,doc_number into d,n;
r:=public.record_invoice_payment(d,'payment',75,'cash',current_date,'','Received test cash',null,key);p:=(r->'entry'->>'id')::uuid;
if (r->'document'->>'amount_paid')::numeric<>175 or(select count(*) from public.payments where document_id=d and kind='opening')<>1 then raise exception 'Opening balance or cash amount incorrect';end if;
r:=public.record_invoice_payment(d,'payment',75,'cash',current_date,'','Received test cash',null,key);
if (r->'entry'->>'id')::uuid<>p or(select count(*) from public.payments where document_id=d)<>2 then raise exception 'Retry duplicated payment';end if;
r:=public.record_invoice_payment(d,'payment',175,'bank',current_date,'test-reference','Recorded bank payment',null,gen_random_uuid());second:=(r->'entry'->>'id')::uuid;
if (r->'document'->>'amount_paid')::numeric<>350 or r->'document'->>'status'<>'paid' then raise exception 'Full payment not reflected';end if;
r:=public.record_invoice_payment(d,'refund',50,'cash',current_date,'','Refund already issued',second,gen_random_uuid());
if (r->'document'->>'amount_paid')::numeric<>300 then raise exception 'Refund balance incorrect';end if;
r:=public.record_invoice_payment(d,'correction',125,'manual',current_date,'','Payment recorded in error',second,gen_random_uuid());
if (r->'document'->>'amount_paid')::numeric<>175 or(select doc_number from public.documents where id=d)<>n then raise exception 'Correction changed number/balance';end if;
begin perform public.record_invoice_payment(d,'refund',1,'cash',current_date,'','Over-refund',second,gen_random_uuid());raise exception 'Over-refund allowed';exception when raise_exception then if sqlerrm='Over-refund allowed' then raise;end if;end;
begin update public.documents set amount_paid=0 where id=d;raise exception 'Generator overwrote ledger';exception when raise_exception then if sqlerrm='Generator overwrote ledger' then raise;end if;end;
begin update public.payments set amount=0 where id=p;raise exception 'Payment entry mutable';exception when insufficient_privilege then null;end;
begin delete from public.documents where id=d;raise exception 'Payment history deleted';exception when raise_exception then if sqlerrm='Payment history deleted' then raise;end if;end;
if (select count(distinct receipt_number) from public.payments where document_id=d and receipt_number is not null)<>4 then raise exception 'Receipt references not unique';end if;
end $test$;
reset role;
select set_config('request.jwt.claim.sub','72c9afac-875f-460b-aa30-0e70b0cbaddc',true);
set local role authenticated;
do $deny$ begin begin perform public.record_invoice_payment(gen_random_uuid(),'payment',1,'cash',current_date,'','',null,gen_random_uuid());raise exception 'Non-Owner recorded payment';exception when insufficient_privilege then null;end;end $deny$;
rollback;
select 'PASS opening balance, cash/bank partial/full payments, idempotency, refund/correction bounds, immutable entries, shared invoice number, unique receipts and Owner-only writes; fixtures rolled back' result;