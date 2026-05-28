import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Adaptively shows a bottom sheet on mobile devices,
/// and a centered dialog on desktop/web screens.
Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  Color? backgroundColor,
  double maxDialogWidth = 460,
  ShapeBorder? shape,
}) {
  final isDesktop = MediaQuery.of(context).size.width > 800;

  if (isDesktop) {
    return showDialog<T>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: backgroundColor ?? (isDark ? const Color(0xFF161B22) : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxDialogWidth),
            child: child,
          ),
        );
      },
    );
  } else {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor ?? Colors.transparent,
      shape: shape ?? const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => child,
    );
  }
}

/// Shows a large centered dialog on desktop for main views (Settings, Tutorial, Help)
Future<T?> showLargeDialog<T>({
  required BuildContext context,
  required Widget child,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<T>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 650,
            maxHeight: 700,
          ),
          child: child,
        ),
      );
    },
  );
}

/// Displays a beautiful success floating snackbar with constrained width on desktop
/// and a nice padded floating snackbar on mobile devices.
void showSuccessSnackBar(BuildContext context, String message, {SnackBarAction? action}) {
  final isDesktop = MediaQuery.of(context).size.width > 800;

  // Clear existing snackbars first
  ScaffoldMessenger.of(context).clearSnackBars();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.primaryColor,
      behavior: SnackBarBehavior.floating,
      width: isDesktop ? 400 : null,
      margin: isDesktop ? null : const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
      action: action,
    ),
  );
}

/// Displays a beautiful error floating snackbar with constrained width on desktop.
void showErrorSnackBar(BuildContext context, String message) {
  final isDesktop = MediaQuery.of(context).size.width > 800;

  // Clear existing snackbars first
  ScaffoldMessenger.of(context).clearSnackBars();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      width: isDesktop ? 400 : null,
      margin: isDesktop ? null : const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ),
  );
}
