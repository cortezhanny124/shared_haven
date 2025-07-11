import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class SpendingPathDetailsCard extends StatelessWidget {
  final Map<String, dynamic>? path;
  final List<Map<String, String>>? pubKeysAlias;
  final BuildContext rootContext;

  const SpendingPathDetailsCard({
    super.key,
    this.path,
    this.pubKeysAlias,
    required this.rootContext,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null) return const SizedBox();

    final String timelockType = path!['type'].contains('RELATIVETIMELOCK')
        ? 'older'
        : path!['type'].contains('ABSOLUTETIMELOCK')
            ? 'after'
            : 'none';

    final isTimelock = timelockType != 'none';
    final threshold = path!['threshold'];
    final fingerprints = path!['fingerprints'] as List;

    final aliases = fingerprints.map((fp) {
      final match = pubKeysAlias!.firstWhere(
        (alias) => alias['publicKey']!.contains(fp),
        orElse: () => {'alias': fp},
      );
      return match['alias'] ?? fp;
    }).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.background(context),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(rootContext)!.translate('spending_path'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: AppColors.text(context)),
                children: [
                  TextSpan(
                    text:
                        "${AppLocalizations.of(rootContext)!.translate('type')}: ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: isTimelock
                        ? "TIMELOCK (${timelockType.toUpperCase()}): ${path!['timelock']} ${AppLocalizations.of(rootContext)!.translate(timelockType == 'older' ? 'blocks' : 'height')}"
                        : "MULTISIG $threshold of ${aliases.length}",
                  ),
                  const TextSpan(text: "\n"),
                  TextSpan(
                    text:
                        "${AppLocalizations.of(rootContext)!.translate('keys')}: ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: aliases.join(', ')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
