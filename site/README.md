# purelofi.app

The static site behind the links in the app (#79): `/privacy` and `/terms`
are required by Google's OAuth consent screen and by both stores, because
PureLofi offers accounts and a subscription. `/imprint` is the German
Impressum.

Plain HTML, the app's palette and fonts, no build step. Deploy the folder as
is — for example on Vercel (`vercel deploy site --prod`, framework: Other) or
GitHub Pages — and point `purelofi.app` at it. `vercel.json` gives the pages
clean URLs (`/privacy` instead of `/privacy.html`), which is what the app
links to (`lib/common/utils/app_links.dart`).

The legal pages are **drafts**: replace every `[PLACEHOLDER]` and have them
reviewed before publishing.
