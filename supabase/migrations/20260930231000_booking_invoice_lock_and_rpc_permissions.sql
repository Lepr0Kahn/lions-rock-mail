create or replace function public.invoice_for_studio_booking(session_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare b public.studio_bookings%rowtype; d public.documents%rowtype; c public.clients%rowtype; m public.app_memberships%rowtype; seq bigint; item_rows jsonb;
begin
 if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('lions-rock-studio-calendar',0));
 select * into b from public.studio_bookings where id=session_id;
 if b.id is null then raise exception 'Booking not found';end if;
 perform pg_advisory_xact_lock(hashtextextended('studio-invoice-'||auth.uid()::text,0));
 select * into d from public.documents where user_id=auth.uid() and booking_id=b.id;
 if d.id is null then
   if b.status<>'confirmed' then raise exception 'Confirm the booking before creating its invoice';end if;
   select * into m from public.app_memberships where user_id=b.user_id;
   select * into c from public.clients where user_id=auth.uid() and lower(email)=lower(m.email) order by created_at limit 1;
   if c.id is null then
     insert into public.clients(user_id,name,email) values(auth.uid(),coalesce(nullif(m.business_name,''),m.email,'Artist'),m.email) returning * into c;
   end if;
   select coalesce(max(substring(doc_number from '^INV-([0-9]+)$')::bigint),0)+1 into seq from public.documents where user_id=auth.uid() and doc_number~'^INV-[0-9]+$';
   insert into public.documents(user_id,booking_id,client_id,doc_type,doc_number,status,doc_date,currency,deposit_pct,subtotal,total,balance_due,client_name,client_email,client_phone,client_address,notes)
   values(auth.uid(),b.id,c.id,'invoice','INV-'||lpad(seq::text,greatest(4,length(seq::text)), '0'),'open',(now() at time zone 'America/Barbados')::date,b.currency,b.deposit_percent,b.price,b.price,b.price,c.name,c.email,c.phone,c.address,
   'Studio booking '||b.id::text||E'\nSession: '||to_char(b.starts_at at time zone 'America/Barbados','DD Mon YYYY HH24:MI')||'–'||to_char(b.ends_at at time zone 'America/Barbados','HH24:MI')||' Barbados time.'||E'\n'||b.notes) returning * into d;
   insert into public.document_items(document_id,user_id,name,description,qty,unit_price,line_total) values(d.id,auth.uid(),b.service_name||' — '||b.variant_name,'Booked studio session',1,b.price,b.price);
 else
   select * into c from public.clients where id=d.client_id and user_id=auth.uid();
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('name',i.name,'desc',i.description,'qty',i.qty,'price',i.unit_price) order by i.sort_order),'[]'::jsonb) into item_rows from public.document_items i where i.document_id=d.id and i.user_id=auth.uid();
 return jsonb_build_object('client',to_jsonb(c),'document',to_jsonb(d)||jsonb_build_object('type',d.doc_type,'paid',d.status='paid','payment_status',case when d.status='paid' then 'paid' when d.amount_paid>0 then 'partial' else 'due' end,'items',item_rows,'project_name','','source_quote_id',d.converted_from_quote_id));
end;$$;
revoke all on function public.invoice_for_studio_booking(uuid) from public,anon;
grant execute on function public.invoice_for_studio_booking(uuid) to authenticated;
revoke execute on function public.create_studio_booking(uuid,timestamptz,text,uuid,uuid),public.create_studio_service(text,text,integer,numeric,text,integer),public.decide_studio_booking(uuid,text),public.register_artist_file(text,text),public.reissue_artist_delivery(uuid),public.studio_availability(date,uuid) from anon;