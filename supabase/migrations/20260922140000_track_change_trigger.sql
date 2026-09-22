-- A layer that reacts to the music changing.
--
-- Skipping a track should be visible in the room, not only in the transport:
-- the tuner on the cassette deck sweeps once when a new track starts.

alter table public.scene_layers
  add column if not exists on_track_change boolean not null default false;
