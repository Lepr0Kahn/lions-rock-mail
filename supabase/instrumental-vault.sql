
create table public.studio_instrumentals(
id uuid primary key default gen_random_uuid(),title text not null check(length(btrim(title)) between 1 and 180),producer text not null default 'Lions Rock',genre text not null default '',bpm integer not null default 0 check(bpm between 0 and 400),
lease_price numeric(12,2) not null check(lease_price>0),currency text not null default 'BBD' check(currency in('BBD','USD')),licence_terms text not null default '' check(length(licence_terms)<=12000),
published boolean not null default false,archived boolean not null default false,master_filename text,preview_filename text,created_at timestamptz not null default now());
create table public.studio_instrumental_requests(
id uuid primary key default gen_random_uuid(),instrumental_id uuid not null references public.studio_instrumentals(id),user_id uuid not null references auth.users(id),
status text not null default 'requested' check(status in('requested','approved','released','denied')),price_snapshot numeric(12,2) not null check(price_snapshot>0),currency text not null check(currency in('BBD','USD')),terms_snapshot text not null,title_snapshot text not null,note text not null default '' check(length(note)<=2000),invoice_id uuid unique references public.documents(id),created_at timestamptz not null default now(),released_at timestamptz);
create unique index instrumental_one_open_request on public.studio_instrumental_requests(instrumental_id,user_id) where status in('requested','approved','released');
create index instrumental_requests_user on public.studio_instrumental_requests(user_id,created_at desc);
alter table public.studio_instrumentals enable row level security;
alter table public.studio_instrumental_requests enable row level security;
revoke all on public.studio_instrumentals,public.studio_instrumental_requests from anon,authenticated;
grant select on public.studio_instrumentals,public.studio_instrumental_requests to authenticated;
grant insert,update on public.studio_instrumentals to authenticated;
create policy instrumentals_read on public.studio_instrumentals for select to authenticated using(private.has_active_artist_access() and((private.is_studio_owner() and private.has_active_studio_access()) or(published and not archived)));
create policy instrumentals_create on public.studio_instrumentals for insert to authenticated with check(private.is_studio_owner() and private.has_active_artist_access() and private.has_active_studio_access());
create policy instrumentals_edit on public.studio_instrumentals for update to authenticated using(private.is_studio_owner() and private.has_active_artist_access() and private.has_active_studio_access()) with check(private.is_studio_owner() and private.has_active_artist_access() and private.has_active_studio_access());
create policy instrumental_requests_read on public.studio_instrumental_requests for select to authenticated using(private.has_active_artist_access() and(user_id=auth.uid() or(private.is_studio_owner() and private.has_active_studio_access())));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('studio-instrumentals','studio-instrumentals',false,52428800,array['audio/mpeg','audio/wav','audio/x-wav','audio/mp4','audio/flac','application/octet-stream']) on conflict(id) do nothing;
create function private.vault_asset_access(asset_name text,writing boolean default false) returns boolean language plpgsql stable security definer set search_path='' as $$
declare b public.studio_instrumentals%rowtype;r record;
begin
if auth.uid() is null or not private.has_active_artist_access() then return false;end if;
select * into b from public.studio_instrumentals where id::text=split_part(asset_name,'/',1);
if b.id is null then return false;end if;
if private.is_studio_owner() and private.has_active_studio_access() then return true;end if;
if writing then return false;end if;
if asset_name=b.id||'/preview/'||b.preview_filename and b.published and not b.archived then return true;end if;
if asset_name<>b.id||'/master/'||b.master_filename then return false;end if;
return exists(select 1 from public.studio_instrumental_requests req join public.documents d on d.id=req.invoice_id where req.instrumental_id=b.id and req.user_id=auth.uid() and req.status='released' and d.doc_type='invoice' and d.status not in('draft','void') and d.currency=req.currency and d.total>=req.price_snapshot and d.total>0 and d.amount_paid>=d.total and exists(select 1 from public.app_memberships m where m.user_id=d.user_id and m.role='owner'));
end;$$;
revoke all on function private.vault_asset_access(text,boolean) from public,anon;
grant execute on function private.vault_asset_access(text,boolean) to authenticated;
create policy vault_asset_read on storage.objects for select to authenticated using(bucket_id='studio-instrumentals' and private.vault_asset_access(name,false));
create policy vault_asset_insert on storage.objects for insert to authenticated with check(bucket_id='studio-instrumentals' and private.vault_asset_access(name,true));
create policy vault_asset_update on storage.objects for update to authenticated using(bucket_id='studio-instrumentals' and private.vault_asset_access(name,true)) with check(bucket_id='studio-instrumentals' and private.vault_asset_access(name,true));
create function private.validate_instrumental_publication() returns trigger language plpgsql security definer set search_path='' as $$
begin
if new.published and not new.archived then
if length(btrim(new.licence_terms))<20 or new.master_filename is null or new.preview_filename is null then raise exception 'Add licence terms, a master and a separate preview before publishing';end if;
if not exists(select 1 from storage.objects where bucket_id='studio-instrumentals' and name=new.id||'/master/'||new.master_filename) or not exists(select 1 from storage.objects where bucket_id='studio-instrumentals' and name=new.id||'/preview/'||new.preview_filename) then raise exception 'Upload both audio assets before publishing';end if;
end if;return new;end;$$;
revoke all on function private.validate_instrumental_publication() from public,anon,authenticated;
create trigger validate_instrumental_publication before insert or update on public.studio_instrumentals for each row execute function private.validate_instrumental_publication();
create function private.request_instrumental_lease(beat_id uuid,request_note text) returns uuid language plpgsql security definer set search_path='' as $$
declare b public.studio_instrumentals%rowtype;req uuid;
begin
if auth.uid() is null or not private.has_active_artist_access() or private.is_studio_owner() then raise exception 'Active Artist Member required' using errcode='42501';end if;
select * into b from public.studio_instrumentals where id=beat_id and published and not archived for share;
if b.id is null then raise exception 'Instrumental unavailable';end if;
insert into public.studio_instrumental_requests(instrumental_id,user_id,price_snapshot,currency,terms_snapshot,title_snapshot,note) values(b.id,auth.uid(),b.lease_price,b.currency,b.licence_terms,b.title,coalesce(request_note,'')) returning id into req;
return req;end;$$;
revoke all on function private.request_instrumental_lease(uuid,text) from public,anon;
grant execute on function private.request_instrumental_lease(uuid,text) to authenticated;
create function public.request_instrumental_lease(beat_id uuid,request_note text default '') returns uuid language sql security invoker set search_path='' as $$select private.request_instrumental_lease(beat_id,request_note);$$;
revoke all on function public.request_instrumental_lease(uuid,text) from public,anon;
grant execute on function public.request_instrumental_lease(uuid,text) to authenticated;
create function private.decide_instrumental_lease(request_id uuid,decision text) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.studio_instrumental_requests%rowtype;doc public.documents%rowtype;member public.app_memberships%rowtype;docid uuid;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_artist_access() or not private.has_active_studio_access() then raise exception 'Active Owner required' using errcode='42501';end if;
select * into r from public.studio_instrumental_requests where id=request_id for update;
if r.id is null then raise exception 'Request not found';end if;
if decision='approve' then
if r.status in('approved','released') then return r.invoice_id;end if;
if r.status<>'requested' then raise exception 'Request closed';end if;
select * into member from public.app_memberships where user_id=r.user_id and access_status='active' and artist_member_enabled and payment_status in('paid','comped') and deleted_at is null and(expires_at is null or expires_at>now());
if member.user_id is null then raise exception 'Artist access is inactive';end if;
insert into public.documents(user_id,doc_type,status,doc_date,currency,deposit_pct,subtotal,total,balance_due,client_name,client_email,notes)
values(auth.uid(),'invoice','open',current_date,r.currency,100,r.price_snapshot,r.price_snapshot,r.price_snapshot,coalesce(nullif(member.business_name,''),member.email),member.email,'Instrumental lease: '||r.title_snapshot||E'\nLicence terms: '||r.terms_snapshot) returning id into docid;
insert into public.document_items(document_id,user_id,name,description,qty,unit_price,line_total) values(docid,auth.uid(),'Instrumental lease — '||r.title_snapshot,r.terms_snapshot,1,r.price_snapshot,r.price_snapshot);
update public.studio_instrumental_requests set status='approved',invoice_id=docid where id=r.id;return docid;
elsif decision='release' then
select * into doc from public.documents where id=r.invoice_id for share;
if r.status not in('approved','released') or doc.id is null or doc.user_id<>auth.uid() or doc.doc_type<>'invoice' or doc.status in('draft','void') or doc.currency<>r.currency or doc.total<r.price_snapshot or doc.amount_paid<doc.total then raise exception 'Full lease payment must be recorded on your invoice before release';end if;
update public.studio_instrumental_requests set status='released',released_at=coalesce(released_at,now()) where id=r.id;return r.invoice_id;
elsif decision='deny' then
if r.status<>'requested' then raise exception 'Only pending requests can be denied';end if;
update public.studio_instrumental_requests set status='denied' where id=r.id;return null;
else raise exception 'Invalid decision';end if;end;$$;
revoke all on function private.decide_instrumental_lease(uuid,text) from public,anon;
grant execute on function private.decide_instrumental_lease(uuid,text) to authenticated;
create function public.decide_instrumental_lease(request_id uuid,decision text) returns uuid language sql security invoker set search_path='' as $$select private.decide_instrumental_lease(request_id,decision);$$;
revoke all on function public.decide_instrumental_lease(uuid,text) from public,anon;
grant execute on function public.decide_instrumental_lease(uuid,text) to authenticated;
