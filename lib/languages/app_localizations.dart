import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations_it.dart';
import 'package:flutter_wallet/languages/app_localizations_ru.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    switch (locale.languageCode) {
      case 'es':
        _localizedStrings = localizedStringsEs;
        break;
      case 'it':
        _localizedStrings = localizedStringsIt;
        break;
      case 'fr':
        _localizedStrings = localizedStringsFr;
        break;
      case 'ru':
        _localizedStrings = localizedStringsRu;
        break;
      default:
        _localizedStrings = localizedStringsEn;
    }
    return true; // ✅ Ensures that loading is complete before use
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'fr', 'it', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
