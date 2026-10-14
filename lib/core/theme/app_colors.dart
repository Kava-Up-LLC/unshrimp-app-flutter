import 'package:flutter/material.dart';

/// Unshrimp palette.
///
/// - Teal: movement, health, "take a break" (primary actions).
/// - Coral: the shrimp posture / Posture Roast / Spine Battery (shame, warnings).
/// - Amber: Spine Streak 🔥 and achievements.
class AppColors {
  const AppColors._();

  // Brand
  static const teal = Color(0xFF0B7A6E);
  static const tealLight = Color(0xFF3FD1BC);
  static const tealContainer = Color(0xFFC6F1EA);
  static const tealContainerDark = Color(0xFF0A4F47);

  static const coral = Color(0xFFFF6B4A);
  static const coralLight = Color(0xFFFF9A80);
  static const coralContainer = Color(0xFFFFDAD1);
  static const coralContainerDark = Color(0xFF7A2A18);

  /// Posture Roast backdrop — matches the shrimp icon's teal so it sits flush.
  static const roastTeal = Color(0xFF46C5BE);

  static const amber = Color(0xFFFFB020);
  static const amberLight = Color(0xFFFFC95C);
  static const amberContainer = Color(0xFFFFE8B8);
  static const amberContainerDark = Color(0xFF6B4A00);

  // Feedback
  static const error = Color(0xFFD93A3F);
  static const errorLight = Color(0xFFFF8A8C);

  // Neutrals — light
  static const backgroundLight = Color(0xFFF6F9F8);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceVariantLight = Color(0xFFE3ECEA);
  static const textLight = Color(0xFF13201E);
  static const textMutedLight = Color(0xFF5A6B68);
  static const outlineLight = Color(0xFFC3D0CD);

  // Neutrals — dark
  static const backgroundDark = Color(0xFF0E1615);
  static const surfaceDark = Color(0xFF16211F);
  static const surfaceVariantDark = Color(0xFF223230);
  static const textDark = Color(0xFFE6EFED);
  static const textMutedDark = Color(0xFF9FB2AE);
  static const outlineDark = Color(0xFF3A4D4A);

  // Text on brand colors
  static const onDark = Color(0xFFFFFFFF);
  static const onTealLight = Color(0xFF00201C);
  static const onCoral = Color(0xFF2A0E06);
  static const onAmber = Color(0xFF2B1A00);
}
