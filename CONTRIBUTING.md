# Contributing

Park Here uses staged branches to keep `main` stable.

## Branches

- `main`: stable integration branch.
- `temp-user`: approval/staging branch for user app work.
- `temp-admin`: approval/staging branch for admin app work.
- Addon/scanner work may use isolated feature branches separately.

## User App Changes

1. Checkout `temp-user`.
2. Implement the user app change.
3. Test the change.
4. Commit with a meaningful message.
5. Push `temp-user`.
6. Wait for approval.
7. Merge `temp-user` into `main` only after approval.

## Admin App Changes

1. Checkout `temp-admin`.
2. Implement the admin app change.
3. Test the change.
4. Commit with a meaningful message.
5. Push `temp-admin`.
6. Wait for approval.
7. Merge `temp-admin` into `main` only after approval.

## Rules

- Never commit feature work directly to `main`.
- Keep `main` stable and releasable.
- Do not force push unless explicitly requested.
- Use focused, meaningful commits.
- Test before every merge to `main`.
- Merge only the intended staging branch into `main`.
