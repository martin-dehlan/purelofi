-- A stable handle for a scene, so uploading the same folder twice updates
-- the scene instead of creating a second one.
--
-- The app never reads it; it exists for tool/upload_scene.dart.

alter table public.scenes
  add column if not exists slug text;

create unique index if not exists scenes_slug_key
  on public.scenes (slug)
  where slug is not null;
