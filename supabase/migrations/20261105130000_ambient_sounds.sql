-- Ambient sounds (#136): the rain, fire and trains the rooms show, heard.
--
-- Real recordings or CC0, never generated — the same rule as the music.
-- Each room lists the sounds it brings and how loud each starts; the
-- listener's own mix stays on their device.

create table if not exists public.ambient_sounds (
  id         uuid primary key default gen_random_uuid(),
  slug       text        not null unique,
  title      text        not null,
  -- A seamless loop, 60–120 s.
  audio_url  text        not null,
  sort_order integer     not null default 0,
  is_active  boolean     not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.scene_ambients (
  scene_id      uuid    not null references public.scenes (id) on delete cascade,
  ambient_id    uuid    not null references public.ambient_sounds (id) on delete cascade,
  default_level numeric not null default 0.5,
  primary key (scene_id, ambient_id),
  constraint scene_ambients_level_range
    check (default_level >= 0 and default_level <= 1)
);

alter table public.ambient_sounds enable row level security;
alter table public.scene_ambients enable row level security;

drop policy if exists "active ambient sounds are public" on public.ambient_sounds;
create policy "active ambient sounds are public"
  on public.ambient_sounds
  for select
  to anon, authenticated
  using (is_active);

-- A room's sounds are as visible as the room and the sound themselves.
drop policy if exists "ambients of active scenes are public" on public.scene_ambients;
create policy "ambients of active scenes are public"
  on public.scene_ambients
  for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.scenes
      where scenes.id = scene_ambients.scene_id and scenes.is_active
    )
    and exists (
      select 1 from public.ambient_sounds
      where ambient_sounds.id = scene_ambients.ambient_id
        and ambient_sounds.is_active
    )
  );

-- Read, nothing else: the same grants as every content table since the
-- security hardening.
revoke insert, update, delete, truncate, references, trigger
  on public.ambient_sounds, public.scene_ambients
  from anon, authenticated;
grant select on public.ambient_sounds, public.scene_ambients
  to anon, authenticated;

insert into storage.buckets (id, name, public)
values ('ambient', 'ambient', true)
on conflict (id) do update set public = excluded.public;
