import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../address/presentation/address_autofill_fields.dart';
import '../data/laravel_organizer_repository.dart';
import '../data/organizer_autofill_settings.dart';
import '../data/organizer_business_autofill.dart';
import '../data/organizer_defaults.dart';
import '../data/organizer_enum_options.dart';
import '../data/organizer_profile_prefill.dart';
import '../data/organizer_repository.dart';
import '../data/organizer_section_mapper.dart';
import 'organizer_credits_step.dart';
import 'organizer_fields.dart';
import 'organizer_form_1040x_step.dart';
import 'organizer_income_forms_step.dart';
import 'organizer_state_returns_step.dart';

enum _AutoSaveStatus { idle, pending, saving, saved, error }

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Tax Organizer — personal + business parity with mkgtaxconsultants.com `/organizer`.
/// Saves into canonical `tax_returns.data` keys (not `mobileOrganizer`).
class OrganizerScreen extends ConsumerStatefulWidget {
  const OrganizerScreen({super.key});

  @override
  ConsumerState<OrganizerScreen> createState() => _OrganizerScreenState();
}

class _OrganizerScreenState extends ConsumerState<OrganizerScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  dynamic _returnId;
  int _year = DateTime.now().year - 1;
  String _status = 'draft';
  int _step = 0;
  /// Hub = icon grid of sections; detail = walk through one section.
  bool _showHub = true;
  Map<String, dynamic> _data = {};

  /// Fast debounce — dirty-section PUT keeps payloads small.
  static const _autoSaveDebounce = Duration(milliseconds: 700);
  Timer? _autoSaveTimer;
  Timer? _autoSaveIdleTimer;
  bool _autoSaveReady = false;
  bool _autoSaving = false;
  _AutoSaveStatus _autoSaveStatus = _AutoSaveStatus.idle;
  String? _autoSaveError;
  final Set<String> _dirtySectionKeys = {};

  List<String> get _steps {
    final prep = '${_data['prepType'] ?? 'personal'}';
    final steps = stepsForPrepType(prep);
    if (!businessEntityTypes.contains(prep) && !showScheduleCStep(_data)) {
      return steps.where((s) => s != 'Schedule C').toList();
    }
    return steps;
  }

  int get _completedCount => _steps.where((s) => isOrganizerStepComplete(s, _data)).length;

  bool get _isLocked =>
      _status == 'processing' ||
      _status == 'completed' ||
      _status == 'filed' ||
      _status == 'accepted';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _autoSaveIdleTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _autoSaveTimer?.cancel();
    _autoSaveIdleTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _autoSaveReady = false;
      _autoSaving = false;
      _autoSaveStatus = _AutoSaveStatus.idle;
      _autoSaveError = null;
      _dirtySectionKeys.clear();
    });
    try {
      final tax = ref.read(taxYearProvider);
      final preferred = tax.selectedYear ?? tax.currentFilingYear;

      if (AppConfig.usesLaravelAuth) {
        final yearHint = preferred ?? tax.currentFilingYear ?? DateTime.now().year - 1;
        // Ensure catalog + selected year exist (deep-link / cold open).
        if (tax.selectedYear == null || tax.currentFilingYear == null) {
          await ref.read(taxYearProvider.notifier).bootstrap();
        }
        final warm = ref.read(taxYearProvider).workspace;
        final needsRefresh = warm?.workspaceId == null ||
            warm?.taxYear != yearHint ||
            ref.read(taxYearProvider).source != 'laravel';
        if (needsRefresh) {
          await ref.read(taxYearProvider.notifier).refreshWorkspace(force: true);
        }
        final taxAfter = ref.read(taxYearProvider);
        final workspaceId = taxAfter.workspace?.workspaceId;
        if (workspaceId == null || workspaceId.isEmpty) {
          throw StateError(
            taxAfter.error ?? 'No tax-year workspace. Select a year and try again.',
          );
        }
        final year = taxAfter.workspace?.taxYear ?? yearHint;
        // Activate already embeds organizer (~20KB, same as GET .../organizer).
        // Reuse it to avoid a second 3–5s round-trip on cold open.
        final snap = taxAfter.organizerSnapshot;
        final snapMatchesWorkspace = snap != null &&
            '${snap['tax_year_workspace_id'] ?? ''}' == workspaceId;
        final defaultsFuture = OrganizerDefaults.load();
        final Map<String, dynamic>? cachedOrg =
            snapMatchesWorkspace ? Map<String, dynamic>.from(snap) : null;
        final orgFuture = cachedOrg != null
            ? Future<Map<String, dynamic>?>.value(cachedOrg)
            : ref.read(laravelOrganizerRepositoryProvider).show(
                  workspaceId,
                  prepType: 'personal',
                );
        final defaults = await defaultsFuture;
        Map<String, dynamic>? org;
        try {
          org = await orgFuture;
        } catch (_) {
          // Workspace is valid — open a defaults draft rather than a dead-end.
          org = null;
        }
        if (!mounted) return;
        Map<String, dynamic> hydrated;
        try {
          hydrated = OrganizerSectionMapper.hydrateFromServer(
            defaults: defaults,
            organizer: org,
            fallbackYear: year,
          );
        } catch (_) {
          hydrated = Map<String, dynamic>.from(defaults)
            ..['filingYear'] = year
            ..['prepType'] = defaults['prepType'] ?? 'personal';
        }
        // Re-fetch with the hydrated prep type so entity catalogs match.
        final prep = '${hydrated['prepType'] ?? 'personal'}';
        Map<String, dynamic>? orgTyped = org;
        if (prep != '${org?['prep_type'] ?? 'personal'}') {
          try {
            orgTyped = await ref
                .read(laravelOrganizerRepositoryProvider)
                .show(workspaceId, prepType: prep);
          } catch (_) {
            orgTyped = org;
          }
        }
        Map<String, dynamic> data;
        try {
          data = OrganizerSectionMapper.hydrateFromServer(
            defaults: defaults,
            organizer: orgTyped ?? org,
            fallbackYear: year,
          );
        } catch (_) {
          data = hydrated;
        }
        final filled = await _maybeAutofillProfile(data);
        if (!mounted) return;
        final filingYear = _asInt(filled['filingYear']) ?? year;
        setState(() {
          _returnId = (orgTyped ?? org)?['id'] ?? workspaceId;
          _year = filingYear;
          _status = ((orgTyped ?? org)?['status'] ?? 'draft').toString();
          _data = filled;
          _loading = false;
          _step = 0;
          _showHub = true;
          _autoSaveReady = true;
        });
        return;
      }

      final qid = GoRouterState.of(context).uri.queryParameters['returnId'];
      final explicitId = qid == null || qid.isEmpty ? null : (int.tryParse(qid) ?? qid);
      final result = await ref.read(organizerRepositoryProvider).loadCurrent(
            preferredYear: preferred,
            returnId: explicitId,
          );
      if (!mounted) return;
      final merged = Map<String, dynamic>.from(result.data)..['filingStatus'] = result.filingStatus;
      final filled = await _maybeAutofillProfile(merged);
      if (!mounted) return;
      setState(() {
        _returnId = result.returnId;
        _year = result.year;
        _status = result.status;
        _data = filled;
        _loading = false;
        _step = 0;
        _showHub = true;
        _autoSaveReady = true;
      });
      // Keep tax-year selector aligned with the opened return.
      if (tax.selectedYear != result.year) {
        await ref.read(taxYearProvider.notifier).selectYear(result.year);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiErrorMapper.map(e);
        _autoSaveReady = false;
      });
    }
  }

  Future<Map<String, dynamic>> _maybeAutofillProfile(
    Map<String, dynamic> data, {
    bool overwrite = false,
  }) async {
    final enabled = ref.read(organizerAutofillEnabledProvider);
    if (!enabled) return data;
    try {
      final prefill = await ref.read(organizerProfilePrefillRepositoryProvider).load();
      return ref.read(organizerProfilePrefillRepositoryProvider).applyTo(
            data,
            prefill,
            overwrite: overwrite,
          );
    } catch (_) {
      return data;
    }
  }

  Future<void> _onAutofillToggled(bool enabled) async {
    await ref.read(organizerAutofillEnabledProvider.notifier).setEnabled(enabled);
    if (!enabled || !mounted) return;
    final filled = await _maybeAutofillProfile(_data, overwrite: false);
    if (!mounted) return;
    setState(() => _data = filled);
    _dirtySectionKeys.add('personal_info');
    _dirtySectionKeys.add('filing_info');
    _scheduleAutoSave();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Auto-filled empty fields from your account profile.')),
    );
  }

  void _markCurrentSectionDirty() {
    if (_steps.isEmpty || _step < 0 || _step >= _steps.length) return;
    _dirtySectionKeys.add(OrganizerSectionMapper.stepToSectionKey(_steps[_step]));
    // Multistate edits live alongside CA when on State Tax Returns.
    if (_steps[_step] == 'State Tax Returns' || _steps[_step] == 'CA 540 State Tax') {
      _dirtySectionKeys.add('state_multistate');
      _dirtySectionKeys.add('state_business');
      _dirtySectionKeys.add('state_ca_540');
    }
  }

  void _setRoot(String key, dynamic value) {
    setState(() => _data = Map<String, dynamic>.from(_data)..[key] = value);
    _markCurrentSectionDirty();
    _scheduleAutoSave();
  }

  /// Apply a preparation / business-filing type and persist it.
  ///
  /// Ensures Schedule C / entity form scaffolds exist, marks filing_info dirty,
  /// autosaves, and returns to the hub so the walkthrough tiles refresh.
  /// Entity types also autofill the primary owner from Personal Info and sync
  /// K-1 → Schedule E Part II when applicable.
  Future<void> _applyPrepType(String prep) async {
    Map<String, dynamic> defaults = const {};
    try {
      defaults = await OrganizerDefaults.load();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      var next = Map<String, dynamic>.from(_data)..['prepType'] = prep;
      if (prep != 'personal') {
        next['includeScheduleC'] = false;
      }
      if (prep == 'business') {
        final scDefault = defaults['scheduleC'];
        final existing = next['scheduleC'];
        if (scDefault is Map && (existing is! Map || existing.isEmpty)) {
          next['scheduleC'] = Map<String, dynamic>.from(scDefault);
        } else if (existing is! Map) {
          next['scheduleC'] = <String, dynamic>{};
        }
      }
      if (businessOwnerPrepTypes.contains(prep)) {
        next = addBusinessWithOwnerAutofill(
          next,
          prep,
          entityDefaults: defaults,
          switchPrepType: true,
          overwritePrimaryOwner: false,
        );
      } else if (businessEntityTypes.contains(prep)) {
        final formDefault = defaults[prep];
        final existing = next[prep];
        if (formDefault is Map) {
          if (existing is! Map || existing.isEmpty) {
            next[prep] = Map<String, dynamic>.from(formDefault);
          } else {
            next[prep] = deepMergeOrganizer(
              Map<String, dynamic>.from(formDefault),
              Map<String, dynamic>.from(existing),
            );
          }
        } else if (existing is! Map) {
          next[prep] = <String, dynamic>{};
        }
      }
      _data = next;
      _step = 0;
      _showHub = true;
    });
    _dirtySectionKeys.add('filing_info');
    if (prep == 'business' || showScheduleCStep(_data)) {
      _dirtySectionKeys.add('schedule_c');
    }
    if (businessEntityTypes.contains(prep)) {
      _dirtySectionKeys.add('entity_form');
    }
    if (k1PassThroughPrepTypes.contains(prep)) {
      _dirtySectionKeys.add('schedule_e');
    }
    _scheduleAutoSave();
    if (!mounted) return;
    final label = prepTypeOptions
        .where((e) => e.$1 == prep)
        .map((e) => e.$2)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => prep);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Filing type set to $label. Open the new section tiles below.')),
    );
  }

  /// "+" Add business: autofill owner onto entity form + K-1 → Schedule E Part II.
  ///
  /// Keeps Form 1040 prep type by default so Schedule E stays on the walkthrough.
  Future<void> _addBusinessInterest(String prep, {bool switchPrepType = false}) async {
    Map<String, dynamic> defaults = const {};
    try {
      defaults = await OrganizerDefaults.load();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _data = addBusinessWithOwnerAutofill(
        _data,
        prep,
        entityDefaults: defaults,
        switchPrepType: switchPrepType,
        overwritePrimaryOwner: true,
      );
      if (switchPrepType) {
        _step = 0;
      }
      _showHub = true;
    });
    _dirtySectionKeys.add('filing_info');
    if (businessEntityTypes.contains(prep) || businessOwnerPrepTypes.contains(prep)) {
      _dirtySectionKeys.add('entity_form');
    }
    if (k1PassThroughPrepTypes.contains(prep)) {
      _dirtySectionKeys.add('schedule_e');
    }
    _scheduleAutoSave();
    if (!mounted) return;
    final label = prepTypeOptions
        .where((e) => e.$1 == prep)
        .map((e) => e.$2)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => prep);
    final k1Note = k1PassThroughPrepTypes.contains(prep)
        ? ' Owner autofilled; K-1 linked to Schedule E Part II.'
        : ' Owner autofilled from Personal Info.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label added.$k1Note')),
    );
  }

  Future<void> _showAddBusinessSheet() async {
    if (_isLocked) return;
    final choice = await showModalBottomSheet<({String prep, bool switchPrep})>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile({
          required IconData icon,
          required String title,
          required String subtitle,
          required String prep,
          required bool switchPrep,
        }) {
          return ListTile(
            leading: Icon(icon, color: MkgColors.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle),
            onTap: () => Navigator.pop(ctx, (prep: prep, switchPrep: switchPrep)),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Add business',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Autofills your Personal Info onto the owner / partner / shareholder '
                  'and links K-1 amounts into Form 1040 Schedule E Part II.',
                  style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.35),
                ),
              ),
              tile(
                icon: Icons.groups_outlined,
                title: 'Partnership / LLC (1065) + K-1',
                subtitle: 'Keep 1040 · owner → K-1 → Schedule E Part II',
                prep: 'form1065',
                switchPrep: false,
              ),
              tile(
                icon: Icons.apartment_outlined,
                title: 'S-Corporation (1120-S) + K-1',
                subtitle: 'Keep 1040 · shareholder → K-1 → Schedule E Part II',
                prep: 'form1120S',
                switchPrep: false,
              ),
              tile(
                icon: Icons.account_balance_outlined,
                title: 'Trust / Estate (1041) + K-1',
                subtitle: 'Keep 1040 · beneficiary → K-1 → Schedule E Part II',
                prep: 'form1041',
                switchPrep: false,
              ),
              tile(
                icon: Icons.business_outlined,
                title: 'C-Corporation (1120)',
                subtitle: 'Autofill officer/owner (no K-1 to Schedule E)',
                prep: 'form1120',
                switchPrep: false,
              ),
              const Divider(),
              tile(
                icon: Icons.swap_horiz_outlined,
                title: 'Switch organizer to entity return',
                subtitle: 'Change prep type to 1120-S / 1065 / 1041 / 1120',
                prep: 'form1120S',
                switchPrep: true,
              ),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    if (choice.switchPrep) {
      // Let user pick which entity to switch to.
      final prep = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final opt in businessTaxFilingChoices.where((e) => e.$1 != 'business'))
                  ListTile(
                    title: Text(opt.$2),
                    subtitle: Text(opt.$3),
                    onTap: () => Navigator.pop(ctx, opt.$1),
                  ),
                for (final opt in otherEntityFilingChoices.where((e) => e.$1 == 'form1041'))
                  ListTile(
                    title: Text(opt.$2),
                    subtitle: Text(opt.$3),
                    onTap: () => Navigator.pop(ctx, opt.$1),
                  ),
              ],
            ),
          );
        },
      );
      if (prep == null || !mounted) return;
      await _addBusinessInterest(prep, switchPrepType: true);
      return;
    }
    await _addBusinessInterest(choice.prep, switchPrepType: false);
  }

  void _setNested(String nestKey, Map<String, dynamic> value) {
    setState(() => _data = Map<String, dynamic>.from(_data)..[nestKey] = value);
    _markCurrentSectionDirty();
    _scheduleAutoSave();
  }

  void _patchData(Map<String, dynamic> patch) {
    setState(() {
      final next = Map<String, dynamic>.from(_data);
      patch.forEach((key, value) => next[key] = value);
      _data = next;
    });
    _markCurrentSectionDirty();
    _scheduleAutoSave();
  }

  Map<String, dynamic> _map(String key) => Map<String, dynamic>.from((_data[key] as Map?) ?? {});

  void _scheduleAutoSave() {
    if (!_autoSaveReady || _isLocked || !mounted) return;
    _autoSaveTimer?.cancel();
    _autoSaveIdleTimer?.cancel();
    // Avoid rebuilds on every keystroke — only flip idle → pending once.
    if (_autoSaveStatus == _AutoSaveStatus.idle) {
      _autoSaveStatus = _AutoSaveStatus.pending;
      _autoSaveError = null;
      if (mounted) setState(() {});
    }
    final step = (_steps.isNotEmpty && _step >= 0 && _step < _steps.length) ? _steps[_step] : '';
    // Heavier sections: longer debounce so Neon PUTs (~5–8s) are not stacked.
    final delay = (step == 'State Tax Returns' ||
            step == 'CA 540 State Tax' ||
            step == 'Income (1040)' ||
            step == 'Credits & Deductions')
        ? const Duration(milliseconds: 1400)
        : _autoSaveDebounce;
    _autoSaveTimer = Timer(delay, _runAutoSave);
  }

  Future<void> _runAutoSave() async {
    if (!_autoSaveReady || !mounted || _isLocked) return;
    if (_saving || _autoSaving) {
      // Manual/continue or autosave in flight — retry shortly after it finishes.
      _autoSaveTimer = Timer(const Duration(milliseconds: 400), _runAutoSave);
      return;
    }
    await _save(silent: true);
  }

  Future<void> _save({bool submit = false, bool silent = false}) async {
    _autoSaveTimer?.cancel();
    if (silent) {
      // Background autosave must not lock Continue / Save buttons.
      setState(() {
        _autoSaving = true;
        _autoSaveStatus = _AutoSaveStatus.saving;
        _autoSaveError = null;
      });
    } else {
      setState(() => _saving = true);
    }
    final dirtySnapshot = Set<String>.from(_dirtySectionKeys);
    try {
      final status = submit ? 'processing' : 'draft';
      final filingStatus = '${_data['filingStatus'] ?? 'single'}';
      if (AppConfig.usesLaravelAuth) {
        final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
        if (workspaceId == null) throw StateError('No tax-year workspace for organizer save.');
        await ref.read(laravelOrganizerRepositoryProvider).saveAllSections(
              workspaceId: workspaceId,
              data: {
                ..._data,
                'filingStatus': filingStatus,
                'source': 'mkg-tax-mobile',
                'clientPlatform': 'flutter',
              },
              submit: submit,
              // Autosave: dirty sections only. Manual/Continue: full snapshot.
              onlySectionKeys: silent && !submit ? dirtySnapshot : null,
            );
      } else {
        await ref.read(organizerRepositoryProvider).save(
              returnId: _returnId,
              year: _year,
              status: status,
              filingStatus: filingStatus,
              data: {
                ..._data,
                'source': 'mkg-tax-mobile',
                'clientPlatform': 'flutter',
              },
            );
      }
      if (!mounted) return;
      // Clear only keys we attempted; keep anything marked while save was in flight.
      _dirtySectionKeys.removeAll(dirtySnapshot);
      // Drop activate-embedded snapshot so the next Organizer open re-fetches.
      // Never let snapshot bookkeeping fail a successful save.
      try {
        ref.read(taxYearProvider.notifier).clearOrganizerSnapshot();
      } catch (_) {}
      setState(() {
        _status = status;
        _saving = false;
        _autoSaving = false;
        if (silent) {
          _autoSaveStatus = _AutoSaveStatus.saved;
          _autoSaveError = null;
        } else {
          _autoSaveStatus = _AutoSaveStatus.idle;
          _dirtySectionKeys.clear();
        }
      });
      if (silent) {
        _autoSaveIdleTimer?.cancel();
        _autoSaveIdleTimer = Timer(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          if (_autoSaveStatus == _AutoSaveStatus.saved) {
            setState(() => _autoSaveStatus = _AutoSaveStatus.idle);
          }
        });
        // If more edits landed during save, flush them ASAP.
        if (_dirtySectionKeys.isNotEmpty) {
          _scheduleAutoSave();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(submit ? 'Submitted for processing.' : 'Draft saved.')),
        );
      }
      if (submit) context.go('/tax-center');
    } catch (e) {
      if (!mounted) return;
      final message = ApiErrorMapper.map(e);
      setState(() {
        _saving = false;
        _autoSaving = false;
        if (silent) {
          _autoSaveStatus = _AutoSaveStatus.error;
          _autoSaveError = message;
        }
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _next() async {
    await _save();
    if (!mounted) return;
    if (_step >= _steps.length - 1) {
      await _save(submit: true);
      return;
    }
    // Return to icon hub so the client can pick the next section.
    setState(() {
      _step += 1;
      _showHub = true;
    });
  }

  void _back() {
    if (!_showHub) {
      setState(() => _showHub = true);
      return;
    }
    context.go('/tax-center');
  }

  void _openStep(int index) {
    setState(() {
      _step = index;
      _showHub = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taxYearProvider, (prev, next) {
      if (prev?.selectedYear != next.selectedYear &&
          next.selectedYear != null &&
          next.selectedYear != _year &&
          !_loading) {
        _load();
      }
    });

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: MkgColors.primary));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final steps = _steps;
    final stepIndex = _step.clamp(0, steps.length - 1);
    final title = steps[stepIndex];
    final locked = _isLocked;

    if (_showHub) {
      return _buildHub(steps: steps, locked: locked);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'All sections',
              onPressed: () => setState(() => _showHub = true),
              icon: const Icon(Icons.grid_view_rounded, color: MkgColors.primary),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: locked || _saving ? null : () => _save(), child: const Text('Save')),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Section ${stepIndex + 1} of ${steps.length} · TY $_year',
                style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
              ),
            ),
            if (!locked) _autoSaveIndicator(),
          ],
        ),
        const SizedBox(height: 12),
        _StepProgress(steps: steps, index: stepIndex),
        const SizedBox(height: 16),
        AbsorbPointer(
          absorbing: locked,
          child: KeyedSubtree(
            key: ValueKey('org-step-$title-$stepIndex'),
            child: _buildStep(title),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _back,
                child: const Text('Sections'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: locked || _saving ? null : _next,
                child: Text(
                  _saving
                      ? 'Saving…'
                      : stepIndex >= steps.length - 1
                          ? 'Submit'
                          : 'Save & Continue',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHub({required List<String> steps, required bool locked}) {
    final done = _completedCount;
    final pct = steps.isEmpty ? 0.0 : done / steps.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Tax Organizer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            if (!locked) _autoSaveIndicator(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a section to walk through and complete · TY $_year',
          style: const TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 14),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$done of ${steps.length} sections complete',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  StatusChip(
                    label: _status,
                    color: locked ? MkgColors.green : MkgColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: MkgColors.surfaceGrey,
                  color: MkgColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Walk through',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: MkgColors.dark),
        ),
        const SizedBox(height: 10),
        if (!locked) ...[
          OutlinedButton.icon(
            onPressed: _showAddBusinessSheet,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add business / K-1 (autofill owner)'),
          ),
          const SizedBox(height: 10),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: steps.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final step = steps[index];
            final complete = isOrganizerStepComplete(step, _data);
            return _SectionTile(
              index: index + 1,
              title: step,
              cue: cueForOrganizerStep(step),
              icon: iconForOrganizerStep(step),
              complete: complete,
              onTap: () => _openStep(index),
            );
          },
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: locked
              ? null
              : () {
                  final nextIncomplete = steps.indexWhere((s) => !isOrganizerStepComplete(s, _data));
                  _openStep(nextIncomplete < 0 ? 0 : nextIncomplete);
                },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(done == 0 ? 'Start walkthrough' : done >= steps.length ? 'Review & submit' : 'Continue walkthrough'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/organizer/form-1040'),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Autofill Form 1040 preview'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/refund-advance/estimate'),
          icon: const Icon(Icons.savings_outlined),
          label: const Text('Refund / tax estimate'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go('/tax-center'),
          child: const Text('Back to Tax Center'),
        ),
      ],
    );
  }

  Widget _buildStep(String title) {
    final prep = '${_data['prepType'] ?? 'personal'}';
    if (title == 'Filing Info') return _filingInfoStep();
    if (title == 'Personal Info') return _personalInfoStep();
    if (title == 'Income (1040)') {
      return OrganizerIncomeFormsStep(
        data: _data,
        onRoot: _setRoot,
        onNested: _setNested,
        onPatch: _patchData,
      );
    }
    if (title == 'Schedule B') return _scheduleBStep();
    if (title == 'Schedule C') return _scheduleCStep();
    if (title == 'Schedule D') return _scheduleDStep();
    if (title == 'Schedule E') return _scheduleEStep();
    if (title == 'Schedule F') return _scheduleFStep();
    if (title == 'Credits & Deductions') {
      return OrganizerCreditsStep(
        data: _data,
        onRoot: _setRoot,
        onNested: _setNested,
        onPatch: _patchData,
      );
    }
    if (title == 'Form 1040-X') {
      return OrganizerForm1040xStep(
        data: _data,
        onNested: _setNested,
      );
    }
    if (title == 'State Tax Returns' || title == 'CA 540 State Tax') {
      return OrganizerStateReturnsStep(
        data: _data,
        onRoot: _setRoot,
        onNested: _setNested,
        onList: _setList,
      );
    }
    if (title == 'Direct Deposit') return _directDepositStep();
    if (title == 'Review & Sign') return _reviewStep();
    if (businessEntityTypes.contains(prep) && title.contains('Form')) {
      return _entityFormStep(prep);
    }
    return const Text('Unknown step');
  }

  Widget _filingYearDropdown() {
    final catalogYears = ref.watch(taxYearProvider).years;
    final currentFiling =
        ref.watch(taxYearProvider).currentFilingYear ?? DateTime.now().year - 1;
    final yearItems = catalogYears.isNotEmpty
        ? <(int, String)>[
            for (final y in catalogYears)
              (
                y.taxYear,
                y.isCurrentFilingYear
                    ? '${y.taxYear} — Current Filing Season'
                    : '${y.taxYear}',
              ),
          ]
        : filingYearOptions(currentYear: currentFiling);
    final selected = _asInt(_data['filingYear']) ?? _year;
    final value = yearItems.any((e) => e.$1 == selected) ? selected : yearItems.first.$1;
    return OrganizerDropdown<int>(
      label: 'Filing year',
      value: value,
      items: yearItems,
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _year = v;
          _data = Map<String, dynamic>.from(_data)..['filingYear'] = v;
        });
        // Keep the shared TY selector / workspace aligned with organizer.
        ref.read(taxYearProvider.notifier).selectYear(v);
      },
    );
  }

  Widget _filingInfoStep() {
    final selected = '${_data['prepType'] ?? 'personal'}';
    final includeScheduleC = _data['includeScheduleC'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrganizerSection(
          title: 'Personal tax filing',
          subtitle: 'Form 1040 individual return (with optional Schedule C).',
          child: Column(
            children: [
              _prepTypeChoiceTile(
                title: 'Personal Tax Prep (1040)',
                hint: 'W-2 wages, interest, dividends, credits',
                selected: selected == 'personal',
                onTap: () => _applyPrepType('personal'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Also include Schedule C (sole prop)'),
                subtitle: const Text(
                  'Adds the Schedule C walkthrough tile even when filing Form 1040.',
                ),
                value: selected == 'personal' && includeScheduleC,
                onChanged: selected == 'personal' && !_isLocked
                    ? (value) async {
                        Map<String, dynamic> defaults = const {};
                        try {
                          defaults = await OrganizerDefaults.load();
                        } catch (_) {}
                        if (!mounted) return;
                        setState(() {
                          final next = Map<String, dynamic>.from(_data)
                            ..['includeScheduleC'] = value;
                          if (value) {
                            final scDefault = defaults['scheduleC'];
                            final existing = next['scheduleC'];
                            if (scDefault is Map &&
                                (existing is! Map || existing.isEmpty)) {
                              next['scheduleC'] =
                                  Map<String, dynamic>.from(scDefault);
                            } else if (existing is! Map) {
                              next['scheduleC'] = <String, dynamic>{};
                            }
                          }
                          _data = next;
                        });
                        _dirtySectionKeys.add('filing_info');
                        if (value) _dirtySectionKeys.add('schedule_c');
                        _scheduleAutoSave();
                      }
                    : null,
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Business tax filing',
          subtitle:
              'Schedule C sole prop, S-Corp, C-Corp, and partnership returns — adds the matching organizer sections.',
          child: Column(
            children: [
              for (final choice in businessTaxFilingChoices)
                _prepTypeChoiceTile(
                  title: choice.$2,
                  hint: choice.$3,
                  selected: selected == choice.$1,
                  onTap: () => _applyPrepType(choice.$1),
                ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Other entity filings',
          subtitle: 'Trust/estate and nonprofit returns.',
          child: Column(
            children: [
              for (final choice in otherEntityFilingChoices)
                _prepTypeChoiceTile(
                  title: choice.$2,
                  hint: choice.$3,
                  selected: selected == choice.$1,
                  onTap: () => _applyPrepType(choice.$1),
                ),
            ],
          ),
        ),
        if (!_isLocked) ...[
          OutlinedButton.icon(
            onPressed: _showAddBusinessSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add business — autofill owner + K-1 → Schedule E Part II'),
          ),
          const SizedBox(height: 12),
        ],
        OrganizerDropdown<String>(
          label: 'Filing status',
          value: '${_data['filingStatus'] ?? 'single'}',
          items: filingStatusOptions,
          onChanged: (v) => _setRoot('filingStatus', v ?? 'single'),
        ),
        _filingYearDropdown(),
        const MkgCard(
          child: Text(
            'Personal & Schedule C use the Form 1040 workflow with Schedules A–F. '
            'Business entity types (1120, 1120-S, 1065, 990-EZ, etc.) use a shorter entity form flow.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _prepTypeChoiceTile({
    required String title,
    required String hint,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? MkgColors.primary.withValues(alpha: 0.08) : MkgColors.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLocked ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? MkgColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? MkgColors.primary : MkgColors.textGrey,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected ? MkgColors.primary : MkgColors.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: const TextStyle(
                          color: MkgColors.textGrey,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _listMaps(String key) {
    final raw = (_data[key] as List?) ?? const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  void _setList(String key, List<Map<String, dynamic>> rows) {
    setState(() => _data = Map<String, dynamic>.from(_data)..[key] = rows);
    _scheduleAutoSave();
  }

  Widget _autoSaveIndicator() {
    switch (_autoSaveStatus) {
      case _AutoSaveStatus.pending:
        return const Text(
          'Unsaved changes…',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
        );
      case _AutoSaveStatus.saving:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: MkgColors.textGrey),
            ),
            SizedBox(width: 6),
            Text('Saving…', style: TextStyle(color: MkgColors.textGrey, fontSize: 12)),
          ],
        );
      case _AutoSaveStatus.saved:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: MkgColors.green),
            SizedBox(width: 4),
            Text('Saved', style: TextStyle(color: MkgColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        );
      case _AutoSaveStatus.error:
        return Tooltip(
          message: _autoSaveError ?? 'Could not auto-save',
          child: InkWell(
            onTap: _isLocked ? null : _runAutoSave,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                SizedBox(width: 4),
                Text(
                  'Save failed — tap to retry',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      case _AutoSaveStatus.idle:
        return const Text(
          'Auto-save on',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
        );
    }
  }

  Widget _personalInfoStep() {
    final dependents = _listMaps('dependents');
    final autofillOn = ref.watch(organizerAutofillEnabledProvider);
    return Column(
      children: [
        OrganizerSection(
          title: 'Auto-fill my information',
          subtitle: 'Use your account profile so you do not retype name, email, phone, or address.',
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: autofillOn,
            activeThumbColor: MkgColors.primary,
            title: Text(
              autofillOn ? 'Auto-fill is on' : 'Auto-fill is off',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              autofillOn
                  ? 'Empty fields are filled from your signed-in profile. Turn off to enter everything manually.'
                  : 'Turn on to fill taxpayer fields from your account.',
              style: const TextStyle(color: MkgColors.textGrey, fontSize: 13),
            ),
            onChanged: _onAutofillToggled,
          ),
        ),
        OrganizerSection(
          title: 'Taxpayer',
          child: Column(
            children: [
              OrganizerTextField(label: 'First name', value: '${_data['firstName'] ?? ''}', onChanged: (v) => _setRoot('firstName', v)),
              OrganizerTextField(label: 'Middle initial', value: '${_data['middleInitial'] ?? ''}', onChanged: (v) => _setRoot('middleInitial', v)),
              OrganizerTextField(label: 'Last name', value: '${_data['lastName'] ?? ''}', onChanged: (v) => _setRoot('lastName', v)),
              OrganizerDropdown<String>(
                label: 'ID type',
                value: '${_data['ssnType'] ?? 'ssn'}',
                items: const [('ssn', 'SSN'), ('itin', 'ITIN')],
                onChanged: (v) => _setRoot('ssnType', v ?? 'ssn'),
              ),
              OrganizerTextField(label: 'SSN / ITIN', value: '${_data['ssn'] ?? ''}', onChanged: (v) => _setRoot('ssn', v)),
              OrganizerTextField(label: 'Date of birth', value: '${_data['dateOfBirth'] ?? ''}', onChanged: (v) => _setRoot('dateOfBirth', v)),
              OrganizerTextField(label: 'Phone', value: '${_data['phone'] ?? ''}', onChanged: (v) => _setRoot('phone', v)),
              OrganizerTextField(label: 'Email', value: '${_data['email'] ?? ''}', onChanged: (v) => _setRoot('email', v)),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Address',
          subtitle: 'Search the free map directory, then tap a result to fill city, state, and ZIP.',
          child: AddressAutofillFields(
            data: _data,
            onChanged: (key, value) => _setRoot(key, value),
          ),
        ),
        if ('${_data['filingStatus']}' == 'married_joint' || '${_data['filingStatus']}' == 'married_separate')
          OrganizerSection(
            title: 'Spouse',
            child: Column(
              children: [
                OrganizerTextField(label: 'Spouse first name', value: '${_data['spouseFirstName'] ?? ''}', onChanged: (v) => _setRoot('spouseFirstName', v)),
                OrganizerTextField(label: 'Spouse last name', value: '${_data['spouseLastName'] ?? ''}', onChanged: (v) => _setRoot('spouseLastName', v)),
                OrganizerTextField(label: 'Spouse SSN', value: '${_data['spouseSSN'] ?? ''}', onChanged: (v) => _setRoot('spouseSSN', v)),
              ],
            ),
          ),
        OrganizerSection(
          title: 'Dependents',
          subtitle: 'Add each dependent’s name, SSN, relationship, and date of birth.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dependents.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No dependents yet. Add children or qualifying relatives.',
                    style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
                  ),
                ),
              for (var i = 0; i < dependents.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Dependent ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(dependents)..removeAt(i);
                              _setList('dependents', next);
                              _setRoot('numDependents', next.length);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerTextField(
                        label: 'Full name',
                        value: '${dependents[i]['name'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(dependents);
                          next[i] = Map<String, dynamic>.from(next[i])..['name'] = v;
                          _setList('dependents', next);
                        },
                      ),
                      OrganizerDropdown<String>(
                        label: 'Relationship',
                        value: dependentRelationshipOptions.any((e) => e.$1 == '${dependents[i]['relationship']}')
                            ? '${dependents[i]['relationship']}'
                            : 'other',
                        items: dependentRelationshipOptions,
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(dependents);
                          next[i] = Map<String, dynamic>.from(next[i])..['relationship'] = v ?? 'other';
                          _setList('dependents', next);
                        },
                      ),
                      OrganizerDropdown<String>(
                        label: 'ID type',
                        value: '${dependents[i]['ssnType'] ?? 'ssn'}',
                        items: const [('ssn', 'SSN'), ('itin', 'ITIN')],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(dependents);
                          next[i] = Map<String, dynamic>.from(next[i])..['ssnType'] = v ?? 'ssn';
                          _setList('dependents', next);
                        },
                      ),
                      OrganizerTextField(
                        label: 'SSN / ITIN',
                        value: '${dependents[i]['ssn'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(dependents);
                          next[i] = Map<String, dynamic>.from(next[i])..['ssn'] = v;
                          _setList('dependents', next);
                        },
                      ),
                      OrganizerTextField(
                        label: 'Date of birth',
                        value: '${dependents[i]['dob'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(dependents);
                          next[i] = Map<String, dynamic>.from(next[i])..['dob'] = v;
                          _setList('dependents', next);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  final next = [...dependents, emptyDependent()];
                  _setList('dependents', next);
                  _setRoot('numDependents', next.length);
                },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add dependent'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleBStep() {
    final scheduleB = _map('scheduleB');
    final interest = List<Map<String, dynamic>>.from(
      ((scheduleB['interestPayers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final dividends = List<Map<String, dynamic>>.from(
      ((scheduleB['dividendPayers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    void syncInterestTotal(List<Map<String, dynamic>> rows) {
      num total = 0;
      for (final r in rows) {
        total += r['amount'] is num ? r['amount'] as num : num.tryParse('${r['amount']}') ?? 0;
      }
      _setRoot('interestIncome', total);
    }

    void syncDividendTotal(List<Map<String, dynamic>> rows) {
      num total = 0;
      for (final r in rows) {
        total += r['ordinaryDividends'] is num
            ? r['ordinaryDividends'] as num
            : num.tryParse('${r['ordinaryDividends']}') ?? 0;
      }
      _setRoot('dividendIncome', total);
    }

    return Column(
      children: [
        OrganizerSection(
          title: 'Schedule B — Interest',
          subtitle: 'List each 1099-INT payer. Totals update Form 1040 interest.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < interest.length; i++) ...[
                MkgCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Payer ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(interest)..removeAt(i);
                              _setNested('scheduleB', {...scheduleB, 'interestPayers': next});
                              syncInterestTotal(next);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerTextField(
                        label: 'Payer name',
                        value: '${interest[i]['payerName'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(interest);
                          next[i] = Map<String, dynamic>.from(next[i])..['payerName'] = v;
                          _setNested('scheduleB', {...scheduleB, 'interestPayers': next});
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'Interest amount',
                        value: interest[i]['amount'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(interest);
                          next[i] = Map<String, dynamic>.from(next[i])..['amount'] = v;
                          _setNested('scheduleB', {...scheduleB, 'interestPayers': next});
                          syncInterestTotal(next);
                        },
                      ),
                      OrganizerCheckbox(
                        label: 'Tax-exempt interest',
                        value: interest[i]['taxExempt'] == true,
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(interest);
                          next[i] = Map<String, dynamic>.from(next[i])..['taxExempt'] = v;
                          _setNested('scheduleB', {...scheduleB, 'interestPayers': next});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  final next = [...interest, emptyInterestPayer()];
                  _setNested('scheduleB', {...scheduleB, 'interestPayers': next});
                },
                icon: const Icon(Icons.add),
                label: const Text('Add interest payer'),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Schedule B — Dividends',
          subtitle: 'List each 1099-DIV payer. Totals update Form 1040 dividends.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < dividends.length; i++) ...[
                MkgCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Payer ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(dividends)..removeAt(i);
                              _setNested('scheduleB', {...scheduleB, 'dividendPayers': next});
                              syncDividendTotal(next);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerTextField(
                        label: 'Payer name',
                        value: '${dividends[i]['payerName'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(dividends);
                          next[i] = Map<String, dynamic>.from(next[i])..['payerName'] = v;
                          _setNested('scheduleB', {...scheduleB, 'dividendPayers': next});
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'Ordinary dividends',
                        value: dividends[i]['ordinaryDividends'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(dividends);
                          next[i] = Map<String, dynamic>.from(next[i])..['ordinaryDividends'] = v;
                          _setNested('scheduleB', {...scheduleB, 'dividendPayers': next});
                          syncDividendTotal(next);
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'Qualified dividends',
                        value: dividends[i]['qualifiedDividends'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(dividends);
                          next[i] = Map<String, dynamic>.from(next[i])..['qualifiedDividends'] = v;
                          _setNested('scheduleB', {...scheduleB, 'dividendPayers': next});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  final next = [...dividends, emptyDividendPayer()];
                  _setNested('scheduleB', {...scheduleB, 'dividendPayers': next});
                },
                icon: const Icon(Icons.add),
                label: const Text('Add dividend payer'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleDStep() {
    final scheduleD = _map('scheduleD');
    final txs = List<Map<String, dynamic>>.from(
      ((scheduleD['transactions'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    void syncCapitalGains(Map<String, dynamic> next) {
      num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
      _setRoot('capitalGains', n(next['shortTermGains']) + n(next['longTermGains']));
    }

    return Column(
      children: [
        OrganizerSection(
          title: 'Schedule D — Capital gains',
          child: Column(
            children: [
              OrganizerMoneyField(
                label: 'Short-term capital gain (loss)',
                value: scheduleD['shortTermGains'],
                onChanged: (v) {
                  final next = {...scheduleD, 'shortTermGains': v};
                  _setNested('scheduleD', next);
                  syncCapitalGains(next);
                },
              ),
              OrganizerMoneyField(
                label: 'Long-term capital gain (loss)',
                value: scheduleD['longTermGains'],
                onChanged: (v) {
                  final next = {...scheduleD, 'longTermGains': v};
                  _setNested('scheduleD', next);
                  syncCapitalGains(next);
                },
              ),
              OrganizerMoneyField(
                label: 'Form 1040 capital gain total',
                value: _data['capitalGains'],
                onChanged: (v) => _setRoot('capitalGains', v),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Transactions (Form 8949 detail)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < txs.length; i++) ...[
                MkgCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Transaction ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(txs)..removeAt(i);
                              _setNested('scheduleD', {...scheduleD, 'transactions': next});
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerTextField(
                        label: 'Description',
                        value: '${txs[i]['description'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(txs);
                          next[i] = Map<String, dynamic>.from(next[i])..['description'] = v;
                          _setNested('scheduleD', {...scheduleD, 'transactions': next});
                        },
                      ),
                      OrganizerDropdown<String>(
                        label: 'Term',
                        value: '${txs[i]['term'] ?? 'long'}',
                        items: const [('short', 'Short-term'), ('long', 'Long-term')],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(txs);
                          next[i] = Map<String, dynamic>.from(next[i])..['term'] = v ?? 'long';
                          _setNested('scheduleD', {...scheduleD, 'transactions': next});
                        },
                      ),
                      OrganizerTextField(
                        label: 'Date acquired',
                        value: '${txs[i]['dateAcquired'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(txs);
                          next[i] = Map<String, dynamic>.from(next[i])..['dateAcquired'] = v;
                          _setNested('scheduleD', {...scheduleD, 'transactions': next});
                        },
                      ),
                      OrganizerTextField(
                        label: 'Date sold',
                        value: '${txs[i]['dateSold'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(txs);
                          next[i] = Map<String, dynamic>.from(next[i])..['dateSold'] = v;
                          _setNested('scheduleD', {...scheduleD, 'transactions': next});
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'Proceeds',
                        value: txs[i]['proceeds'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(txs);
                          final row = Map<String, dynamic>.from(next[i])..['proceeds'] = v;
                          final basis = row['costBasis'] is num ? row['costBasis'] as num : num.tryParse('${row['costBasis']}') ?? 0;
                          row['gainOrLoss'] = v - basis;
                          next[i] = row;
                          _setNested('scheduleD', {...scheduleD, 'transactions': next});
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'Cost basis',
                        value: txs[i]['costBasis'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(txs);
                          final row = Map<String, dynamic>.from(next[i])..['costBasis'] = v;
                          final proceeds = row['proceeds'] is num ? row['proceeds'] as num : num.tryParse('${row['proceeds']}') ?? 0;
                          row['gainOrLoss'] = proceeds - v;
                          next[i] = row;
                          _setNested('scheduleD', {...scheduleD, 'transactions': next});
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'Gain or loss',
                        value: txs[i]['gainOrLoss'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(txs);
                          next[i] = Map<String, dynamic>.from(next[i])..['gainOrLoss'] = v;
                          _setNested('scheduleD', {...scheduleD, 'transactions': next});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  final next = [...txs, emptyCapitalTransaction()];
                  _setNested('scheduleD', {...scheduleD, 'transactions': next});
                },
                icon: const Icon(Icons.add),
                label: const Text('Add capital transaction'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleEStep() {
    final scheduleE = _map('scheduleE');
    final rentals = List<Map<String, dynamic>>.from(
      ((scheduleE['rentalProperties'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final partII = List<Map<String, dynamic>>.from(
      ((scheduleE['partII'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final k1Forms = List<Map<String, dynamic>>.from(
      ((_data['federalK1Forms'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    void persistScheduleE({
      List<Map<String, dynamic>>? nextRentals,
      List<Map<String, dynamic>>? nextPartII,
      List<Map<String, dynamic>>? nextK1s,
      bool syncFromK1 = false,
    }) {
      var next = Map<String, dynamic>.from(_data);
      final se = Map<String, dynamic>.from((next['scheduleE'] as Map?) ?? {});
      if (nextRentals != null) se['rentalProperties'] = nextRentals;
      if (nextPartII != null) se['partII'] = nextPartII;
      next['scheduleE'] = se;
      if (nextK1s != null) next['federalK1Forms'] = nextK1s;
      if (syncFromK1 || nextK1s != null) {
        next = syncK1ToScheduleEPartII(next);
      } else {
        // Keep rentalIncome in sync for Part I edits.
        num net = 0;
        final rows = List<Map<String, dynamic>>.from(
          ((se['rentalProperties'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        for (final r in rows) {
          num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
          net += n(r['rentReceived']) -
              n(r['mortgage']) -
              n(r['insurance']) -
              n(r['repairs']) -
              n(r['taxes']) -
              n(r['utilities']) -
              n(r['depreciation']) -
              n(r['advertising']) -
              n(r['otherExpenses']);
        }
        for (final row in ((se['partII'] as List?) ?? const [])) {
          if (row is! Map) continue;
          num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
          net += n(row['ordinaryIncome']) +
              n(row['netRentalRealEstate']) +
              n(row['otherNetRentalIncome']) +
              n(row['guaranteedPayments']);
        }
        next['rentalIncome'] = net;
      }
      setState(() => _data = next);
      _markCurrentSectionDirty();
      _scheduleAutoSave();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrganizerSection(
          title: 'Schedule E — Part I (Rental / Royalty)',
          subtitle: 'Add each rental property you own.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rentals.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Property ${i + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(rentals)..removeAt(i);
                              persistScheduleE(nextRentals: next);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerTextField(
                        label: 'Address',
                        value: '${rentals[i]['address'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rentals);
                          next[i] = Map<String, dynamic>.from(next[i])..['address'] = v;
                          persistScheduleE(nextRentals: next);
                        },
                      ),
                      for (final field in const [
                        ('rentReceived', 'Rent received'),
                        ('mortgage', 'Mortgage interest'),
                        ('insurance', 'Insurance'),
                        ('repairs', 'Repairs'),
                        ('taxes', 'Taxes'),
                        ('utilities', 'Utilities'),
                        ('depreciation', 'Depreciation'),
                        ('advertising', 'Advertising'),
                        ('otherExpenses', 'Other expenses'),
                      ])
                        OrganizerMoneyField(
                          label: field.$2,
                          value: rentals[i][field.$1],
                          onChanged: (v) {
                            final next = List<Map<String, dynamic>>.from(rentals);
                            next[i] = Map<String, dynamic>.from(next[i])..[field.$1] = v;
                            persistScheduleE(nextRentals: next);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  persistScheduleE(nextRentals: [...rentals, emptyRentalProperty()]);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add rental property'),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Federal K-1 intake',
          subtitle:
              'Partner / shareholder / beneficiary K-1 boxes. Use + Add business to autofill owner info from Personal Info.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < k1Forms.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'K-1 ${i + 1} · ${k1Forms[i]['sourceForm'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(k1Forms)..removeAt(i);
                              persistScheduleE(nextK1s: next, syncFromK1: true);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerTextField(
                        label: 'Entity name',
                        value: '${k1Forms[i]['entityName'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(k1Forms);
                          next[i] = Map<String, dynamic>.from(next[i])..['entityName'] = v;
                          persistScheduleE(nextK1s: next, syncFromK1: true);
                        },
                      ),
                      OrganizerTextField(
                        label: 'EIN',
                        value: '${k1Forms[i]['ein'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(k1Forms);
                          next[i] = Map<String, dynamic>.from(next[i])..['ein'] = v;
                          persistScheduleE(nextK1s: next, syncFromK1: true);
                        },
                      ),
                      OrganizerTextField(
                        label: 'Partner / shareholder name',
                        value: '${k1Forms[i]['partnerOrShareholderName'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(k1Forms);
                          next[i] = Map<String, dynamic>.from(next[i])
                            ..['partnerOrShareholderName'] = v;
                          persistScheduleE(nextK1s: next, syncFromK1: true);
                        },
                      ),
                      OrganizerTextField(
                        label: 'Partner / shareholder TIN',
                        value: '${k1Forms[i]['partnerOrShareholderTIN'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(k1Forms);
                          next[i] = Map<String, dynamic>.from(next[i])
                            ..['partnerOrShareholderTIN'] = v;
                          persistScheduleE(nextK1s: next, syncFromK1: true);
                        },
                      ),
                      OrganizerTextField(
                        label: 'Ownership %',
                        value: '${k1Forms[i]['ownershipPercentage'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(k1Forms);
                          next[i] = Map<String, dynamic>.from(next[i])
                            ..['ownershipPercentage'] = num.tryParse(v) ?? 0;
                          persistScheduleE(nextK1s: next, syncFromK1: true);
                        },
                      ),
                      for (final field in const [
                        ('ordinaryIncome', 'Ordinary business income (loss)'),
                        ('netRentalRealEstate', 'Net rental real estate'),
                        ('otherNetRentalIncome', 'Other net rental income'),
                        ('guaranteedPayments', 'Guaranteed payments'),
                        ('section179Deduction', 'Section 179 deduction'),
                        ('selfEmploymentEarnings', 'Self-employment earnings'),
                      ])
                        OrganizerMoneyField(
                          label: field.$2,
                          value: k1Forms[i][field.$1],
                          onChanged: (v) {
                            final next = List<Map<String, dynamic>>.from(k1Forms);
                            next[i] = Map<String, dynamic>.from(next[i])..[field.$1] = v;
                            persistScheduleE(nextK1s: next, syncFromK1: true);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: _showAddBusinessSheet,
                icon: const Icon(Icons.add),
                label: const Text('Add business / K-1 (autofill owner)'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => persistScheduleE(syncFromK1: true),
                icon: const Icon(Icons.sync_alt),
                label: const Text('Sync K-1 → Schedule E Part II'),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Schedule E — Part II (Partnerships / S-corps / Trusts)',
          subtitle:
              'Automated from federal K-1 intake. Amounts flow to Form 1040 Schedule E Part II.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (partII.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No Part II interests yet. Add a business / K-1 above.',
                    style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
                  ),
                ),
              for (var i = 0; i < partII.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${partII[i]['entityName'] ?? '(unnamed)'} · ${partII[i]['entityType'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'EIN: ${partII[i]['ein'] ?? '—'}',
                        style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text('Ordinary income: ${partII[i]['ordinaryIncome'] ?? 0}'),
                      Text('Net rental real estate: ${partII[i]['netRentalRealEstate'] ?? 0}'),
                      Text('Other net rental: ${partII[i]['otherNetRentalIncome'] ?? 0}'),
                      Text('Guaranteed payments: ${partII[i]['guaranteedPayments'] ?? 0}'),
                      if ('${partII[i]['sourceK1Id'] ?? ''}'.trim().isEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(partII)..removeAt(i);
                              persistScheduleE(nextPartII: next);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleFStep() {
    final scheduleF = _map('scheduleF');
    final method = normalizeEnumValue(
      scheduleF['accountingMethod'],
      accountingMethodOptions,
      fallback: 'cash',
    );
    const identity = [
      'farmName',
      'farmEIN',
      'principalProduct',
      'employerIDNumber',
    ];
    final rest = scheduleF.keys
        .where((k) => !identity.contains(k) && k != 'accountingMethod')
        .toList();
    return Column(
      children: [
        OrganizerSection(
          title: 'Schedule F — Farm identity',
          child: Column(
            children: [
              NestedMapEditor(
                data: scheduleF,
                onlyKeys: identity,
                onChanged: (m) {
                  final next = Map<String, dynamic>.from(m)..['accountingMethod'] = method;
                  _setNested('scheduleF', next);
                  final gross = next['grossFarmIncome'];
                  if (gross != null) _setRoot('farmIncome', gross);
                },
              ),
              OrganizerDropdown<String>(
                label: 'Accounting method',
                value: method,
                items: accountingMethodOptions,
                onChanged: (v) {
                  final next = Map<String, dynamic>.from(scheduleF)
                    ..['accountingMethod'] = v ?? 'cash';
                  _setNested('scheduleF', next);
                },
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Farm income & expenses',
          child: NestedMapEditor(
            data: scheduleF,
            onlyKeys: rest,
            onChanged: (m) {
              final next = Map<String, dynamic>.from(m)..['accountingMethod'] = method;
              _setNested('scheduleF', next);
              final gross = next['grossFarmIncome'];
              if (gross != null) _setRoot('farmIncome', gross);
            },
          ),
        ),
      ],
    );
  }

  Widget _scheduleCStep() {
    final scheduleC = _map('scheduleC');
    final businessType = normalizeEnumValue(
      scheduleC['businessType'],
      scheduleCBusinessTypeOptions,
      fallback: '',
    );
    final method = normalizeEnumValue(
      scheduleC['accountingMethod'],
      accountingMethodOptions,
      fallback: 'cash',
    );
    const identity = [
      'businessName',
      'businessEIN',
    ];
    final addressKeys = {
      'businessAddress',
      'businessApartment',
      'businessCity',
      'businessState',
      'businessZip',
    };
    final expenseKeys = scheduleC.keys
        .where(
          (k) =>
              !identity.contains(k) &&
              !addressKeys.contains(k) &&
              k != 'businessType' &&
              k != 'accountingMethod',
        )
        .toList();
    return Column(
      children: [
        OrganizerSection(
          title: 'Business identity',
          subtitle: 'Schedule C — Profit or Loss From Business (sole prop / gig).',
          child: Column(
            children: [
              NestedMapEditor(
                data: scheduleC,
                onlyKeys: identity,
                onChanged: (m) {
                  final next = Map<String, dynamic>.from(m)
                    ..['businessType'] = businessType
                    ..['accountingMethod'] = method;
                  _setNested('scheduleC', next);
                },
              ),
              OrganizerDropdown<String>(
                label: 'Business type',
                value: businessType,
                items: scheduleCBusinessTypeOptions,
                onChanged: (v) {
                  final next = Map<String, dynamic>.from(scheduleC)
                    ..['businessType'] = v ?? '';
                  _setNested('scheduleC', next);
                },
              ),
              OrganizerDropdown<String>(
                label: 'Accounting method',
                value: method,
                items: accountingMethodOptions,
                onChanged: (v) {
                  final next = Map<String, dynamic>.from(scheduleC)
                    ..['accountingMethod'] = v ?? 'cash';
                  _setNested('scheduleC', next);
                },
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Business address (street map)',
          subtitle: 'Search the map to fill city, state, and ZIP.',
          child: AddressAutofillFields(
            data: scheduleC,
            onChanged: (key, value) {
              final next = Map<String, dynamic>.from(scheduleC)..[key] = value;
              _setNested('scheduleC', next);
            },
            streetKey: 'businessAddress',
            cityKey: 'businessCity',
            stateKey: 'businessState',
            zipKey: 'businessZip',
            apartmentKey: 'businessApartment',
            streetLabel: 'Business street',
            helperText: 'Map search fills business city, state, and ZIP',
          ),
        ),
        OrganizerSection(
          title: 'Income & expenses',
          child: NestedMapEditor(
            data: scheduleC,
            onlyKeys: expenseKeys,
            onChanged: (m) {
              final next = Map<String, dynamic>.from(m)
                ..['businessType'] = businessType
                ..['accountingMethod'] = method;
              _setNested('scheduleC', next);
            },
          ),
        ),
      ],
    );
  }

  Widget _directDepositStep() {
    return OrganizerSection(
      title: 'Banking / direct deposit',
      child: Column(
        children: [
          OrganizerTextField(label: 'Bank name', value: '${_data['bankName'] ?? ''}', onChanged: (v) => _setRoot('bankName', v)),
          OrganizerTextField(label: 'Routing number', value: '${_data['routingNumber'] ?? ''}', onChanged: (v) => _setRoot('routingNumber', v)),
          OrganizerTextField(label: 'Account number', value: '${_data['accountNumber'] ?? ''}', onChanged: (v) => _setRoot('accountNumber', v)),
          OrganizerDropdown<String>(
            label: 'Account type',
            value: '${_data['accountType'] ?? 'checking'}',
            items: const [('checking', 'Checking'), ('savings', 'Savings')],
            onChanged: (v) => _setRoot('accountType', v ?? 'checking'),
          ),
        ],
      ),
    );
  }

  /// Enum fields pulled out of NestedMapEditor as dropdowns (AOTC pattern).
  List<(String key, String label, List<(String, String)> options, String fallback)>
      _entityEnumSpecs(String prep) {
    switch (prep) {
      case 'form1041':
        return [
          ('entityType', 'Entity type', form1041EntityTypeOptions, 'simple_trust'),
          ('taxYearType', 'Tax year type', taxYearTypeOptions, 'calendar'),
        ];
      case 'form1065':
        return [
          ('partnershipType', 'Partnership type', partnershipTypeOptions, 'general'),
        ];
      case 'form1120':
      case 'form1120S':
        return [
          (
            'stateOfIncorporation',
            'State of incorporation',
            stateOfIncorporationOptions,
            '',
          ),
        ];
      case 'form990':
        return [
          ('taxExemptStatus', 'Tax-exempt status', taxExemptStatusOptions, '501c3'),
          ('organizationType', 'Organization type', nonprofitOrgTypeOptions, 'corporation'),
          ('groupReturn', 'Group return', yesNoOptions, 'no'),
        ];
      case 'form990EZ':
        return [
          ('taxExemptStatus', 'Tax-exempt status', taxExemptStatusOptions, '501c3'),
          ('organizationType', 'Organization type', nonprofitOrgTypeOptions, 'corporation'),
        ];
      default:
        return const [];
    }
  }

  Widget _entityFormStep(String prep) {
    final form = _map(prep);
    final labels = businessFormLabels[prep] ?? prep;
    final enumSpecs = _entityEnumSpecs(prep);
    final enumKeys = {for (final s in enumSpecs) s.$1};
    final enumValues = <String, String>{
      for (final s in enumSpecs)
        s.$1: normalizeEnumValue(form[s.$1], s.$3, fallback: s.$4),
    };
    final owners = List<Map<String, dynamic>>.from(
      ((form['owners'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    // Prefer identity-ish keys first for usability.
    final keys = form.keys.toList();
    final skipKeys = {...enumKeys, 'owners', 'beneficiaries'};
    final identityKeys = <String>[];
    for (final k in keys) {
      if (skipKeys.contains(k)) continue;
      final lower = k.toLowerCase();
      if (lower.startsWith('schedule')) continue;
      final isId = lower.contains('name') ||
          lower.contains('ein') ||
          lower.contains('address') ||
          lower.contains('year') ||
          lower.contains('type') ||
          lower.contains('code') ||
          lower.contains('date') ||
          lower.contains('number') ||
          lower.contains('partner') ||
          lower.contains('shareholder') ||
          lower.contains('website') ||
          lower.contains('mission') ||
          lower.contains('purpose') ||
          lower.contains('status') ||
          lower.contains('city') ||
          lower == 'state' ||
          lower.contains('zip');
      if (isId) identityKeys.add(k);
      if (identityKeys.length >= 18) break;
    }
    final rest = keys
        .where((k) => !identityKeys.contains(k) && !skipKeys.contains(k))
        .toList();

    void persist(Map<String, dynamic> m) {
      final next = Map<String, dynamic>.from(m);
      for (final e in enumValues.entries) {
        next[e.key] = e.value;
      }
      next['owners'] = owners;
      _setNested(prep, next);
    }

    void persistOwners(List<Map<String, dynamic>> nextOwners) {
      final next = Map<String, dynamic>.from(form);
      for (final e in enumValues.entries) {
        next[e.key] = e.value;
      }
      next['owners'] = nextOwners;
      if (prep == 'form1065') next['numberOfPartners'] = nextOwners.length;
      if (prep == 'form1120S') next['numberOfShareholders'] = nextOwners.length;
      _setNested(prep, next);
      if (k1PassThroughPrepTypes.contains(prep)) {
        setState(() {
          var data = Map<String, dynamic>.from(_data)..[prep] = next;
          data = upsertFederalK1ForEntity(data, prep);
          data = syncK1ToScheduleEPartII(data);
          _data = data;
        });
        _dirtySectionKeys.add('schedule_e');
        _dirtySectionKeys.add('entity_form');
        _scheduleAutoSave();
      }
    }

    return Column(
      children: [
        OrganizerSection(
          title: labels,
          subtitle: 'Field names match mkgtaxconsultants.com `$prep` in tax_returns.data.',
          child: Column(
            children: [
              for (final s in enumSpecs)
                OrganizerDropdown<String>(
                  label: s.$2,
                  value: enumValues[s.$1]!,
                  items: s.$3,
                  onChanged: (v) {
                    final next = Map<String, dynamic>.from(form)..[s.$1] = v ?? s.$4;
                    next['owners'] = owners;
                    _setNested(prep, next);
                  },
                ),
              NestedMapEditor(
                data: form,
                onlyKeys: identityKeys.isEmpty
                    ? keys.where((k) => !skipKeys.contains(k)).take(12).toList()
                    : identityKeys,
                excludeKeys: skipKeys,
                onChanged: persist,
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Owners / partners / shareholders',
          subtitle:
              'Tap + to autofill from Personal Info. Pass-through K-1 identity syncs to Schedule E Part II.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < owners.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${owners[i]['isPrimary'] == true ? 'Primary · ' : ''}'
                              '${owners[i]['role'] ?? 'owner'} ${i + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(owners)..removeAt(i);
                              persistOwners(next);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerTextField(
                        label: 'Name',
                        value: '${owners[i]['name'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(owners);
                          next[i] = Map<String, dynamic>.from(next[i])..['name'] = v;
                          persistOwners(next);
                        },
                      ),
                      OrganizerTextField(
                        label: 'TIN / SSN',
                        value: '${owners[i]['tin'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(owners);
                          next[i] = Map<String, dynamic>.from(next[i])..['tin'] = v;
                          persistOwners(next);
                        },
                      ),
                      OrganizerTextField(
                        label: 'Address',
                        value: '${owners[i]['address'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(owners);
                          next[i] = Map<String, dynamic>.from(next[i])..['address'] = v;
                          persistOwners(next);
                        },
                      ),
                      OrganizerTextField(
                        label: 'Ownership %',
                        value: '${owners[i]['ownershipPercentage'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(owners);
                          next[i] = Map<String, dynamic>.from(next[i])
                            ..['ownershipPercentage'] = num.tryParse(v) ?? 0;
                          persistOwners(next);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  final seeded = ownerFromPersonalInfo(
                    _data,
                    role: ownerRoleForPrep(prep),
                    isPrimary: owners.isEmpty,
                  );
                  persistOwners([...owners, seeded]);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add owner (autofill from Personal Info)'),
              ),
              if (owners.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() {
                      var next = Map<String, dynamic>.from(_data);
                      final formNext = autofillPrimaryOwnerOnEntityForm(
                        next,
                        form,
                        prep,
                        overwritePrimary: true,
                      );
                      next[prep] = formNext;
                      if (k1PassThroughPrepTypes.contains(prep)) {
                        next = upsertFederalK1ForEntity(next, prep);
                        next = syncK1ToScheduleEPartII(next);
                        _dirtySectionKeys.add('schedule_e');
                      }
                      _data = next;
                    });
                    _dirtySectionKeys.add('entity_form');
                    _scheduleAutoSave();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Primary owner refreshed from Personal Info.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Refresh primary owner from Personal Info'),
                ),
              ],
            ],
          ),
        ),
        OrganizerSection(
          title: 'Income, deductions & schedules',
          child: NestedMapEditor(
            data: form,
            onlyKeys: rest,
            excludeKeys: skipKeys,
            onChanged: persist,
          ),
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final prep = '${_data['prepType'] ?? 'personal'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prep type: $prep', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Filing status: ${_data['filingStatus']}'),
              Text('Year: ${_data['filingYear'] ?? _year}'),
              Text('Name: ${_data['firstName'] ?? ''} ${_data['lastName'] ?? ''}'),
              Text('Dependents: ${_listMaps('dependents').length}'),
              Text('W-2 forms: ${_listMaps('w2Forms').where((w) => '${w['employerName'] ?? ''}'.trim().isNotEmpty || (w['box1_wagesTips'] is num && w['box1_wagesTips'] > 0)).length}'),
              Text('Wages total: ${_data['wages'] ?? 0}'),
              Text('Interest / dividends: ${_data['interestIncome'] ?? 0} / ${_data['dividendIncome'] ?? 0}'),
              Text('Capital gains: ${_data['capitalGains'] ?? 0}'),
              if (prep == 'business' || showScheduleCStep(_data))
                Text('Schedule C: ${_map('scheduleC')['businessName'] ?? '(not named)'}'),
              if ((_map('scheduleE')['rentalProperties'] as List?)?.isNotEmpty == true)
                Text('Schedule E properties: ${(_map('scheduleE')['rentalProperties'] as List).length}'),
              if ('${_map('scheduleF')['farmName'] ?? ''}'.trim().isNotEmpty || (_data['farmIncome'] is num && (_data['farmIncome'] as num) > 0))
                Text('Schedule F farm: ${_map('scheduleF')['farmName'] ?? 'entered'}'),
              if (_data['itemizeDeductions'] == true) const Text('Schedule A: itemizing'),
              if (_data['hasEIC'] == true || (_data['educationCredits'] is num && (_data['educationCredits'] as num) > 0))
                const Text('Federal credits entered'),
              Text('Additional state returns: ${_listMaps('additionalStateReturns').length}'),
              if (businessEntityTypes.contains(prep))
                Text('Entity: ${businessFormLabels[prep]}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrganizerTextField(
          label: 'Typed signature / printed name',
          value: '${_data['typedSignature'] ?? _data['printedName'] ?? ''}',
          onChanged: (v) {
            _setRoot('typedSignature', v);
            _setRoot('printedName', v);
            _setRoot('signatureType', 'type');
          },
        ),
        OrganizerCheckbox(
          label: 'I consent to e-file this return',
          value: _data['consentToEFile'] == true,
          onChanged: (v) => _setRoot('consentToEFile', v),
        ),
        OrganizerCheckbox(
          label: 'I declare under penalty of perjury that this information is true',
          value: _data['consentPerjury'] == true,
          onChanged: (v) => _setRoot('consentPerjury', v),
        ),
        OrganizerCheckbox(
          label: 'Consent to use / disclose tax information (IRC 7216)',
          value: _data['consent7216Use'] == true,
          onChanged: (v) {
            _setRoot('consent7216Use', v);
            _setRoot('consent7216Disclosure', v);
            _setRoot('consentToDisclosure', v);
          },
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.steps, required this.index});

  final List<String> steps;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (index + 1) / steps.length,
            minHeight: 8,
            backgroundColor: MkgColors.surfaceGrey,
            color: MkgColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${index + 1} of ${steps.length}',
          style: const TextStyle(fontSize: 12, color: MkgColors.textGrey, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.index,
    required this.title,
    required this.cue,
    required this.icon,
    required this.complete,
    required this.onTap,
  });

  final int index;
  final String title;
  final String cue;
  final IconData icon;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = complete ? MkgColors.green : MkgColors.primary;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  if (complete)
                    const Icon(Icons.check_circle, color: MkgColors.green, size: 22)
                  else
                    Text(
                      '$index',
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                cue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: MkgColors.textGrey, fontSize: 11, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
