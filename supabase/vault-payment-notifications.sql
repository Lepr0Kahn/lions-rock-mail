alter table public.studio_notifications drop constraint studio_notifications_action_kind_check;
alter table public.studio_notifications add constraint studio_notifications_action_kind_check check(action_kind in('bookings','project','vault','payments'));
create function private.capture_vault_payment_notification() returns trigger
language plpgsql security definer set search_path='' as $$
declare event uuid:=gen_random_uuid();heading text;detail text;recipient uuid;owner_id uuid;destination text;
begin
if tg_table_name='studio_instrumental_requests' then
 if tg_op='UPDATE' and new.status is not distinct from old.status then return new;end if;
 recipient:=new.user_id;destination:='vault';
 heading:=case new.status when 'requested' then 'Instrumental lease requested' when 'approved' then 'Instrumental lease approved' when 'released' then 'Instrumental master released' when 'denied' then 'Instrumental lease declined' else 'Instrumental lease updated' end;
 detail:=new.title_snapshot||'. Open the vault for current terms, payment and download status.';
 insert into public.studio_notifications(user_id,event_id,title,body,action_kind)
 select m.user_id,event,heading,detail,destination from public.app_memberships m
 where m.user_id=recipient or m.role='owner' on conflict(user_id,event_id) do nothing;
elsif tg_table_name='payments' then
 if new.kind='opening' then return new;end if;
 event:=new.id;owner_id:=new.user_id;
 heading:=case new.kind when 'payment' then 'Invoice payment recorded' when 'refund' then 'Invoice refund recorded' else 'Invoice payment corrected' end;
 select d.doc_number||' · '||d.currency||' '||abs(new.amount)::text||'. Recorded entry; open for current status.' into detail from public.documents d where d.id=new.document_id and d.user_id=owner_id;
 if detail is null then return new;end if;
 insert into public.studio_notifications(user_id,event_id,title,body,action_kind)
 values(owner_id,event,heading,detail,'payments') on conflict(user_id,event_id) do nothing;
 insert into public.studio_notifications(user_id,event_id,title,body,action_kind)
 select distinct r.user_id,event,heading,detail,'vault' from public.studio_instrumental_requests r
 where r.invoice_id=new.document_id and r.user_id<>owner_id
 on conflict(user_id,event_id) do nothing;
end if;
return new;
end;$$;
revoke all on function private.capture_vault_payment_notification() from public,anon,authenticated;
create trigger studio_vault_notifications after insert or update on public.studio_instrumental_requests for each row execute function private.capture_vault_payment_notification();
create trigger studio_payment_notifications after insert on public.payments for each row execute function private.capture_vault_payment_notification();
