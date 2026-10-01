
alter table public.app_memberships add column is_minor boolean not null default false;
create table private.studio_guardian_contacts(
 artist_id uuid primary key references auth.users(id) on delete cascade,
 guardian_name text not null,guardian_email text not null,updated_at timestamptz not null default now());
alter table private.studio_guardian_contacts enable row level security;
revoke all on private.studio_guardian_contacts from public,anon,authenticated;
create table private.studio_guardian_links(
 id uuid primary key default gen_random_uuid(),invoice_id uuid not null references public.documents(id),
 artist_id uuid not null references auth.users(id),owner_id uuid not null references auth.users(id),
 token_hash text unique not null,snapshot jsonb not null,status text not null default 'pending' check(status in('pending','approved','revoked')),
 guardian_name text not null,guardian_email text not null,approved_name text,approved_at timestamptz,
 expires_at timestamptz not null default now()+interval '7 days',created_at timestamptz not null default now(),
 cash_requested_at timestamptz,cash_note text);
alter table private.studio_guardian_links enable row level security;
revoke all on private.studio_guardian_links from public,anon,authenticated;
create function private.is_minor_artist() returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.app_memberships where user_id=auth.uid() and is_minor);$$;
revoke all on function private.is_minor_artist() from public,anon;
grant execute on function private.is_minor_artist() to authenticated;
create or replace function private.has_active_studio_access() returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.app_memberships m where m.user_id=auth.uid() and not m.is_minor and m.deleted_at is null and m.access_status='active' and m.payment_status in('paid','comped') and(m.role='owner' or m.business_tools_enabled) and(m.expires_at is null or m.expires_at>now()));$$;
create function private.guard_minor_membership() returns trigger language plpgsql set search_path='' as $$
begin if new.is_minor and(new.role='owner' or new.business_tools_enabled) then raise exception 'Minor accounts must use Artist access only';end if;return new;end;$$;
revoke all on function private.guard_minor_membership() from public,anon,authenticated;
create trigger guard_minor_membership before insert or update on public.app_memberships for each row execute function private.guard_minor_membership();
create function private.manage_artist_guardian(artist_id uuid,minor boolean,guardian_name text,guardian_email text) returns void language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() then raise exception 'Active Owner required' using errcode='42501';end if;
if minor is null or not exists(select 1 from public.app_memberships m where m.user_id=artist_id and m.role<>'owner' and m.deleted_at is null) then raise exception 'Existing member required';end if;
if minor and(length(btrim(coalesce(guardian_name,'')))<2 or length(guardian_name)>200 or length(guardian_email)>320 or guardian_email !~ '^[^ @]+@[^ @]+\.[^ @]+$') then raise exception 'Enter guardian name and email';end if;
update public.app_memberships m set is_minor=minor,business_tools_enabled=case when minor then false else m.business_tools_enabled end,artist_member_enabled=case when minor then true else m.artist_member_enabled end,updated_at=now() where m.user_id=artist_id;
if minor then insert into private.studio_guardian_contacts values(artist_id,btrim(guardian_name),lower(btrim(guardian_email)),now()) on conflict on constraint studio_guardian_contacts_pkey do update set guardian_name=excluded.guardian_name,guardian_email=excluded.guardian_email,updated_at=now();end if;
if minor then update public.documents d set client_email=d.client_email where private.guardian_invoice_artist(d.id)=manage_artist_guardian.artist_id;end if;
update private.studio_guardian_links l set status='revoked' where l.artist_id=manage_artist_guardian.artist_id and l.status in('pending','approved');
end;$$;
create function public.manage_artist_guardian(artist_id uuid,minor boolean,guardian_name text default '',guardian_email text default '') returns void language sql security invoker set search_path='' as $$select private.manage_artist_guardian(artist_id,minor,guardian_name,guardian_email);$$;
revoke all on function private.manage_artist_guardian(uuid,boolean,text,text),public.manage_artist_guardian(uuid,boolean,text,text) from public,anon;
grant execute on function private.manage_artist_guardian(uuid,boolean,text,text),public.manage_artist_guardian(uuid,boolean,text,text) to authenticated;

create function private.guardian_invoice_artist(invoice_id uuid) returns uuid language sql stable security definer set search_path='' as $$
select coalesce((select r.user_id from public.studio_instrumental_requests r where r.invoice_id=d.id),(select b.user_id from public.studio_bookings b where b.id=d.booking_id),(select p.user_id from public.artist_projects p where p.id=d.artist_project_id)) from public.documents d where d.id=invoice_id;$$;
create function private.guardian_invoice_snapshot(invoice_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('invoice',jsonb_build_object('id',d.id,'number',d.doc_number,'client_name',d.client_name,'currency',d.currency,'subtotal',d.subtotal,'discount',d.discount,'tax_pct',d.tax_pct,'tax',d.tax,'total',d.total,'deposit_pct',d.deposit_pct,'notes',d.notes,'due_date',d.due_date),
'items',coalesce((select jsonb_agg(to_jsonb(i)-'created_at'-'updated_at' order by i.id) from public.document_items i where i.document_id=d.id),'[]'),
'booking',(select jsonb_build_object('starts_at',b.starts_at,'ends_at',b.ends_at,'service',b.service_name,'offering',b.variant_name) from public.studio_bookings b where b.id=d.booking_id),
'contact',(select jsonb_build_object('name',c.guardian_name,'email',c.guardian_email,'updated_at',c.updated_at) from private.studio_guardian_contacts c where c.artist_id=private.guardian_invoice_artist(d.id)))
from public.documents d where d.id=invoice_id;$$;
create function private.valid_guardian_link(link private.studio_guardian_links) returns boolean language sql stable security definer set search_path='' as $$
select link.status in('pending','approved') and link.expires_at>now() and link.snapshot=private.guardian_invoice_snapshot(link.invoice_id)
and exists(select 1 from public.documents d join public.app_memberships o on o.user_id=d.user_id where d.id=link.invoice_id and d.user_id=link.owner_id and d.doc_type='invoice' and d.status not in('draft','void') and o.role='owner' and not o.is_minor and o.deleted_at is null and o.access_status='active' and o.payment_status in('paid','comped') and(o.expires_at is null or o.expires_at>now()))
and exists(select 1 from public.app_memberships m where m.user_id=link.artist_id and m.is_minor and m.artist_member_enabled and m.deleted_at is null and m.access_status='active' and m.payment_status in('paid','comped') and(m.expires_at is null or m.expires_at>now()));$$;
revoke all on function private.guardian_invoice_artist(uuid),private.guardian_invoice_snapshot(uuid),private.valid_guardian_link(private.studio_guardian_links) from public,anon,authenticated;

create function private.issue_guardian_invoice_link(invoice_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare d public.documents%rowtype;artist uuid;c private.studio_guardian_contacts%rowtype;t text;link private.studio_guardian_links%rowtype;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() then raise exception 'Active Owner required' using errcode='42501';end if;
select * into d from public.documents where id=invoice_id and user_id=auth.uid() for update;
artist:=private.guardian_invoice_artist(invoice_id);
if d.id is null or d.doc_type<>'invoice' or d.status in('draft','void') or not exists(select 1 from public.app_memberships m where m.user_id=artist and m.is_minor and m.artist_member_enabled and m.deleted_at is null and m.access_status='active' and m.payment_status in('paid','comped') and(m.expires_at is null or m.expires_at>now())) then raise exception 'Issued invoice linked to an active minor Artist required';end if;
select * into c from private.studio_guardian_contacts where artist_id=artist;if c.artist_id is null then raise exception 'Set guardian contact first';end if;
t:=encode(extensions.gen_random_bytes(32),'hex');
update private.studio_guardian_links l set status='revoked' where l.invoice_id=d.id and l.status in('pending','approved');
insert into private.studio_guardian_links(invoice_id,artist_id,owner_id,token_hash,snapshot,guardian_name,guardian_email)
values(d.id,artist,auth.uid(),encode(extensions.digest(t,'sha256'),'hex'),private.guardian_invoice_snapshot(d.id),c.guardian_name,c.guardian_email) returning * into link;
return jsonb_build_object('token',t,'expires_at',link.expires_at,'guardian_name',c.guardian_name,'guardian_email',c.guardian_email);end;$$;
create function public.issue_guardian_invoice_link(invoice_id uuid) returns jsonb language sql security invoker set search_path='' as $$select private.issue_guardian_invoice_link(invoice_id);$$;
revoke all on function private.issue_guardian_invoice_link(uuid),public.issue_guardian_invoice_link(uuid) from public,anon;
grant execute on function private.issue_guardian_invoice_link(uuid),public.issue_guardian_invoice_link(uuid) to authenticated;
create function private.guardian_invoice_portal(token text,operation text default 'view',guardian_name text default '',consent boolean default false,note text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare l private.studio_guardian_links%rowtype;d public.documents%rowtype;records jsonb;
begin
if token is null or token !~ '^[0-9a-f]{64}$' or operation not in('view','approve','cash') then raise exception 'Invalid approval link';end if;
select * into l from private.studio_guardian_links where token_hash=encode(extensions.digest(token,'sha256'),'hex');
if l.id is null then raise exception 'Approval link unavailable';end if;
select * into d from public.documents where id=l.invoice_id for update;
select * into l from private.studio_guardian_links where id=l.id for update;
if not private.valid_guardian_link(l) then raise exception 'Approval link expired, revoked, or changed. Ask the studio for a new link';end if;
if operation='approve' then
if consent is distinct from true or length(btrim(coalesce(guardian_name,'')))<2 or length(guardian_name)>200 then raise exception 'Enter your full name and confirm guardian consent';end if;
if l.status='pending' then update private.studio_guardian_links set status='approved',approved_name=btrim(guardian_invoice_portal.guardian_name),approved_at=now() where id=l.id returning * into l;end if;
elsif operation='cash' then
if l.cash_requested_at is null and d.amount_paid>=d.total then raise exception 'Invoice already fully paid';end if;
if l.status<>'approved' or length(coalesce(note,''))>1000 then raise exception 'Approve the invoice first and keep the cash note within 1000 characters';end if;
if l.cash_requested_at is null then update private.studio_guardian_links set cash_requested_at=now(),cash_note=coalesce(guardian_invoice_portal.note,'') where id=l.id returning * into l;
insert into public.studio_notifications(user_id,event_id,title,body,action_kind) values(l.owner_id,l.id,'Guardian cash payment requested',d.doc_number||'. Guardian plans to pay cash; no payment received yet.','payments') on conflict(user_id,event_id) do nothing;end if;
end if;
select coalesce(jsonb_agg(jsonb_build_object('receipt_number',p.receipt_number,'kind',p.kind,'amount',p.amount,'payment_date',p.payment_date,'method',p.method) order by p.created_at),'[]') into records from public.payments p where p.document_id=d.id;
return jsonb_build_object('guardian_name',l.guardian_name,'status',l.status,'expires_at',l.expires_at,'cash_requested',l.cash_requested_at is not null,'invoice',l.snapshot->'invoice','items',l.snapshot->'items','booking',l.snapshot->'booking','amount_paid',d.amount_paid,'balance_due',greatest(d.total-d.amount_paid,0),'records',records);
end;$$;
create function public.guardian_invoice_portal(token text,operation text default 'view',guardian_name text default '',consent boolean default false,note text default '') returns jsonb language sql security invoker set search_path='' as $$select private.guardian_invoice_portal(token,operation,guardian_name,consent,note);$$;
revoke all on function private.guardian_invoice_portal(text,text,text,boolean,text),public.guardian_invoice_portal(text,text,text,boolean,text) from public;
grant execute on function private.guardian_invoice_portal(text,text,text,boolean,text),public.guardian_invoice_portal(text,text,text,boolean,text) to anon,authenticated;
create function private.enforce_guardian_payment_release() returns trigger language plpgsql security definer set search_path='' as $$
declare invoice uuid;artist uuid;
begin
if tg_table_name='payments' then if new.kind<>'payment' then return new;end if;invoice:=new.document_id;
elsif tg_table_name='documents' then if new.amount_paid<=old.amount_paid then return new;end if;invoice:=new.id;
else if new.status<>'released' or new.status is not distinct from old.status then return new;end if;invoice:=new.invoice_id;
end if;
artist:=private.guardian_invoice_artist(invoice);
if exists(select 1 from public.app_memberships where user_id=artist and is_minor) and not exists(select 1 from private.studio_guardian_links l where l.invoice_id=invoice and l.status='approved' and private.valid_guardian_link(l)) then raise exception 'Current guardian invoice approval required before recording payment or releasing a minor lease';end if;
return new;end;$$;
revoke all on function private.enforce_guardian_payment_release() from public,anon,authenticated;
create trigger guardian_payment_guard before insert on public.payments for each row execute function private.enforce_guardian_payment_release();
create trigger guardian_document_payment_guard before update on public.documents for each row execute function private.enforce_guardian_payment_release();
create trigger guardian_vault_release_guard before update on public.studio_instrumental_requests for each row execute function private.enforce_guardian_payment_release();

create function private.minor_workspace_data(section text) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
if auth.uid() is null or not private.has_active_artist_access() or not private.is_minor_artist() then raise exception 'Active minor Artist required' using errcode='42501';end if;
case section
when 'projects' then select coalesce(jsonb_agg(to_jsonb(p)-'budget_amount'-'budget_currency' order by p.created_at desc),'[]') into result from public.artist_projects p where p.user_id=auth.uid();
when 'services' then select coalesce(jsonb_agg(to_jsonb(s)-'catalogue_price'-'catalogue_currency'-'description' order by s.name),'[]') into result from public.studio_services s where s.active;
when 'variants' then select coalesce(jsonb_agg(to_jsonb(v)-'price'-'currency'-'deposit_percent' order by v.name),'[]') into result from public.studio_service_variants v join public.studio_services s on s.id=v.service_id where s.active;
when 'bookings' then select coalesce(jsonb_agg(to_jsonb(b)-'price'-'currency'-'deposit_percent' order by b.starts_at desc),'[]') into result from public.studio_bookings b where b.user_id=auth.uid();
when 'vault' then select coalesce(jsonb_agg(to_jsonb(b)-'lease_price'-'currency'-'licence_terms' order by b.created_at desc),'[]') into result from public.studio_instrumentals b where b.published and not b.archived;
when 'requests' then select coalesce(jsonb_agg(to_jsonb(r)-'price_snapshot'-'currency'-'terms_snapshot' order by r.created_at desc),'[]') into result from public.studio_instrumental_requests r where r.user_id=auth.uid();
when 'notifications' then select jsonb_build_object('unread',(select count(*) from public.studio_notifications where user_id=auth.uid() and read_at is null),'rows',coalesce(jsonb_agg(x.item order by x.created_at desc),'[]')) into result from
(select n.created_at,(to_jsonb(n)-'body')||jsonb_build_object('body',case when n.action_kind in('vault','payments') then 'Open the vault for current status. Financial approvals are handled by your guardian.' else n.body end) item from public.studio_notifications n where n.user_id=auth.uid() order by n.created_at desc limit 50)x;
else raise exception 'Unknown workspace section';
end case;
return result;
end;$$;
create function public.minor_workspace_data(section text) returns jsonb language sql security invoker set search_path='' as $$select private.minor_workspace_data(section);$$;
revoke all on function private.minor_workspace_data(text),public.minor_workspace_data(text) from public,anon;
grant execute on function private.minor_workspace_data(text),public.minor_workspace_data(text) to authenticated;
create policy artist_projects_minor_money_guard on public.artist_projects as restrictive for select to authenticated using(not (select private.is_minor_artist()));
create policy studio_services_minor_money_guard on public.studio_services as restrictive for select to authenticated using(not (select private.is_minor_artist()));
create policy studio_service_variants_minor_money_guard on public.studio_service_variants as restrictive for select to authenticated using(not (select private.is_minor_artist()));
create policy studio_bookings_minor_money_guard on public.studio_bookings as restrictive for select to authenticated using(not (select private.is_minor_artist()));
create policy studio_instrumentals_minor_money_guard on public.studio_instrumentals as restrictive for select to authenticated using(not (select private.is_minor_artist()));
create policy studio_instrumental_requests_minor_money_guard on public.studio_instrumental_requests as restrictive for select to authenticated using(not (select private.is_minor_artist()));
create policy studio_notifications_minor_money_guard on public.studio_notifications as restrictive for select to authenticated using(not (select private.is_minor_artist()));

create function private.minor_project_write(project_id uuid,project_values jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.artist_projects%rowtype;
begin
if auth.uid() is null or not private.has_active_artist_access() or not private.is_minor_artist() then raise exception 'Active minor Artist required' using errcode='42501';end if;
if project_id is null then
if length(btrim(coalesce(project_values->>'title','')))=0 or length(project_values->>'title')>200 or length(coalesce(project_values->>'brief',''))>5000 then raise exception 'Invalid project details';end if;
insert into public.artist_projects(user_id,title,kind,brief,target_date) values(auth.uid(),btrim(project_values->>'title'),project_values->>'kind',coalesce(project_values->>'brief',''),nullif(project_values->>'target_date','')::date) returning * into p;
else
update public.artist_projects set status=project_values->>'status' where id=project_id and user_id=auth.uid() returning * into p;
if p.id is null then raise exception 'Your project required' using errcode='42501';end if;
end if;
return to_jsonb(p)-'budget_amount'-'budget_currency';
end;$$;
create function public.minor_project_write(project_id uuid,project_values jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.minor_project_write(project_id,project_values);$$;
revoke all on function private.minor_project_write(uuid,jsonb),public.minor_project_write(uuid,jsonb) from public,anon;
grant execute on function private.minor_project_write(uuid,jsonb),public.minor_project_write(uuid,jsonb) to authenticated;
create function private.minor_notifications_seen(notification_id uuid default null) returns void language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null or not private.has_active_artist_access() or not private.is_minor_artist() then raise exception 'Active minor Artist required' using errcode='42501';end if;
update public.studio_notifications set read_at=now() where user_id=auth.uid() and read_at is null and(notification_id is null or id=notification_id);end;$$;
create function public.minor_notifications_seen(notification_id uuid default null) returns void language sql security invoker set search_path='' as $$select private.minor_notifications_seen(notification_id);$$;
revoke all on function private.minor_notifications_seen(uuid),public.minor_notifications_seen(uuid) from public,anon;
grant execute on function private.minor_notifications_seen(uuid),public.minor_notifications_seen(uuid) to authenticated;
create function private.guardian_management() returns jsonb language plpgsql security definer set search_path='' as $$
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() then raise exception 'Active Owner required' using errcode='42501';end if;
return jsonb_build_object('contacts',(select coalesce(jsonb_agg(to_jsonb(c)),'[]') from private.studio_guardian_contacts c),'links',(select coalesce(jsonb_agg(jsonb_build_object('invoice_id',l.invoice_id,'status',case when private.valid_guardian_link(l) then l.status else 'unavailable' end,'cash_requested_at',l.cash_requested_at,'cash_note',l.cash_note,'expires_at',l.expires_at) order by l.created_at desc),'[]') from private.studio_guardian_links l where l.owner_id=auth.uid()));
end;$$;
create function public.guardian_management() returns jsonb language sql security invoker set search_path='' as $$select private.guardian_management();$$;
revoke all on function private.guardian_management(),public.guardian_management() from public,anon;
grant execute on function private.guardian_management(),public.guardian_management() to authenticated;
revoke execute on function private.artist_project_timestamp() from public,anon;
grant usage on schema private to anon;

create or replace function private.vault_asset_access(asset_name text,writing boolean default false) returns boolean language plpgsql stable security definer set search_path='' as $$
declare b public.studio_instrumentals%rowtype;
begin
if auth.uid() is null or not private.has_active_artist_access() then return false;end if;
select * into b from public.studio_instrumentals where id::text=split_part(asset_name,'/',1);
if b.id is null then return false;end if;
if private.is_studio_owner() and private.has_active_studio_access() then return true;end if;
if writing then return false;end if;
if asset_name=b.id||'/preview/'||b.preview_filename and b.published and not b.archived then return true;end if;
if b.master_filename is null or asset_name is distinct from b.id||'/master/'||b.master_filename then return false;end if;
return exists(select 1 from public.studio_instrumental_requests req join public.documents d on d.id=req.invoice_id where req.instrumental_id=b.id and req.user_id=auth.uid() and req.status='released' and d.doc_type='invoice' and d.status not in('draft','void') and d.currency=req.currency and d.total>=req.price_snapshot and d.total>0 and d.amount_paid>=d.total and exists(select 1 from public.app_memberships m where m.user_id=d.user_id and m.role='owner') and (not private.is_minor_artist() or exists(select 1 from private.studio_guardian_links l where l.invoice_id=d.id and l.status='approved' and l.snapshot=private.guardian_invoice_snapshot(d.id))));
end;$$;
create function private.guard_minor_project_budget() returns trigger language plpgsql security definer set search_path='' as $$
begin
if private.is_minor_artist() and (case when tg_op='INSERT' then new.budget_amount is not null or new.budget_currency is not null else new.budget_amount is distinct from old.budget_amount or new.budget_currency is distinct from old.budget_currency end) then raise exception 'Minor budgets are handled by management and guardian';end if;
return new;end;$$;
revoke all on function private.guard_minor_project_budget() from public,anon,authenticated;
create trigger guard_minor_project_budget before insert or update on public.artist_projects for each row execute function private.guard_minor_project_budget();
create function private.guardian_document_recipient() returns trigger language plpgsql security definer set search_path='' as $$
declare artist uuid;email text;
begin
artist:=coalesce((select r.user_id from public.studio_instrumental_requests r where r.invoice_id=new.id),(select b.user_id from public.studio_bookings b where b.id=new.booking_id),(select p.user_id from public.artist_projects p where p.id=new.artist_project_id));
if exists(select 1 from public.app_memberships m where m.user_id=artist and m.is_minor) then
select guardian_email into email from private.studio_guardian_contacts where artist_id=artist;
if email is null then raise exception 'Set the minor guardian contact before issuing financial documents';end if;
new.client_email:=email;
end if;return new;end;$$;
revoke all on function private.guardian_document_recipient() from public,anon,authenticated;
create trigger guardian_document_recipient before insert or update on public.documents for each row execute function private.guardian_document_recipient();
create function private.guardian_lease_invoice_recipient() returns trigger language plpgsql security definer set search_path='' as $$
begin
if new.invoice_id is not null and (tg_op='INSERT' or new.invoice_id is distinct from old.invoice_id) and exists(select 1 from public.app_memberships where user_id=new.user_id and is_minor) then update public.documents set client_email=client_email where id=new.invoice_id;end if;return new;end;$$;
revoke all on function private.guardian_lease_invoice_recipient() from public,anon,authenticated;
create trigger guardian_lease_invoice_recipient after insert or update on public.studio_instrumental_requests for each row execute function private.guardian_lease_invoice_recipient();