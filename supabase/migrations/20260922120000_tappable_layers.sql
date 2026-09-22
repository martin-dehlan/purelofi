-- A layer the listener can touch.
--
-- A tappable layer rests on its first frame and plays its animation once when
-- tapped, then rests again — the same shape as a rare event, but triggered by
-- a finger instead of a timer. The cat asleep on the bed is the first one.

alter table public.scene_layers
  add column if not exists tappable boolean not null default false;
