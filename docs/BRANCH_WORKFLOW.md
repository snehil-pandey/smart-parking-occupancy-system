# Branch Workflow

Park Here uses approval/staging branches so user and admin app changes are reviewed before they reach `main`.

## Stable Branch

`main` is the stable branch. It should contain only approved, validated work.

Rules:

- Never commit feature work directly to `main`.
- Keep `main` stable.
- Test before merging.
- Do not force push unless explicitly requested.
- Use meaningful commits.

## User App Changes

Use `temp-user` for all future user app work.

1. `git checkout temp-user`
2. Implement changes.
3. Test changes.
4. Commit changes.
5. `git push origin temp-user`
6. Wait for approval.
7. Merge `temp-user` into `main` only after approval.

## Admin App Changes

Use `temp-admin` for all future admin app work.

1. `git checkout temp-admin`
2. Implement changes.
3. Test changes.
4. Commit changes.
5. `git push origin temp-admin`
6. Wait for approval.
7. Merge `temp-admin` into `main` only after approval.

## Addon And Scanner Work

Addon or scanner work can use isolated feature branches separate from `temp-user` and `temp-admin`. Keep those branches focused and merge them into `main` only after explicit approval.

## Merge Discipline

Before merging into `main`:

1. Confirm the source branch is the intended branch.
2. Confirm `main` is up to date.
3. Run the relevant analysis and tests.
4. Resolve conflicts without overwriting unrelated app work.
5. Push `main` only after validation.
