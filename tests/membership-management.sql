begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);set local role authenticated;
do $$ declare mid uuid;oid uuid;r jsonb;before_payment text;begin
select id,payment_status into mid,before_payment from public.app_memberships where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
select id into oid from public.app_memberships where user_id=auth.uid();
r:=public.manage_studio_membership(mid,'switch','artist_member');if not (r->>'artist_member_enabled')::boolean or (r->>'business_tools_enabled')::boolean then raise exception 'Artist switch failed';end if;
r:=public.manage_studio_membership(mid,'switch','business_tools');if not (r->>'business_tools_enabled')::boolean or (r->>'artist_member_enabled')::boolean then raise exception 'Business switch failed';end if;
if (select payment_status from public.app_memberships where id=mid)<>before_payment then raise exception 'Payment changed';end if;
r:=public.manage_studio_membership(mid,'remove');if r->>'deleted_at' is null or r->>'access_status'<>'suspended' or (r->>'business_tools_enabled')::boolean or (r->>'artist_member_enabled')::boolean then raise exception 'Removal did not revoke';end if;
begin perform public.manage_studio_membership(mid,'switch','artist_member');raise exception 'Removed member switched';exception when raise_exception then if sqlerrm='Removed member switched' then raise;end if;end;
r:=public.manage_studio_membership(mid,'restore','artist_member');if r->>'deleted_at' is not null or r->>'access_status'<>'suspended' or not (r->>'artist_member_enabled')::boolean then raise exception 'Restore failed';end if;
begin perform public.manage_studio_membership(oid,'remove');raise exception 'Owner removal permitted';exception when insufficient_privilege then null;end;
begin perform public.manage_studio_membership(mid,'switch','bad');raise exception 'Invalid type permitted';exception when raise_exception then if sqlerrm='Invalid type permitted' then raise;end if;end;
end;$$;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
do $$ declare mid uuid;begin
select id into mid from public.app_memberships where user_id=auth.uid();
if private.has_active_artist_access() or private.has_active_studio_access() then raise exception 'Suspended restore has active access';end if;
begin perform public.manage_studio_membership(mid,'switch','business_tools');raise exception 'Non-Owner control allowed';exception when insufficient_privilege then null;end;
end;$$;
rollback;