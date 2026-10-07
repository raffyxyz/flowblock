import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Round animated checkbox with a 48px touch target.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return Semantics(
      button: true,
      checked: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: AppSpace.x12,
          height: AppSpace.x12,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.short,
              curve: Curves.easeOut,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? colors.accent : Colors.transparent,
                border: Border.all(
                  color: value ? colors.accent : colors.muted,
                  width: 2,
                ),
              ),
              child: AnimatedScale(
                duration: AppMotion.short,
                curve: Curves.easeOut,
                scale: value ? 1 : 0,
                child: Icon(Icons.check, size: 16, color: colors.onAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
