# Syncing Permissions to Custom Claims

A Firestore trigger that syncs to Custom Claims when the permission field of a `users` document changes.
This enables permission control on the client side by referencing `request.auth.token.<field_name>`.

Initial claims are set by the return value of `beforeUserCreated` (see [blocking_functions.md](blocking_functions.md)), so this trigger only handles subsequent updates. Claims updated via `setCustomUserClaims` take effect on the next token refresh; call `getIdToken(true)` on the client to force it.

## Firestore Trigger

```javascript
const { onDocumentWritten } = require("firebase-functions/firestore");
const { getAuth } = require("firebase-admin/auth");

const USER_ROLE = Object.freeze({
  ADMIN: "admin",
  USER: "user",
  PENDING: "pending",
  DELETED: "deleted",
});

module.exports = onDocumentWritten(
  { document: "users/{id}" },
  async (event) => {
    // Skip creation: initial claims are set by beforeUserCreated's return value
    if (!event.data.before.exists) return;
    // Skip deletion: removal is represented by role "deleted", not document deletion
    if (!event.data.after.exists) return;

    const before = event.data.before.data();
    const after = event.data.after.data();

    // Update Custom Claims only when the permission field changes
    if (before.role !== after.role) {
      await getAuth().setCustomUserClaims(event.params.id, {
        role: after.role,
      });
    }
  }
);
```
