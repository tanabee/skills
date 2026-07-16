---
name: firebase-emulator
description: Access the Firebase Emulator Suite (Firestore, Auth, Functions, Hub) via REST and Admin SDK without trial-and-error. Use this skill whenever you read/write/query/clear Firestore Emulator data, create test users or obtain ID tokens from the Auth Emulator, verify Functions triggers, seed/export emulator data, or hit unexpected 403/404 from an emulator endpoint. Consult it BEFORE curling any emulator port — it encodes the auth header and host-resolution rules that otherwise cause retries.
allowed-tools: Bash, Read, Write, Grep, Glob, AskUserQuestion
---

# Firebase Emulator

Efficient access to the Firebase Emulator Suite. Each rule below exists because skipping it has burned a real debugging session.

## Iron rules

1. **Always use `127.0.0.1`, never `localhost`, in emulator URLs.** `localhost` can resolve to IPv6 `::1`, where an unrelated service (e.g. Docker publishing `*:8080`) may be listening — you get confusing 404s from the wrong server, and no auth header will fix it.
2. **Firestore REST always needs `-H "Authorization: Bearer owner"`** (the literal string `owner`). Security rules ARE evaluated by the emulator; without the header, reads fail with `403 PERMISSION_DENIED (Null value error)`. `owner` is treated as admin and bypasses rules. OAuth access tokens are NOT accepted (`invalid jwt`) — only `owner` or an Auth-Emulator-issued ID token works.
3. To act as a **signed-in user with rules evaluated**, sign in via the Auth Emulator REST (`accounts:signInWithPassword`, any `?key=` string works) and pass the returned unsigned `idToken` as the Bearer.
4. **On any unexpected 404 or off-looking response, first verify you are talking to the emulator at all**: `curl -s http://127.0.0.1:<port>/` and `lsof -nP -iTCP:<port> -sTCP:LISTEN`. Do not iterate on headers or paths against an unverified port.
5. **Discover the setup, don't assume it.** Read `firebase.json` (`emulators` block) and `.firebaserc` (project id), or ask the Hub: `curl -s http://127.0.0.1:4400/emulators` lists every running emulator with its host/port. Project id matters: data is namespaced per project id, so a "missing" document may just be under a different id.
6. **Never stop or restart emulators the user started** unless explicitly asked — they often hold imported data and parallel work.
7. An empty collection is often not a bug — seed data may simply not contain it. Check what actually exists first with `documents:listCollectionIds` before investigating.

## Project config

Keep project-specific knowledge in `config.json` next to this SKILL.md:

1. Read `config.json` first. If it has an entry for the current project, trust it (ports, project id, region, quirks).
2. If not, detect from `firebase.json` / `.firebaserc` / `package.json` scripts, then save an entry:
   ```json
   {
     "projects": {
       "<repo-name>": {
         "projectId": "...",
         "ports": { "firestore": 8080, "auth": 9099, "functions": 5001, "hub": 4400 },
         "functionsRegion": "us-central1",
         "startCommand": "firebase emulators:start",
         "quirks": []
       }
     }
   }
   ```
3. When you discover a project-specific pitfall during work (port conflicts, required env vars, seed-data layout), append it to that project's `quirks` so the next session skips the rediscovery.

## Common operations

Substitute `PROJECT` (project id) and ports. Full endpoint catalogue: [references/rest-api.md](references/rest-api.md).

```bash
# List documents in a collection (admin, bypasses rules)
curl -s -H "Authorization: Bearer owner" \
  "http://127.0.0.1:8080/v1/projects/PROJECT/databases/(default)/documents/users?pageSize=50"

# What collections actually exist?
curl -s -H "Authorization: Bearer owner" -X POST -H 'Content-Type: application/json' -d '{}' \
  "http://127.0.0.1:8080/v1/projects/PROJECT/databases/(default)/documents:listCollectionIds"

# Query
curl -s -H "Authorization: Bearer owner" -H 'Content-Type: application/json' \
  -d '{"structuredQuery":{"from":[{"collectionId":"users"}],"limit":5}}' \
  "http://127.0.0.1:8080/v1/projects/PROJECT/databases/(default)/documents:runQuery"

# Create/update a document (handy for firing triggers without UI)
curl -s -X PATCH -H "Authorization: Bearer owner" -H 'Content-Type: application/json' \
  -d '{"fields":{"name":{"stringValue":"smoke"}}}' \
  "http://127.0.0.1:8080/v1/projects/PROJECT/databases/(default)/documents/users/test-doc"

# Wipe all Firestore data for a project id (emulator-only endpoint; no auth header needed)
curl -s -X DELETE \
  "http://127.0.0.1:8080/emulator/v1/projects/PROJECT/databases/(default)/documents"

# Create a user and grab an ID token (rules-evaluated access / callable functions)
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"email":"t@example.com","password":"password123","returnSecureToken":true}' \
  "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key"

# Which emulators are running, on which ports?
curl -s http://127.0.0.1:4400/emulators
```

Admin SDK scripts: set `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080` (and/or `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099`) — no `http://` prefix — and the SDK connects to the emulator as admin. Note: some project scripts string-compare this variable (`localhost:8080` vs `127.0.0.1:8080`), so match the value the script expects.

## When something fails

Match the symptom against [references/troubleshooting.md](references/troubleshooting.md) BEFORE retrying variations — 403 (missing `Bearer owner`), 404 (port hijacked / wrong host), hanging `emulators:start` (undefined params), and other known patterns are listed with their fixes.

## Notes

- `demo-*` project ids run fully offline and can never touch production — prefer them for throwaway tests; real project ids are fine when working with imported data.
- Prefer REST over browser UI operations for verifying triggers and state transitions — faster and immune to stale-UI issues. Confirm trigger firing via emulator logs, not UI.
- The Emulator UI defaults to port 4000 but auto-increments on conflict (4001, ...). Before giving the user a UI URL, confirm the actual port from the startup logs or the Hub (`curl -s http://127.0.0.1:4400/emulators`).
- Keep HTTP header values ASCII-only; non-ASCII values get mangled.
