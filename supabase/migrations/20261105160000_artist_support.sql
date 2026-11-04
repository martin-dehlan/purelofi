-- A way to support an artist directly (#152): their Bandcamp, Ko-fi,
-- Patreon. The money goes from the listener to the artist; PureLofi only
-- links. A web link only, like every other link the app opens.

alter table public.artists
  add column if not exists support_url text;

alter table public.artists
  drop constraint if exists artists_support_url_is_web,
  add constraint artists_support_url_is_web
    check (support_url is null or support_url ~* '^https://');

comment on column public.artists.support_url is
  'Where to support the artist directly (Bandcamp, Ko-fi, Patreon...) (#152).';
