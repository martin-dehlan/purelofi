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

`vercel.json` gives clean URLs (`/privacy` instead of `/privacy.html`).
Deploy the folder with the Vercel CLI (framework: Other) and point
`purelofi.app` at it.

Fonts: Karla and Pixelify Sans, both under the SIL Open Font License (`a/OFL-*.txt`).
