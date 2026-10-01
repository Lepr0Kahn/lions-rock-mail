alter table public.app_memberships add column deleted_at timestamptz;
create or replace function private.has_active_artist_access() returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.app_memberships m where m.user_id=(select auth.uid()) and m.deleted_at is null and m.access_status='active' and m.payment_status in ('paid','comped') and (m.role='owner' or m.artist_member_enabled=true) and (m.expires_at is null or m.expires_at>now()));$$;
create or replace function private.has_active_studio_access() returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.app_memberships m where m.user_id=(select auth.uid()) and m.deleted_at is null and m.access_status='active' and m.payment_status in ('paid','comped') and (m.role='owner' or m.business_tools_enabled=true) and (m.expires_at is null or m.expires_at>now()));$$;
create or replace function public.manage_studio_membership(member_id uuid,operation text,access_type text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare m public.app_memberships%rowtype;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
if operation not in ('switch','remove','restore') or operation is null then raise exception 'Invalid membership operation';end if;
select * into m from public.app_memberships where id=member_id for update;
if m.id is null then raise exception 'Member not found';end if;
if m.role='owner' or m.user_id=auth.uid() then raise exception 'Owner membership cannot be changed here' using errcode='42501';end if;
if operation in ('switch','restore') and (access_type is null or access_type not in ('business_tools','artist_member')) then raise exception 'Choose Artist Member or Business Tools';end if;
if operation='switch' then
 if m.deleted_at is not null then raise exception 'Restore this membership first';end if;
 update public.app_memberships set business_tools_enabled=access_type='business_tools',artist_member_enabled=access_type='artist_member',updated_at=now() where id=member_id returning * into m;
elsif operation='remove' then
 update public.app_memberships set deleted_at=coalesce(deleted_at,now()),access_status='suspended',business_tools_enabled=false,artist_member_enabled=false,updated_at=now() where id=member_id returning * into m;
else
 if m.deleted_at is null then raise exception 'Membership is not removed';end if;
 update public.app_memberships set deleted_at=null,access_status='suspended',business_tools_enabled=access_type='business_tools',artist_member_enabled=access_type='artist_member',updated_at=now() where id=member_id returning * into m;
end if;
return jsonb_build_object('id',m.id,'user_id',m.user_id,'access_status',m.access_status,'business_tools_enabled',m.business_tools_enabled,'artist_member_enabled',m.artist_member_enabled,'deleted_at',m.deleted_at);
end;$$;
revoke all on function public.manage_studio_membership(uuid,text,text) from public,anon;
grant execute on function public.manage_studio_membership(uuid,text,text) to authenticated;