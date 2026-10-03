-- Vault final-sale policy.
-- Once a licensed master has been released, the transaction is final and non-refundable.

create or replace function private.prevent_released_vault_financial_reversal() returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.kind in ('refund','correction')
     and exists(
       select 1
       from public.studio_instrumental_requests r
       where r.invoice_id=new.document_id
         and r.status='released'
     )
  then
    raise exception 'Released instrumental licences are final and non-refundable. Financial reversals are blocked after master release.'
      using errcode='42501';
  end if;
  return new;
end;
$$;

revoke all on function private.prevent_released_vault_financial_reversal() from public,anon,authenticated;

drop trigger if exists prevent_released_vault_financial_reversal on public.payments;
create trigger prevent_released_vault_financial_reversal
before insert on public.payments
for each row execute function private.prevent_released_vault_financial_reversal();

create or replace function private.stamp_vault_final_sale_notice() returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare notice text:='FINAL SALE NOTICE: Once Lions Rock releases the licensed master, this instrumental purchase is final and non-refundable.';
begin
  if new.invoice_id is not null and new.status in ('approved','released') then
    update public.documents
    set notes=case
      when position(notice in coalesce(notes,''))>0 then notes
      when coalesce(notes,'')='' then notice
      else notes||E'\n\n'||notice
    end
    where id=new.invoice_id;
  end if;
  return new;
end;
$$;

revoke all on function private.stamp_vault_final_sale_notice() from public,anon,authenticated;

drop trigger if exists stamp_vault_final_sale_notice on public.studio_instrumental_requests;
create trigger stamp_vault_final_sale_notice
after insert or update of status,invoice_id on public.studio_instrumental_requests
for each row execute function private.stamp_vault_final_sale_notice();

update public.documents d
set notes=case
  when position('FINAL SALE NOTICE: Once Lions Rock releases the licensed master, this instrumental purchase is final and non-refundable.' in coalesce(d.notes,''))>0 then d.notes
  when coalesce(d.notes,'')='' then 'FINAL SALE NOTICE: Once Lions Rock releases the licensed master, this instrumental purchase is final and non-refundable.'
  else d.notes||E'\n\nFINAL SALE NOTICE: Once Lions Rock releases the licensed master, this instrumental purchase is final and non-refundable.'
end
from public.studio_instrumental_requests r
where r.invoice_id=d.id and r.status in('approved','released');
