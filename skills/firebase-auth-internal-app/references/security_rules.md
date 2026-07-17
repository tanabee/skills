# Firestore Security Rules

Define `isUser()` and `isAdmin()` helper functions based on the `role` Custom Claim to control access.

## Basic Structure

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth.token.role == 'admin';
    }
    function isUser() {
      return request.auth.token.role == 'user' || isAdmin();
    }

    match /users/{userId} {
      allow read: if isUser() || (request.auth.uid == userId);
      // Self-updates must not change `role`, otherwise a user could escalate
      // their own privileges (the Firestore trigger syncs `role` to Custom Claims)
      allow update: if isAdmin()
        || (request.auth.uid == userId
            && request.resource.data.role == resource.data.role);
      // Documents are created by beforeUserCreated and "deleted" via role change,
      // both server-side (Admin SDK bypasses rules), so clients never need these
      allow create, delete: if false;
    }
  }
}
```

### Helper Functions

- `isAdmin()`: Returns `true` if the user's `role` Custom Claim is `admin`.
- `isUser()`: Returns `true` if the user's `role` Custom Claim is `user` or `admin`. Users with `pending` or `deleted` roles are excluded.

### users Collection Rules

- **read**: Allowed for `user` / `admin` roles, or the user reading their own document.
- **update**: Allowed for `admin` role. Users may update their own document only if `role` is unchanged — without this condition, a user could set their own `role` to `admin` and the Custom Claims sync trigger would grant them real admin privileges.
- **create / delete**: Denied for clients. Creation happens in `beforeUserCreated` and deletion is expressed as `role: "deleted"`, both via the Admin SDK (which bypasses rules).

### Usage in Other Collections

Use `isUser()` and `isAdmin()` to control access to application-specific collections.

```
    match /posts/{postId} {
      allow read: if isUser();
      allow write: if isUser();
    }

    match /settings/{id} {
      allow read: if isUser();
      allow write: if isAdmin();
    }
```
