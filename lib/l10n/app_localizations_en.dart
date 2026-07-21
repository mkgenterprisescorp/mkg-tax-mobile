// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MKG Tax Consultants';

  @override
  String get tessaTitle => 'Ask Tessa';

  @override
  String get tessaGreeting =>
      'Hi — I am Tessa AI, your MKG Tax assistant. Ask about federal Form 1040, CA 540 / business forms, or nationwide state intake.';

  @override
  String get languageSetupTitle =>
      'Which language would you like Tessa to use?';

  @override
  String get languageSetupSubtitle =>
      'Tessa never guesses your language from your name, address, or location. You choose.';

  @override
  String get preferredLanguage => 'Spoken / written language';

  @override
  String get secondaryLanguage => 'Secondary language';

  @override
  String get regionLabel => 'MKG service region';

  @override
  String get bilingualTaxTerms => 'Show bilingual tax terms';

  @override
  String get keepFormLabelsEnglish => 'Keep tax form labels in English';

  @override
  String get spokenResponses => 'Spoken responses (when voice is enabled)';

  @override
  String get humanInterpreter => 'Request a human interpreter';

  @override
  String get saveLanguagePreferences => 'Save language preferences';

  @override
  String get languageSaved => 'Language preferences saved';

  @override
  String get interpreterNoted =>
      'Interpreter request recorded for staff follow-up';

  @override
  String get sendMessage => 'Send';

  @override
  String get conversationNotReady => 'Conversation not ready yet.';

  @override
  String get formW2Label => 'Form W-2 — Wage and Tax Statement';

  @override
  String get escalateHuman => 'Speak with an MKG tax professional';

  @override
  String get voiceUnavailable => 'Voice is not enabled yet for this language.';

  @override
  String get correctTranscript => 'Correct transcript';

  @override
  String get languageSettings => 'Language settings';
}
