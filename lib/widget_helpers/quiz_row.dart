import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class QuizRow {
  final int position; // 1-based index in the mnemonic
  final String correct;
  final List<String> options; // length 3, shuffled

  QuizRow({
    required this.position,
    required this.correct,
    required this.options,
  });
}

class MnemonicRow extends StatelessWidget {
  final QuizRow row;
  final int? selected; // 0..2
  final ValueChanged<int> onSelect;
  final BuildContext rootContext;

  const MnemonicRow({
    super.key,
    required this.row,
    required this.selected,
    required this.onSelect,
    required this.rootContext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // e.g., “Select word #7”
        Text(
          '${AppLocalizations.of(rootContext)!.translate('select_word')} #${row.position}',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(row.options.length, (idx) {
            final word = row.options[idx];
            final isSelected = selected == idx;
            return ChoiceChip(
              label: Text(word),
              selected: isSelected,
              onSelected: (_) => onSelect(idx),
              selectedColor: Colors.orangeAccent.opaque(0.25),
              labelStyle: TextStyle(
                color: AppColors.text(context),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? Colors.orangeAccent
                      : AppColors.container(context),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
