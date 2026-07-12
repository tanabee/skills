# Firebase Emulator REST API catalogue

All examples assume default ports (Firestore 8080, Auth 9099, Hub 4400) and use `127.0.0.1` on purpose — see SKILL.md iron rule 1. `PROJECT` = the project id the data is namespaced under.

## Contents

- [Authentication model](#authentication-model)
- [Firestore Emulator](#firestore-emulator)
- [Auth Emulator](#auth-emulator)
- [Emulator Hub (4400)](#emulator-hub-4400)
- [Environment variables & Admin SDK](#environment-variables--admin-sdk)
- [Other emulators](#other-emulators)

## Authentication model

The Firestore Emulator accepts exactly two kinds of `Authorization` header:

| Header | Effect |
|---|---|
| `Authorization: Bearer owner` | Admin — security rules bypassed entirely |
| `Authorization: Bearer <idToken>` | The unsigned JWT issued by the Auth Emulator; rules evaluated as that user |
| (none) | `request.auth == null` — rules usually reject with 403 |

OAuth2 access tokens are rejected (`invalid jwt`). Auth-Emulator ID tokens are unsigned (`alg: none`) and only accepted by other emulators / emulator-configured Admin SDKs — never by production.

Sources: https://firebase.google.com/docs/emulator-suite/connect_firestore , firebase-tools issues #2010, #4581.

## Firestore Emulator

Base: `http://127.0.0.1:8080/v1` — same contract as production Firestore REST v1.
Database id is always the literal `(default)` (parentheses included, no URL-encoding needed).

| Operation | Method + path |
|---|---|
| Get document | `GET /v1/projects/PROJECT/databases/(default)/documents/{path}` |
| List collection | `GET .../documents/{collection}?pageSize=50` |
| Create/update | `PATCH .../documents/{path}` |
| Partial update | `PATCH .../documents/{path}?updateMask.fieldPaths={field}` (repeatable) |
| Delete document | `DELETE .../documents/{path}` |
| Query | `POST .../documents:runQuery` |
| List collection ids | `POST .../documents:listCollectionIds` (body `{}`) |
| Batch write | `POST .../documents:batchWrite` |
| Commit (transaction) | `POST .../documents:commit` |

Document bodies use typed value objects:

```json
{"fields": {"name": {"stringValue": "x"}, "count": {"integerValue": "3"},
            "ok": {"booleanValue": true}, "at": {"timestampValue": "2026-01-01T00:00:00Z"},
            "tags": {"arrayValue": {"values": [{"stringValue": "a"}]}},
            "meta": {"mapValue": {"fields": {"k": {"stringValue": "v"}}}}}}
```

`runQuery` example:

```bash
curl -s -H "Authorization: Bearer owner" -H 'Content-Type: application/json' \
  -d '{"structuredQuery":{
        "from":[{"collectionId":"users"}],
        "where":{"fieldFilter":{"field":{"fieldPath":"role"},"op":"EQUAL","value":{"stringValue":"admin"}}},
        "orderBy":[{"field":{"fieldPath":"createdAt"},"direction":"DESCENDING"}],
        "limit":5}}' \
  "http://127.0.0.1:8080/v1/projects/PROJECT/databases/(default)/documents:runQuery"
```

### Emulator-only endpoints (`/emulator/v1/...`, no auth header)

| Purpose | Method + path |
|---|---|
| Wipe all data for a project id | `DELETE /emulator/v1/projects/PROJECT/databases/(default)/documents` |
| Replace security rules | `PUT /emulator/v1/projects/PROJECT:securityRules` |
| Rules coverage (JSON) | `GET /emulator/v1/projects/PROJECT:ruleCoverage` |
| Rules coverage (HTML) | `GET /emulator/v1/projects/PROJECT:ruleCoverage.html` |

Await the wipe response before proceeding (the flush is synchronous with the response). Note the path is `.../databases/(default)/documents` — with a slash, not `:documents`.

Caveat: emulator builds occasionally lag the production v1 surface (issue #4581); if an exotic endpoint 404s on a verified emulator port, test with a simpler call before concluding anything.

## Auth Emulator

Base: `http://127.0.0.1:9099`. Production `identitytoolkit.googleapis.com/v1` paths are served under the emulator host. **`?key=` accepts any string** — the emulator never validates it.

| Operation | Path (POST, `Content-Type: application/json`) |
|---|---|
| Sign up (create user) | `/identitytoolkit.googleapis.com/v1/accounts:signUp` |
| Email+password sign-in | `/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword` |
| Exchange custom token | `/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken` |
| Lookup user (claims etc.) | `/identitytoolkit.googleapis.com/v1/accounts:lookup` |
| Update user | `/identitytoolkit.googleapis.com/v1/accounts:update` |

```bash
# Get an ID token for a known user
IDTOKEN=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"email":"t@example.com","password":"password123","returnSecureToken":true}' \
  "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=any" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["idToken"])')

# Lookup by localId as admin (works with Bearer owner, project-scoped path)
curl -s -X POST -H "Authorization: Bearer owner" -H 'Content-Type: application/json' \
  -d '{"localId":["SOME_UID"]}' \
  "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/PROJECT/accounts:lookup"
```

### Emulator-only management endpoints

| Purpose | Method + path |
|---|---|
| Delete all accounts | `DELETE /emulator/v1/projects/PROJECT/accounts` |
| Get/patch emulator config | `GET` / `PATCH /emulator/v1/projects/PROJECT/config` |
| Pending OOB codes (email verify / password reset / email link) | `GET /emulator/v1/projects/PROJECT/oobCodes` |
| Pending SMS verification codes | `GET /emulator/v1/projects/PROJECT/verificationCodes` |

`oobCodes` is the non-interactive way to complete email-link sign-in or password reset: fetch the list, open/consume the `oobLink`.

To **list accounts**, note that `GET /emulator/v1/projects/PROJECT/accounts` is NOT allowed (verified: "Method GET not allowed"). Use the production-shaped admin endpoints with `Bearer owner` instead:

```bash
# List/query all accounts (admin)
curl -s -X POST -H "Authorization: Bearer owner" -H 'Content-Type: application/json' -d '{}' \
  "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/PROJECT/accounts:query"

# Or the downloadAccount shape
curl -s -H "Authorization: Bearer owner" \
  "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/PROJECT/accounts:batchGet"
```

## Emulator Hub (4400)

| Purpose | Method + path |
|---|---|
| List running emulators + ports | `GET /emulators` |
| Export all emulator data | `POST /_admin/export` body `{"path":"./emulator-data","initiatedBy":"cli"}` |
| Disable Functions background triggers | `PUT /functions/disableBackgroundTriggers` |
| Re-enable background triggers | `PUT /functions/enableBackgroundTriggers` |

Disabling background triggers is the clean way to bulk-delete/seed data without firing `onWrite`/`onDelete` functions. CLI equivalents: `firebase emulators:export <dir>`, `firebase emulators:start --import=<dir> --export-on-exit`.

## Environment variables & Admin SDK

Values are `host:port` — **never include `http://`**.

| Variable | Example | Effect |
|---|---|---|
| `FIRESTORE_EMULATOR_HOST` | `127.0.0.1:8080` | Admin/server SDKs hit the Firestore emulator, authenticated as `owner` (rules bypassed) |
| `FIREBASE_AUTH_EMULATOR_HOST` | `127.0.0.1:9099` | SDKs hit the Auth emulator; unsigned tokens accepted |
| `FIREBASE_DATABASE_EMULATOR_HOST` | `127.0.0.1:9000` | RTDB emulator |
| `FIREBASE_STORAGE_EMULATOR_HOST` | `127.0.0.1:9199` | Storage emulator |
| `PUBSUB_EMULATOR_HOST` | `127.0.0.1:8085` | Pub/Sub emulator (a gcloud component, not firebase-tools) |
| `GCLOUD_PROJECT` / `GOOGLE_CLOUD_PROJECT` | `demo-test` | Project id when `initializeApp` doesn't specify one |

One-liner pattern:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node -e "
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
initializeApp({projectId:'PROJECT'});
getFirestore().collection('users').limit(3).get().then(s=>console.log(s.size));"
```

With `FIRESTORE_EMULATOR_HOST` set, writes go to the emulator even if the script also loads real service-account credentials.

### `demo-*` project ids

A project id starting with `demo-` marks a "demo project": emulators start without any real Firebase project, run fully offline, and accidental calls to non-emulated services can never reach production. Recommended for CI and throwaway tests. Data imported from a real project lives under the real project id — use that id in URLs to see it.

## Other emulators

- **Functions**: HTTP functions at `http://127.0.0.1:5001/PROJECT/REGION/FUNCTION_NAME` — region must match the deployed region (check the code; it is not always `us-central1`). Callable functions take `-H "Authorization: Bearer $IDTOKEN"`.
- **Storage** (9199): serves the GCS/Firebase Storage JSON API shape against the emulator host.
- **Pub/Sub** (8085): production Pub/Sub REST v1 shape (`/v1/projects/PROJECT/topics` etc.); no wipe endpoint — restart to clear.

## Primary sources

- https://firebase.google.com/docs/emulator-suite/connect_firestore
- https://firebase.google.com/docs/emulator-suite/connect_auth
- https://firebase.google.com/docs/emulator-suite/install_and_configure
- https://firebase.google.com/docs/firestore/use-rest-api
- firebase-tools source: `src/emulator/hub.ts`, `src/emulator/auth/server.ts`, `src/emulator/firestoreEmulator.ts`
- Bearer-token behavior: https://github.com/firebase/firebase-tools/issues/2010 , https://github.com/firebase/firebase-tools/issues/4581
