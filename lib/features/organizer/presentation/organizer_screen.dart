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
import '../data/organizer_defaults.dart';
import '../data/organizer_profile_prefill.dart';
import '../data/organizer_repository.dart';
import '../data/organizer_section_mapper.dart';
import 'organizer_credits_step.dart';
import 'organizer_fields.dart';
import 'organizer_form_1040x_step.dart';
import 'organizer_income_forms_step.dart';
import 'organizer_state_returns_step.dart';

enum _AutoSaveStatus { idle, pending, saving, saved, error }

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
        // Skip redundant activate/tasks when home already warmed this year.
        final warm = tax.workspace;
        final yearHint = preferred ?? tax.currentFilingYear ?? DateTime.now().year - 1;
        if (warm?.workspaceId == null || warm?.taxYear != yearHint) {
          await ref.read(taxYearProvider.notifier).refreshWorkspace();
        }
        final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
        if (workspaceId == null) {
          throw Exception('No tax-year workspace. Select a year and try again.');
        }
        final year = ref.read(taxYearProvider).workspace?.taxYear ?? yearHint;
        // Parallel: defaults JSON + first organizer fetch.
        final defaultsFuture = OrganizerDefaults.load();
        final orgFuture = ref.read(laravelOrganizerRepositoryProvider).show(
              workspaceId,
              prepType: 'personal',
            );
        final defaults = await defaultsFuture;
        final org = await orgFuture;
        if (!mounted) return;
        final hydrated = OrganizerSectionMapper.hydrateFromServer(
          defaults: defaults,
          organizer: org,
          fallbackYear: year,
        );
        // Re-fetch with the hydrated prep type so entity catalogs match.
        final prep = '${hydrated['prepType'] ?? 'personal'}';
        final orgTyped = prep == '${org?['prep_type'] ?? 'personal'}'
            ? org
            : await ref.read(laravelOrganizerRepositoryProvider).show(workspaceId, prepType: prep);
        final data = OrganizerSectionMapper.hydrateFromServer(
          defaults: defaults,
          organizer: orgTyped ?? org,
          fallbackYear: year,
        );
        final filled = await _maybeAutofillProfile(data);
        if (!mounted) return;
        setState(() {
          _returnId = (orgTyped ?? org)?['id'] ?? workspaceId;
          _year = (filled['filingYear'] as num?)?.toInt() ?? year;
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
    final delay = (step == 'State Tax Returns' || step == 'CA 540 State Tax' || step == 'Income (1040)')
        ? const Duration(milliseconds: 1100)
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
    final selected = (_data['filingYear'] as num?)?.toInt() ?? _year;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrganizerSection(
          title: 'Filing type',
          subtitle: 'Matches mkgtaxconsultants.com prepType — personal, Schedule C business, or entity returns.',
          child: OrganizerDropdown<String>(
            label: 'Preparation type',
            value: '${_data['prepType'] ?? 'personal'}',
            items: prepTypeOptions,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _data = Map<String, dynamic>.from(_data)..['prepType'] = v;
                _step = 0;
              });
            },
          ),
        ),
        OrganizerDropdown<String>(
          label: 'Filing status',
          value: '${_data['filingStatus'] ?? 'single'}',
          items: filingStatusOptions,
          onChanged: (v) => _setRoot('filingStatus', v ?? 'single'),
        ),
        _filingYearDropdown(),
        const MkgCard(
          child: Text(
            'Personal & Schedule C use the Form 1040 workflow with Schedules A–F. Business entity types (1120, 1120-S, 1065, 990-EZ, etc.) use a shorter entity form flow.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.4),
          ),
        ),
      ],
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

    void syncRentalIncome(List<Map<String, dynamic>> rows) {
      num net = 0;
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
      _setRoot('rentalIncome', net);
    }

    return OrganizerSection(
      title: 'Schedule E — Rental / Royalty',
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
                      Expanded(child: Text('Property ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      IconButton(
                        onPressed: () {
                          final next = List<Map<String, dynamic>>.from(rentals)..removeAt(i);
                          _setNested('scheduleE', {...scheduleE, 'rentalProperties': next});
                          syncRentalIncome(next);
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
                      _setNested('scheduleE', {...scheduleE, 'rentalProperties': next});
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
                        _setNested('scheduleE', {...scheduleE, 'rentalProperties': next});
                        syncRentalIncome(next);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () {
              final next = [...rentals, emptyRentalProperty()];
              _setNested('scheduleE', {...scheduleE, 'rentalProperties': next});
            },
            icon: const Icon(Icons.add),
            label: const Text('Add rental property'),
          ),
        ],
      ),
    );
  }

  Widget _scheduleFStep() {
    final scheduleF = _map('scheduleF');
    const identity = [
      'farmName',
      'farmEIN',
      'principalProduct',
      'accountingMethod',
      'employerIDNumber',
    ];
    final rest = scheduleF.keys.where((k) => !identity.contains(k)).toList();
    return Column(
      children: [
        OrganizerSection(
          title: 'Schedule F — Farm identity',
          child: NestedMapEditor(
            data: scheduleF,
            onlyKeys: identity,
            onChanged: (m) {
              _setNested('scheduleF', m);
              final gross = m['grossFarmIncome'];
              if (gross != null) _setRoot('farmIncome', gross);
            },
          ),
        ),
        OrganizerSection(
          title: 'Farm income & expenses',
          child: NestedMapEditor(
            data: scheduleF,
            onlyKeys: rest,
            onChanged: (m) {
              _setNested('scheduleF', m);
              final gross = m['grossFarmIncome'];
              if (gross != null) _setRoot('farmIncome', gross);
            },
          ),
        ),
      ],
    );
  }

  Widget _scheduleCStep() {
    final scheduleC = _map('scheduleC');
    const identity = [
      'businessName',
      'businessEIN',
      'businessType',
      'accountingMethod',
    ];
    final addressKeys = {
      'businessAddress',
      'businessApartment',
      'businessCity',
      'businessState',
      'businessZip',
    };
    final expenseKeys = scheduleC.keys
        .where((k) => !identity.contains(k) && !addressKeys.contains(k))
        .toList();
    return Column(
      children: [
        OrganizerSection(
          title: 'Business identity',
          subtitle: 'Schedule C — Profit or Loss From Business (sole prop / gig).',
          child: NestedMapEditor(
            data: scheduleC,
            onlyKeys: identity,
            onChanged: (m) => _setNested('scheduleC', m),
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
            onChanged: (m) => _setNested('scheduleC', m),
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

  Widget _entityFormStep(String prep) {
    final form = _map(prep);
    final labels = businessFormLabels[prep] ?? prep;
    // Prefer identity-ish keys first for usability.
    final keys = form.keys.toList();
    final identityKeys = <String>[];
    for (final k in keys) {
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
    final rest = keys.where((k) => !identityKeys.contains(k)).toList();

    return Column(
      children: [
        OrganizerSection(
          title: labels,
          subtitle: 'Field names match mkgtaxconsultants.com `$prep` in tax_returns.data.',
          child: NestedMapEditor(
            data: form,
            onlyKeys: identityKeys.isEmpty ? keys.take(12).toList() : identityKeys,
            onChanged: (m) => _setNested(prep, m),
          ),
        ),
        OrganizerSection(
          title: 'Income, deductions & schedules',
          child: NestedMapEditor(
            data: form,
            onlyKeys: rest,
            onChanged: (m) => _setNested(prep, m),
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
