-- A layer that is only there while the music plays.
--
-- only_while_playing freezes a layer's animation when the audio stops. This
-- hides it outright, which is what lets a scene light up when playback
-- starts: the lit lamp and its pool of light are their own layer, and the
-- room underneath is painted dark.

alter table public.scene_layers
  add column if not exists hide_when_paused boolean not null default false;
