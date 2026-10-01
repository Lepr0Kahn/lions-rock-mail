create table private.document_number_counters(user_id uuid not null references auth.users(id),prefix text not null check(prefix in ('INV','QUO')),last_value bigint not null default 0,primary key(user_id,prefix));
create table private.document_number_reservations(user_id uuid not null references auth.users(id),document_id uuid not null,prefix text not null,doc_number text not null,primary key(user_id,document_id),unique(user_id,doc_number));
alter table private.document_number_counters enable row level security;
alter table private.document_number_reservations enable row level security;
revoke all on private.document_number_counters,private.document_number_reservations from public,anon,authenticated;
create or replace function public.reserve_document_number(document_id uuid,document_type text) returns text language plpgsql security definer set search_path='' as $fn$
declare u uuid:=auth.uid(); p text; n bigint; existing text; existing_type text;
begin
 if u is null or not private.has_active_studio_access() then raise exception 'Active Business Tools access required' using errcode='42501';end if;
 if document_id is null or document_type not in ('invoice','quote') then raise exception 'Invalid document';end if;
 p:=case when document_type='quote' then 'QUO' else 'INV' end;
 perform pg_advisory_xact_lock(hashtextextended('studio-document-numbers-'||u::text,0));
 select d.doc_number,d.doc_type into existing,existing_type from public.documents d where d.id=document_id and d.user_id=u;
 if existing is not null then
  if existing_type<>document_type then raise exception 'Document type cannot change';end if;
  return existing;
 end if;
 if exists(select 1 from public.documents d where d.id=document_id) then raise exception 'Document belongs to another account' using errcode='42501';end if;
 select r.doc_number,r.prefix into existing,existing_type from private.document_number_reservations r where r.user_id=u and r.document_id=reserve_document_number.document_id;
 if existing is not null then if existing_type<>p then raise exception 'Reserved document type cannot change';end if;return existing;end if;
 select coalesce(max(substring(d.doc_number from '([0-9]+)$')::bigint),0) into n from public.documents d where d.user_id=u and ((p='INV' and d.doc_number~'^(INV|RCP)-[0-9]+$') or (p='QUO' and d.doc_number~'^QUO-[0-9]+$'));
 insert into private.document_number_counters(user_id,prefix,last_value) values(u,p,n) on conflict(user_id,prefix) do update set last_value=greatest(private.document_number_counters.last_value,excluded.last_value);
 update private.document_number_counters c set last_value=c.last_value+1 where c.user_id=u and c.prefix=p returning c.last_value into n;
 existing:=p||'-'||lpad(n::text,greatest(4,length(n::text)),'0');
 insert into private.document_number_reservations values(u,document_id,p,existing);
 return existing;
end;$fn$;
revoke all on function public.reserve_document_number(uuid,text) from public,anon;
grant execute on function public.reserve_document_number(uuid,text) to authenticated;
create or replace function private.assign_document_number() returns trigger language plpgsql security definer set search_path='' as $fn$
declare existing text;
begin
 if tg_op='UPDATE' then
  if new.doc_type<>old.doc_type then raise exception 'Create a new document to change type';end if;
  new.doc_number:=old.doc_number; return new;
 end if;
 select d.doc_number into existing from public.documents d where d.id=new.id and d.user_id=new.user_id;
 if existing is not null then new.doc_number:=existing;return new;end if;
 if auth.uid() is null or auth.uid()<>new.user_id then raise exception 'Document owner authentication required' using errcode='42501';end if;
 new.doc_number:=public.reserve_document_number(new.id,new.doc_type);
 return new;
end;$fn$;
revoke all on function private.assign_document_number() from public,anon,authenticated;
create trigger assign_document_number before insert or update on public.documents for each row execute function private.assign_document_number();
