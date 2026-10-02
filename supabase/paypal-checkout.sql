-- PayPal checkout persistence and verified capture recording.
-- Applied to production on 2026-10-02.

create table if not exists public.studio_paypal_intents (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.documents(id) on delete restrict,
  artist_user_id uuid not null references auth.users(id) on delete restrict,
  portion text not null check (portion in ('deposit','balance','full')),
  invoice_amount numeric(12,2) not null check (invoice_amount > 0),
  invoice_currency text not null,
  charge_amount numeric(12,2) not null check (charge_amount > 0),
  charge_currency text not null,
  fx_rate numeric(18,6) not null check (fx_rate > 0),
  provider_order_id text unique,
  provider_capture_id text unique,
  status text not null default 'created' check (status in ('created','approved','captured','cancelled','failed')),
  created_at timestamptz not null default now(),
  captured_at timestamptz
);

alter table public.studio_paypal_intents enable row level security;
revoke all on public.studio_paypal_intents from anon, authenticated;
grant all on public.studio_paypal_intents to service_role;

create table if not exists public.studio_paypal_events (
  event_id text primary key,
  event_type text not null,
  provider_resource_id text,
  payload jsonb not null,
  received_at timestamptz not null default now()
);

alter table public.studio_paypal_events enable row level security;
revoke all on public.studio_paypal_events from anon, authenticated;
grant all on public.studio_paypal_events to service_role;

create or replace function public.studio_record_paypal_capture(
  paypal_intent_id uuid,
  capture_id text,
  captured_charge_amount numeric,
  captured_charge_currency text,
  provider_fee numeric default 0,
  provider_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  i public.studio_paypal_intents%rowtype;
  d public.documents%rowtype;
  existing public.payments%rowtype;
  seq integer;
  receipt text;
  p public.payments%rowtype;
  current_paid numeric;
begin
  if current_user not in ('service_role','postgres') then
    raise exception 'Server payment worker required' using errcode='42501';
  end if;

  select * into i from public.studio_paypal_intents where id=paypal_intent_id for update;
  if i.id is null then raise exception 'PayPal intent not found'; end if;

  if i.status='captured' then
    select * into existing from public.payments where reference=capture_id and method='paypal' limit 1;
    return jsonb_build_object('idempotent',true,'payment',to_jsonb(existing));
  end if;

  if i.provider_capture_id is not null and i.provider_capture_id<>capture_id then
    raise exception 'PayPal intent already belongs to another capture';
  end if;

  if captured_charge_currency<>i.charge_currency or abs(captured_charge_amount-i.charge_amount)>0.01 then
    raise exception 'PayPal capture amount or currency mismatch';
  end if;

  if exists(select 1 from public.studio_paypal_intents x where x.provider_capture_id=capture_id and x.id<>i.id)
     or exists(select 1 from public.payments x where x.method='paypal' and x.reference=capture_id) then
    raise exception 'PayPal capture already recorded';
  end if;

  select * into d from public.documents where id=i.invoice_id for update;
  if d.id is null or d.doc_type<>'invoice' or d.status in ('draft','void') then
    raise exception 'Invoice is not payable';
  end if;
  if d.currency<>i.invoice_currency or d.balance_due<i.invoice_amount then
    raise exception 'Invoice changed after PayPal order creation';
  end if;

  current_paid:=d.amount_paid;
  select count(*)+1 into seq from public.payments where document_id=d.id and receipt_number is not null;
  receipt:=d.doc_number||'-P'||lpad(seq::text,3,'0');

  insert into public.payments(
    user_id,document_id,amount,payment_date,method,reference,notes,kind,request_key,receipt_number
  )
  values(
    d.user_id,d.id,i.invoice_amount,(now() at time zone 'America/Barbados')::date,
    'paypal',capture_id,
    'Verified PayPal capture. Provider fee: '||coalesce(provider_fee,0)::text||' '||i.charge_currency,
    'payment',i.id,receipt
  )
  returning * into p;

  update public.documents
  set amount_paid=round(current_paid+i.invoice_amount,2),
      balance_due=greatest(round(total-(current_paid+i.invoice_amount),2),0),
      payment_date=(now() at time zone 'America/Barbados')::date,
      status=case when current_paid+i.invoice_amount>=total then 'paid' else 'open' end,
      paid_at=case when current_paid+i.invoice_amount>=total then now() else null end,
      payment_ledger_enabled=true
  where id=d.id;

  update public.studio_paypal_intents
  set provider_capture_id=capture_id,status='captured',captured_at=now()
  where id=i.id;

  return jsonb_build_object('idempotent',false,'payment',to_jsonb(p),'invoice_id',d.id);
end;
$function$;

revoke all on function public.studio_record_paypal_capture(uuid,text,numeric,text,numeric,jsonb) from public, anon, authenticated;
grant execute on function public.studio_record_paypal_capture(uuid,text,numeric,text,numeric,jsonb) to service_role;
