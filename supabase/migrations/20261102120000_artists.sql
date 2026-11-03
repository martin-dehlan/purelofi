-- The people behind the music.
--
-- PureLofi plays tracks by many lo-fi artists. Each track names the one who
-- made it, and the app gives every artist a page: who they are and where to
-- find more of their music.

create table if not exists public.artists (
  id         uuid primary key default gen_random_uuid(),
  name       text        not null,
  slug       text        not null unique,
  bio        text,
  avatar_url text,
  link_url   text,
  is_active  boolean     not null default true,
  created_at timestamptz not null default now()
);

alter table public.tracks
  add column if not exists artist_id uuid
  references public.artists (id) on delete set null;

-- The track's own artwork, square. Rooms stay the picture behind the
-- player; the cover is what a track looks like in a list.
alter table public.tracks
  add column if not exists cover_url text;

create index if not exists tracks_artist_id_idx on public.tracks (artist_id);

alter table public.artists enable row level security;

drop policy if exists "active artists are public" on public.artists;
create policy "active artists are public"
  on public.artists
  for select
  to anon, authenticated
  using (is_active);

insert into storage.buckets (id, name, public)
values ('artists', 'artists', true)
on conflict (id) do update set public = excluded.public;
