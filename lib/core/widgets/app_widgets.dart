import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppGradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppGradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
  });

  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions,
      bottom: bottom,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: AppTheme.brandGradient),
      ),
    );
  }
}

class AppResponsiveContent extends StatelessWidget {
  const AppResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 680,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppGradientButton extends StatelessWidget {
  const AppGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: loading ? '$label. Procesando.' : label,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.24),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
          icon: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : icon == null
              ? const SizedBox.shrink()
              : Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

class AppStatusView extends StatelessWidget {
  const AppStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color = AppColors.textMuted,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: color),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppInlineMessage extends StatelessWidget {
  const AppInlineMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
    this.action,
  });

  final IconData icon;
  final String message;
  final Color background;
  final Color foreground;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
