import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Modern, consistent header widget for all pages
/// Provides uniform styling with InkSync branding
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showLogo;
  final bool centerTitle;
  final VoidCallback? onBack;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showLogo = false,
    this.centerTitle = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimary,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Leading widget (back button or custom)
            if (leading != null)
              leading!
            else if (onBack != null)
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
                onPressed: onBack,
              )
            else
              const SizedBox(width: 8),

            // Logo (optional)
            if (showLogo) ...[_buildLogo(), const SizedBox(width: 8)],

            // Title & Subtitle
            if (centerTitle) const Spacer(),
            Expanded(
              flex: centerTitle ? 0 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: showLogo ? 20 : 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (centerTitle) const Spacer(),

            // Actions
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF1E88E5), // Blue
          Color(0xFF10D98C), // Green
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Image.asset(
        'assets/images/logo_transparent.png',
        width: 28,
        height: 28,
      ),
    );
  }
}

/// Simple header for pages that just need a title, back button, and optional actions
class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;

  const SimpleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading:
          leading ??
          (showBackButton
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                )
              : null),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppTheme.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: false,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}
