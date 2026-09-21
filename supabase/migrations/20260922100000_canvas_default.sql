-- The authoring canvas is 320x696, not 320x568.
--
-- 568 is a 16:9 shape. Current phones are about 19.5:9, so the renderer had
-- to overshoot to cover the height and threw away a third of the width.
-- See docs/12.

alter table public.scenes
  alter column canvas_height set default 696;
