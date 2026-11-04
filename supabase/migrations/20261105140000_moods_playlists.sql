-- Moods and playlists (#141).
--
-- Moods are PureLofi's: curated lists of tracks, read by everyone, written
-- with the service role. Playlists are the listener's own, synced with the
-- account like favorites (#78) and scoped to auth.uid() the same way.

create table if not exists public.moods (
  id         uuid primary key default gen_random_uuid(),
  slug       text        not null unique,
  title      text        not null,
  cover_url  text,
  sort_order integer     not null default 0,
  is_active  boolean     not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.mood_tracks (
  mood_id  uuid    not null references public.moods (id) on delete cascade,
  track_id uuid    not null references public.tracks (id) on delete cascade,
  position integer not null default 0,
  primary key (mood_id, track_id)
);

alter table public.moods enable row level security;
alter table public.mood_tracks enable row level security;

drop policy if exists "active moods are public" on public.moods;
create policy "active moods are public"
  on public.moods for select
  to anon, authenticated
  using (is_active);

drop policy if exists "tracks of active moods are public" on public.mood_tracks;
create policy "tracks of active moods are public"
  on public.mood_tracks for select
  to anon, authenticated
  using (
    exists (select 1 from public.moods where moods.id = mood_tracks.mood_id and moods.is_active)
    and exists (select 1 from public.tracks where tracks.id = mood_tracks.track_id and tracks.is_active)
  );

revoke insert, update, delete, truncate, references, trigger
  on public.moods, public.mood_tracks
  from anon, authenticated;
grant select on public.moods, public.mood_tracks to anon, authenticated;

-- The listener's playlists. One row per playlist: the items are a short
-- ordered list read and written whole, so a jsonb array is the honest
-- shape. A deleted playlist keeps its row with deleted_at set, so the
-- deletion reaches the listener's other devices.
create table if not exists public.user_playlists (
  id         uuid primary key,
  user_id    uuid        not null references auth.users (id) on delete cascade,
  name       text        not null,
  -- [{"track_id": "...", "source": "catalogue"|"local"}, ...]
  items      jsonb       not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint user_playlists_name_length check (char_length(name) between 1 and 100),
  constraint user_playlists_items_array check (jsonb_typeof(items) = 'array')
);

create index if not exists user_playlists_user_id_idx
  on public.user_playlists (user_id);

alter table public.user_playlists enable row level security;

create policy "Listeners read their own playlists"
  on public.user_playlists for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Listeners add their own playlists"
  on public.user_playlists for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "Listeners change their own playlists"
  on public.user_playlists for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- No delete policy: a playlist is removed by setting deleted_at, and the
-- row goes with the account (cascade).
revoke all on public.user_playlists from anon;
revoke delete, truncate, references, trigger on public.user_playlists from authenticated;
grant select, insert, update on public.user_playlists to authenticated;
