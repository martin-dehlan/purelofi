-- Layered scenes: a scene is a stack of pixel-art sprite layers rather than
-- one video.
--
-- Video stays supported. A scene with no rows in scene_layers still plays its
-- video_url, so both kinds can coexist and a scene can be converted one at a
-- time.
--
-- Why layers: a video codec fights pixel art. Chroma subsampling smears 1px
-- highlights, DCT ringing softens hard edges, rain eats bitrate, and the
-- device scales 1080x1920 by a non-integer factor. Sprites let the client
-- pick an integer scale and draw with no filtering at all.

-- The authoring grid. The client scales by an integer factor from here, then
-- crops the overflow, which is what keeps the pixels square.
alter table public.scenes
  add column if not exists canvas_width  integer not null default 320,
  add column if not exists canvas_height integer not null default 568;

create table if not exists public.scene_layers (
  id         uuid primary key default gen_random_uuid(),
  scene_id   uuid not null references public.scenes(id) on delete cascade,

  -- Draw order, 0 = furthest back.
  z_index    integer not null,

  -- A horizontal strip of frame_count frames, each canvas-space sized.
  sprite_url  text    not null,
  frame_count integer not null default 1,
  fps         numeric not null default 0,

  -- Placement on the canvas, in canvas pixels.
  offset_x   integer not null default 0,
  offset_y   integer not null default 0,

  -- 1.0 moves with the camera, 0.5 moves half as far — depth without 3D.
  parallax   numeric not null default 1.0,

  -- Repeat across the canvas instead of being placed once (rain, dust).
  tiles      boolean not null default false,

  -- Advances only while audio plays: the tape reels stop when the music does.
  only_while_playing boolean not null default false,

  -- Set on both to make this a rare event rather than a loop: it fires at a
  -- random point in the range, plays once, then rests on its first frame.
  event_interval_min_seconds integer,
  event_interval_max_seconds integer,

  created_at timestamptz not null default now(),

  constraint scene_layers_frame_count_positive
    check (frame_count > 0),
  constraint scene_layers_fps_not_negative
    check (fps >= 0),
  constraint scene_layers_parallax_sane
    check (parallax >= 0 and parallax <= 2),
  -- An event needs both bounds, in order, or neither.
  constraint scene_layers_event_interval_complete
    check (
      (event_interval_min_seconds is null and event_interval_max_seconds is null)
      or (
        event_interval_min_seconds is not null
        and event_interval_max_seconds is not null
        and event_interval_min_seconds > 0
        and event_interval_max_seconds >= event_interval_min_seconds
      )
    ),
  -- An animation needs a frame rate; a still layer must not claim one.
  constraint scene_layers_animation_needs_fps
    check ((frame_count = 1 and fps = 0) or (frame_count > 1 and fps > 0))
);

-- One layer per depth per scene: draw order is unambiguous.
create unique index if not exists scene_layers_scene_z_index_key
  on public.scene_layers (scene_id, z_index);

alter table public.scene_layers enable row level security;

-- Layers of an inactive scene stay invisible, like the scene itself.
drop policy if exists "layers of active scenes are public" on public.scene_layers;
create policy "layers of active scenes are public"
  on public.scene_layers
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.scenes
      where scenes.id = scene_layers.scene_id
        and scenes.is_active
    )
  );
