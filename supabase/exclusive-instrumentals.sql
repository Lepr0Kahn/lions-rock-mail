alter table public.studio_instrumentals add column exclusive_price numeric(12,2) check(exclusive_price>0),add column exclusive_terms text not null default '' check(length(exclusive_terms)<=12000),add column sold_exclusive boolean not null default false;
alter table public.studio_instrumental_requests add column licence_kind text not null default 'lease' check(licence_kind in('lease','exclusive'));
create unique index one_exclusive_reservation on public.studio_instrumental_requests(instrumental_id) where licence_kind='exclusive' and status in('approved','released');
create function private.request_instrumental(beat_id uuid,licence_kind text,request_note text) returns uuid language plpgsql security definer set search_path='' as $$
declare b public.studio_instrumentals%rowtype;req uuid;t text;price numeric;
begin
if auth.uid() is null or not private.has_active_artist_access() or private.is_studio_owner() then raise exception 'Active Artist required' using errcode='42501';end if;
if licence_kind not in('lease','exclusive') then raise exception 'Invalid licence kind';end if;
select * into b from public.studio_instrumentals where id=beat_id and published and not archived for update;
if b.id is null or b.sold_exclusive or exists(select 1 from public.studio_instrumental_requests where instrumental_id=beat_id and studio_instrumental_requests.licence_kind='exclusive' and status in('approved','released')) then raise exception 'Instrumental unavailable or reserved';end if;
if licence_kind='exclusive' then
if b.exclusive_price is null or length(btrim(b.exclusive_terms))<20 then raise exception 'Exclusive offer requires price and separate terms';end if;
price:=b.exclusive_price;t:=b.exclusive_terms||E'\nExisting nonexclusive licences remain valid under their original terms. Download expiry does not terminate a licence.';
else price:=b.lease_price;t:=b.licence_terms;end if;
insert into public.studio_instrumental_requests(instrumental_id,user_id,price_snapshot,currency,terms_snapshot,title_snapshot,note,licence_kind) values(b.id,auth.uid(),price,b.currency,t,b.title,coalesce(request_note,''),licence_kind) returning id into req;
return req;end;$$;
revoke all on function private.request_instrumental(uuid,text,text) from public,anon;
grant execute on function private.request_instrumental(uuid,text,text) to authenticated;
create function public.request_instrumental(beat_id uuid,licence_kind text,request_note text default '') returns uuid language sql security invoker set search_path='' as $$select private.request_instrumental(beat_id,licence_kind,request_note);$$;
revoke all on function public.request_instrumental(uuid,text,text) from public,anon;
grant execute on function public.request_instrumental(uuid,text,text) to authenticated;
create or replace function private.request_instrumental_lease(beat_id uuid,request_note text) returns uuid language sql security invoker set search_path='' as $$select private.request_instrumental(beat_id,'lease',request_note);$$;
do $$
declare d text;
begin
select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='decide_instrumental_lease';
d:=replace(d,'select * into r from public.studio_instrumental_requests where id=request_id for update;','select * into r from public.studio_instrumental_requests where id=request_id; perform 1 from public.studio_instrumentals where id=r.instrumental_id for update; select * into r from public.studio_instrumental_requests where id=request_id for update;');
d:=replace(d,'select * into member from public.app_memberships',E'if exists(select 1 from public.studio_instrumentals where id=r.instrumental_id and sold_exclusive) or exists(select 1 from public.studio_instrumental_requests x where x.instrumental_id=r.instrumental_id and x.id<>r.id and x.status in(''approved'',''released'') and (x.licence_kind=''exclusive'' or (r.licence_kind=''exclusive'' and x.status=''approved''))) then raise exception ''Resolve competing approved requests before this approval'';end if; select * into member from public.app_memberships');
d:=replace(d,'''Instrumental lease: ''','(case when r.licence_kind=''exclusive'' then ''Exclusive instrumental: '' else ''Instrumental lease: '' end)');
d:=replace(d,'''Instrumental lease — ''','(case when r.licence_kind=''exclusive'' then ''Exclusive instrumental — '' else ''Instrumental lease — '' end)');
d:=replace(d,'update public.studio_instrumental_requests set status=''released''',E'if r.licence_kind=''exclusive'' then update public.studio_instrumentals set sold_exclusive=true,published=false,archived=true where id=r.instrumental_id;end if; update public.studio_instrumental_requests set status=''released''');
execute d;
select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='minor_workspace_data';
d:=replace(d,'''lease_price''-''currency''','''lease_price''-''exclusive_price''-''exclusive_terms''-''currency''');
execute d;
end;$$;
create function private.prevent_exclusive_republication() returns trigger language plpgsql set search_path='' as $$begin
if tg_op='UPDATE' and old.sold_exclusive and not new.sold_exclusive then raise exception 'Exclusive sale cannot be cleared';end if;
if new.sold_exclusive and new.published then raise exception 'Sold exclusive instrumental cannot be republished';end if;return new;end;$$;
revoke all on function private.prevent_exclusive_republication() from public,anon,authenticated;
create trigger prevent_exclusive_republication before insert or update on public.studio_instrumentals for each row execute function private.prevent_exclusive_republication();

do $$declare d text;begin select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='minor_workspace_data'; d:=replace(d,'to_jsonb(b)-''lease_price''-''exclusive_price''-''exclusive_terms''-''currency''-''licence_terms'' order by','(to_jsonb(b)-''lease_price''-''exclusive_price''-''exclusive_terms''-''currency''-''licence_terms'')||jsonb_build_object(''exclusive_available'',b.exclusive_price is not null and length(btrim(b.exclusive_terms))>=20 and not b.sold_exclusive) order by');execute d;end;$$;
create policy instrumentals_existing_licence_read on public.studio_instrumentals for select to authenticated using(private.has_active_artist_access() and exists(select 1 from public.studio_instrumental_requests r where r.instrumental_id=studio_instrumentals.id and r.user_id=auth.uid() and r.status='released'));
do $$declare d text;begin select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='minor_workspace_data';d:=replace(d,'where b.published and not b.archived;','where (b.published and not b.archived) or exists(select 1 from public.studio_instrumental_requests r where r.instrumental_id=b.id and r.user_id=auth.uid() and r.status=''released'');');execute d;end;$$;