-- Database integration only. Provider availability, email and browser acceptance
-- require a separately reviewed live booking. All mutations below roll back.
begin;
do $$
declare actor uuid; offering public.studio_service_variants%rowtype;start_time timestamptz;
ticket jsonb;booking uuid;first_invoice jsonb;again jsonb;generator_id uuid:=gen_random_uuid();
quote_id uuid:=gen_random_uuid();generator_number text;quote_number text;next_number text;invoice_number text;
begin
 select user_id into actor from public.app_memberships where role='owner' and access_status='active'
 and deleted_at is null and artist_member_enabled and business_tools_enabled and payment_status in ('paid','comped')
 and (expires_at is null or expires_at>now()) limit 1;
 if actor is null then raise exception 'Active Owner fixture required';end if;
 select * into offering from public.studio_service_variants where id='0b305aae-87cc-4274-9656-bf1e921364ef';
 perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',actor)::text,true);
 select starts_at into start_time from public.studio_availability((now() at time zone 'America/Barbados')::date+30,offering.id) where available order by starts_at limit 1;
 if start_time is null then raise exception 'No OS test slot';end if;
 generator_number:=public.reserve_document_number(generator_id,'invoice');
 quote_number:=public.reserve_document_number(quote_id,'quote');
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 ticket:=public.studio_calendar_backend('ticket',jsonb_build_object('actorId',actor,'variantId',offering.id,'start',start_time,'end',start_time+make_interval(mins=>offering.duration_minutes)));
 perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',actor)::text,true);
 booking:=public.create_calendar_studio_booking((ticket->>'ticket')::uuid,offering.id,start_time,'ROLLBACK ONLY — integration verification');
 first_invoice:=public.invoice_for_studio_booking(booking);
 again:=public.invoice_for_studio_booking(booking);
 invoice_number:=first_invoice->'document'->>'doc_number';
 if first_invoice->'document'->>'id'<>again->'document'->>'id' then raise exception 'Duplicate booking invoice';end if;
 if (first_invoice->'document'->>'total')::numeric<>offering.price or (first_invoice->'document'->>'deposit_pct')::numeric<>offering.deposit_percent then raise exception 'Booking price/deposit mismatch';end if;
 if substring(invoice_number from '[0-9]+$')::bigint<>substring(generator_number from '[0-9]+$')::bigint+1 then raise exception 'Generator and OS invoice sequences diverged';end if;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 ticket:=public.studio_calendar_backend('ticket',jsonb_build_object('actorId',actor,'bookingId',booking,'variantId',offering.id,'start',start_time+interval '1 day','end',start_time+interval '1 day 2 hours'));
 perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',actor)::text,true);
 perform public.reschedule_calendar_studio_booking((ticket->>'ticket')::uuid,booking,start_time+interval '1 day',120);
 again:=public.invoice_for_studio_booking(booking);
 if first_invoice->'document'->>'id'<>again->'document'->>'id' or invoice_number<>again->'document'->>'doc_number' or first_invoice->'document'->>'total'<>again->'document'->>'total' then raise exception 'Rescheduling changed invoice identity/price';end if;
 perform public.decide_studio_booking(booking,'cancelled');
 again:=public.invoice_for_studio_booking(booking);
 if first_invoice->'document'->>'id'<>again->'document'->>'id' then raise exception 'Cancellation changed invoice identity';end if;
 next_number:=public.reserve_document_number(gen_random_uuid(),'invoice');
 if substring(next_number from '[0-9]+$')::bigint<>substring(invoice_number from '[0-9]+$')::bigint+1 then raise exception 'Next generator invoice number incorrect';end if;
 if public.reserve_document_number(quote_id,'quote')<>quote_number then raise exception 'Quote retry changed number';end if;
end;$$;
select 'PASS: booking/invoice idempotency, deposit snapshot, reschedule/cancel, shared numbering — rollback only' result;
rollback;
