-- What a screen reader says for a tappable layer (#153): "Pet the cat".
--
-- A tappable layer is a button drawn in pixels, and a button needs a name.
-- Without one the layer stays out of the screen reader's way, which is
-- better than a button called nothing.

alter table public.scene_layers
  add column if not exists tap_label text;

comment on column public.scene_layers.tap_label is
  'Screen-reader label for a tappable layer, e.g. "Pet the cat".';
