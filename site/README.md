# purelofi.app

One page and three legal pages, plain HTML, no build step.

- `index.html`, `style.css`, `world.js`: the landing page. A phone shows a
  room at its native size; the room's weather and light fill the page, and
  scrolling moves from room to room. The page plays no music; that stays in
  the app.
- `scenes.js`: the rooms' sprite layers as stored in Supabase (`scenes`,
  `scene_layers`), with their files copied into `a/`. Regenerate both when a
  room changes.
- `privacy.html`, `terms.html`, `imprint.html` with `legal.css`: the pages the
  app links to (`lib/common/utils/app_links.dart`). The app holds no legal
  text of its own, so these three URLs must stay as they are. They are
  **drafts**: replace every `[PLACEHOLDER]` and have them reviewed before
  publishing.

- **Not deployed:** `.vercelignore` keeps the web player below off the site
  until it is picked up again. To bring it back, empty that file, link it from
  `index.html`, add it to the sitemap and fill in `config.js` at deploy time.
- `listen.html`, `listen.css`, `listen.js`: the web player (#150). One room
  at a time from `scenes.js`, PureLofi's tracks shuffled from Supabase, the
  system's media keys. No account, no Pro, no downloads: a taste of the app.
  It needs `config.js` filled in at deploy time with the project URL and
  the **public anon key** (the same two values as the app's `.env`; never
  the service-role key). Left empty, the page says it is not on yet.
  The CSP in `vercel.json` allows `connect-src` and `media-src` to
  `https://*.supabase.co` for it.

- `sitemap.xml`, `robots.txt`: written by hand. List only pages that are live,
  under `www.purelofi.app` (the bare domain redirects there).

`vercel.json` gives clean URLs (`/privacy` instead of `/privacy.html`).
Deploy the folder with the Vercel CLI (framework: Other) and point
`purelofi.app` at it.

Fonts: Karla, DM Mono and Pixelify Sans, all under the SIL Open Font License (`a/OFL-*.txt`).
