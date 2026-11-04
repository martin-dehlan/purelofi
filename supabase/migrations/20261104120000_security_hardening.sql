-- Security hardening from the audit of 2026-11-04.
--
-- Row-level security is what keeps the content read-only, and it does. But
-- Supabase's default privileges hand anon and authenticated ALL on every new
-- table in public, so the only thing between a stranger and an UPDATE is
-- that no policy allows it. One `disable row level security` in the
-- dashboard, or one over-broad policy, and that is gone — and TRUNCATE is
-- not subject to RLS at all. The privileges should say what the policies
-- say: the content tables are read, and nothing else.

-- Content: the app reads it, the upload tool writes it with the service
-- role. Nobody else writes, so nobody else gets the privilege.
revoke insert, update, delete, truncate, references, trigger
  on public.scenes, public.scene_layers, public.tracks, public.artists
  from anon, authenticated;

grant select
  on public.scenes, public.scene_layers, public.tracks, public.artists
  to anon, authenticated;

-- Favorites: a mark is there or it is not. The policies already allow only
-- select, insert and delete; the grants now match them.
revoke update, truncate, references, trigger
  on public.user_favorites
  from authenticated;

-- Artist links are opened outside the app, so they must be web links. A
-- `javascript:`, `intent:` or `file:` URL in a row should be refused by the
-- database, not trusted by every client that reads it. NOT VALID: rows that
-- are already there are not re-checked here, only what is written from now
-- on — the client filters anything older (lib/features/player/domain/
-- artist_link.dart).
--
-- Every entry has to start with http:// or https://: joined by newlines, no
-- line may start with anything else.
alter table public.artists
  drop constraint if exists artists_links_are_web,
  add constraint artists_links_are_web
    check (
      cardinality(links) = 0
      or array_to_string(links, E'\n') !~* '(^|\n)(?!https?://)'
    ) not valid;

alter table public.artists
  drop constraint if exists artists_link_url_is_web,
  add constraint artists_link_url_is_web
    check (link_url is null or link_url ~* '^https?://') not valid;
