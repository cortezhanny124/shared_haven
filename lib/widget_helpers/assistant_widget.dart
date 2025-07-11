import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class AssistantWidget extends StatefulWidget {
  final String initialMessage;
  final BuildContext context; // ✅ Accept context as a parameter
  final Function() onClose;
  final Function(Offset)? onDragEnd;
  final Function() onNextMessage;

  const AssistantWidget({
    super.key,
    required this.initialMessage,
    required this.context, // ✅ Store context
    required this.onClose,
    required this.onNextMessage,
    this.onDragEnd,
  });

  @override
  AssistantWidgetState createState() => AssistantWidgetState();
}

class AssistantWidgetState extends State<AssistantWidget>
    with SingleTickerProviderStateMixin {
  String _message = ""; // Store the message inside state
  bool _showMessage = false;

  late SettingsProvider settingsProvider;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage; // Initialize the message

    settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Ensure context is available after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {}); // Triggers a rebuild when context is available
      }
    });
  }

  void updateMessage(String newMessage) {
    setState(() {
      _message = newMessage;
      _showMessage = true;
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Draggable(
      // When the widget is dragged, this defines what will be displayed as a "preview" while dragging.
      feedback: Material(
        color: Colors
            .transparent, // Keeps the background transparent while dragging
        child: _buildAssistant(), // Displays the assistant while being dragged
      ),

      // When the widget is being dragged, this defines what remains in place.
      childWhenDragging:
          Container(), // Keeps an empty space while the assistant is being dragged

      // Callback triggered when the user stops dragging the widget.
      onDragEnd: (details) {
        widget.onDragEnd?.call(details
            .offset); // Updates the assistant's position if a drag end function is provided.
      },

      // The main child that is draggable.
      child: GestureDetector(
        // When the assistant is tapped, cycle to the next message.
        onTap: widget.onNextMessage, // ✅ Tap cycles through messages

        // Ensures that the assistant can still be dragged even though GestureDetector is handling taps.
        onPanStart:
            (details) {}, // ✅ Detects drag gestures, preventing GestureDetector from blocking dragging

        // Builds the assistant widget, which includes the icon and the speech bubble (if active).
        child: _buildAssistant(),
      ),
    );
  }

  Widget _buildAssistant() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speech Bubble (only if visible)
        if (_showMessage)
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMessage = false;
                });
              },
              child: Transform.translate(
                offset: const Offset(10, -10), // optional fine-tuning
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 50,
                    maxWidth: 200,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.container(context),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.background(context),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    AppLocalizations.of(widget.context)!.translate(_message),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text(widget.context),
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 8), // spacing between bubble and icon

        // Assistant Icon
        GestureDetector(
          onTap: () {
            widget.onNextMessage();
          },
          child: CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.dialog(context),
            child: Lottie.asset(
              settingsProvider.isMainnet
                  ? 'assets/animations/assistant_mainnet.json'
                  : 'assets/animations/assistant_testnet.json',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
        ),
      ],
    );
  }
}
