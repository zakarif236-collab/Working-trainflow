import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/services/auth_service.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.authService});

  final AuthService authService;

  static Future<bool> showAsSheet(BuildContext context) async {
    final authService = AuthService();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      builder: (_) => AuthSheet(authService: authService),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AuthSheet(authService: authService);
  }
}

class AuthSheet extends StatefulWidget {
  const AuthSheet({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await widget.authService.signInWithGoogle();
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
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

  String _mapError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    final body = _isSignUp ? _buildEmailForm() : _buildWelcomeButtons(isIOS);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeButtons(bool isIOS) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8A1E), Color(0xFFFFA94D)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fitness_center_rounded, size: 32, color: Colors.white),
        ),
        const SizedBox(height: 20),
        const Text(
          'Welcome \u{1F44B}',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Sign in to sync workouts, share routines and join the community.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(height: 28),
        _buildSocialButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Continue with Google',
          onTap: _isGoogleLoading ? null : _signInWithGoogle,
          isLoading: _isGoogleLoading,
        ),
        if (isIOS) ...[
          const SizedBox(height: 12),
          _buildSocialButton(
            icon: Icons.apple_rounded,
            label: 'Continue with Apple',
            onTap: () {},
          ),
        ],
        const SizedBox(height: 12),
        _buildSocialButton(
          icon: Icons.email_outlined,
          label: 'Continue with Email',
          onTap: () => setState(() => _isSignUp = true),
        ),
        const SizedBox(height: 12),
        _buildTextButton(
          label: 'Continue as Guest',
          onTap: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(height: 20),
        Text(
          'By continuing you agree to the Terms & Privacy Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              _isSignUp ? 'Create Account' : 'Sign In',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp ? 'Enter your details to get started.' : 'Welcome back to the grind.',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            if (_isSignUp) ...[
              TextFormField(
                controller: _displayNameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(label: 'Display Name', icon: Icons.person_outline_rounded),
                validator: (value) => value == null || value.trim().length < 2 ? 'Name must be at least 2 characters' : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(label: 'Email', icon: Icons.email_outlined),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Email is required';
                if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Password is required';
                if (value.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            if (_isSignUp) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(label: 'Confirm Password', icon: Icons.lock_outline_rounded),
                validator: (value) => _isSignUp && value != _passwordController.text ? 'Passwords do not match' : null,
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A1E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _toggleMode,
              child: Text(
                _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
                style: const TextStyle(color: Color(0xFFFF8A1E), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, color: Colors.white54),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white.withValues(alpha: 0.08),
          foregroundColor: foregroundColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
      ),
    );
  }

  Widget _buildTextButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
