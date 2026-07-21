import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mkg_tax_mobile/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/region_language_registry.dart';
import '../../../core/localization/supported_locales.dart';
import '../../../core/network/laravel_api_client.dart';
import '../../../core/theme/mkg_theme.dart';
import '../data/language_preferences_repository.dart';

class LanguageSetupScreen extends ConsumerStatefulWidget {
  const LanguageSetupScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  ConsumerState<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends ConsumerState<LanguageSetupScreen> {
  late String _preferred;
  late String _secondary;
  late String _regionId;
  late bool _bilingual;
  late bool _keepEnglish;
  late bool _spoken;
  late bool _interpreter;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = ref.read(localeControllerProvider);
    _preferred = current.preferredLanguage;
    _secondary = current.secondaryLanguage;
    _regionId = current.regionId;
    _bilingual = current.bilingualTaxTerms;
    _keepEnglish = current.keepFormLabelsEnglish;
    _spoken = current.spokenResponseEnabled;
    _interpreter = current.humanInterpreterRequested;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final next = LanguagePreferences(
      preferredLanguage: _preferred,
      secondaryLanguage: _secondary,
      regionId: _regionId,
      bilingualTaxTerms: _bilingual,
      keepFormLabelsEnglish: _keepEnglish,
      spokenResponseEnabled: _spoken,
      humanInterpreterRequested: _interpreter,
      setupCompleted: true,
    );
    try {
      await ref.read(localeControllerProvider.notifier).updateLocal(next);
      final api = ref.read(laravelApiClientProvider);
      final repo = LanguagePreferencesRepository(api);
      try {
        await repo.savePreferences(next);
      } catch (_) {
        // Local persistence still succeeds offline; server sync when authed.
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _interpreter ? l10n.interpreterNoted : l10n.languageSaved,
          ),
        ),
      );
      if (widget.fromSettings) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final regionLangs = RegionLanguageRegistry.forRegion(_regionId)
        .where(SupportedLocales.isPhaseOneUi)
        .toList();
    final preferredOptions = regionLangs.isEmpty
        ? SupportedLocales.phaseOneUi
        : regionLangs;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.languageSettings),
        backgroundColor: MkgColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.languageSetupTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MkgColors.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(l10n.languageSetupSubtitle),
          const SizedBox(height: 24),
          Text(l10n.regionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('region-$_regionId'),
            initialValue: _regionId,
            items: RegionLanguageRegistry.regionNames.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text('Region ${e.key} — ${e.value}'),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _regionId = v;
                final langs = RegionLanguageRegistry.forRegion(v)
                    .where(SupportedLocales.isPhaseOneUi)
                    .toList();
                if (langs.isNotEmpty && !langs.contains(_preferred)) {
                  _preferred = langs.first;
                }
              });
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text(l10n.preferredLanguage, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('preferred-$_preferred'),
            initialValue: preferredOptions.contains(_preferred) ? _preferred : preferredOptions.first,
            items: preferredOptions
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(SupportedLocales.displayName(c)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _preferred = v);
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text(l10n.secondaryLanguage, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('secondary-$_secondary'),
            initialValue: SupportedLocales.phaseOneUi.contains(_secondary)
                ? _secondary
                : 'en-US',
            items: SupportedLocales.phaseOneUi
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(SupportedLocales.displayName(c)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _secondary = v);
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          SwitchListTile(
            title: Text(l10n.bilingualTaxTerms),
            value: _bilingual,
            onChanged: (v) => setState(() => _bilingual = v),
          ),
          SwitchListTile(
            title: Text(l10n.keepFormLabelsEnglish),
            value: _keepEnglish,
            onChanged: (v) => setState(() => _keepEnglish = v),
          ),
          SwitchListTile(
            title: Text(l10n.spokenResponses),
            subtitle: Text(l10n.voiceUnavailable),
            value: _spoken,
            onChanged: (v) => setState(() => _spoken = v),
          ),
          SwitchListTile(
            title: Text(l10n.humanInterpreter),
            value: _interpreter,
            onChanged: (v) => setState(() => _interpreter = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: MkgColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_saving ? '…' : l10n.saveLanguagePreferences),
          ),
        ],
      ),
    );
  }
}
