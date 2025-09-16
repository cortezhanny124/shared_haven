import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class InkwellButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String? label;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? iconColor;
  final double borderRadius;

  const InkwellButton({
    super.key,
    required this.onTap,
    this.label,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.iconColor,
    this.borderRadius = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      splashColor: isDisabled ? Colors.transparent : null, // Prevent ripple
      child: Card(
        color: isDisabled
            ? backgroundColor.opaque(0.5) // Dim background
            : backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: isDisabled ? 0.0 : 4.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  color: isDisabled
                      ? textColor.opaque(0.5)
                      : iconColor ?? textColor,
                  size: 24,
                ),
              if (icon != null && label != null) const SizedBox(width: 8),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    color: isDisabled ? textColor.opaque(0.5) : textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
