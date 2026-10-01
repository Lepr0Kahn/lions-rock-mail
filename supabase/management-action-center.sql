create or replace function public.studio_management_overview() returns jsonb language plpgsql security invoker set search_path='' as $fn$
declare result jsonb;today date:=(now() at time zone 'America/Barbados')::date;
begin
 if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
 with requests as (
 select b.id,b.user_id,b.service_name,b.variant_name,b.starts_at,b.ends_at,b.hold_expires_at from public.studio_bookings b where b.status='requested' and b.starts_at>now() and b.hold_expires_at>now()
 ), upcoming as (
 select b.id,b.user_id,b.service_name,b.variant_name,b.starts_at,b.ends_at from public.studio_bookings b where b.status='confirmed' and b.starts_at>=now()
 ), outstanding as (
 select d.id,d.doc_number,d.client_name,d.currency,d.balance_due,d.due_date from public.documents d where d.user_id=auth.uid() and d.doc_type='invoice' and d.status not in ('paid','void') and d.balance_due>0
 ), expiring as (
 select f.id,f.project_id,f.filename,f.expires_at,p.title project_title from public.artist_project_files f join public.artist_projects p on p.id=f.project_id where p.status<>'archived' and f.kind in ('master','mp3_delivery') and f.expires_at>now() and f.expires_at<=now()+interval '7 days'
 )
 select jsonb_build_object(
 'pending_count',(select count(*) from requests),
 'upcoming_count',(select count(*) from upcoming),
 'outstanding_count',(select count(*) from outstanding),
 'overdue_count',(select count(*) from outstanding where due_date<today),
 'expiring_count',(select count(*) from expiring),
 'currency_balances',coalesce((select jsonb_agg(to_jsonb(x)) from (select currency,sum(balance_due) balance_due from outstanding group by currency order by currency)x),'[]'::jsonb),
 'booking_requests',coalesce((select jsonb_agg(to_jsonb(x)) from (select * from requests order by hold_expires_at limit 5)x),'[]'::jsonb),
 'upcoming_sessions',coalesce((select jsonb_agg(to_jsonb(x)) from (select * from upcoming order by starts_at limit 5)x),'[]'::jsonb),
 'due_invoices',coalesce((select jsonb_agg(to_jsonb(x)||jsonb_build_object('overdue',x.due_date<today)) from (select * from outstanding order by due_date nulls last,id limit 5)x),'[]'::jsonb),
 'expiring_deliveries',coalesce((select jsonb_agg(to_jsonb(x)) from (select * from expiring order by expires_at limit 5)x),'[]'::jsonb),
 'computed_at',now(),'timezone','America/Barbados'
 ) into result;return result;
end;$fn$;
revoke all on function public.studio_management_overview() from public,anon;
grant execute on function public.studio_management_overview() to authenticated;
