begin;
-- Isolated eligibility fixtures; rollback restores each account's current state.
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=false,business_tools_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
insert into public.artist_projects(user_id,title) values ('1204ab25-7433-43a5-80e1-7a66b2eee057','Owner isolation fixture');
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.artist_projects) then raise exception 'Business user can read Artist data'; end if;
 begin insert into public.artist_projects(title) values ('Forbidden business write'); raise exception 'Business insert unexpectedly succeeded'; exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.app_memberships set access_status='active',payment_status='comped',deleted_at=null,expires_at=null,artist_member_enabled=true,business_tools_enabled=false where user_id='9bcb2126-19ab-4c12-8ee6-eca68ce7234e';
select set_config('request.jwt.claim.sub','9bcb2126-19ab-4c12-8ee6-eca68ce7234e',true);
set local role authenticated;
insert into public.artist_projects(title,kind,brief,target_date) values ('Artist isolation fixture','ep','Fixture brief','2026-10-15');
do $$ declare changed integer; begin
 if (select count(*) from public.artist_projects where title='Artist isolation fixture')<>1 then raise exception 'Artist own-row isolation failed'; end if;
 update public.artist_projects set status='released' where title='Artist isolation fixture';get diagnostics changed=row_count;if changed<>1 then raise exception 'Own update failed'; end if;
 update public.artist_projects set status='archived' where title='Owner isolation fixture';get diagnostics changed=row_count;if changed<>0 then raise exception 'Cross-account update succeeded'; end if;
 begin insert into public.artist_projects(user_id,title) values ('1204ab25-7433-43a5-80e1-7a66b2eee057','Forged owner');raise exception 'Cross-account insert succeeded';exception when insufficient_privilege then null;end;
 begin update public.artist_projects set user_id='1204ab25-7433-43a5-80e1-7a66b2eee057';raise exception 'Row reassignment succeeded';exception when insufficient_privilege then null;end;
 begin delete from public.artist_projects;raise exception 'Unexpected delete privilege';exception when insufficient_privilege then null;end;
end $$;
reset role;
update public.app_memberships set access_status='suspended' where user_id='9bcb2126-19ab-4c12-8ee6-eca68ce7234e';
set local role authenticated;
do $$ begin if exists(select 1 from public.artist_projects) then raise exception 'Suspended Artist access';end if; end $$;
reset role;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $$ begin if (select count(*) from public.artist_projects where title in ('Artist isolation fixture','Owner isolation fixture'))<>2 then raise exception 'Owner oversight failed'; end if;end $$;
reset role;
set local role anon;
do $$ begin begin perform 1 from public.artist_projects;raise exception 'Anonymous data access';exception when insufficient_privilege then null;end;end $$;
rollback;