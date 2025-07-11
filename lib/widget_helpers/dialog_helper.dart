import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/widget_helpers/assistant_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DialogHelper {
  /// Generic dialog helper that can return any type (`bool`, `String`, `int`, etc.).
  static Future<T?> buildCustomDialog<T>({
    required BuildContext context,
    required String titleKey, // Localization key for the title
    Map<String, String>? titleParams, // Dynamic
    required Widget content, // Dialog's main content
    List<Widget>? actions, // Optional actions
    bool showCloseButton = true, // Default: Show the close button
    Axis actionsLayout =
        Axis.horizontal, // Default: actions in row or vertical for column
  }) async {
    final rootContext = context;

    // Get the translated string and replace placeholders dynamically
    String localizedTitle =
        AppLocalizations.of(rootContext)!.translate(titleKey);
    if (titleParams != null) {
      titleParams.forEach((key, value) {
        localizedTitle = localizedTitle.replaceAll('{$key}', value);
      });
    }

    return showDialog<T>(
      context: rootContext,
      barrierDismissible: false, // Prevent accidental closing
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Stack(
              children: [
                AlertDialog(
                  backgroundColor: AppColors.dialog(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  titlePadding: EdgeInsets.zero, // Remove default title padding
                  title: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 24.0,
                        ),
                        child: Text(
                          localizedTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardTitle(context),
                          ),
                        ),
                      ),

                      // Conditionally show the close button in the top-right corner
                      if (showCloseButton)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: AppColors.text(context),
                            ),
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true).pop();
                            },
                          ),
                        ),
                    ],
                  ),
                  content: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    child: SingleChildScrollView(
                      physics:
                          BouncingScrollPhysics(), // Makes scrolling smooth
                      child: content,
                    ),
                  ),
                  actionsPadding:
                      EdgeInsets.only(bottom: 10), // Adjust bottom padding
                  actionsAlignment: MainAxisAlignment.center, // Center actions
                  actions: actions != null && actions.isNotEmpty
                      ? [
                          if (actionsLayout == Axis.horizontal)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: actions,
                            )
                          else
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: actions,
                            ),
                        ]
                      : null, // Hide actions row if not provided
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<T?> buildCustomStatefulDialog<T>({
    required BuildContext context,
    required String titleKey, // Localization key for the title
    required Widget Function(void Function(void Function()) setDialogState,
            void Function(BuildContext, String) updateAssistant)
        contentBuilder,
    List<Widget> Function(StateSetter setDialogState)?
        actionsBuilder, // Actions builder
    bool showCloseButton = true, // Default: Show the close button
    bool showAssistant = false, // Show the assistant in this dialog
    List<String> assistantMessages =
        const [], // ✅ Messages specific to this dialog
  }) async {
    final rootContext = context;
    final GlobalKey<AssistantWidgetState> assistantKey =
        GlobalKey<AssistantWidgetState>();

    String assistantMessage = assistantMessages.isNotEmpty
        ? assistantMessages[0]
        : "How can I assist you?";

    int assistantMessageIndex = 0;

    return showDialog<T>(
      context: rootContext,
      barrierDismissible: false, // Prevent accidental closing
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            void updateAssistantMessage(BuildContext context, String message) {
              setDialogState(() {
                assistantMessage = message;
              });

              if (assistantKey.currentState != null) {
                assistantKey.currentState!.updateMessage(message);
              }
            }

            void onNextAssistantMessage() {
              if (assistantMessage.isNotEmpty) {
                setDialogState(() {
                  // print("Index before: $assistantMessageIndex");

                  assistantMessageIndex =
                      (assistantMessageIndex + 1) % assistantMessages.length;
                  assistantMessage = assistantMessages[assistantMessageIndex];
                });

                // print("Index after: $assistantMessageIndex");

                // print("Next message: $assistantMessage");

                if (assistantKey.currentState != null) {
                  assistantKey.currentState!.updateMessage(assistantMessage);
                }
              }
            }

            return Stack(
              children: [
                AlertDialog(
                  backgroundColor: AppColors.dialog(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  titlePadding: EdgeInsets.zero, // Remove default title padding
                  title: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 24.0,
                        ),
                        child: Text(
                          AppLocalizations.of(rootContext)!.translate(titleKey),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardTitle(context),
                          ),
                        ),
                      ),

                      // Conditionally show the close button in the top-right corner
                      if (showCloseButton)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton(
                            icon: Icon(Icons.close,
                                color: AppColors.text(context)),
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true).pop();
                            },
                          ),
                        ),
                    ],
                  ),
                  content: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: contentBuilder(setDialogState,
                          updateAssistantMessage), // Pass StateSetter
                    ),
                  ),
                  actionsPadding:
                      EdgeInsets.only(bottom: 10), // Adjust bottom padding
                  actionsAlignment: MainAxisAlignment.center, // Center actions
                  actions: actionsBuilder != null
                      ? [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: actionsBuilder(
                                setDialogState), // Pass StateSetter to actions
                          ),
                        ]
                      : null, // Hide actions row if not provided
                ),
                if (showAssistant)
                  Positioned(
                    right: 20,
                    bottom: 80,
                    child: AssistantWidget(
                      onNextMessage: onNextAssistantMessage,
                      context: rootContext,
                      key: assistantKey,
                      initialMessage: assistantMessage,
                      onClose: () {
                        setDialogState(() {
                          assistantMessage = "";
                        });
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> showFullscreenQrDialog({
    required BuildContext context,
    required String data,
    String? titleKey,
  }) async {
    final rootContext = context;

    await showGeneralDialog(
      context: rootContext,
      barrierDismissible: true,
      barrierLabel: 'fullscreen_qr',
      pageBuilder: (BuildContext dialogContext, _, __) {
        final size = MediaQuery.of(dialogContext).size;
        final qrSize = size.shortestSide * 0.85;

        return Material(
          color: AppColors.black(),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: qrSize,
                  height: qrSize,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.white(),
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.background(rootContext),
                        blurRadius: 8.0,
                        spreadRadius: 2.0,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    size: qrSize - 32,
                    backgroundColor: AppColors.white(),
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                ),
              ),

              // Optional: close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppColors.white(),
                    size: 32,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                  },
                ),
              ),

              if (titleKey != null)
                Positioned(
                  top: 40,
                  left: 20,
                  child: Text(
                    AppLocalizations.of(rootContext)!.translate(titleKey),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// ✅ **Updated method to show and control a loading dialog**
  static Future<void> showLoadingDialog(BuildContext context,
      {String? messageKey}) async {
    final rootContext = context;

    showDialog(
      context: rootContext,
      barrierDismissible: false, // Prevent closing
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialog(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(rootContext)!
                    .translate(messageKey ?? 'processing'),
                style: TextStyle(
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        );
      },
    );

    return; // Can be awaited to ensure the function completes
  }

  /// Shows an error dialog with a custom message.
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String messageKey, // Localization key for the message
  }) async {
    final rootContext = context;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialog(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error,
                color: AppColors.error(context),
              ),
              SizedBox(width: 8),
              Text(
                'Error',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(rootContext)!.translate(messageKey),
            style: TextStyle(color: AppColors.text(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// ✅ **Method to close any open dialog (including loading dialog)**
  static void closeDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
