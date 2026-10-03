begin;
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
create temporary table vault_fixture(beat uuid,request uuid,invoice uuid);
insert into public.studio_instrumentals(title,lease_price,licence_terms,master_filename,preview_filename) values('Disposable vault regression',150,'Test-only nonexclusive licence terms; no actual rights granted.','master.wav','preview.mp3');
insert into vault_fixture(beat) select id from public.studio_instrumentals where title='Disposable vault regression';
insert into storage.objects(bucket_id,name) select 'studio-instrumentals',beat||'/master/master.wav' from vault_fixture union all select 'studio-instrumentals',beat||'/preview/preview.mp3' from vault_fixture;
update public.studio_instrumentals set published=true where id=(select beat from vault_fixture);
grant select,update on vault_fixture to authenticated;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
select public.manage_artist_guardian('8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true,'Test Guardian','guardian@example.invalid');
reset role;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
update vault_fixture set request=public.request_instrumental_lease(beat,'Disposable request');
do $test$ declare b uuid;begin select beat into b from vault_fixture;
if not private.vault_asset_access(b||'/preview/preview.mp3',false) or private.vault_asset_access(b||'/master/master.wav',false) then raise exception 'Preview/master gate failed';end if;
begin perform public.request_instrumental_lease(b,'duplicate');raise exception 'Duplicate request allowed';exception when unique_violation then null;end;
begin perform public.decide_instrumental_lease((select request from vault_fixture),'approve');raise exception 'Artist approved own request';exception when insufficient_privilege then null;end;
end $test$;
reset role;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
update vault_fixture set invoice=public.decide_instrumental_lease(request,'approve');
do $test$ begin
if public.decide_instrumental_lease((select request from vault_fixture),'approve')<>(select invoice from vault_fixture) then raise exception 'Approval retry created another invoice';end if;
if not exists(select 1 from public.documents d where d.id=(select invoice from vault_fixture) and d.client_email='guardian@example.invalid' and d.doc_number like 'INV-%' and d.total=150 and d.deposit_pct=100) then raise exception 'Shared invoice allocator/price mismatch';end if;
begin perform public.decide_instrumental_lease((select request from vault_fixture),'release');raise exception 'Unpaid master released';exception when raise_exception then if sqlerrm='Unpaid master released' then raise;end if;end;

begin perform public.record_invoice_payment((select invoice from vault_fixture),'payment',150,'cash',(now() at time zone 'America/Barbados')::date,'','',null,gen_random_uuid());raise exception 'Unapproved minor payment allowed';exception when raise_exception then if sqlerrm='Unapproved minor payment allowed' then raise;end if;end;
perform set_config('test.guardian_token',public.issue_guardian_invoice_link((select invoice from vault_fixture))->>'token',true);
perform public.guardian_invoice_portal(current_setting('test.guardian_token'),'approve','Test Guardian',true);
perform public.guardian_invoice_portal(current_setting('test.guardian_token'),'cash');
perform public.record_invoice_payment((select invoice from vault_fixture),'payment',150,'cash',(now() at time zone 'America/Barbados')::date,'','',null,gen_random_uuid());

perform public.decide_instrumental_lease((select request from vault_fixture),'release');
end $test$;
reset role;
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $test$ begin if not private.vault_asset_access((select beat||'/master/master.wav' from vault_fixture),false) then raise exception 'Paid released master blocked';end if;end $test$;
reset role;
reset role;
set local role anon;
do $test$ begin
if public.guardian_invoice_portal(current_setting('test.guardian_token'))->>'status'<>'approved' then raise exception 'Guardian view failed';end if;
perform public.guardian_invoice_portal(current_setting('test.guardian_token'),'cash');
perform public.guardian_invoice_portal(current_setting('test.guardian_token'),'cash');
end $test$;
reset role;
insert into private.studio_calendar_tickets(actor_id,booking_id,variant_id,starts_at,ends_at)
values('8da3fa1f-10ef-4fac-8294-279e6a9e61b1'::uuid,null,'196c7505-e8e8-4638-b0bb-83b6b2adf4c6'::uuid,'2032-11-01 16:00:00+00'::timestamptz,'2032-11-01 18:00:00+00'::timestamptz);
select set_config('test.minor_calendar_ticket',(select id::text from private.studio_calendar_tickets where actor_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1'::uuid and starts_at='2032-11-01 16:00:00+00'::timestamptz order by expires_at desc limit 1),true);
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $test$ declare j jsonb;p jsonb;begin
if exists(select 1 from public.studio_instrumentals) or exists(select 1 from public.studio_instrumental_requests) or exists(select 1 from public.studio_service_variants) or exists(select 1 from public.studio_bookings) or exists(select 1 from public.artist_projects) or exists(select 1 from public.studio_notifications) then raise exception 'Minor direct read bypass';end if;
j:=public.minor_workspace_data('vault');
if j::text like '%lease_price%' or j::text like '%licence_terms%' then raise exception 'Minor catalogue money leak';end if;
j:=public.minor_workspace_data('requests');if j::text like '%price_snapshot%' or j::text like '%terms_snapshot%' then raise exception 'Minor request money leak';end if;
j:=public.minor_workspace_data('notifications');if j::text like '%BBD 150%' then raise exception 'Minor notification money leak';end if;
perform public.create_calendar_studio_booking(current_setting('test.minor_calendar_ticket')::uuid,'196c7505-e8e8-4638-b0bb-83b6b2adf4c6','2032-11-01 12:00:00-04','Minor fixture');
if public.minor_workspace_data('bookings')::text like '%"price"%' or public.minor_workspace_data('variants')::text like '%"price"%' or public.minor_workspace_data('services')::text like '%catalogue_price%' then raise exception 'Minor booking money leak';end if;
p:=public.minor_project_write(null,'{"title":"Minor project fixture","kind":"single","brief":"Disposable"}');
perform public.minor_project_write((p->>'id')::uuid,'{"status":"released"}');
if public.minor_workspace_data('projects')::text like '%budget_amount%' then raise exception 'Budget leak';end if;
begin insert into public.artist_projects(user_id,title,budget_amount,budget_currency) values(auth.uid(),'Forbidden minor budget',100,'BBD');raise exception 'Minor budget insert allowed';exception when raise_exception then if sqlerrm='Minor budget insert allowed' then raise;end if;end;
begin perform public.manage_artist_guardian(auth.uid(),false,'','');raise exception 'Minor self reclassified';exception when insufficient_privilege then null;end;
perform public.minor_notifications_seen();
end $test$;
reset role;
update public.document_items set description='Material terms changed' where document_id=(select invoice from vault_fixture);
set local role anon;
do $test$ begin
begin perform public.guardian_invoice_portal(current_setting('test.guardian_token'));raise exception 'Changed invoice token accepted';exception when raise_exception then if sqlerrm='Changed invoice token accepted' then raise;end if;end;
end $test$;
reset role;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
select set_config('test.guardian_replacement',public.issue_guardian_invoice_link((select invoice from vault_fixture))->>'token',true);
reset role;
set local role anon;
do $test$ begin
begin perform public.guardian_invoice_portal(repeat('0',64));raise exception 'Forged token accepted';exception when raise_exception then if sqlerrm='Forged token accepted' then raise;end if;end;
begin perform public.guardian_invoice_portal(current_setting('test.guardian_replacement'),'approve','Test Guardian',false);raise exception 'No consent accepted';exception when raise_exception then if sqlerrm='No consent accepted' then raise;end if;end;
end $test$;
reset role;
update private.studio_guardian_links set expires_at=now()-interval '1 second' where token_hash=encode(extensions.digest(current_setting('test.guardian_replacement'),'sha256'),'hex');
set local role anon;
do $test$ begin
begin perform public.guardian_invoice_portal(current_setting('test.guardian_replacement'));raise exception 'Expired token accepted';exception when raise_exception then if sqlerrm='Expired token accepted' then raise;end if;end;
end $test$;
reset role;
rollback;
select 'PASS minor price/API protection, project workflow, guardian approval/payment/release, token portal, cash retry, changed terms invalidation; rolled back' result;