import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../states/data/state_workflow_repository.dart';
import 'organizer_fields.dart';

/// Renders a nationwide state workflow form (personal or business) from the API catalog.
class OrganizerNationwideForm extends ConsumerStatefulWidget {
  const OrganizerNationwideForm({
    super.key,
    required this.stateCode,
    required this.family,
    required this.filingType,
    required this.answers,
    required this.onChanged,
    this.taxYear = 2025,
  });

  final String stateCode;
  final String family;
  final String filingType;
  final Map<String, dynamic> answers;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final int taxYear;

  @override
  ConsumerState<OrganizerNationwideForm> createState() =>
      _OrganizerNationwideFormState();
}

class _OrganizerNationwideFormState extends ConsumerState<OrganizerNationwideForm> {
  Map<String, dynamic>? _ret;
  Map<String, dynamic>? _progress;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OrganizerNationwideForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateCode != widget.stateCode ||
        oldWidget.family != widget.family ||
        oldWidget.filingType != widget.filingType) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(stateWorkflowRepositoryProvider);
    final ret = await repo.findReturn(
      stateCode: widget.stateCode,
      family: widget.family,
      filingType: widget.filingType,
      taxYear: widget.taxYear,
    );
    if (!mounted) return;
    if (ret == null) {
      setState(() {
        _loading = false;
        _error = widget.stateCode.toUpperCase() == 'CA'
            ? 'California uses the Form 540 suite above.'
            : 'No workflow catalog for ${widget.stateCode} / ${widget.family}.';
        _ret = null;
      });
      return;
    }
    setState(() {
      _ret = ret;
      _loading = false;
    });
    await _refreshProgress(ret);
  }

  Future<void> _refreshProgress(Map<String, dynamic> ret) async {
    final repo = ref.read(stateWorkflowRepositoryProvider);
    final progress = await repo.evaluate(
      stateCode: widget.stateCode,
      family: widget.family,
      filingType: widget.filingType,
      answers: widget.answers,
    );
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  void _setAnswer(String key, dynamic value) {
    final next = Map<String, dynamic>.from(widget.answers)..[key] = value;
    widget.onChanged(next);
    if (_ret != null) {
      _refreshProgress(_ret!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(_error!, style: const TextStyle(color: MkgColors.textGrey)),
      );
    }
    final ret = _ret!;
    final groups = (ret['fieldGroups'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final pct = (_progress?['percentComplete'] as num?)?.toInt() ?? 0;
    final formId = '${ret['primaryFormId'] ?? ''}';
    final title = '${ret['primaryFormTitle'] ?? formId}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$formId · $title',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Intake workflow · ${ret['calculationMode'] ?? 'intake_only'} · '
                'not a certified tax computation',
                style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: MkgColors.primary.withValues(alpha: 0.12),
                color: MkgColors.primary,
              ),
              const SizedBox(height: 4),
              Text('$pct% required steps complete', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final group in groups) ...[
          OrganizerSection(
            title: '${group['title'] ?? group['id']}',
            subtitle: group['description']?.toString(),
            child: Column(
              children: [
                for (final raw in (group['fields'] as List? ?? const []))
                  if (raw is Map) _field(Map<String, dynamic>.from(raw)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _field(Map<String, dynamic> field) {
    final key = '${field['key']}';
    final label = '${field['label'] ?? key}';
    final type = '${field['type'] ?? 'string'}';
    final required = field['required'] == true;
    final shown = required ? '$label *' : label;
    final value = widget.answers[key];

    if (type == 'boolean') {
      return OrganizerCheckbox(
        label: shown,
        value: value == true,
        onChanged: (v) => _setAnswer(key, v),
      );
    }
    if (type == 'enum') {
      final options = (field['options'] as List? ?? const [])
          .map((e) => ('$e', '$e'))
          .toList();
      if (options.isEmpty) {
        return OrganizerTextField(
          label: shown,
          value: '${value ?? ''}',
          onChanged: (v) => _setAnswer(key, v),
        );
      }
      final current = options.any((e) => e.$1 == '$value') ? '$value' : options.first.$1;
      return OrganizerDropdown<String>(
        label: shown,
        value: current,
        items: options,
        onChanged: (v) => _setAnswer(key, v ?? options.first.$1),
      );
    }
    if (type == 'currency' || type == 'number' || type == 'percent') {
      return OrganizerMoneyField(
        label: shown,
        value: value,
        onChanged: (v) => _setAnswer(key, v),
      );
    }
    return OrganizerTextField(
      label: shown,
      value: '${value ?? ''}',
      onChanged: (v) => _setAnswer(key, v),
    );
  }
}
