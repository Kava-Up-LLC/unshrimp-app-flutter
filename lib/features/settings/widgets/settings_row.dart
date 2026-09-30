import 'package:flutter/material.dart';

/// One settings row: a label, an optional subtitle, and a value or [trailing]
/// widget on the right. Disabled when [onTap] is null.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.subtitle,
    this.value,
    this.trailing,
    this.labelColor,
    this.onTap,
  });

  final String label;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(
          color: labelColor,
          fontWeight: labelColor != null ? FontWeight.w700 : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          : null,
      trailing:
          trailing ??
          (value != null
              ? Text(
                  value!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null),
    );
  }
}
