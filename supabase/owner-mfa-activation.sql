create function private.configure_owner_mfa(enable boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
if auth.uid() is null or not exists(select 1 from public.app_memberships where user_id=auth.uid() and role='owner' and access_status='active' and deleted_at is null and payment_status in('paid','comped') and (expires_at is null or expires_at>now())) then raise exception 'Active Owner required' using errcode='42501';end if;
if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception 'Verify your authenticator first' using errcode='42501';end if;
if enable is null then raise exception 'Choose enable or disable';end if;
if enable and (select count(*) from auth.mfa_factors where user_id=auth.uid() and status='verified' and factor_type='totp')<2 then raise exception 'Verify a primary and a separate backup authenticator before enabling';end if;
insert into private.owner_mfa_settings(user_id,required) values(auth.uid(),enable) on conflict(user_id) do update set required=excluded.required;
return private.owner_mfa_status();
end;$$;
revoke all on function private.configure_owner_mfa(boolean) from public,anon;
grant execute on function private.configure_owner_mfa(boolean) to authenticated;
create function public.configure_owner_mfa(enable boolean) returns jsonb language sql security invoker set search_path='' as $$select private.configure_owner_mfa(enable);$$;
revoke all on function public.configure_owner_mfa(boolean) from public,anon;
grant execute on function public.configure_owner_mfa(boolean) to authenticated;
