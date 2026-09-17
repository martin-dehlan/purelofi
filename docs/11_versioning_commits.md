# Versioning, Commits & Branches

**TL;DR:** Semver `MAJOR.MINOR.PATCH+BUILD`. Conventional Commits. Feature work
on `feat/<name>` branches with PR. Trivial fixes direct to `main`. Push after
every commit.

---

## Version policy

Pattern: `MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`.

| Bump | When |
|------|------|
| MAJOR | Breaking changes. First public store release = `1.0.0`. |
| MINOR | New feature batch (offline sprint = `0.2.0`, favorites = `0.3.0`, etc). |
| PATCH | Bug fixes within a version, no new features. |
| BUILD | `+1` per store upload (TestFlight / Play Internal). Always increment. |

Bump version only when the feature batch is **shipped to a store**, not at the
start of work. MVP starts at `0.1.0+1`.

---

## Conventional Commits

Format: `type(scope): subject`

| Type | When |
|------|------|
| `feat` | New functionality. |
| `fix` | Bug fix. |
| `refactor` | Code change, no behavior change. |
| `chore` | Build, deps, tooling. |
| `docs` | Docs / comments only. |
| `style` | Formatting / visual tweaks (no logic). |
| `test` | Test changes only. |

Rules:
- Subject ≤ 60 chars, lowercase, no trailing period.
- Imperative voice ("add x", not "added x" / "adds x").
- Scope = feature dir or area (`player`, `scenes`, `bts`, `analytics`,
  `android`, `ios`, `router`, `ci`).

---

## Commit cadence

- One logical change per commit. No big dumps.
- Group related file edits when they form one concept (e.g. controller + its
  codegen + its UI consumer).
- Don't mix unrelated changes in one commit.

---

## Branch & PR flow

Public OSS — keep history visible and reviewable.

| Change kind | Where |
|-------------|-------|
| Feature work | `feat/<short-name>` branch → PR |
| Bug fix that needs review | `fix/<short-name>` branch → PR |
| Trivial fix (typo, dep bump, single-line) | direct to `main` |
| Docs / policy update | `docs/<short-name>` branch → PR |

PR rules:
- One self-contained concept per PR.
- Title = the merge commit message after squash (Conventional Commits format).
- Body = summary + test plan.
- Squash-merge to keep `main` linear and readable.

---

## Pre-push checklist

Before `git push`:
1. `flutter analyze` — no new errors (info-level pre-existing OK).
2. `dart run build_runner build --delete-conflicting-outputs` — succeeds if any
   annotated files changed.
3. Manual smoke test of the changed flow on simulator/device.
4. Commit message follows Conventional Commits.

---

## Push policy

- Push after every commit. Don't accumulate local commits.
- Never `--force` to `main`.
- Never skip hooks (`--no-verify`).

---

## Current sprint

- **MVP v0.1.0** — player end to end: scenes loop, audio streams in the
  background (lock-screen controls), random track selection, scene switcher, BTS
  modal, PostHog wired (`app_opened`, `track_played`, `bts_opened`,
  `scene_switched`).
- Bump to `0.1.0+1` only on the first TestFlight / Play Internal upload.
- Phase 2 batches (later): offline caching (`0.2.0`), favorites (`0.3.0`),
  RevenueCat paywall (→ `1.0.0`).
