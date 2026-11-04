# Security audit — 2026-11-04

Scope: the Flutter app (`lib/`), the Supabase schema (`supabase/migrations`,
`supabase/config.toml`), the upload tool (`tool/`), the Android and iOS
shells, the website (`site/`, Vercel), CI, and the third-party services the
app talks to (Supabase Auth/PostgREST/Storage, RevenueCat, PostHog, Google
and Apple sign-in).

The live Supabase project could not be scanned: the Supabase account
connected to the audit holds no PureLofi project. Everything about the
database below is read from the migrations and was checked against a local
Postgres with Supabase's roles and default privileges. The dashboard-only
settings are listed under **To do by hand**.

## What is already right

- Secrets are split correctly: `.env` (bundled) holds only publishable keys,
  `.env.tools` holds the service role key, and `Env.load()` refuses to start
  with a banned key in `.env`. No secret was ever committed (git history
  checked for JWTs, `sk_`, `sb_secret_`, `.env`, `key.properties`).
- RLS is on for every table. Content is select-only for `anon`/`authenticated`
  and filters inactive rows; `user_favorites` is scoped to `auth.uid()`.
- `delete_account()` is `security definer` with `search_path = ''`, takes no
  argument (can only delete the caller), and is revoked from `public`/`anon`.
- Storage buckets are public-read with no `storage.objects` policies, so they
  can be neither listed nor written by clients.
- Sign-in: Apple uses a SHA-256 nonce from `Random.secure()`; Google and
  email go through Supabase; the browser fallback uses supabase_flutter's
  PKCE flow, so an app that also claims `purelofi://` cannot use an
  intercepted callback on its own.
- Analytics: PostHog is identified by user id only, a `beforeSend` scrubber
  removes emails and file paths from error reports, EU host.
- Android: no cleartext traffic, release keystore kept out of the repo.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | Medium | Supabase's default privileges leave `anon`/`authenticated` with INSERT/UPDATE/DELETE/TRUNCATE on the content tables, and UPDATE/TRUNCATE on `user_favorites`. Only RLS stood in the way, and TRUNCATE ignores RLS. | Fixed — migration `20261104120000_security_hardening.sql` |
| 2 | Medium | Artist links from the database were handed to the OS URL handler unchecked: `intent:`, `file:`, `tel:`, `javascript:` or another app's custom scheme would have been opened. | Fixed — `isWebLink()` filters links; `AppLinks.open` only passes `https`/`http`/`mailto`; DB check constraints refuse non-web links |
| 3 | Medium | Android backup (cloud, device transfer, `adb backup` < API 31) included Flutter's shared preferences, which hold the Supabase access and refresh token. | Fixed — `backup_rules.xml` / `data_extraction_rules.xml` exclude them |
| 4 | Medium | The website sent no security headers (no CSP, HSTS, framing or MIME-sniffing protection). | Fixed — headers in `site/vercel.json` |
| 5 | Low | `Env` banned only two keys by name. `VERCEL_TOKEN` (in `.env.tools.example`) was not banned, and a secret pasted under a public name (service role JWT as `SUPABASE_ANON_KEY`, RevenueCat `sk_…`, Supabase `sb_secret_…`) went through. | Fixed — `VERCEL_TOKEN` banned, secrets recognised by shape |
| 6 | Low | "Report a problem" mail: the track title went into the `mailto:` query unencoded, so `&cc=` in a title would add recipients. | Fixed — subject and body percent-encoded |
| 7 | Low | `Uri.parse` on database/store URLs threw synchronously in tap handlers. | Fixed — `AppLinks.openUrl` uses `tryParse` |
| 8 | Low | Deep link `purelofi://app/track/<id>` passed any string to a query. PostgREST parameterises it, so no injection, but junk ids caused server errors. | Fixed — only UUIDs are accepted |
| 9 | Low | `tool/upload_scene.dart` would send the service role key to an `http://` `SUPABASE_URL`. | Fixed — https required (localhost excepted) |
| 10 | Low | Local auth config: `secure_password_change = false`. | Fixed in `config.toml`; mirror it in the dashboard |
| 11 | Info / business | Pro gating is client-side only. Every scene, layer and sprite is readable with the public anon key and public bucket URLs, so Pro scenes can be fetched without paying. | Open — see plan |
| 12 | Info | Google native sign-in sends no nonce (google_sign_in 7 does not expose one). The ID token is audience-bound and short-lived. | Accepted |
| 13 | Info | Media cache downloads whole files into memory without a size cap; URLs come only from our own database. | Accepted |

## Remediation plan

Done in this branch: findings 1–10, each with tests (`flutter test`: all
green; migration checked against Postgres 16 with Supabase roles).

To do by hand (needs the production dashboard):

1. **Apply the migration** (`supabase db push`), then run Supabase's
   **Security Advisor** and confirm it is clean.
2. **Auth → Providers → Email:** turn on *Leaked password protection*
   (HaveIBeenPwned), *Secure password change*, keep the OTP expiry at
   ≤ 1 hour, minimum password length 8 or more.
3. **Auth → URL configuration:** redirect allow-list holds only
   `purelofi://app/auth-callback` and the site URL — no wildcards, no
   `localhost`.
4. **Auth → Rate limits:** check email-send and verification limits are on
   (they are what keep the six-digit codes from being brute-forced).
5. **Storage:** set a per-bucket file size limit and allowed MIME types
   (`image/png` for sprites, `audio/*` for tracks, `video/mp4` for BTS).
6. **API keys:** if the project still uses the legacy JWT keys, move to the
   new publishable/secret keys so the service key can be rotated alone.
7. **RevenueCat:** confirm only the public SDK keys (`appl_`/`goog_`) are in
   `.env`; restrict the secret key's permissions in the dashboard.
8. **Vercel:** after deploy, check the headers at securityheaders.com; HSTS
   preload can be added once every subdomain serves https.

Later (product decision, finding 11): if Pro content needs real protection,
move Pro scenes to a private bucket and gate `scene_layers` rows on an
entitlement table filled by a RevenueCat webhook (Edge Function), serving
sprites through signed URLs.
