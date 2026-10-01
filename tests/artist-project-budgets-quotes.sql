begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $test$ declare p uuid; d uuid; r jsonb; r2 jsonb; n text; begin
insert into public.artist_projects(title,budget_amount,budget_currency) values('Disposable budget and quote test',450,'BBD') returning id into p;
r:=public.quote_for_artist_project(p);r2:=public.quote_for_artist_project(p);
d:=(r->'document'->>'id')::uuid;
if d is distinct from (r2->'document'->>'id')::uuid then raise exception 'duplicate quote';end if;
select doc_number into n from public.documents where id=d;
if n is null or n not like 'QUO%' then raise exception 'quote numbering missing';end if;
if not exists(select 1 from public.documents where id=d and artist_project_id=p and total=0 and deposit_pct=50) then raise exception 'quote link/defaults mismatch';end if;
begin update public.artist_projects set budget_amount=-1 where id=p;raise exception 'negative budget accepted';exception when check_violation then null;end;
update public.artist_projects set budget_amount=null,budget_currency=null where id=p;
insert into public.document_items(document_id,user_id,name,qty,unit_price,line_total) values(d,auth.uid(),'Disposable test service',1,100,100);
update public.documents set status='open',total=100 where id=d;
if (public.artist_career_tracks()#>>'{signals,quotes}')::integer<1 then raise exception 'saved quote not counted';end if;
insert into public.documents(user_id,artist_project_id,client_id,doc_type,status,doc_date,currency,total,amount_paid,converted_from_quote_id)
select user_id,artist_project_id,client_id,'invoice','open',doc_date,currency,100,0,id from public.documents where id=d;
if not exists(select 1 from public.documents where artist_project_id=p and doc_type='invoice' and doc_number like 'INV%') then raise exception 'invoice number missing';end if;
update public.documents set amount_paid=100 where artist_project_id=p and doc_type='invoice';
if not exists(select 1 from public.artist_career_events e join public.documents x on x.id=e.source_id where x.artist_project_id=p and e.event_key='invoice_settled') then raise exception 'project settlement event missing';end if;
update public.documents set amount_paid=100 where artist_project_id=p and doc_type='invoice';
if (select count(*) from public.artist_career_events e join public.documents x on x.id=e.source_id where x.artist_project_id=p and e.event_key='invoice_settled')<>1 then raise exception 'duplicate settlement event';end if;
if (public.artist_career_tracks()#>>'{signals,invoices_settled}')::integer<1 then raise exception 'settled invoice not counted';end if;
update public.documents set status='void' where artist_project_id=p and doc_type='invoice';
if (public.artist_career_tracks()#>>'{signals,invoices_settled}')::integer>(select count(*) from public.documents x where x.doc_type='invoice' and x.artist_project_id is distinct from p and x.status<>'void' and x.total>0 and x.amount_paid>=x.total) then raise exception 'void invoice still eligible';end if;
update public.documents set status='void' where id=d;
if exists(select 1 from public.documents where id=d and status<>'void') then raise exception 'void test failed';end if;
raise notice 'PASS quote idempotency, numbered draft, 50 percent default, budget independent and validation';
end $test$;
rollback;
begin;
-- Grant test-only Artist eligibility inside this transaction; rollback restores current access.
update public.app_memberships set access_status='active',payment_status='comped',artist_member_enabled=true,deleted_at=null,expires_at=null where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
insert into public.artist_projects(id,user_id,title) values('b693e947-1b99-4895-a1ca-ae3dc7a9da67','1204ab25-7433-43a5-80e1-7a66b2eee057','Disposable isolation test');
select set_config('request.jwt.claim.sub','8da3fa1f-10ef-4fac-8294-279e6a9e61b1',true);
set local role authenticated;
do $t$ declare n integer;r jsonb;begin
update public.artist_projects set budget_amount=100,budget_currency='BBD' where id='b693e947-1b99-4895-a1ca-ae3dc7a9da67';get diagnostics n=row_count;
if n<>0 then raise exception 'cross artist budget update';end if;
begin perform public.quote_for_artist_project('b693e947-1b99-4895-a1ca-ae3dc7a9da67');raise exception 'member quote action permitted';exception when insufficient_privilege then null;end;
r:=public.artist_career_tracks();
if r#>>'{tracks,network,available_max}'<>'100' or r#>>'{tracks,business,available_max}'<>'100' then raise exception 'coverage mismatch';end if;
end $t$;rollback;