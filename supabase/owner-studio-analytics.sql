CREATE OR REPLACE FUNCTION private.studio_analytics(window_days integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare since_at timestamptz; artist record; track record; signals jsonb; scores jsonb; stages jsonb:='{"join":0,"discover":0,"plan":0,"create":0,"produce":0,"prepare":0,"release":0,"grow":0}';totals jsonb:='{"creative":0,"momentum":0,"audience":0,"network":0,"business":0}';names text[]:=array['join','discover','plan','create','produce','prepare','release','grow'];gates boolean[];reached integer;i integer;members integer:=0;inactive jsonb:='[]';last_activity timestamptz;milestones bigint;contributors bigint;finance jsonb;bookings jsonb;
begin
if auth.uid() is null or not private.is_studio_owner() or not private.has_active_studio_access() or not private.has_active_artist_access() then raise exception 'Active Owner access required' using errcode='42501';end if;
if window_days is null or window_days not in (7,30,90) then raise exception 'Choose 7, 30 or 90 days';end if;
since_at:=now()-make_interval(days=>window_days);
for artist in select m.user_id,coalesce(nullif(m.business_name,''),m.email) name from public.app_memberships m where m.role<>'owner' and m.artist_member_enabled and m.access_status='active' and m.payment_status in ('paid','comped') and m.deleted_at is null and (m.expires_at is null or m.expires_at>now()) order by m.user_id loop
 members:=members+1;
 scores:=public.artist_career_tracks(artist.user_id);signals:=scores->'signals';
 gates:=array[true,(signals->>'profile')::int>0,(signals->>'projects')::int>0,(signals->>'uploads')::int>0,(signals->>'bookings')::int>0,(signals->>'masters')::int>0,(signals->>'masters_collected')::int>0,(signals->>'releases')::int>0];
 reached:=1;for i in 2..8 loop if gates[i] then reached:=i;else exit;end if;end loop;
 stages:=jsonb_set(stages,array[names[reached]],to_jsonb((stages->>names[reached])::int+1));
 for track in select key,value from jsonb_each(scores->'tracks') loop totals:=jsonb_set(totals,array[track.key],to_jsonb((totals->>track.key)::numeric+(track.value->>'score')::numeric));end loop;
 select max(e.occurred_at) into last_activity from public.artist_career_events e where e.user_id=artist.user_id and e.occurred_at<=now() and not e.backfilled and private.career_event_eligible(e) and not exists(select 1 from public.artist_career_event_reversals r where r.event_id=e.id);
 if last_activity is null or last_activity<since_at then inactive:=inactive||jsonb_build_array(jsonb_build_object('artist_id',artist.user_id,'name',artist.name,'last_activity',last_activity));end if;
end loop;
for track in select key,value from jsonb_each(totals) loop totals:=jsonb_set(totals,array[track.key],case when members=0 then 'null'::jsonb else to_jsonb(round((track.value#>>'{}')::numeric/members,1)) end);end loop;
select count(*),count(distinct e.user_id) into milestones,contributors from public.artist_career_events e join public.app_memberships m on m.user_id=e.user_id where m.role<>'owner' and m.artist_member_enabled and m.access_status='active' and m.payment_status in ('paid','comped') and m.deleted_at is null and(m.expires_at is null or m.expires_at>now()) and e.occurred_at>=since_at and e.occurred_at<=now() and not e.backfilled and private.career_event_eligible(e) and not exists(select 1 from public.artist_career_event_reversals r where r.event_id=e.id);
select coalesce(jsonb_agg(to_jsonb(x)),'[]') into finance from (
select currency,count(*) invoices,sum(total) invoiced,sum(coalesce(amount_paid,0)) recorded_paid,sum(greatest(total-coalesce(amount_paid,0),0)) outstanding from public.documents where user_id=auth.uid() and doc_type='invoice' and status not in ('draft','void') group by currency order by currency)x;
select jsonb_build_object('created',count(*),'confirmed',count(*) filter(where status='confirmed'),'requested',count(*) filter(where status='requested'),'cancelled',count(*) filter(where status='cancelled')) into bookings from public.studio_bookings where created_at>=since_at and created_at<=now();
return jsonb_build_object('days',window_days,'since',since_at,'computed_at',now(),'active_artists',members,'milestones',milestones,'contributing_artists',contributors,'milestones_per_artist',case when members>0 then round(milestones::numeric/members,2) else null end,'evidence_stages',stages,'track_averages',totals,'no_recent_milestones',inactive,'bookings',bookings,'finance_snapshot',finance);
end;$function$;

CREATE OR REPLACE FUNCTION public.studio_analytics(window_days integer DEFAULT 30) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$select private.studio_analytics(window_days);$$;
REVOKE ALL ON FUNCTION private.studio_analytics(integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.studio_analytics(integer) TO authenticated;
REVOKE ALL ON FUNCTION public.studio_analytics(integer) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.studio_analytics(integer) TO authenticated;
