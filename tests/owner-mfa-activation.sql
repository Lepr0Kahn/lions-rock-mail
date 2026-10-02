begin;
select set_config('request.jwt.claims','{"sub":"1204ab25-7433-43a5-80e1-7a66b2eee057","role":"authenticated","aal":"aal1"}',true);
set local role authenticated;
do $$begin begin perform public.configure_owner_mfa(false);raise exception 'unexpected allowed';exception when insufficient_privilege then null;end;end;$$;
select set_config('request.jwt.claims','{"sub":"8da3fa1f-10ef-4fac-8294-279e6a9e61b1","role":"authenticated","aal":"aal2"}',true);
do $$begin begin perform public.configure_owner_mfa(false);raise exception 'unexpected member allowed';exception when insufficient_privilege then null;end;end;$$;
select set_config('request.jwt.claims','{"sub":"1204ab25-7433-43a5-80e1-7a66b2eee057","role":"authenticated","aal":"aal2"}',true);
select public.configure_owner_mfa(false) verified_disable_result;
reset role;
rollback;
begin;
select set_config('request.jwt.claims','{"sub":"1204ab25-7433-43a5-80e1-7a66b2eee057","role":"authenticated","aal":"aal2"}',true);
do $$begin if (select count(*) from auth.mfa_factors where user_id='1204ab25-7433-43a5-80e1-7a66b2eee057' and status='verified' and factor_type='totp')<2 then
begin perform public.configure_owner_mfa(true);raise exception 'Backup gate unexpectedly allowed';exception when raise_exception then if sqlerrm<>'Verify a primary and a separate backup authenticator before enabling' then raise;end if;end;
end if;end;$$;
select 'Backup prerequisite checked without enrollment changes' result;
rollback;