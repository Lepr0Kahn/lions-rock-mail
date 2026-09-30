drop policy artist_projects_create on public.artist_projects;
create policy artist_projects_create on public.artist_projects for insert to authenticated
with check ((select private.has_active_artist_access()) and
 (user_id=(select auth.uid()) or ((select private.is_studio_owner()) and exists(
 select 1 from public.app_memberships m where m.user_id=artist_projects.user_id and m.access_status='active'
 and m.artist_member_enabled and m.payment_status in ('paid','comped') and (m.expires_at is null or m.expires_at>now())))));
