# Exercise seed tooling (TV2)

One-time tooling to author and push the template exercise catalog (`exercises/{exerciseId}`
in Firestore) per `docs/TV2_TASKS.md` §6. Not part of the Flutter app — this runs manually,
once, from a developer machine. The app itself never calls any of these APIs at runtime.

## Layout

- `data/*.json` — authored content, one file per `primaryMuscle` (13 files). Each entry is an
  exercise **without** `id`, `createdAt`, `updatedAt` — those are added at build/push time.
- `scripts/fetch-wger-reference.mjs` — calls the open `wger.de` API and saves the raw response
  to `reference/` (git-ignored). **Brainstorming input only** — names/categories are used as
  inspiration for `data/*.json`, never copied verbatim, and `wger.de` images are never used
  (license risk, disallowed by TV2_TASKS.md §6).
- `scripts/build-seed.mjs` — merges `data/*.json` into `exercises_seed.json`, generates a
  stable `id` per exercise, and validates every entry against the schema/enums below. Fails
  the build on any violation.
- `scripts/fetch-images.mjs` — optional. Fills `imageUrl` for entries that don't have one yet,
  using the Pexels API (free key, license-safe) with a fixed size/crop so every image shares
  the same aspect ratio. Requires `PEXELS_API_KEY` env var.
- `scripts/push-to-firestore.mjs` — reads `exercises_seed.json` and writes each entry to the
  `exercises` collection via the Firebase Admin SDK. Refuses to push any entry with an empty
  `imageUrl` unless run with `--allow-missing-images`.

## Schema (must match `docs/TV2_TASKS.md` §2.1)

```
name, primaryMuscle, secondaryMuscles[], equipment[], difficulty,
instructions[], commonMistakes[], quickTip, suggestedRestSeconds,
imageUrl, isActive
```

Enums (see `schema.mjs`, source of truth — kept in sync with the project memory notes since
`docs/TV2_TASKS.md` §3 itself still lists the old 6-value equipment list as of 2026-07-29):

- `muscle` (13): nguc, lung_tren, lung_duoi, vai_truoc, vai_giua, vai_sau, tay_truoc, tay_sau,
  dui_truoc, dui_sau, mong, bap_chan, bung
- `equipment` (9, revised with Việt Anh's sign-off): khong_dung_cu, ta_don, ta_doi,
  day_khang_luc, ghe_tap, may_tap_nguc, may_keo_xo, may_tap_chan, xa_ngang
- `difficulty` (3): beginner, intermediate, advanced

## Usage

```bash
npm install

# optional, brainstorming only
npm run fetch-reference

# merge data/*.json -> exercises_seed.json, validate schema/enums
npm run build

# optional, fills missing imageUrl via Pexels (needs PEXELS_API_KEY)
PEXELS_API_KEY=xxx npm run fetch-images

# place your Firebase service-account key at ./serviceAccountKey.json (git-ignored), then:
GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json npm run push
```

`push-to-firestore.mjs` is idempotent — it uses `set()` keyed by the generated `id`, so
re-running after fixing content overwrites the same documents instead of duplicating them.
