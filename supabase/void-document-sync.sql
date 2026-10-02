create or replace function private.preserve_void_document()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  -- Retain void document history even when an older client syncs stale data.
  if old.status = 'void' then return old; end if;
  return new;
end;
$$;
revoke all on function private.preserve_void_document() from public;
create trigger zz_preserve_void_document before update on public.documents
for each row execute function private.preserve_void_document();