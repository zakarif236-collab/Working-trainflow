### Task 1: Swap App ID in Android manifest and iOS Info.plist

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:18-20`
- Modify: `ios/Runner/Info.plist:7-8`

**Interfaces:**
- Consumes: nothing.
- Produces: platform config files that advertise the new App ID to the AdMob SDK at app launch. Later tasks depend only on `AdHelper`, not on these files directly, but ad serving requires the App ID to match the account owning the production banner unit.

- [ ] **Step 1: Update the Android manifest App ID**

Edit `android/app/src/main/AndroidManifest.xml` lines 18-20. Change only the `android:value`:

```xml
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3222893031015336~9049517717"/>
```

- [ ] **Step 2: Update the iOS Info.plist App ID**

Edit `ios/Runner/Info.plist` lines 7-8. Change only the string value:

```xml
	<key>GADApplicationIdentifier</key>
	<string>ca-app-pub-3222893031015336~9049517717</string>
```

- [ ] **Step 3: Verify the change is scoped correctly**

Run: `rg "ca-app-pub-3222893031015336" android ios`
Expected: exactly 2 matches — one in `android/app/src/main/AndroidManifest.xml`, one in `ios/Runner/Info.plist`.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat(ads): point App ID to new AdMob account"
```

---
