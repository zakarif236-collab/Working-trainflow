# Task 7 Report: Wire Firestore rules into deploy; parameterize admin authorization

**Status:** DONE_WITH_CONCERNS

## What changed

1. **`firebase.json`** — Replaced the single-line file with the intended replacement JSON: the current content plus a top-level `"firestore":{"rules":"firestore.rules"}` section, so `firebase deploy --only firestore:rules` pushes `firestore.rules`.

2. **`firestore.rules`** — Replaced ONLY the community-workout delete rule (lines 24-26). Changed `request.auth.token.email == 'kingslayer.et@gmail.com'` to `request.auth.token.admin == true`. All surrounding rules and comments untouched.

## JSON validation

Command (run from `C:\Users\hp\my_app`):

```
node -e "JSON.parse(require('fs').readFileSync('firebase.json','utf8')); console.log('valid json')"
```

Output:

```
valid json
```

Additional structural check: `JSON.parse` of the committed content yields top-level keys `flutter, firestore` with `firestore.rules === "firestore.rules"` (9 `{` / 9 `}`).

## Commit

- SHA: `6e5006cd18a091b561ee38e7440748554a89c33a` (short: `6e5006c`)
- Subject: `chore: wire firestore rules into deploy and use admin custom claim`
- Files: only `firebase.json` and `firestore.rules` (verified via `git show --stat`). No `git add -A` / `git add .` used.

## Concern (why DONE_WITH_CONCERNS)

The task brief's Step 1 verbatim JSON string (`.superpowers/sdd/task-7-brief.md`, line 15) is **invalid JSON**: it has 9 opening braces and only 8 closing braces (verified programmatically). Committing it byte-for-byte would break `firebase.json` and make the whole `firebase deploy` configuration unparseable — contradicting Step 3, which requires the validation command to output `valid json`.

I fixed the brief's typo minimally: inserted exactly one `}` immediately before `,"firestore"` so `firestore` is a top-level key (sibling of `flutter`), matching the brief's stated intent ("the current file's content plus `"firestore":{"rules":"firestore.rules"}` at the end"). This is the only byte difference from the brief's string (582 vs 583 bytes, single added `}`). If the brief's verbatim string was intentional, the correct string is NOT what the brief contains and would need to be reconciled.

## Step 5: Manual checklist (documented for the user; NOT run)

1. Set the admin claim once: `firebase` Admin SDK `setCustomUserClaims('<admin-uid>', {admin: true})`.
2. Deploy: `firebase deploy --only firestore:rules`.
3. Verify a community-workout delete still works for the admin and still fails for non-admins.

Note: `firebase deploy` and Admin SDK commands were intentionally NOT run in this task, per task instructions.
