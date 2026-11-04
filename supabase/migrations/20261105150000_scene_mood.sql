-- Music that fits the room (#143): a room can name a mood, and with
-- "Music follows the room" on, the stream plays that mood while the
-- listener is in it. One idea — a mood — feeds both the library and the
-- rooms, so the curating happens in one place.

alter table public.scenes
  add column if not exists mood_id uuid
  references public.moods (id) on delete set null;

comment on column public.scenes.mood_id is
  'The mood this room plays when "Music follows the room" is on (#143).';
