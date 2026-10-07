import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Rounded square "+" / "−" used everywhere in the ordering flow (cart,
/// product buy bar, product cards): soft pale-blue tile with a dark-blue "+",
/// light-grey tile with a dark "−". No border.
class StepperButton extends StatelessWidget {
  const StepperButton.plus(
      {super.key, required this.tooltip, this.onPressed, this.size = 34})
      : icon = Icons.add,
        _isPlus = true;

  const StepperButton.minus(
      {super.key, required this.tooltip, this.onPressed, this.size = 34})
      : icon = Icons.remove,
        _isPlus = false;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool _isPlus;

  static const plusBackground = AppColors.primarySoft; // #EEF2FB
  static const plusForeground = AppColors.primaryDark; // #3F478D
  static const minusBackground = Color(0xFFF1F3F7);
  static const minusForeground = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : .4,
        child: Material(
          color: _isPlus ? plusBackground : minusBackground,
          borderRadius: BorderRadius.circular(size * .3),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(size * .3),
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon,
                  size: size * .55,
                  color: _isPlus ? plusForeground : minusForeground),
            ),
          ),
        ),
      ),
    );
  }
}
