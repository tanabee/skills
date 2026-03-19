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
      allow write: if isAdmin() || (request.auth.uid == userId);
    }
  }
}
```

### Helper Functions

- `isAdmin()`: Returns `true` if the user's `role` Custom Claim is `admin`.
- `isUser()`: Returns `true` if the user's `role` Custom Claim is `user` or `admin`. Users with `pending` or `deleted` roles are excluded.

### users Collection Rules

- **read**: Allowed for `user` / `admin` roles, or the user reading their own document.
- **write**: Allowed for `admin` role, or the user writing to their own document.

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
