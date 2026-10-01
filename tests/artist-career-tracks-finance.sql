begin;
update public.documents set total=100,amount_paid=100,status='paid' where id='7a80d820-a722-41e1-af1b-867553a1a6b0';
select set_config('request.jwt.claim.sub','1204ab25-7433-43a5-80e1-7a66b2eee057',true);set local role authenticated;
do $$ declare r jsonb;begin
r:=public.artist_career_tracks();
if (r#>>'{signals,invoices_settled}')::int<1 or (r#>>'{signals,deposits_paid}')::int<1 then raise exception 'Linked payment evidence missing';end if;
end;$$;
reset role;
update public.documents set status='void' where id='7a80d820-a722-41e1-af1b-867553a1a6b0';
set local role authenticated;
do $$ declare r jsonb;begin r:=public.artist_career_tracks();if (r#>>'{signals,invoices_settled}')::int<>0 or(r#>>'{signals,deposits_paid}')::int<>0 then raise exception 'Void invoice counted';end if;end;$$;
reset role;
update public.app_memberships set deleted_at=now() where user_id='8da3fa1f-10ef-4fac-8294-279e6a9e61b1';
set local role authenticated;
do $$ begin begin perform public.artist_career_tracks('8da3fa1f-10ef-4fac-8294-279e6a9e61b1');raise exception 'Removed target allowed';exception when insufficient_privilege then null;end;end;$$;
rollback;