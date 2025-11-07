import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final double padding;
  final double iconSize;
  final bool verticalLayout;
  final double spacing;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.iconColor,
    this.label = '',
    this.padding = 16.0,
    this.iconSize = 24.0,
    this.verticalLayout = false,
    this.spacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLabel = label.isNotEmpty;
    final bool hasIcon = icon != null;

    final Widget? iconWidget = hasIcon
        ? Icon(
            icon,
            size: iconSize,
            color: iconColor ?? foregroundColor,
          )
        : null;

    final Widget textWidget = hasLabel
        ? Text(
            label,
            textAlign: TextAlign.center,
          )
        : const SizedBox.shrink();

    List<Widget> children = [];

    if (hasIcon) {
      children.add(iconWidget!);
    }

    if (hasIcon && hasLabel) {
      // Only add spacing if both exist
      children.add(verticalLayout
          ? SizedBox(height: spacing)
          : SizedBox(width: spacing));
    }

    if (hasLabel) {
      children.add(textWidget);
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        padding: EdgeInsets.symmetric(vertical: padding, horizontal: padding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: verticalLayout
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
    );
  }
}
