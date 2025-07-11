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
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: foregroundColor, // Text color
        backgroundColor: backgroundColor, // Button background color
        padding: EdgeInsets.symmetric(vertical: padding, horizontal: padding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Rounded corners
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min, // Makes button take only necessary space
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 6), // Space between icon and text
            Text(label),
          ],
        ],
      ),
    );
  }
}
