import 'dart:convert';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:flutter_wallet/widget_helpers/assistant_widget.dart';
import 'package:flutter_wallet/widget_helpers/custom_bottom_sheet.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
// import 'package:url_launcher/url_launcher.dart';

class BaseScaffold extends StatefulWidget {
  final Widget body;
  final Text title;
  final Future<void> Function()? onRefresh;
  final bool showAssistantButton;
  final bool showDrawer;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onRefresh,
    this.showAssistantButton = true,
    this.showDrawer = true,
  });

  @override
  BaseScaffoldState createState() => BaseScaffoldState();
}

class BaseScaffoldState extends State<BaseScaffold> {
  Box<dynamic>? _descriptorBox;
  Map<String, Future<DescriptorPublicKey?>> pubKeyFutures = {};

  String _version = '';

  late WalletService walletService;

  DescriptorPublicKey? pubKey;

  bool _showAssistant = false;

  bool _isDuplicate = false;

  String _assistantMessage = "";
  List<String> _assistantMessages = [];

  int _assistantMessageIndex = 0;

  Offset _assistantPosition = Offset(50, 500);

  final GlobalKey<AssistantWidgetState> _assistantKey =
      GlobalKey(); // Track assistant widget state

  final utilitiesService = UtilitiesService();

  @override
  void initState() {
    super.initState();

    walletService =
        WalletService(Provider.of<SettingsProvider>(context, listen: false));

    _descriptorBox = Hive.box<dynamic>('descriptorBox');
    _getVersion();
  }

  void _toggleAssistant() {
    setState(() {
      _showAssistant = !_showAssistant;
    });
    String initialMessage =
        utilitiesService.getAssistantGreetingForRoute(context);
    _assistantMessages = utilitiesService.getAssistantTipsForRoute(context);

    // Show initial message when turning on
    if (_showAssistant) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_assistantKey.currentState != null) {
          _assistantKey.currentState!.updateMessage(initialMessage);
        }
      });
    }
  }

  void _nextAssistantMessage() {
    setState(() {
      _assistantMessageIndex =
          (_assistantMessageIndex + 1) % _assistantMessages.length;
    });

    if (_assistantKey.currentState != null) {
      _assistantKey.currentState!
          .updateMessage(_assistantMessages[_assistantMessageIndex]);
    }
  }

  void updateAssistantMessage(BuildContext context, String message) {
    setState(() {
      _assistantMessage = message;
    });

    // Directly update AssistantWidget state using the GlobalKey
    if (_assistantKey.currentState != null) {
      _assistantKey.currentState!.updateMessage(message);
    }
  }

  void updateAssistantPosition(Offset newPosition) {
    setState(() {
      _assistantPosition = newPosition;
    });
  }

  Future<void> _getVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  bool _isDuplicateDescriptorName(String firstName, String descriptorName) {
    final descriptorBox = Hive.box('descriptorBox');

    // Iterate through all keys and check if any key contains the same descriptor name
    for (var key in descriptorBox.keys) {
      // print('Key: $key');
      if (key.toString().contains(descriptorName.trim()) &&
          !(key.toString().contains(firstName.trim()))) {
        return true; // Duplicate found
      }
    }
    return false; // No duplicate found
  }

  Future<EditAliasResult?> showEditAliasDialog(
    BuildContext context,
    List<Map<String, dynamic>> pubKeysAlias,
    Box<dynamic> box,
    String compositeKey,
    String descriptorName,
  ) async {
    // Create a map of alias controllers

    Map<String, TextEditingController> aliasControllers = {
      for (var entry in pubKeysAlias)
        entry['publicKey']!: TextEditingController(text: entry['alias']),
    };

    bool hasDuplicateAliases() {
      final aliasValues = aliasControllers.values
          .map((controller) => controller.text.trim())
          .where((alias) => alias.isNotEmpty)
          .toList();

      final uniqueAliases = aliasValues.toSet();

      return uniqueAliases.length != aliasValues.length;
    }

    TextEditingController descriptorNameController =
        TextEditingController(text: descriptorName);

    String updatedDescriptorName = '';

    // print('CompositeKey: $compositeKey');

    final localizationContext = Navigator.of(context).context;

    return (await CustomBottomSheet.buildCustomStatefulBottomSheet<
        EditAliasResult>(
      context: context,
      titleKey: 'edit_sw_info',
      contentBuilder: (setDialogState, updateAssistantMessage) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.gradient(context),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppColors.primary(context)),
              ),
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(localizationContext)!
                        .translate('descriptor_name'),
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                  ),
                  TextField(
                    controller: descriptorNameController,
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                    decoration: InputDecoration(
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: AppColors.container(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      errorText: _isDuplicate
                          ? AppLocalizations.of(context)!
                              .translate('descriptor_name_exists')
                          : null,
                    ),
                    onChanged: (value) {
                      final descName = value.trim();

                      // print(descName);
                      // print(descriptorName);

                      setDialogState(() {
                        _isDuplicate = _isDuplicateDescriptorName(
                            descriptorName, descName);

                        // print(_isDuplicate);

                        if (!_isDuplicate) {
                          updatedDescriptorName = descName;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: pubKeysAlias.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: AppColors.gradient(context),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: AppColors.primary(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${AppLocalizations.of(localizationContext)!.translate('pub_key')}: ${entry['publicKey']}",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.text(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 10),
                      TextField(
                        controller: aliasControllers[entry['publicKey']],
                        style: TextStyle(
                          color: AppColors.text(context),
                        ),
                        decoration: InputDecoration(
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: AppColors.container(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
      actionsBuilder: (setDialogState) {
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkwellButton(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop(null);
                },
                label: AppLocalizations.of(localizationContext)!
                    .translate('cancel'),
                backgroundColor: AppColors.gradient(context),
                textColor: AppColors.text(context),
                icon: Icons.cancel_rounded,
                iconColor: AppColors.error(context),
              ),
              InkwellButton(
                onTap: _isDuplicate
                    ? null
                    : () async {
                        if (hasDuplicateAliases()) {
                          _log(
                              '❌ Duplicate aliases detected. Aborting update.');
                          DialogHelper.showErrorDialog(
                            context: context,
                            messageKey: 'duplicate_aliases_error',
                          );
                          return;
                        }

                        _log(
                            '✅ No duplicate aliases. Proceeding to update pubKeysAlias from controllers.');

// Update all aliases in pubKeysAlias
                        for (var entry in pubKeysAlias) {
                          final pk = entry['publicKey'];
                          final controller = aliasControllers[pk];
                          final newAlias = controller?.text ?? '';
                          _log(
                              '↪ Updating alias for pubKey=${pk?.toString().substring(0, 12)}... to "$newAlias"');
                          entry['alias'] = newAlias;
                        }

// Extract descriptor name from composite key
                        _log('🔧 Parsing compositeKey: "$compositeKey"');
                        List<String> keyParts =
                            compositeKey.split('_descriptor_');
                        if (keyParts.length != 2) {
                          _log(
                              '❌ Invalid composite key format. Expected "<prefix>_descriptor_<name>". Got: "$compositeKey"');
                          return;
                        }

                        if (updatedDescriptorName.isEmpty) {
                          setState(() {
                            updatedDescriptorName = descriptorName;
                          });
                          _log(
                              'ℹ️ updatedDescriptorName was empty. Falling back to existing descriptorName="$descriptorName"');
                        }

// Create the new composite key
                        String newCompositeKey =
                            "${keyParts[0]}_descriptor_$updatedDescriptorName";
                        _log(
                            '🧩 Computed newCompositeKey="$newCompositeKey" from old compositeKey="$compositeKey"');

// Store the old composite key BEFORE modifying it
                        String oldCompositeKey = compositeKey;
                        _log('📌 oldCompositeKey="$oldCompositeKey"');

// Retrieve existing data from the old key
                        var rawValue = box.get(oldCompositeKey);
                        if (rawValue != null) {
                          _log(
                              '📦 Retrieved raw value for oldCompositeKey (length=${rawValue.toString().length}). Attempting JSON decode...');
                          try {
                            // Parse JSON
                            final parsedValue =
                                jsonDecode(rawValue) as Map<String, dynamic>;
                            _log(
                                '✅ JSON decode successful. Keys: ${parsedValue.keys.toList()}');

                            // Update pubKeysAlias
                            parsedValue['pubKeysAlias'] = pubKeysAlias;
                            _log(
                                '📝 Updated "pubKeysAlias" with ${pubKeysAlias.length} entries.');

                            _log(
                                '🔐 Writing updated value under newCompositeKey="$newCompositeKey"...');
                            box.put(newCompositeKey, jsonEncode(parsedValue));

                            // Confirm it's saved
                            var savedData = box.get(newCompositeKey);
                            if (savedData != null) {
                              _log(
                                  '✅ Successfully saved to new key: $newCompositeKey (length=${savedData.toString().length})');
                            } else {
                              _log(
                                  '❌ Save verification failed: data not found under new key.');
                            }

                            // Check if old key exists before deleting
                            if (box.containsKey(oldCompositeKey)) {
                              _log('🧹 Deleting old key: $oldCompositeKey');
                              box.delete(oldCompositeKey);
                            } else {
                              _log('ℹ️ Old key not found, skipping deletion.');
                            }

                            // Force Hive to commit changes
                            _log(
                                '🗜️ Calling box.compact() and box.flush() to persist changes...');
                            await box.compact();
                            await box.flush();
                            _log('✅ Box compact/flush completed.');

                            // Close the dialog
                            _log(
                                '🚪 Closing dialog with success. updatedDescriptorName="$updatedDescriptorName"');
                            Navigator.of(localizationContext,
                                    rootNavigator: true)
                                .pop(
                              EditAliasResult(
                                success: true,
                                descriptorName: updatedDescriptorName,
                              ),
                            );

                            // _log('updatedDescriptorName: $updatedDescriptorName');
                          } catch (e, st) {
                            _log('💥 Error updating Hive box: $e');
                            _log('🧵 Stacktrace: $st');
                          }
                        } else {
                          _log(
                              '❌ Original composite key not found in Hive: "$oldCompositeKey"');
                        }
                      },
                label:
                    AppLocalizations.of(localizationContext)!.translate('save'),
                backgroundColor: AppColors.gradient(context),
                textColor: AppColors.text(context),
                icon: Icons.save_rounded,
                iconColor: AppColors.icon(context),
              ),
            ],
          ),
        ];
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.title,
            if (settingsProvider
                .isTestnet) // Show the Testnet banner if `isTestnet` is true
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.container(context)
                      .withAlpha((0.8 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error(context),
                    width: 1,
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.translate('network_banner'),
                  style: TextStyle(
                    fontSize: 16, // Bigger font
                    fontWeight: FontWeight.bold,
                    color: AppColors.error(context), // High contrast color
                  ),
                ),
              ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent(context),
                AppColors.gradient(context),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (widget.showAssistantButton)
            IconButton(
              icon: Icon(Icons.help_outline, color: AppColors.icon(context)),
              onPressed: _toggleAssistant,
            ),
          // IconButton(
          //   icon: Icon(
          //     Icons.travel_explore,
          //     color: AppColors.icon(context),
          //   ),
          //   onPressed: () async {
          //     final Uri url = Uri.parse("https://btcmap.org/map");

          //     if (await canLaunchUrl(url)) {
          //       await launchUrl(url, mode: LaunchMode.externalApplication);
          //     } else {
          //       throw "Could not launch $url";
          //     }
          //   },
          // ),
          IconButton(
            icon: Icon(
              settingsProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: AppColors.icon(context),
            ),
            onPressed: () {
              Provider.of<SettingsProvider>(context, listen: false)
                  .toggleTheme();
              setState(() {});
            },
          ),
        ],
      ),
      drawer: widget.showDrawer
          ? Drawer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent(context),
                      AppColors.gradient(context),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDrawerHeader(context),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildPersonalWalletTile(context),
                          const SizedBox(height: 10),
                          _buildSharedWalletTiles(context),
                          const SizedBox(height: 10),
                          _buildCreateSharedWalletTile(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          widget.onRefresh != null
              ? RefreshIndicator(
                  onRefresh: widget.onRefresh!, // Call onRefresh if provided
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent(context),
                            AppColors.gradient(context)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: widget.body,
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent(context),
                        AppColors.gradient(context)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: widget.body,
                  ),
                ),

          // ✅ Assistant is properly positioned inside Stack
          if (_showAssistant)
            Positioned(
              left: _assistantPosition.dx,
              top: _assistantPosition.dy,
              child: StatefulBuilder(
                // ✅ Allow dynamic updates
                builder: (context, setState) {
                  return AssistantWidget(
                    key:
                        _assistantKey, // Assign GlobalKey to track widget state
                    initialMessage: _assistantMessage,
                    context: context,
                    onClose: _toggleAssistant,
                    onNextMessage: _nextAssistantMessage,
                    onDragEnd: updateAssistantPosition,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent(context),
            AppColors.gradient(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            child: Icon(Icons.settings),
            onTap: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
          const SizedBox(height: 10),
          Flexible(
            flex: 1,
            child: Text(
              AppLocalizations.of(context)!.translate('welcome'),
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Text(
              AppLocalizations.of(context)!.translate('welcoming_description'),
              style: TextStyle(
                color: AppColors.text(context).withAlpha((0.8 * 255).toInt()),
                fontSize: 14,
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Text(
              '${AppLocalizations.of(context)!.translate('version')}: $_version',
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalWalletTile(BuildContext context) {
    return Card(
      elevation: 6,
      color: AppColors.gradient(context),
      shadowColor: AppColors.background(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.wallet,
          color: AppColors.cardTitle(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('personal_wallet'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text(context),
          ),
        ),
        onTap: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/wallet_page', (Route<dynamic> route) => false);
        },
      ),
    );
  }

  Widget _buildSharedWalletTiles(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable:
          _descriptorBox!.listenable(), // Listen for changes in the box
      builder: (context, Box<dynamic> box, _) {
        List<Widget> sharedWalletCards = [];

        for (int i = 0; i < box.length; i++) {
          final compositeKey = box.keyAt(i) ?? 'Unknown Composite Key';
          final rawValue = box.getAt(i);

          // Split the composite key into mnemonic and descriptor name
          final keyParts = compositeKey.split('_descriptor');
          final mnemonic =
              keyParts.isNotEmpty ? keyParts[0] : 'Unknown Mnemonic';
          String descriptorName = keyParts.length > 1
              ? keyParts[1].replaceFirst('_', '')
              : 'Unnamed Descriptor';

          // print('descriptorName: $compositeKey');

          // Parse the raw value (JSON) into a Map
          Map<String, dynamic>? parsedValue;
          if (rawValue != null) {
            try {
              parsedValue = jsonDecode(rawValue);
            } catch (e) {
              // print('Error parsing descriptor JSON: $e');
              throw ('Error parsing descriptor JSON: $e');
            }
          }

          final descriptor =
              parsedValue?['descriptor'] ?? 'No descriptor available';
          final pubKeysAlias = (parsedValue?['pubKeysAlias'] as List<dynamic>)
              .map((item) => Map<String, String>.from(item))
              .toList();

          final rootContext = context;

          sharedWalletCards.add(
            FutureBuilder<DescriptorPublicKey?>(
              future: walletService.getpubkey(pubKeyFutures, mnemonic),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(); // Show a loader while waiting
                } else if (snapshot.hasError) {
                  return const Text('Error fetching public key');
                }

                final pubKey = snapshot.data;
                if (pubKey == null) {
                  return const Text('Public key not found');
                }

                // Extract the content inside square brackets
                final RegExp regex = RegExp(r'\[([^\]]+)\]');
                final Match? match = regex.firstMatch(pubKey.asString());

                final String targetFingerprint = match!.group(1)!.split('/')[0];

                final matchingAliasEntry = pubKeysAlias.firstWhere(
                  (entry) => entry['publicKey']!.contains(targetFingerprint),
                  orElse: () => {
                    'alias': 'Unknown Alias'
                  }, // Fallback if no match is found
                );

                final displayAlias = matchingAliasEntry['alias'] ?? 'No Alias';

                return Card(
                  elevation: 6,
                  color: AppColors.gradient(context),
                  shadowColor: AppColors.background(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.cardTitle(context),
                    ),
                    title: Text(
                      '${descriptorName}_$displayAlias',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    subtitle: Text(
                      descriptor,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.text(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onLongPress: () async {
                      final EditAliasResult? result = await showEditAliasDialog(
                        context,
                        pubKeysAlias,
                        box,
                        compositeKey,
                        descriptorName,
                      );

                      // Wait until the user dismisses the dialog
                      if (result != null) {
                        setState(() {
                          descriptorName = result.descriptorName;
                        });

                        // print('descriptorNameAfterChanging: $descriptorName');
                        if (result.success) {
                          Navigator.push(
                            rootContext,
                            MaterialPageRoute(
                              builder: (context) => SharedWallet(
                                descriptor: descriptor,
                                mnemonic: mnemonic,
                                pubKeysAlias: pubKeysAlias,
                                descriptorName: descriptorName,
                              ),
                            ),
                          );
                        }
                      }
                      //  else {
                      //   print("Dialog dismissed without changes.");
                      // }
                    },
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SharedWallet(
                            descriptor: descriptor,
                            mnemonic: mnemonic,
                            pubKeysAlias: pubKeysAlias,
                            descriptorName: descriptorName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        }

        return Column(children: sharedWalletCards);
      },
    );
  }

  void _log(String msg) {
    // Using debugPrint avoids truncation of long lines in Flutter logs.
    debugPrint('[EditAliases ${DateTime.now().toIso8601String()}] $msg');
  }

  Widget _buildCreateSharedWalletTile(BuildContext context) {
    return Card(
      elevation: 6,
      color: AppColors.gradient(context),
      shadowColor: AppColors.background(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.add_circle,
          color: AppColors.cardTitle(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('create_shared_wallet'),
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context)),
        ),
        onTap: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/shared_wallet', (Route<dynamic> route) => false);
        },
      ),
    );
  }
}

class EditAliasResult {
  final bool success;
  final String descriptorName;

  EditAliasResult({required this.success, required this.descriptorName});
}
