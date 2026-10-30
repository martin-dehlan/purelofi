-- Favorites that follow the account to every device (#78).
--
-- The first table that belongs to a listener rather than to PureLofi, so
-- every policy is scoped to auth.uid(): a listener reads, adds and removes
-- their own marks and can see nobody else's. There is no update policy —
-- a mark is there or it is not.
--
-- Both foreign keys cascade: deleting the account (delete_account()) takes
-- its marks with it, and a track pulled from the catalogue takes its marks
-- off every account.

create table if not exists public.user_favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  track_id uuid not null references public.tracks (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, track_id)
);

alter table public.user_favorites enable row level security;

create policy "Listeners read their own favorites"
  on public.user_favorites for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Listeners add their own favorites"
  on public.user_favorites for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "Listeners remove their own favorites"
  on public.user_favorites for delete
  to authenticated
  using (user_id = (select auth.uid()));

-- Nothing for anon: signed out, favorites stay on the device.
revoke all on public.user_favorites from anon;
grant select, insert, delete on public.user_favorites to authenticated;
