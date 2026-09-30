create table public.artist_project_files (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.artist_projects(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 uploaded_by uuid not null references auth.users(id),
 object_path text not null unique,
 filename text not null,
 kind text not null check(kind in ('reference','stem','demo','mp3_delivery','master')),
 notes text not null default '' check(length(notes)<=5000),
 size_bytes bigint not null check(size_bytes>=0),
 expires_at timestamptz,
 created_at timestamptz not null default now()
);
create index artist_project_files_project_idx on public.artist_project_files(project_id,created_at desc);
create index artist_project_files_user_idx on public.artist_project_files(user_id);
alter table public.artist_project_files enable row level security;
revoke all on public.artist_project_files from anon,authenticated;
grant select on public.artist_project_files to authenticated;
create policy artist_files_read on public.artist_project_files for select to authenticated using
 ((select private.has_active_artist_access()) and (user_id=(select auth.uid()) or (select private.is_studio_owner())));
insert into storage.buckets(id,name,public,file_size_limit) values('artist-project-files','artist-project-files',false,52428800);

create function private.artist_upload_allowed(path text) returns boolean language sql stable security definer set search_path='' as $$
 select private.has_active_artist_access() and exists(
 select 1 from public.artist_projects p where p.id::text=split_part(path,'/',2) and p.user_id::text=split_part(path,'/',1)
 and (p.user_id=auth.uid() or private.is_studio_owner())
 and split_part(path,'/',3) in ('reference','stem','demo','mp3_delivery','master')
 and (split_part(path,'/',3) not in ('mp3_delivery','master') or private.is_studio_owner())
 and array_length(string_to_array(path,'/'),1)=5
 and split_part(path,'/',4) ~ '^[0-9a-f-]{36}$'
 and length(split_part(path,'/',5)) between 1 and 200);
$$;
revoke all on function private.artist_upload_allowed(text) from public;
grant execute on function private.artist_upload_allowed(text) to authenticated;

create policy artist_storage_insert on storage.objects for insert to authenticated with check
 (bucket_id='artist-project-files' and private.artist_upload_allowed(name));
create policy artist_storage_read on storage.objects for select to authenticated using
 (bucket_id='artist-project-files' and (select private.has_active_artist_access()) and (
 exists(select 1 from public.artist_project_files f where f.object_path=name and (f.user_id=(select auth.uid()) or (select private.is_studio_owner())) and (f.expires_at is null or f.expires_at>now()))
 or (owner_id=(select auth.uid())::text and not exists(select 1 from public.artist_project_files f where f.object_path=name))));
create policy artist_storage_cleanup on storage.objects for delete to authenticated using
 (bucket_id='artist-project-files' and owner_id=(select auth.uid())::text
 and not exists(select 1 from public.artist_project_files f where f.object_path=name));

create function public.register_artist_file(path text,file_notes text default '') returns uuid
language plpgsql security definer set search_path='' as $$
declare obj storage.objects%rowtype; proj public.artist_projects%rowtype; existing uuid; file_id uuid;
begin
 if not private.artist_upload_allowed(path) then raise exception 'Artist project upload access required' using errcode='42501';end if;
 if length(coalesce(file_notes,''))>5000 then raise exception 'Notes are too long';end if;
 select * into proj from public.artist_projects where id::text=split_part(path,'/',2) for key share;
 perform pg_advisory_xact_lock(hashtextextended(path,0));
 select id into existing from public.artist_project_files where object_path=path;
 if existing is not null then return existing;end if;
 select * into obj from storage.objects where bucket_id='artist-project-files' and name=path;
 if obj.id is null or obj.owner_id is distinct from auth.uid()::text then raise exception 'Upload not found for this account' using errcode='42501';end if;
 if obj.metadata->>'size' is null then raise exception 'Upload is not complete';end if;
 insert into public.artist_project_files(project_id,user_id,uploaded_by,object_path,filename,kind,notes,size_bytes,expires_at)
 values(proj.id,proj.user_id,auth.uid(),path,split_part(path,'/',5),split_part(path,'/',3),coalesce(file_notes,''),(obj.metadata->>'size')::bigint,
 case when split_part(path,'/',3) in ('mp3_delivery','master') then now()+interval '30 days' else null end) returning id into file_id;
 return file_id;
end;$$;
revoke all on function public.register_artist_file(text,text) from public;
grant execute on function public.register_artist_file(text,text) to authenticated;
create function public.reissue_artist_delivery(file_id uuid) returns timestamptz language plpgsql security definer set search_path='' as $$
declare expiry timestamptz;
begin
 if not private.is_studio_owner() or not private.has_active_artist_access() then raise exception 'Owner access required' using errcode='42501';end if;
 update public.artist_project_files set expires_at=now()+interval '30 days' where id=file_id and kind in ('mp3_delivery','master') returning expires_at into expiry;
 if expiry is null then raise exception 'Delivery not found';end if;
 return expiry;
end;$$;
revoke all on function public.reissue_artist_delivery(uuid) from public;
grant execute on function public.reissue_artist_delivery(uuid) to authenticated;