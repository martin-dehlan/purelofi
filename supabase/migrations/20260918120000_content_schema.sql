-- PureLofi content schema: the scenes and tracks the player streams.
--
-- Public, read-only content. There is no auth in the MVP, so the anon role
-- may read active rows and nothing else — no insert, update or delete policy
-- exists, which denies those to anon and authenticated alike.

create extension if not exists "pgcrypto";

-- Looping pixel-art backgrounds.
create table if not exists public.scenes (
  id            uuid primary key default gen_random_uuid(),
  title         text        not null,
  video_url     text        not null,
  thumbnail_url text,
  sort_order    integer     not null default 0,
  is_active     boolean     not null default true,
  created_at    timestamptz not null default now()
);

-- The music: real guitar/bass recordings, plus the proof they are real.
create table if not exists public.tracks (
  id               uuid primary key default gen_random_uuid(),
  title            text        not null,
  audio_url        text        not null,
  bts_video_url    text,
  duration_seconds integer,
  is_active        boolean     not null default true,
  created_at       timestamptz not null default now(),
  constraint tracks_duration_positive
    check (duration_seconds is null or duration_seconds > 0)
);

-- The player orders scenes by sort_order and filters both tables on is_active.
create index if not exists scenes_active_sort_order_idx
  on public.scenes (sort_order)
  where is_active;

create index if not exists tracks_active_created_at_idx
  on public.tracks (created_at)
  where is_active;

alter table public.scenes enable row level security;
alter table public.tracks enable row level security;

-- Inactive rows stay invisible to the client, not just unrequested.
drop policy if exists "active scenes are public" on public.scenes;
create policy "active scenes are public"
  on public.scenes
  for select
  to anon, authenticated
  using (is_active);

drop policy if exists "active tracks are public" on public.tracks;
create policy "active tracks are public"
  on public.tracks
  for select
  to anon, authenticated
  using (is_active);

-- Storage: public read, uploads happen with the service role key.
insert into storage.buckets (id, name, public)
values
  ('scenes', 'scenes', true),
  ('tracks', 'tracks', true),
  ('bts',    'bts',    true)
on conflict (id) do update set public = excluded.public;
