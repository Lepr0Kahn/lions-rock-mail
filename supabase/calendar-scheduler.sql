create extension if not exists pg_cron;
create extension if not exists pg_net;
create function private.dispatch_studio_calendar_work() returns void language plpgsql security definer set search_path='' as $$
declare token text;action text;
begin
 if not (select enabled and not paused from private.studio_calendar_settings where singleton) then return;end if;
 delete from private.studio_calendar_runner_tokens where expires_at<now();
 foreach action in array array['recover','process'] loop
  if (action='process' and exists(select 1 from private.studio_calendar_operations where state='pending')) or (action='recover' and exists(select 1 from private.studio_calendar_operations where state='uncertain' or(state='running' and lease_until<now()))) then
   token:=encode(extensions.gen_random_bytes(32),'hex');
   insert into private.studio_calendar_runner_tokens(digest,expires_at) values(encode(extensions.digest(token,'sha256'),'hex'),now()+interval '2 minutes');
   perform net.http_post(url:='https://xsvczfqvscnvmngwcmtp.supabase.co/functions/v1/studio-calendar-worker',headers:=jsonb_build_object('Content-Type','application/json','apikey','sb_publishable_ZQGFWpZzlDsWBRclrySAyg_CYWqvU40','x-calendar-runner-token',token),body:=jsonb_build_object('action',action),timeout_milliseconds:=120000);
  end if;
 end loop;
end;$$;
revoke all on function private.dispatch_studio_calendar_work() from public,anon,authenticated;
select cron.schedule('studio-calendar-worker','* * * * *','select private.dispatch_studio_calendar_work()');
