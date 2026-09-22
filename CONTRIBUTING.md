# Contributing to PureLofi

PureLofi is a public, minimalist pixel-art lo-fi player built with Flutter.
The binding architecture rules live in [`docs/01`–`docs/11`](docs/); the app
scope lives in [`docs/SPEC.md`](docs/SPEC.md). Where `SPEC.md` and a numbered
rule disagree, `SPEC.md` wins.

## Setup

```bash
flutter pub get
cp .env.example .env          # fill in Supabase + PostHog keys
cp .env.tools.example .env.tools   # only if you upload scenes
dart run build_runner build
flutter run
```

Both are git-ignored. Never commit real keys.

`.env` is bundled into the app — it is an asset in `pubspec.yaml`, and an app
bundle is a zip. It may hold only keys that are safe to publish: the Supabase
URL, the anon key (RLS protects the data), the PostHog key. The service role
key and the database password belong in `.env.tools`, which only `tool/`
reads. The app throws on startup if it finds one in `.env`.

## Testing policy

- **Tests are required for new behaviour.** A PR that adds or changes
  behaviour adds or updates tests covering it. UI-only styling changes are
  exempt; anything with a state transition, a mapping, or an error path is not.
- **Every bug fix ships with a regression test** that fails before the fix and
  passes after it.
- Test layout and patterns are defined in [`docs/10`](docs/10_testing_rules.md):
  unit tests in `test/unit/`, widget tests in `test/widget/`, integration tests
  in `integration_test/`, mirroring `lib/`.
- No real network, Supabase, `just_audio` or `video_player` calls in unit or
  widget tests — mock with `mocktail` or override the provider.

```bash
flutter test                   # unit + widget
flutter test integration_test/ # integration
```

## Code rules (short form)

- Layer flow: Domain (pure Dart) → Data (Supabase) → Controller (Riverpod) → UI.
- File naming `name.type.dart`, classes `NameType` (`docs/02`). One widget per file.
- All providers for a feature in one `feature.provider.dart` (`docs/05`).
- Zero fixed spacing or font sizes — everything from `MediaQuery` (`docs/03`).
- Colors from `Theme.of(context).colorScheme` only. No gradients, no
  glassmorphism (`docs/09`).
- Run `dart run build_runner build` after changing
  any `@freezed` / `@riverpod` annotation (`docs/06`).
- Do not add `drift`, `drift_flutter` or `purchases_flutter` — Phase 2 only.
- Anything that talks to a platform channel (`video_player`, `just_audio`,
  `audio_service`) goes behind an interface or a builder provider, so tests
  can replace it.

## Branches, commits, PRs

- Conventional Commits: `type(scope): subject`, ≤60 chars, imperative, lowercase.
- Feature work on `feat/<name>`, fixes on `fix/<name>`, docs on `docs/<name>`.
- One self-contained concept per PR. Body = summary + test plan. Squash-merge.
- Before pushing: `dart format`, `flutter analyze` clean, `build_runner`
  succeeds, smoke test the changed flow. CI enforces the first three on every
  PR. Full rules in [`docs/11`](docs/11_versioning_commits.md).
