-- Exercise recorded payments only. All documents, events and counters roll back.
begin;
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);
set local role authenticated;
do $test$
declare p uuid;d uuid;initial_settled integer;initial_deposits integer;sig jsonb;n text;
begin
sig:=public.artist_career_tracks()->'signals';
initial_settled:=(sig->>'invoices_settled')::integer;
initial_deposits:=(sig->>'deposits_paid')::integer;
insert into public.artist_projects(title) values('Disposable payment correction regression') returning id into p;
insert into public.documents(user_id,artist_project_id,doc_type,status,doc_date,currency,total,amount_paid,deposit_pct)
values(auth.uid(),p,'invoice','open',current_date,'BBD',350,0,50) returning id,doc_number into d,n;
update public.documents set amount_paid=175 where id=d;
sig:=public.artist_career_tracks()->'signals';
if (sig->>'invoices_settled')::integer<>initial_settled or (sig->>'deposits_paid')::integer<>initial_deposits+1 then raise exception 'Half deposit incorrectly settled';end if;
if (select total-amount_paid from public.documents where id=d)<>175 then raise exception 'Deposit balance mismatch';end if;
if exists(select 1 from public.artist_career_events where source_id=d and event_key='invoice_settled') then raise exception 'Premature settlement event';end if;
update public.documents set amount_paid=350 where id=d;
sig:=public.artist_career_tracks()->'signals';
if (sig->>'invoices_settled')::integer<>initial_settled+1 then raise exception 'Full payment not counted';end if;
update public.documents set amount_paid=175 where id=d;
sig:=public.artist_career_tracks()->'signals';
if (sig->>'invoices_settled')::integer<>initial_settled then raise exception 'Corrected payment still settled';end if;
update public.documents set amount_paid=0 where id=d;
sig:=public.artist_career_tracks()->'signals';
if (sig->>'deposits_paid')::integer<>initial_deposits then raise exception 'Zero payment still credited';end if;
update public.documents set amount_paid=350 where id=d;
if (select count(*) from public.artist_career_events where source_id=d and event_key='invoice_settled')<>1 then raise exception 'Repeated settlement duplicated milestone';end if;
update public.documents set status='void' where id=d;
sig:=public.artist_career_tracks()->'signals';
if (sig->>'invoices_settled')::integer<>initial_settled or (sig->>'deposits_paid')::integer<>initial_deposits then raise exception 'Void invoice retains financial credit';end if;
if (select doc_number from public.documents where id=d) is distinct from n then raise exception 'Payment edit changed document number';end if;
end $test$;
rollback;
select 'PASS partial, full, corrected, zero and void payments; stable number; single settlement milestone' as result;
