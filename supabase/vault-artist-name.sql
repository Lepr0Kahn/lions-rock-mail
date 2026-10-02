-- Require an Artist Name throughout Instrumental Vault requests and lease invoice creation.

create or replace function private.request_instrumental(beat_id uuid, licence_kind text, request_note text)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  b public.studio_instrumentals%rowtype;
  req uuid;
  t text;
  price numeric;
  artist_label text;
begin
  if auth.uid() is null or not private.has_active_artist_access() or private.is_studio_owner() then
    raise exception 'Active Artist required' using errcode='42501';
  end if;

  select nullif(btrim(artist_name),'') into artist_label
  from public.artist_career_profiles
  where user_id=auth.uid();

  if artist_label is null then
    raise exception 'Set your Artist Name before requesting an instrumental';
  end if;

  if licence_kind not in('lease','exclusive') then raise exception 'Invalid licence kind'; end if;

  select * into b from public.studio_instrumentals
  where id=beat_id and published and not archived
  for update;

  if b.id is null
     or b.sold_exclusive
     or exists(
       select 1 from public.studio_instrumental_requests
       where instrumental_id=beat_id
         and studio_instrumental_requests.licence_kind='exclusive'
         and status in('approved','released')
     )
  then raise exception 'Instrumental unavailable or reserved';
  end if;

  if licence_kind='exclusive' then
    if b.exclusive_price is null or length(btrim(b.exclusive_terms))<20 then
      raise exception 'Exclusive offer requires price and separate terms';
    end if;
    price:=b.exclusive_price;
    t:=b.exclusive_terms||E'\nExisting nonexclusive licences remain valid under their original terms. Download expiry does not terminate a licence.';
  else
    price:=b.lease_price;
    t:=b.licence_terms;
  end if;

  insert into public.studio_instrumental_requests(
    instrumental_id,user_id,price_snapshot,currency,terms_snapshot,title_snapshot,note,licence_kind
  )
  values(b.id,auth.uid(),price,b.currency,t,b.title,coalesce(request_note,''),licence_kind)
  returning id into req;

  return req;
end;
$function$;

create or replace function private.decide_instrumental_lease(request_id uuid, decision text)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  r public.studio_instrumental_requests%rowtype;
  doc public.documents%rowtype;
  member public.app_memberships%rowtype;
  docid uuid;
  artist_label text;
begin
  if auth.uid() is null or not private.is_studio_owner() or not private.has_active_artist_access() or not private.has_active_studio_access() then
    raise exception 'Active Owner required' using errcode='42501';
  end if;

  select * into r from public.studio_instrumental_requests where id=request_id;
  perform 1 from public.studio_instrumentals where id=r.instrumental_id for update;
  select * into r from public.studio_instrumental_requests where id=request_id for update;
  if r.id is null then raise exception 'Request not found'; end if;

  if decision='approve' then
    if r.status in('approved','released') then return r.invoice_id; end if;
    if r.status<>'requested' then raise exception 'Request closed'; end if;

    if exists(select 1 from public.studio_instrumentals where id=r.instrumental_id and sold_exclusive)
       or exists(
         select 1 from public.studio_instrumental_requests x
         where x.instrumental_id=r.instrumental_id
           and x.id<>r.id
           and x.status in('approved','released')
           and (x.licence_kind='exclusive' or (r.licence_kind='exclusive' and x.status='approved'))
       )
    then raise exception 'Resolve competing approved requests before this approval';
    end if;

    select * into member
    from public.app_memberships
    where user_id=r.user_id
      and access_status='active'
      and artist_member_enabled
      and payment_status in('paid','comped')
      and deleted_at is null
      and(expires_at is null or expires_at>now());

    if member.user_id is null then raise exception 'Artist access is inactive'; end if;

    select nullif(btrim(artist_name),'') into artist_label
    from public.artist_career_profiles
    where user_id=r.user_id;

    if artist_label is null then
      raise exception 'Artist must set an Artist Name before this request can be approved';
    end if;

    insert into public.documents(
      user_id,doc_type,status,doc_date,currency,deposit_pct,subtotal,total,balance_due,client_name,client_email,notes
    )
    values(
      auth.uid(),'invoice','open',(now() at time zone 'America/Barbados')::date,
      r.currency,100,r.price_snapshot,r.price_snapshot,r.price_snapshot,
      artist_label,member.email,
      (case when r.licence_kind='exclusive' then 'Exclusive instrumental: ' else 'Instrumental lease: ' end)
      ||r.title_snapshot||E'\nLicence terms: '||r.terms_snapshot
    )
    returning id into docid;

    insert into public.document_items(document_id,user_id,name,description,qty,unit_price,line_total)
    values(
      docid,auth.uid(),
      (case when r.licence_kind='exclusive' then 'Exclusive instrumental — ' else 'Instrumental lease — ' end)||r.title_snapshot,
      r.terms_snapshot,1,r.price_snapshot,r.price_snapshot
    );

    update public.studio_instrumental_requests set status='approved',invoice_id=docid where id=r.id;
    return docid;

  elsif decision='release' then
    select * into doc from public.documents where id=r.invoice_id for share;
    if r.status not in('approved','released')
       or doc.id is null
       or doc.user_id<>auth.uid()
       or doc.doc_type<>'invoice'
       or doc.status in('draft','void')
       or doc.currency<>r.currency
       or doc.total<r.price_snapshot
       or doc.amount_paid<doc.total
    then raise exception 'Full lease payment must be recorded on your invoice before release';
    end if;

    if r.licence_kind='exclusive' then
      update public.studio_instrumentals set sold_exclusive=true,published=false,archived=true
      where id=r.instrumental_id;
    end if;

    update public.studio_instrumental_requests
    set status='released',released_at=coalesce(released_at,now())
    where id=r.id;
    return r.invoice_id;

  elsif decision='deny' then
    if r.status<>'requested' then raise exception 'Only pending requests can be denied'; end if;
    update public.studio_instrumental_requests set status='denied' where id=r.id;
    return null;
  else
    raise exception 'Invalid decision';
  end if;
end;
$function$;
