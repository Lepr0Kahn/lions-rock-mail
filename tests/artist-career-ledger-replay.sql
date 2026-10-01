begin;
update public.documents set total=100,amount_paid=100,status='paid' where id='7a80d820-a722-41e1-af1b-867553a1a6b0';
update public.documents set total=100,amount_paid=100,status='paid' where id='7a80d820-a722-41e1-af1b-867553a1a6b0';
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);set local role authenticated;
do $$ declare n integer;after_n integer;begin
if(select count(*) from public.artist_career_events where event_key='invoice_settled' and source_id='7a80d820-a722-41e1-af1b-867553a1a6b0')<>1 then raise exception 'Invoice milestone replay';end if;
select count(*) into n from public.artist_career_events;perform public.artist_career_tracks();perform public.artist_career_history();perform public.artist_career_tracks();select count(*) into after_n from public.artist_career_events;if n<>after_n then raise exception 'Reading progress awards milestones';end if;
end;$$;rollback;
select has_function_privilege('anon','public.artist_career_history(uuid)','EXECUTE') anonymous_history,has_function_privilege('anon','public.reverse_artist_career_event(uuid,text)','EXECUTE') anonymous_reversal,has_function_privilege('authenticated','private.record_career_event(uuid,text,uuid)','EXECUTE') direct_record;
