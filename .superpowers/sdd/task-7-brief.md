### Task 7: Wire Firestore rules into deploy; parameterize admin authorization

**Files:**
- Modify: `firebase.json`
- Modify: `firestore.rules`

**Interfaces:**
- Produces: `firebase deploy --only firestore:rules` pushes `firestore.rules`; community-workout delete requires `request.auth.token.admin == true`.

- [ ] **Step 1: Add the rules reference to `firebase.json`**

Replace the entire one-line `firebase.json` with:

```json
{"flutter":{"platforms":{"android":{"default":{"projectId":"video-helper-21817","appId":"1:832592716654:android:11ec55736f9e676665577f","fileOutput":"android/app/google-services.json"}},"dart":{"lib/firebase_options.dart":{"projectId":"video-helper-21817","configurations":{"android":"1:832592716654:android:11ec55736f9e676665577f","ios":"1:832592716654:ios:ac715fa0b6bd8a6365577f","macos":"1:832592716654:ios:ac715fa0b6bd8a6365577f","web":"1:832592716654:web:20a5212b50d8da4a65577f","windows":"1:832592716654:web:ef4d41d6988f5f1b65577f"}}}},"firestore":{"rules":"firestore.rules"}}
```

- [ ] **Step 2: Replace the admin email with a custom claim in `firestore.rules`**

In `firestore.rules`, replace the delete rule (lines 24-26):

```
      allow delete: if request.auth != null &&
          (resource.data.creatorId == request.auth.uid ||
           request.auth.token.email == 'kingslayer.et@gmail.com');
```

with:

```
      allow delete: if request.auth != null &&
          (resource.data.creatorId == request.auth.uid ||
           request.auth.token.admin == true);
```

- [ ] **Step 3: Validate the JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('firebase.json','utf8')); console.log('valid json')"`
Expected: `valid json`

- [ ] **Step 4: Commit**

```bash
git add firebase.json firestore.rules
git commit -m "chore: wire firestore rules into deploy and use admin custom claim"
```

- [ ] **Step 5: Manual checklist (document for the user, do not run)**

1. Set the admin claim once: `firebase` Admin SDK `setCustomUserClaims('<admin-uid>', {admin: true})`.
2. Deploy: `firebase deploy --only firestore:rules`.
3. Verify a community-workout delete still works for the admin and still fails for non-admins.

---

