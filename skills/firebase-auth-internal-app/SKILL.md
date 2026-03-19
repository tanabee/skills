---
name: firebase-auth-internal-app
description: Integrate Firebase Auth (authentication + domain restriction) into internal applications. Includes domain restriction via Blocking Functions and user registration to Firestore.
requires-skills: firebase-auth-basics
---

Integrate Firebase Authentication into an internal application. Implement the following components.

## Prerequisites

- A Firebase project has been created
- Firebase CLI is installed and logged in
- Firestore is enabled
- The `firebase-auth-basics` skill is available

## Implementation

### 1. Authentication Setup

Follow the `firebase-auth-basics` skill to:

1. Use AskUserQuestion to ask the user which authentication method to use
2. Provision the selected authentication method (`firebase.json` configuration or manual setup via Firebase Console)
3. Implement client-side authentication (initialization, sign-in, auth state monitoring, sign-out)

Refer to `firebase-auth-basics` for all authentication method options, provisioning steps, and client SDK implementation examples.

For non-web platforms (iOS / Android / Flutter / Unity, etc.), fetch the relevant platform information from the official documentation at https://firebase.google.com/docs/auth.

### 2. Domain Restriction via Blocking Functions

Implement based on [references/blocking_functions.md](references/blocking_functions.md).

Using `beforeUserCreated`, implement the following:
- Determine the domain from the user's email address
- If the domain is allowed, register user information in the Firestore `users` collection
- If the domain is not allowed, return an error to reject sign-in

Use AskUserQuestion to ask the user for the allowed email domain(s) (e.g., `example.com`). For multiple domains, ask for comma-separated input.

Also confirm the following:
- Fields to store in the `users` collection (default: `email`, `role`, `createdAt`)

### 3. Permission Management via Custom Claims

Implement based on [references/custom_claims.md](references/custom_claims.md).

Use `onDocumentWritten` to monitor changes to `users/{id}` documents and sync permission information to Custom Claims:
- When the permission field in a `users` document is updated, reflect it in the ID token via `setCustomUserClaims`
- On the client side, Custom Claims in the token can be used for permission control

Default `role` values:
- `admin`: Administrator
- `user`: Regular user
- `pending`: Pending approval
- `deleted`: Deleted

The initial `role` for users who pass domain restriction is `user`. Confirm the following with the user:
- The permission field name to store in Custom Claims (default: `role`)
- Whether to customize the `role` types (default: `admin`, `user`, `pending`, `deleted`)

### 4. Firestore Security Rules

Implement based on [references/security_rules.md](references/security_rules.md).

Define helper functions `isUser()` and `isAdmin()` based on the `role` Custom Claim, and set up security rules for the `users` collection as a minimum.

The application's other collections should also use `isUser()` and `isAdmin()` for access control.

## Notes

- If any prerequisites are not met, notify the user which ones are missing before proceeding
- Always confirm environment-specific values such as allowed domains and app name with the user before setting them
- Blocking Functions use Cloud Functions for Firebase (2nd gen)
- Writing to the `users` collection uses the `firebase-admin` SDK (server-side)
