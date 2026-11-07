# Linux desktop end-to-end smoke test

This suite drives the Flutter app against a live, isolated HappyNotes.Api run. It covers password login, creating a note, finding it in the list and search results, and deleting it through the list UI.

## Prerequisites

- Flutter 3.38.x (stable) with the Linux desktop toolchain enabled.
- `xvfb-run` and a working Linux desktop build environment (`flutter doctor` should report no Linux desktop blockers).
- A clean, dedicated clone or worktree of this repository. The runner creates `.env` because Flutter assets require it; it refuses to run when `.env` already exists.
- A checked-out HappyNotes.Api repository with its `e2e/up.sh` stack available. The API e2e prerequisites are documented in that repository's `e2e/README.md`.

## Run

Start the API e2e stack, keep its state file, run the Flutter smoke test, then remove exactly that stack:

```bash
api_state="$(cd ../HappyNotes.Api && e2e/up.sh | sed -n 's/^\[e2e\] state file:[[:space:]]*//p' | tail -n 1)"
evidence="$(mktemp -d)"

tool/e2e/run.sh "$api_state" "$evidence"

(cd ../HappyNotes.Api && e2e/down.sh "$api_state")
```

`run.sh` parses the API state file by key; it never sources the file. It requires `E2E_STATE=running`, `E2E_API_URL`, `E2E_SEED_USERNAME`, and `E2E_SEED_PASSWORD`. The generated `.env` points at the API and sets the smoke note's default visibility to public so the API search index can observe it. The generated `.env` and the per-run HOME/XDG directories are removed when the test exits, including on failure. Do not run it in a developer checkout containing `.env`.

The evidence directory contains `runner.log` and these screenshots under `app/`:

```text
01-login.png
02-note-editor.png
03-note-created.png
04-search-results.png
05-note-deleted.png
```

To check isolation explicitly, use separate evidence directories and run the same API state twice:

```bash
mkdir -p "$evidence/first" "$evidence/second"
tool/e2e/run.sh "$api_state" "$evidence/first"
test ! -e .env
tool/e2e/run.sh "$api_state" "$evidence/second"
test ! -e .env
```

The API state must remain running between the two invocations. `run.sh` gives each invocation separate HOME/XDG storage, so SharedPreferences tokens cannot leak between runs. It preserves the caller's `CARGO_HOME` and `RUSTUP_HOME` so native Flutter assets can use the installed Rust toolchain; those directories are toolchain caches rather than app state. Shut down the API run with `e2e/down.sh` after both invocations.

## CI behavior

The repository's ordinary `flutter test integration_test/` invocation registers the smoke test as skipped unless `HAPPYNOTES_E2E_STATE` is set. This keeps the existing unit/widget CI job offline and unchanged. A live run is intentionally opt-in through `tool/e2e/run.sh`, which supplies the state, seed credentials, API URL, and evidence directory.
