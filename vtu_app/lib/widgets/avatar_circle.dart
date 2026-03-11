import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

/// Displays the user's profile photo (from [AuthProvider.avatarPath]) or
/// their initial as a fallback. Rebuilds automatically when the avatar changes.
class AvatarCircle extends StatelessWidget {
  final double radius;
  final double fontSize;

  const AvatarCircle({
    super.key,
    required this.radius,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final avatarPath = auth.avatarPath;
    final initial = auth.user?.firstName.isNotEmpty == true
        ? auth.user!.firstName[0].toUpperCase()
        : 'U';

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.15),
      backgroundImage:
          avatarPath != null ? FileImage(File(avatarPath)) : null,
      child: avatarPath == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryIndigo,
              ),
            )
          : null,
    );
  }
}
