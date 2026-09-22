-- A layer that would rather not be seen than be seen half off the edge.
--
-- Scenes are scaled by whole device pixels to stay crisp, so the scale is
-- rounded up and the overflow falls off the sides. A background is meant to
-- bleed that way. A single object is not: the cat on the bed reads as a cat
-- falling off the bed once the mattress under it has been cropped away.
--
-- With this set, the renderer draws the layer only when all of it fits.

alter table public.scene_layers
  add column if not exists hide_when_clipped boolean not null default false;
