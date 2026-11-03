-- Every channel an artist is on (#109), in the order the app shows them.
-- link_url stays for the builds that still read it; links is the list.
alter table public.artists
  add column links text[] not null default '{}';

update public.artists
   set links = array[link_url]
 where link_url is not null;

comment on column public.artists.links is
  'The artist''s channels (YouTube, SoundCloud, Spotify, ...), in order.';
comment on column public.artists.link_url is
  'Superseded by links (#109); kept for builds that still read it.';
