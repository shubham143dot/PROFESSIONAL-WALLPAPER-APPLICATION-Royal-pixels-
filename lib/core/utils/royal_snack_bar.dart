import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum SnackBarType { success, error, info }

/// Shows a custom floating, dark-themed snackbar.
///
/// Usage:
/// ```dart
/// RoyalSnackBar.show(context, '✅ Wallpaper saved!');
/// RoyalSnackBar.show(context, 'Download failed', type: SnackBarType.error);
/// ```
class RoyalSnackBar {
  RoyalSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final Color bgColor;
    final Color borderColor;
    final IconData icon;
    final Color iconColor;

    switch (type) {
      case SnackBarType.success:
        bgColor = const Color(0xFF0A1F14);
        borderColor = Colors.greenAccent.withAlpha(100);
        icon = Icons.check_circle_outline_rounded;
        iconColor = Colors.greenAccent;
        break;
      case SnackBarType.error:
        bgColor = const Color(0xFF1F0A0A);
        borderColor = Colors.redAccent.withAlpha(100);
        icon = Icons.error_outline_rounded;
        iconColor = Colors.redAccent;
        break;
      case SnackBarType.info:
        bgColor = AppColors.bg2;
        borderColor = AppColors.goldMid.withAlpha(100);
        icon = Icons.info_outline_rounded;
        iconColor = AppColors.goldLight;
        break;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: duration,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(80),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
