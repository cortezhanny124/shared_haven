import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/widget_helpers/assistant_widget.dart';

class CustomBottomSheet {
  static Future<T?> buildCustomBottomSheet<T>({
    required BuildContext context,
    required String titleKey,
    Map<String, String>? titleParams,
    required Widget content,
    List<Widget>? actions,
    Axis actionsLayout = Axis.horizontal,
    double maxHeightFactor = 0.9,
    double cordnerRadius = 20.0,
    bool useRootNavigator = true,
  }) {
    final rootContext = context;

    // Localize title with dynamic placeholders
    String localizedTitle =
        AppLocalizations.of(rootContext)!.translate(titleKey);
    if (titleParams != null && titleParams.isNotEmpty) {
      titleParams.forEach((k, v) {
        localizedTitle = localizedTitle.replaceAll('{$k}', v);
      });
    }

    return showModalBottomSheet(
      context: rootContext,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: AppColors.transaparent(),
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final maxH = media.size.height * maxHeightFactor;

        return GestureDetector(
          onTap: () {}, // Prevent taps from leaking to the barrier
          child: SafeArea(
            top: false, // Bottom sheet, keep top safe-area off
            child: Padding(
              // Respect the keyboard if open
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.dialog(sheetContext),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(cordnerRadius),
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, -6),
                          color: AppColors.black().opaque(0.25),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.text(sheetContext).opaque(0.25),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Text(
                            localizedTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(sheetContext),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.text(sheetContext).opaque(0.1),
                        ),

                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            child: content,
                          ),
                        ),

                        if (actions != null && actions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: actionsLayout == Axis.horizontal
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: actions
                                        .map((w) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6.0),
                                              child: w,
                                            ))
                                        .toList(),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: actions
                                        .map((w) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6.0),
                                              child: w,
                                            ))
                                        .toList(),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<T?> buildCustomStatefulBottomSheet<T>({
    required BuildContext context,
    required String titleKey,
    required Widget Function(
      StateSetter setSheetState,
      void Function(BuildContext, String) updateAssistantMessage,
    ) contentBuilder,
    List<Widget> Function(StateSetter setSheetState)? actionsBuilder,
    bool showAssistant = false,
    List<String> assistantMessages = const [],
    double initialChildSize = 0.7, // <- start size
    double minChildSize = 0.5,
    double maxChildSize = 0.95, // <- max size
    bool useRootNavigator = true,
  }) {
    final rootContext = context;
    final GlobalKey<AssistantWidgetState> assistantKey =
        GlobalKey<AssistantWidgetState>();

    String assistantMessage = assistantMessages.isNotEmpty
        ? assistantMessages[0]
        : "How can I assist you?";
    int assistantMessageIndex = 0;

    return showModalBottomSheet(
      context: rootContext,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppColors.transaparent(),
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);

        return StatefulBuilder(
            builder: (BuildContext ctx, StateSetter setSheetState) {
          void updateAssistantMessage(BuildContext context, String message) {
            setSheetState(() {
              assistantMessage = message;
            });
            assistantKey.currentState?.updateMessage(message);
          }

          void onNextAssistantMessage() {
            if (assistantMessages.isEmpty) return;
            setSheetState(() {
              assistantMessageIndex =
                  (assistantMessageIndex + 1) % assistantMessages.length;

              assistantMessage = assistantMessages[assistantMessageIndex];
            });
            assistantKey.currentState?.updateMessage(assistantMessage);
          }

          return GestureDetector(
            onTap: () {}, // Prevent taps from leaking to the barrier
            child: SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: Stack(
                  children: [
                    // Sheet Body
                    DraggableScrollableSheet(
                      initialChildSize: initialChildSize.clamp(
                        minChildSize,
                        maxChildSize,
                      ),
                      minChildSize: minChildSize,
                      maxChildSize: maxChildSize,
                      builder: (context, scrollController) {
                        return Material(
                          color: AppColors.dialog(sheetContext),
                          elevation: 12,
                          shadowColor: AppColors.black().opaque(0.25),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 4),
                                child: Container(
                                  width: 44,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: AppColors.text(sheetContext)
                                        .opaque(0.25),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                child: Text(
                                  AppLocalizations.of(rootContext)!
                                      .translate(titleKey),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardTitle(sheetContext),
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: AppColors.text(sheetContext).opaque(0.1),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                  child: contentBuilder(
                                    setSheetState,
                                    updateAssistantMessage,
                                  ),
                                ),
                              ),
                              if (actionsBuilder != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: actionsBuilder(setSheetState),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    if (showAssistant)
                      Positioned(
                        right: 20,
                        bottom: 80,
                        child: AssistantWidget(
                          key: assistantKey,
                          initialMessage: assistantMessage,
                          context: rootContext,
                          onClose: () {
                            setSheetState(() {
                              assistantMessage = "";
                            });
                          },
                          onNextMessage: onNextAssistantMessage,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
