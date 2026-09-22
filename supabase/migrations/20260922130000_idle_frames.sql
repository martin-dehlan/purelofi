-- A tappable layer that keeps living while it waits.
--
-- Until now a tappable layer rested on its first frame and played its whole
-- strip when touched, so it could idle or react but not both. With
-- idle_frame_count the strip is split: the first frames loop as the idle
-- animation, the rest play once as the reaction. The cat breathes while it
-- sleeps and stretches when it is touched.

alter table public.scene_layers
  add column if not exists idle_frame_count integer not null default 0,
  add constraint scene_layers_idle_frames_fit
    check (idle_frame_count >= 0 and idle_frame_count < frame_count);
