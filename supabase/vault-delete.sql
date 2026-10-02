-- Owner-only Vault deletion policies.
-- Lease/request history is protected by the existing FK from studio_instrumental_requests.

grant delete on table public.studio_instrumentals to authenticated;

drop policy if exists instrumentals_delete on public.studio_instrumentals;
create policy instrumentals_delete
on public.studio_instrumentals
for delete
to authenticated
using (
  private.is_studio_owner()
  and private.has_active_artist_access()
  and private.has_active_studio_access()
);

drop policy if exists vault_asset_delete on storage.objects;
create policy vault_asset_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'studio-instrumentals'
  and private.is_studio_owner()
  and private.has_active_artist_access()
  and private.has_active_studio_access()
);
