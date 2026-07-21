// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'MKG Tax Consultants';

  @override
  String get tessaTitle => 'Preguntar a Tessa';

  @override
  String get tessaGreeting =>
      'Hola — soy Tessa AI, su asistente de impuestos de MKG. Pregunte sobre Form 1040 federal, CA 540 / formularios empresariales o intake estatal.';

  @override
  String get languageSetupTitle => '¿En qué idioma desea que Tessa le atienda?';

  @override
  String get languageSetupSubtitle =>
      'Tessa nunca adivina su idioma por su nombre, dirección o ubicación. Usted elige.';

  @override
  String get preferredLanguage => 'Idioma hablado / escrito';

  @override
  String get secondaryLanguage => 'Idioma secundario';

  @override
  String get regionLabel => 'Región de servicio MKG';

  @override
  String get bilingualTaxTerms => 'Mostrar términos tributarios bilingües';

  @override
  String get keepFormLabelsEnglish =>
      'Mantener etiquetas de formularios en inglés';

  @override
  String get spokenResponses =>
      'Respuestas habladas (cuando la voz esté habilitada)';

  @override
  String get humanInterpreter => 'Solicitar un intérprete humano';

  @override
  String get saveLanguagePreferences => 'Guardar preferencias de idioma';

  @override
  String get languageSaved => 'Preferencias de idioma guardadas';

  @override
  String get interpreterNoted =>
      'Solicitud de intérprete registrada para seguimiento del personal';

  @override
  String get sendMessage => 'Enviar';

  @override
  String get conversationNotReady => 'La conversación aún no está lista.';

  @override
  String get formW2Label => 'Form W-2 — Declaración de salarios e impuestos';

  @override
  String get escalateHuman => 'Hablar con un profesional de impuestos de MKG';

  @override
  String get voiceUnavailable =>
      'La voz aún no está habilitada para este idioma.';

  @override
  String get correctTranscript => 'Corregir transcripción';

  @override
  String get languageSettings => 'Configuración de idioma';
}
