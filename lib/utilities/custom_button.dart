import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final Color iconColor;
  final String label;
  final double padding;
  final double iconSize;
  final bool
      verticalLayout; // 🔥 new: determines if icon/text are stacked vertically
  final double spacing; // optional: space between icon and text

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.iconColor,
    this.label = '',
    this.padding = 16.0,
    this.iconSize = 24.0,
    this.verticalLayout = false, // default = row layout
    this.spacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLabel = label.isNotEmpty;

    final Widget iconWidget = Icon(
      icon,
      size: iconSize,
      color: iconColor,
    );

    final Widget textWidget = hasLabel
        ? Text(
            label,
          )
        : const SizedBox.shrink();

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: foregroundColor, // text color
        backgroundColor: backgroundColor, // button background
        padding: EdgeInsets.symmetric(vertical: padding, horizontal: padding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: verticalLayout
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                if (hasLabel) SizedBox(height: spacing),
                textWidget,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                if (hasLabel) SizedBox(width: spacing),
                textWidget,
              ],
            ),
    );
  }
}
