import 'dart:async';
import 'dart:math';

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/wallet_pages/import_wallet_page.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/widget_helpers/custom_bottom_sheet.dart';
import 'package:flutter_wallet/widget_helpers/quiz_row.dart';
import 'package:hive/hive.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:provider/provider.dart';

class CreateWalletPage extends StatefulWidget {
  const CreateWalletPage({super.key});

  @override
  CreateWalletPageState createState() => CreateWalletPageState();
}

class CreateWalletPageState extends State<CreateWalletPage> {
  String? _mnemonic;
  String _status = 'Idle';

  Wallet? _wallet;

  final TextEditingController _mnemonicController = TextEditingController();

  late final WalletService _walletService;

  bool _isMnemonicEntered = false;

  final FocusNode _mnemonicFocusNode = FocusNode();
  Timer? _debounceTimer;

  static Network _network(BuildContext context) =>
      Provider.of<SettingsProvider>(context, listen: false).network;

  // === Mnemonic grid state (12 words) ===
  static const int _wordCount = 12;
  late final List<TextEditingController> _wordCtrls;
  late final List<FocusNode> _wordFocus;

  // Prevent feedback loop when syncing master <-> boxes
  bool _squelchMasterListener = false;

  // UI enables
  bool _canClear = false; // enables the Clear button

  @override
  void initState() {
    super.initState();

    _walletService =
        WalletService(Provider.of<SettingsProvider>(context, listen: false));

    // --- NEW: build 12 controllers/focus nodes ---
    _wordCtrls = List.generate(_wordCount, (_) => TextEditingController());
    _wordFocus = List.generate(_wordCount, (_) => FocusNode());

    // Mirror existing master mnemonic (if any) into boxes
    _syncFromMaster(_mnemonicController.text);

    // If the master text changes from *outside*, mirror into boxes
    _mnemonicController.addListener(() {
      if (_squelchMasterListener) return;
      _mnemonic = _mnemonicController.text;
      _syncFromMaster(_mnemonic!);
      _validateMnemonic(_mnemonic!); // your debounced validator
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final c in _wordCtrls) {
      c.dispose();
    }
    for (final f in _wordFocus) {
      f.dispose();
    }
    _mnemonicController.dispose();
    _mnemonicFocusNode.dispose();
    super.dispose();
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  // Join words from boxes -> master controller (no rebuilds unless needed)
  void _joinWordsToMaster() {
    final joined = _wordCtrls
        .map((c) => c.text.trim())
        .where((w) => w.isNotEmpty)
        .join(' ');

    // Update "Clear" button enablement cheaply
    final nextCanClear = joined.isNotEmpty;
    if (_canClear != nextCanClear) {
      if (mounted) setState(() => _canClear = nextCanClear);
    }

    if (_mnemonicController.text == joined) return;

    _squelchMasterListener = true;
    try {
      _mnemonicController.text = joined;
      _mnemonicController.selection =
          TextSelection.collapsed(offset: joined.length);
    } finally {
      scheduleMicrotask(() => _squelchMasterListener = false);
    }

    // Let your debounced validator decide when _isMnemonicEntered flips
    _validateMnemonic(joined);
  }

  // Master controller -> boxes (used at init and when master changes externally)
  void _syncFromMaster(String full) {
    final words =
        full.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    for (int i = 0; i < _wordCount; i++) {
      final newVal = (i < words.length) ? words[i] : '';
      if (_wordCtrls[i].text != newVal) {
        _wordCtrls[i].text = newVal;
      }
    }
    // Update clear enablement & trigger validation
    _joinWordsToMaster();
  }

  // Clear all boxes
  void _clearWords() {
    for (final c in _wordCtrls) {
      c.clear();
    }
    _joinWordsToMaster(); // will disable clear and create after debounce
    // Go back to recover mode visually if you want:
  }

  // Copy Mnemonic
  void _copyWords() {
    String mnemonic = '';

    for (final c in _wordCtrls) {
      mnemonic += '${c.text} ';
    }

    // print(mnemonic);

    UtilitiesService.copyToClipboard(
      context: context,
      text: mnemonic,
      messageKey: 'mnemonic_clipboard',
    );
  }

  // Handle user typing in a single cell
  void _onWordChanged(int index, String value) {
    // If user pasted into a single cell (contains spaces), distribute forward
    if (value.contains(' ')) {
      final parts = value
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      for (int k = 0; k < parts.length && (index + k) < _wordCount; k++) {
        final target = index + k;
        if (_wordCtrls[target].text != parts[k]) {
          _wordCtrls[target].text = parts[k];
        }
      }
      // Focus last filled cell
      final last = (index + parts.length - 1).clamp(0, _wordCount - 1);
      FocusScope.of(context).requestFocus(_wordFocus[last]);
    }
    _joinWordsToMaster();
  }

  // Move focus on space/submit for quick entry
  void _focusNext(int index) {
    final next = (index + 1).clamp(0, _wordCount - 1);
    if (next != index) FocusScope.of(context).requestFocus(_wordFocus[next]);
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  Future<void> _verifyMnemonic() async {
    final words = _mnemonic!.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.length < 12) {
      return;
    }

    final r = Random();
    // --- pick 3 UNIQUE indices to verify ---
    final indices = <int>{};
    while (indices.length < 3) {
      indices.add(r.nextInt(words.length));
    }
    final quizTargets = indices.toList()..sort(); // optional sort

    // --- build rows with 1 correct + 2 distractors (all unique) ---
    List<QuizRow> rows = [];
    for (final idx in quizTargets) {
      final correct = words[idx];

      // pick 2 distinct distractors not equal to 'correct'
      final used = <int>{idx};
      String pickDistractor() {
        int di;
        do {
          di = r.nextInt(words.length);
        } while (used.contains(di));
        used.add(di);
        return words[di];
      }

      final d1 = pickDistractor();
      final d2 = pickDistractor();

      // shuffle options
      final options = [correct, d1, d2]..shuffle(r);

      rows.add(QuizRow(
        position: idx + 1,
        correct: correct,
        options: options,
      ));
    }

    final rootContext = context;
    final selections = List<int?>.filled(rows.length, null, growable: false);

    CustomBottomSheet.buildCustomStatefulBottomSheet(
      context: context,
      titleKey: 'verify_mnemonic',
      contentBuilder: (setDialogState, updateAssistantMessage) {
        bool allAnswered() => selections.every((e) => e != null);
        bool allCorrect() {
          for (int i = 0; i < rows.length; i++) {
            final sel = selections[i];
            if (sel == null) return false;
            if (rows[i].options[sel] != rows[i].correct) return false;
          }
          return true;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // instruction
            Text(
              AppLocalizations.of(rootContext)!
                  .translate('pick_the_right_word'),
              style: TextStyle(
                color: AppColors.text(context).opaque(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // rows
            for (int i = 0; i < rows.length; i++) ...[
              MnemonicRow(
                row: rows[i],
                selected: selections[i],
                onSelect: (idx) {
                  setDialogState(() {
                    selections[i] = idx;
                  });
                },
                rootContext: rootContext,
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 4),

            // feedback
            if (allAnswered() && !allCorrect()) ...[
              Text(
                AppLocalizations.of(rootContext)!
                    .translate('one_or_more_answers_are_wrong'),
                style: TextStyle(
                  color: Colors.redAccent.opaque(0.9),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
            ],

            // actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // cancel
                    },
                    child: Text(
                      AppLocalizations.of(rootContext)!.translate('cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: allAnswered() && allCorrect()
                        ? () {
                            Navigator.of(rootContext, rootNavigator: true)
                                .pop();
                            // proceed
                            _createWallet();
                          }
                        : null,
                    child: Text(
                      AppLocalizations.of(rootContext)!.translate('confirm'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _createWallet() async {
    setState(() {
      _status = 'Creating wallet...';
    });

    final connectivityResult = await Connectivity().checkConnectivity();
    Wallet wallet;

    if (!connectivityResult.contains(ConnectivityResult.none)) {
      wallet = await _walletService.loadSavedWallet(mnemonic: _mnemonic!);

      setState(() {
        _wallet = wallet;
        _status = 'Wallet loaded successfully!';
      });
    } else {
      wallet = await _walletService.createOrRestoreWallet(_mnemonic!);
      setState(() {
        _wallet = wallet;
        _status = 'Wallet created successfully';
      });
    }

    var walletBox = Hive.box('walletBox');
    walletBox.put('walletMnemonic', _mnemonic);
    walletBox.put('walletNetwork', _network.toString());

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/wallet_page',
      arguments: _wallet,
    );
  }

  Future<void> _generateMnemonic() async {
    final res = await Mnemonic.create(WordCount.words12);

    setState(() {
      _mnemonicController.text = res.asString();
      _mnemonic = res.asString();
      _status = 'New mnemonic generated!';
    });
  }

  String _getAnimationPath() {
    if (_status.contains('successfully')) {
      return 'assets/animations/success.json';
    } else if (_status.contains('Creating')) {
      return 'assets/animations/creating_wallet.json';
    } else {
      return 'assets/animations/idle.json';
    }
  }

  void _validateMnemonic(String value) {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Start a new one
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final isValid =
          value.trim().isNotEmpty && await _walletService.checkMnemonic(value);

      // print('Value: $value');

      if (_isMnemonicEntered != isValid) {
        if (mounted) {
          setState(() {
            _isMnemonicEntered = isValid;
            _mnemonic = value;
          });
        }
      }
    });
  }

  Widget _buildStatusIndicator() {
    String statusText;

    if (_status.startsWith('Idle')) {
      statusText = AppLocalizations.of(context)!.translate('idle_ready_import');
    } else if (_status == 'New mnemonic generated!') {
      statusText = AppLocalizations.of(context)!.translate('new_mnemonic');
    } else if (_status == 'Creating wallet...') {
      statusText = AppLocalizations.of(context)!.translate('creating_wallet');
    } else if (_status == 'Wallet loaded successfully!') {
      statusText = AppLocalizations.of(context)!.translate('wallet_loaded');
    } else if (_status == 'Wallet created successfully') {
      statusText = AppLocalizations.of(context)!.translate('wallet_created');
    } else if (_status.contains('Success')) {
      statusText = AppLocalizations.of(context)!.translate('navigating_wallet');
    } else {
      statusText = AppLocalizations.of(context)!.translate('loading');
    }

    return Column(
      children: [
        // Lottie Animation
        Lottie.asset(
          _getAnimationPath(),
          height: 80,
          width: 80,
          repeat:
              !_status.contains('successfully'), // Loop only for non-success
        ),
        // Status Text
        Text(
          statusText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<BaseScaffoldState> baseScaffoldKey =
        GlobalKey<BaseScaffoldState>();

    return BaseScaffold(
      title:
          Text(AppLocalizations.of(context)!.translate('create_single_wallet')),
      key: baseScaffoldKey,
      showDrawer: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cool Status Indicator with Animation
                  _buildStatusIndicator(),

                  const SizedBox(height: 20),

                  _buildMnemonicGrid(),

                  const SizedBox(height: 10),

                  // Create Wallet Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: GestureDetector(
                            onLongPress: () {
                              final baseScaffoldState =
                                  baseScaffoldKey.currentState;
                              baseScaffoldState?.updateAssistantMessage(
                                  context, 'assistant_create_wallet');
                            },
                            child: CustomButton(
                              onPressed:
                                  _isMnemonicEntered ? _verifyMnemonic : null,
                              backgroundColor: AppColors.background(context),
                              foregroundColor: AppColors.text(context),
                              icon: Icons.wallet,
                              iconColor: AppColors.gradient(context),
                              verticalLayout: true,
                              label: AppLocalizations.of(context)!
                                  .translate('create_wallet'),
                              padding: 16.0,
                              iconSize: 28.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: GestureDetector(
                            onLongPress: () {
                              final baseScaffoldState =
                                  baseScaffoldKey.currentState;
                              baseScaffoldState?.updateAssistantMessage(
                                  context, 'assistant_generate_mnemonic');
                            },
                            child: CustomButton(
                              onPressed: _generateMnemonic,
                              backgroundColor: AppColors.background(context),
                              foregroundColor: AppColors.gradient(context),
                              icon: Icons.create,
                              iconColor: AppColors.text(context),
                              verticalLayout: true,
                              label: AppLocalizations.of(context)!
                                  .translate('generate_mnemonic'),
                              padding: 16.0,
                              iconSize: 28.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: GestureDetector(
                            onLongPress: () {
                              final baseScaffoldState =
                                  baseScaffoldKey.currentState;
                              baseScaffoldState?.updateAssistantMessage(
                                  context, 'assistant_goto_import_wallet');
                            },
                            child: CustomButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ImportWalletPage(),
                                  ),
                                );
                              },
                              backgroundColor: AppColors.background(context),
                              foregroundColor: AppColors.text(context),
                              verticalLayout: true,
                              label: AppLocalizations.of(context)!
                                  .translate('goto_import_wallet'),
                              padding: 16.0,
                              iconSize: 28.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMnemonicGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_wordCount, (i) {
            return SizedBox(
              width: 120, // tweak or make responsive later
              height: 50,
              child: TextField(
                controller: _wordCtrls[i],
                focusNode: _wordFocus[i],
                readOnly: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: (i == _wordCount - 1)
                    ? TextInputAction.done
                    : TextInputAction.next,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: '${i + 1}', // shows index label
                  borderColor: AppColors.primary(context),
                ),
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 14,
                ),
                onChanged: (v) => _onWordChanged(i, v),
                onSubmitted: (_) => _focusNext(i),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z'\-]|\s")),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: Listenable.merge(_wordCtrls),
          builder: (context, _) {
            final filled =
                _wordCtrls.where((c) => c.text.trim().isNotEmpty).length;
            final allFilled = filled == _wordCount;

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkwellButton(
                      onTap: filled > 0 ? _clearWords : null,
                      icon: Icons.clear,
                      label: AppLocalizations.of(context)!.translate('clear'),
                      backgroundColor: AppColors.background(context),
                      textColor: AppColors.text(context),
                      iconColor: AppColors.gradient(context),
                    ),
                    const SizedBox(width: 8),
                    InkwellButton(
                      onTap: filled > 0 ? _copyWords : null,
                      icon: Icons.copy,
                      label: AppLocalizations.of(context)!.translate('copy'),
                      backgroundColor: AppColors.background(context),
                      textColor: AppColors.text(context),
                      iconColor: AppColors.gradient(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: allFilled
                        ? AppColors.primary(context).opaque(0.15)
                        : AppColors.background(context).opaque(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: allFilled
                          ? AppColors.primary(context)
                          : AppColors.text(context).opaque(0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        allFilled ? Icons.check_circle : Icons.edit_note,
                        size: 18,
                        color: allFilled
                            ? AppColors.primary(context)
                            : AppColors.text(context).opaque(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$filled / $_wordCount words',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: allFilled
                              ? AppColors.primary(context)
                              : AppColors.text(context),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
