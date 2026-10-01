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
raise notice 'PASS quote idempotency, numbered draft, 50 percent default, budget independent and validation';
end $test$;
rollback;
begin;
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