import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/services/user_profile_service.dart';

class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key, required this.authService});

  final AuthService authService;

  static Future<void> showIfNeeded(BuildContext context, AuthService authService) async {
    final isFirst = await authService.isFirstLogin;
    if (!isFirst) return;
    final onboardingDone = await authService.isOnboardingComplete;
    if (onboardingDone) return;
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => OnboardingSheet(authService: authService),
    );
  }

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final _usernameController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _profileImagePath;
  FitnessGoal? _selectedGoal;
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked != null) {
      setState(() => _profileImagePath = picked.path);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = widget.authService.currentUserId;
      final displayName = _usernameController.text.trim();
      if (displayName.isNotEmpty) {
        await UserProfileService().updateProfile(uid, {'displayName': displayName});
        final settings = SettingsService();
        await settings.saveDisplayName(displayName);
      }
      if (_profileImagePath != null && _profileImagePath!.trim().isNotEmpty) {
        await UserProfileService().updateProfile(uid, {'profileImagePath': _profileImagePath});
        final settings = SettingsService();
        await settings.saveProfileImagePath(_profileImagePath!);
      }
      if (_selectedGoal != null) {
        await UserProfileService().updateProfile(uid, {'fitnessGoal': _selectedGoal!.name});
      }
      await widget.authService.markOnboardingComplete();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
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
            const SizedBox(height: 24),
            const Text(
              'Set up your profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a username and optionally a profile photo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF384A6A), Color(0xFF2E314A)],
                      ),
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _profileImagePath != null
                        ? Image.file(File(_profileImagePath!), fit: BoxFit.cover)
                        : const Icon(Icons.person_rounded, size: 40, color: Colors.white54),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF8A1E), shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white54),
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
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Fitness Goal (optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: FitnessGoal.values.map((goal) {
                final selected = _selectedGoal == goal;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGoal = selected ? null : goal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFF8A1E).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(0xFFFF8A1E) : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      goal.displayName,
                      style: TextStyle(
                        color: selected ? const Color(0xFFFF8A1E) : Colors.white70,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A1E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 44,
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        await widget.authService.markOnboardingComplete();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: Text('Skip', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
