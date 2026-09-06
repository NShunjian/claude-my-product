import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// 对齐 components/ColorSwatch.vue — 6 色圆形调色板,v-model 风格。
class ColorSwatch extends StatelessWidget {
  const ColorSwatch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const palette = <String>[
    '#2E7DE6',
    '#BA1A1A',
    '#FFA000',
    '#388E3C',
    '#7B1FA2',
    '#A0AEC0',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final hex in palette)
          GestureDetector(
            onTap: () => onChanged(hex),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _parse(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: value.toUpperCase() == hex
                      ? c.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Color _parse(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
