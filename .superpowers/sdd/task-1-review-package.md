# Task 1 Review Package

## Commits
6f076da feat: add AuthService wrapping FirebaseAuth

## Stat Summary
 lib/services/auth_service.dart | 28 ++++++++++++++++++++++++++++
 1 file changed, 28 insertions(+)

## Full Diff
```diff
diff --git a/lib/services/auth_service.dart b/lib/services/auth_service.dart
new file mode 100644
index 0000000..2918cf5
--- /dev/null
+++ b/lib/services/auth_service.dart
@@ -0,0 +1,28 @@
+import 'package:firebase_auth/firebase_auth.dart';
+
+class AuthService {
+  final FirebaseAuth _auth = FirebaseAuth.instance;
+
+  Stream<User?> get authStateChanges => _auth.authStateChanges();
+
+  String? get currentUserId => _auth.currentUser?.uid;
+
+  Future<void> signIn(String email, String password) async {
+    await _auth.signInWithEmailAndPassword(
+      email: email.trim(),
+      password: password,
+    );
+  }
+
+  Future<void> signUp(String email, String password, String displayName) async {
+    final credential = await _auth.createUserWithEmailAndPassword(
+      email: email.trim(),
+      password: password,
+    );
+    await credential.user?.updateDisplayName(displayName.trim());
+  }
+
+  Future<void> signOut() async {
+    await _auth.signOut();
+  }
+}
```
