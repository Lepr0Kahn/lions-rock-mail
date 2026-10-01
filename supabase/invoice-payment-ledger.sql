
alter table public.payments add column kind text not null default 'payment' check(kind in('payment','refund','correction','opening'));
alter table public.payments add column source_payment_id uuid references public.payments(id);
alter table public.payments add column request_key uuid;
alter table public.payments add column receipt_number text;
create unique index payment_request_key on public.payments(user_id,request_key) where request_key is not null;
create unique index payment_receipt_number on public.payments(user_id,receipt_number) where receipt_number is not null;
create index payment_document_time on public.payments(document_id,created_at,id);
alter table public.documents add column payment_ledger_enabled boolean not null default false;
revoke insert,update,delete on public.payments from authenticated;
create function private.record_invoice_payment(invoice_id uuid,entry_kind text,entry_amount numeric,entry_method text,entry_date date,entry_reference text,entry_notes text,source_id uuid,idempotency_key uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.documents%rowtype;p public.payments%rowtype;original public.payments%rowtype;balance numeric;available numeric;seq integer;new_id uuid;receipt text;delta numeric;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() then raise exception 'Active Owner required' using errcode='42501';end if;
if idempotency_key is null or entry_kind not in('payment','refund','correction') or entry_amount is null or entry_amount<=0 or entry_amount<>round(entry_amount,2) or entry_date is null or entry_date>(now() at time zone 'America/Barbados')::date then raise exception 'Enter a positive amount to two decimals and a valid received/issued date';end if;
if entry_method not in('cash','bank','manual') or length(coalesce(entry_reference,''))>300 or length(coalesce(entry_notes,''))>2000 then raise exception 'Invalid payment details';end if;
select * into d from public.documents where id=invoice_id and user_id=auth.uid() for update;
if d.id is null or d.doc_type<>'invoice' then raise exception 'Your invoice is required' using errcode='42501';end if;
select * into p from public.payments where user_id=auth.uid() and request_key=idempotency_key;
if p.id is not null then
if p.document_id<>invoice_id or p.kind<>entry_kind or abs(p.amount)<>entry_amount or p.source_payment_id is distinct from source_id then raise exception 'Request key belongs to another entry';end if;
return jsonb_build_object('entry',to_jsonb(p),'document',to_jsonb(d));end if;
if d.status in('draft','void') then raise exception 'Issue the invoice before recording payments';end if;
if d.total<=0 then raise exception 'A positive invoice total is required';end if;
select coalesce(sum(amount),0) into balance from public.payments where document_id=d.id;
if not d.payment_ledger_enabled then
if balance>d.amount_paid then raise exception 'Existing payment records need reconciliation';end if;
if d.amount_paid>balance then insert into public.payments(user_id,document_id,amount,payment_date,method,notes,kind) values(auth.uid(),d.id,d.amount_paid-balance,coalesce(d.payment_date,(now() at time zone 'America/Barbados')::date),'legacy','Opening balance imported from the invoice; method and original payment date unverified.','opening');end if;
balance:=d.amount_paid;
update public.documents set payment_ledger_enabled=true where id=d.id;
end if;
if entry_kind='payment' then
if source_id is not null or balance+entry_amount>d.total then raise exception 'Payment exceeds invoice balance or has an invalid source';end if;
delta:=entry_amount;
else
if length(btrim(coalesce(entry_notes,'')))=0 then raise exception 'Give the refund/correction reason';end if;
select * into original from public.payments where id=source_id and document_id=d.id and user_id=auth.uid() and kind in('payment','opening') for update;
if original.id is null then raise exception 'Select the original payment';end if;
select original.amount+coalesce(sum(amount),0) into available from public.payments where source_payment_id=original.id;
if entry_amount>available or entry_amount>balance then raise exception 'Refund/correction exceeds remaining recorded payment';end if;
delta:=-entry_amount;
end if;
select count(*)+1 into seq from public.payments where document_id=d.id and receipt_number is not null;
receipt:=d.doc_number||case when entry_kind='payment' then '-P' when entry_kind='refund' then '-R' else '-C' end||lpad(seq::text,3,'0');
insert into public.payments(user_id,document_id,amount,payment_date,method,reference,notes,kind,source_payment_id,request_key,receipt_number)
values(auth.uid(),d.id,delta,entry_date,entry_method,coalesce(entry_reference,''),coalesce(entry_notes,''),entry_kind,source_id,idempotency_key,receipt) returning * into p;
balance:=balance+delta;
update public.documents set amount_paid=balance,balance_due=greatest(total-balance,0),payment_date=entry_date,status=case when balance>=total then 'paid' else 'open' end,paid_at=case when balance>=total then now() else null end where id=d.id returning * into d;
return jsonb_build_object('entry',to_jsonb(p),'document',to_jsonb(d));
end;$$;
revoke all on function private.record_invoice_payment(uuid,text,numeric,text,date,text,text,uuid,uuid) from public,anon;
grant execute on function private.record_invoice_payment(uuid,text,numeric,text,date,text,text,uuid,uuid) to authenticated;
create function public.record_invoice_payment(invoice_id uuid,entry_kind text,entry_amount numeric,entry_method text,entry_date date,entry_reference text default '',entry_notes text default '',source_id uuid default null,idempotency_key uuid default null) returns jsonb language sql security invoker set search_path='' as $$select private.record_invoice_payment(invoice_id,entry_kind,entry_amount,entry_method,entry_date,entry_reference,entry_notes,source_id,idempotency_key);$$;
revoke all on function public.record_invoice_payment(uuid,text,numeric,text,date,text,text,uuid,uuid) from public,anon;
grant execute on function public.record_invoice_payment(uuid,text,numeric,text,date,text,text,uuid,uuid) to authenticated;
create function private.guard_invoice_payment_ledger() returns trigger language plpgsql security definer set search_path='' as $$
declare expected numeric;
begin
if old.payment_ledger_enabled or new.payment_ledger_enabled then
if old.payment_ledger_enabled and not new.payment_ledger_enabled then raise exception 'Payment ledger cannot be disabled';end if;
if new.user_id<>old.user_id or new.doc_type<>old.doc_type or new.currency<>old.currency then raise exception 'Ledger invoice account, type and currency cannot change';end if;
select coalesce(sum(amount),0) into expected from public.payments where document_id=old.id;
if new.amount_paid<>expected then raise exception 'Use Payments to record or correct this invoice payment balance';end if;
end if;return new;end;$$;
revoke all on function private.guard_invoice_payment_ledger() from public,anon,authenticated;
create trigger guard_invoice_payment_ledger before update on public.documents for each row execute function private.guard_invoice_payment_ledger();
alter table public.payments drop constraint payments_amount_check;
alter table public.payments add constraint payments_amount_check check((kind in('payment','opening') and amount>0) or(kind in('refund','correction') and amount<0));

create function private.prepare_invoice_payment_ledger(invoice_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare d public.documents%rowtype;balance numeric;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() then raise exception 'Active Owner required' using errcode='42501';end if;
select * into d from public.documents where id=invoice_id and user_id=auth.uid() for update;
if d.id is null or d.doc_type<>'invoice' or d.status in('draft','void') then raise exception 'Your issued invoice required';end if;
if d.payment_ledger_enabled then return;end if;
select coalesce(sum(amount),0) into balance from public.payments where document_id=d.id;
if balance>d.amount_paid then raise exception 'Existing payments need reconciliation';end if;
if d.amount_paid>balance then insert into public.payments(user_id,document_id,amount,payment_date,method,notes,kind) values(auth.uid(),d.id,d.amount_paid-balance,coalesce(d.payment_date,(now() at time zone 'America/Barbados')::date),'legacy','Opening balance imported from invoice; original method/date unverified.','opening');end if;
update public.documents set payment_ledger_enabled=true where id=d.id;end;$$;
revoke all on function private.prepare_invoice_payment_ledger(uuid) from public,anon;
grant execute on function private.prepare_invoice_payment_ledger(uuid) to authenticated;
create function public.prepare_invoice_payment_ledger(invoice_id uuid) returns void language sql security invoker set search_path='' as $$select private.prepare_invoice_payment_ledger(invoice_id);$$;
revoke all on function public.prepare_invoice_payment_ledger(uuid) from public,anon;
grant execute on function public.prepare_invoice_payment_ledger(uuid) to authenticated;
create function private.protect_invoice_payment_history() returns trigger language plpgsql security definer set search_path='' as $$begin if old.payment_ledger_enabled or exists(select 1 from public.payments p where p.document_id=old.id) then raise exception 'Void this invoice instead of deleting its payment history';end if;return old;end;$$;
revoke all on function private.protect_invoice_payment_history() from public,anon,authenticated;
create trigger protect_invoice_payment_history before delete on public.documents for each row execute function private.protect_invoice_payment_history();
