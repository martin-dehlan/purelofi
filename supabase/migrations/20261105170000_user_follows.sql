-- Following an artist (#147): the listener's own marks, synced with the
-- account like favorites (#78) and scoped to auth.uid() the same way.
-- Telling followers about a new track waits for push (#97).

create table if not exists public.user_follows (
  user_id    uuid not null references auth.users (id) on delete cascade,
  artist_id  uuid not null references public.artists (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, artist_id)
);

alter table public.user_follows enable row level security;

create policy "Listeners read their own follows"
  on public.user_follows for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Listeners follow for themselves"
  on public.user_follows for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "Listeners unfollow for themselves"
  on public.user_follows for delete
  to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.user_follows from anon;
revoke update, truncate, references, trigger on public.user_follows from authenticated;
grant select, insert, delete on public.user_follows to authenticated;
