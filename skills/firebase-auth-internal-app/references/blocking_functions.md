# Domain Restriction via Blocking Functions

Blocking Functions are Cloud Functions triggered by Firebase Authentication events (user creation, sign-in) that allow customization of the authentication flow.

## beforeUserCreated

Executed when a user is created for the first time. Throwing an error blocks the user creation.

### Basic Structure

```javascript
const { beforeUserCreated, HttpsError } = require("firebase-functions/identity");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

const db = getFirestore();

const ROLE = Object.freeze({
  ADMIN: "admin",
  USER: "user",
  PENDING: "pending",
  DELETED: "deleted",
});

// Allowed email domains
const ALLOWED_DOMAINS = ["example.com", "subsidiary.example.com"];

module.exports = beforeUserCreated(async (event) => {
  const { uid, email } = event.data;

  if (!email) {
    throw new HttpsError("invalid-argument", "Email address is required");
  }

  const domain = email.split("@")[1];

  // Domain restriction: block domains not in the allowed list
  if (!ALLOWED_DOMAINS.includes(domain)) {
    throw new HttpsError(
      "permission-denied",
      "This app is only available to organization members"
    );
  }

  // Register user information in the Firestore users collection
  await db.doc(`users/${uid}`).set({
    email,
    role: ROLE.USER,
    createdAt: Timestamp.now(),
  });
});
```

## Deployment

Deploy Blocking Functions the same way as regular Cloud Functions.

```bash
firebase deploy --only functions
```

Specify the target directory in the `functions` configuration in `firebase.json`.

```json
{
  "functions": {
    "source": "functions"
  }
}
```
