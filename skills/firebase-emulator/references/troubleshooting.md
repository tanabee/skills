# Troubleshooting: symptom → cause → fix

Work through the matching row before retrying variations. Every entry here comes from a real debugging session that took longer than it should have.

## Firestore REST

| Symptom | Likely cause | Fix |
|---|---|---|
| `403 PERMISSION_DENIED` / `Null value error. for 'list'` | No `Authorization` header — rules evaluate `request.auth == null` | Add `-H "Authorization: Bearer owner"` |
| `invalid jwt` | You sent an OAuth access token (e.g. from `gcloud auth print-access-token`) | Use `Bearer owner` (admin) or an Auth-Emulator `idToken` |
| `404 {"detail":"Not Found"}` on a path that should exist, headers don't help | **You are not talking to the Firestore emulator.** `localhost` resolved to IPv6 `::1` where another service (Docker etc.) listens on the port | Use `127.0.0.1` explicitly. Verify with `curl -s http://127.0.0.1:8080/` (emulator answers `Ok`) and `lsof -nP -iTCP:8080 -sTCP:LISTEN` |
| Port genuinely occupied by another service | Conflict with Docker / other dev servers | Move the emulator: copy `firebase.json` to e.g. `firebase.emutest.json` with a free port and `firebase emulators:start --config firebase.emutest.json`. If client code hardcodes `connectFirestoreEmulator(db, 'localhost', 8080)`, change it for the test and revert after |
| Collection unexpectedly empty | Seed/imported data simply doesn't contain it, or data lives under a different project id | `documents:listCollectionIds` to see what exists; check the project id in the URL against `.firebaserc` / the `--project` flag the emulator was started with |
| Wipe endpoint 404s | Wrong path shape | It is `DELETE /emulator/v1/projects/PROJECT/databases/(default)/documents` — `/documents` with a slash, not `:documents`; no auth header needed |
| `Not Found` only when the URL is built from a shell variable (e.g. `"$BASE:runQuery"`) but the literal URL works | zsh treats `$VAR:x` as a history-style modifier and mangles the expansion | Always write `"${BASE}:runQuery"` with braces, or use the full literal URL |
| Stale data breaks repeated integration runs | Previous run's data persists per project-id namespace | Wipe that project id's namespace before each run; suites can isolate by using distinct project ids |

## Auth Emulator

| Symptom | Likely cause | Fix |
|---|---|---|
| Sign-in returns `INVALID_API_KEY`-style confusion | It never validates the key — the error is something else (wrong path, wrong port) | Any `?key=whatever` works; recheck host/port/path |
| Need to complete email-link / password-reset flow non-interactively | The link only exists "in an email" the emulator never sends | `GET /emulator/v1/projects/PROJECT/oobCodes` and open/consume `oobLink` |
| Auth-Emulator `idToken` rejected somewhere | The token is unsigned (`alg: none`) — only emulators and emulator-configured Admin SDKs accept it | Make sure the consumer also points at the emulators (`FIREBASE_AUTH_EMULATOR_HOST`) |

## Functions / Hosting emulators

| Symptom | Likely cause | Fix |
|---|---|---|
| `emulators:start` hangs forever with no error (esp. in background) | A `defineInt`/`defineString` param has no value → interactive prompt is waiting invisibly | Define the param in the functions `.env` files before starting; when starting in background, grep the log for `All emulators ready` and for prompt text like `Enter a` |
| Functions discovery timeout on large codebases | Default discovery timeout too short | `FUNCTIONS_DISCOVERY_TIMEOUT=120 firebase emulators:start ...` |
| API route through hosting emulator returns `index.html` with 200 | Framework-integrated (Vite etc.) hosting doesn't apply function rewrites | Hit the function URL directly: `http://127.0.0.1:5001/PROJECT/REGION/FUNCTION/...`; judge success by response body (JSON), not status code |
| Function URL 404 | Wrong region (not everything is `us-central1`) or wrong function-name format | Check the region in the functions code; exported grouped functions are hyphen-separated in URLs (`callable-foo-bar`, not `callable.foo.bar`) |
| Requiring `functions/index.js` in plain Node crashes at load | Code reads `process.env.FIREBASE_CONFIG` at module load | `FIREBASE_CONFIG='{"projectId":"demo-x"}' FUNCTIONS_EMULATOR=true node ...` |
| Bulk delete/seed fires triggers you don't want | Background triggers enabled | `curl -X PUT http://127.0.0.1:4400/functions/disableBackgroundTriggers`, do the work, then re-enable |

## Admin SDK scripts

| Symptom | Likely cause | Fix |
|---|---|---|
| Project script refuses to run against the emulator | Script string-compares `FIRESTORE_EMULATOR_HOST` against one exact value | Read the script's check and pass exactly that value (`localhost:8080` vs `127.0.0.1:8080` are different strings) |
| SDK silently talks to production | Env var missing, typo'd, or includes `http://` | Value must be bare `host:port`; verify with a read before any write |

## General diagnosis order

1. `curl -s http://127.0.0.1:4400/emulators` — what is actually running, on which ports?
2. `curl -s http://127.0.0.1:<port>/` + `lsof -nP -iTCP:<port> -sTCP:LISTEN` — is that port really the emulator?
3. Only then iterate on paths/headers/bodies.
4. Non-ASCII characters in HTTP header values get mangled — keep header values ASCII.
