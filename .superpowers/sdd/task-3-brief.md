### Task 3: AuthSheet — Handle Anonymous Linking

**Files:**
- Modify: `lib/pages/auth_page.dart`

**Interfaces:**
- Consumes: `AuthService.isAnonymous`, `AuthService.linkWithGoogle()`, `AuthService.linkWithEmail(String, String)`
- Produces: Auth sheet that links credentials when current user is anonymous, signs in normally otherwise

**Changes:**

1. Replace `_signInWithGoogle` to use linking when anonymous:

```dart
Future<void> _signInWithGoogle() async {
  setState(() => _isGoogleLoading = true);
  try {
    if (widget.authService.isAnonymous) {
      await widget.authService.linkWithGoogle();
    } else {
      await widget.authService.signInWithGoogle();
    }
    if (mounted) Navigator.of(context).pop(true);
  } on AuthServiceException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Google sign-in failed: $e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } finally {
    if (mounted) setState(() => _isGoogleLoading = false);
  }
}
```

2. Replace `_submit` to use linking when anonymous:

```dart
Future<void> _submit() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;
  setState(() => _isLoading = true);
  try {
    if (widget.authService.isAnonymous) {
      await widget.authService.linkWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      if (_isSignUp) {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(_displayNameController.text);
      }
    } else {
      if (_isSignUp) {
        await widget.authService.signUp(
          _emailController.text,
          _passwordController.text,
          _displayNameController.text,
        );
      } else {
        await widget.authService.signIn(
          _emailController.text,
          _passwordController.text,
        );
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;
    final message = _mapError(e.code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Something went wrong. Please try again.'), behavior: SnackBarBehavior.floating),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Note:** The file already imports `package:firebase_auth/firebase_auth.dart` (for `FirebaseAuthException`) and `package:my_app/services/auth_service.dart`. No new imports needed.

Run `dart analyze lib/pages/auth_page.dart` to verify.
Commit: `feat: link credentials when anonymous in AuthSheet`
