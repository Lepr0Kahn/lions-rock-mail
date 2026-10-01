create table private.owner_mfa_settings(user_id uuid primary key references auth.users(id),required boolean not null default false);
alter table private.owner_mfa_settings enable row level security;
revoke all on private.owner_mfa_settings from public,anon,authenticated;
create function private.owner_mfa_allowed() returns boolean language sql stable security definer set search_path='' as $$
select auth.uid() is not null and (not exists(select 1 from private.owner_mfa_settings s where s.user_id=auth.uid() and s.required) or coalesce(auth.jwt()->>'aal','aal1')='aal2');$$;
revoke all on function private.owner_mfa_allowed() from public,anon;
grant execute on function private.owner_mfa_allowed() to authenticated;
create function private.owner_mfa_status() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
if auth.uid() is null then raise exception 'Sign in required' using errcode='42501';end if;
return jsonb_build_object('required',exists(select 1 from private.owner_mfa_settings where user_id=auth.uid() and required),'allowed',private.owner_mfa_allowed());
end;$$;
revoke all on function private.owner_mfa_status() from public,anon;
grant execute on function private.owner_mfa_status() to authenticated;
create function public.owner_mfa_status() returns jsonb language sql stable security invoker set search_path='' as $$select private.owner_mfa_status();$$;
revoke all on function public.owner_mfa_status() from public,anon;
grant execute on function public.owner_mfa_status() to authenticated;
do $$
declare t record; d text;
begin
for t in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in('is_studio_owner','has_active_studio_access','has_active_artist_access') loop
d:=pg_get_functiondef(t.oid);d:=replace(d,'select exists','select private.owner_mfa_allowed() and exists');execute d;
end loop;
for t in select tablename from pg_tables where schemaname='public' and rowsecurity and tablename<>'app_memberships' loop
execute format('create policy owner_mfa_gate on public.%I as restrictive for all to authenticated using ((select private.owner_mfa_allowed())) with check ((select private.owner_mfa_allowed()))',t.tablename);
end loop;
end;$$;
create policy owner_mfa_storage_gate on storage.objects as restrictive for all to authenticated using ((select private.owner_mfa_allowed())) with check ((select private.owner_mfa_allowed()));
