-- A partial unique index cannot back an ON CONFLICT clause, which is how the
-- upload tool makes re-uploads idempotent. A plain unique index works and
-- still allows many scenes without a slug — Postgres treats NULLs as
-- distinct.

drop index if exists public.scenes_slug_key;

create unique index if not exists scenes_slug_key
  on public.scenes (slug);
