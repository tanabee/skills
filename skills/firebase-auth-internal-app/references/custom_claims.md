# Syncing Permissions to Custom Claims

A Firestore trigger that syncs to Custom Claims when the permission field of a `users` document changes.
This enables permission control on the client side by referencing `request.auth.token.<field_name>`.

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
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Update Custom Claims only when the permission field changes
    if (before?.role !== after.role) {
      await getAuth().setCustomUserClaims(event.params.id, {
        role: after.role,
      });
    }
  }
);
```
