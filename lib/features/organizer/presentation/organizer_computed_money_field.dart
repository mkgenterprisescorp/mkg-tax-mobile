import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mkg_theme.dart';
import '../data/computed_field_policy.dart';

/// Auto-calculated money field with override warning / professional unlock.
class OrganizerComputedMoneyField extends StatefulWidget {
  const OrganizerComputedMoneyField({
    super.key,
    required this.policy,
    required this.computedValue,
    required this.storedValue,
    required this.isOverridden,
    required this.isProfessional,
    required this.onApplyComputed,
    required this.onManualValue,
    required this.onMarkOverridden,
    required this.onClearOverride,
  });

  final ComputedFieldPolicy policy;
  final num computedValue;
  final dynamic storedValue;
  final bool isOverridden;
  final bool isProfessional;
  final VoidCallback onApplyComputed;
  final ValueChanged<num> onManualValue;
  final VoidCallback onMarkOverridden;
  final VoidCallback onClearOverride;

  @override
  State<OrganizerComputedMoneyField> createState() => _OrganizerComputedMoneyFieldState();
}

class _OrganizerComputedMoneyFieldState extends State<OrganizerComputedMoneyField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  num get _display {
    if (widget.isOverridden) {
      if (widget.storedValue is num) return widget.storedValue as num;
      return num.tryParse('${widget.storedValue}') ?? widget.computedValue;
    }
    return widget.computedValue;
  }

  bool get _locked {
    if (widget.isOverridden) return false;
    return true;
  }

  static String _fmt(num v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _fmt(_display));
  }

  @override
  void didUpdateWidget(covariant OrganizerComputedMoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _fmt(_display);
    if (next != _controller.text) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestEdit() async {
    if (widget.isOverridden) return;
    final policy = widget.policy;
    final isPro = widget.isProfessional;

    if (policy.lockLevel == ComputedLockLevel.professionalOnly && !isPro) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(policy.guidance.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(policy.guidance.body),
                const SizedBox(height: 12),
                const Text(
                  'Locked for consumer accounts. A tax professional must unlock this field after due diligence.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (policy.guidance.checklist.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final item in policy.guidance.checklist)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $item'),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            if (policy.guidance.officialUrl != null)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(policy.guidance.officialUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(policy.guidance.officialLabel ?? 'Open guidance'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPro && policy.lockLevel == ComputedLockLevel.professionalOnly
              ? 'Professional unlock — ${policy.label}'
              : policy.guidance.title,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(policy.guidance.body),
              if (policy.formLine != null) ...[
                const SizedBox(height: 8),
                Text(policy.formLine!, style: const TextStyle(color: MkgColors.textGrey)),
              ],
              Text(
                '\nCalculated: \$${_fmt(widget.computedValue).isEmpty ? '0' : _fmt(widget.computedValue)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (policy.guidance.checklist.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Due diligence checklist', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                for (final item in policy.guidance.checklist)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $item'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          if (policy.guidance.officialUrl != null)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(policy.guidance.officialUrl!),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(policy.guidance.officialLabel ?? 'Knowledge base'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep auto')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPro ? 'Unlock & edit' : 'Override'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onMarkOverridden();
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      widget.onManualValue(num.tryParse(raw) ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isOverridden
        ? '${widget.policy.label} (manual override)'
        : '${widget.policy.label} (auto)';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _controller,
            readOnly: _locked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: label,
              prefixText: '\$ ',
              suffixIcon: Icon(
                widget.isOverridden
                    ? Icons.edit
                    : (widget.policy.lockLevel == ComputedLockLevel.professionalOnly
                        ? Icons.lock_outline
                        : Icons.auto_awesome),
                color: MkgColors.primary,
                size: 20,
              ),
            ),
            onTap: _locked ? _requestEdit : null,
            onChanged: _locked ? null : _onChanged,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                if (widget.isOverridden)
                  TextButton.icon(
                    onPressed: () {
                      widget.onClearOverride();
                      widget.onApplyComputed();
                    },
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Restore auto calculation'),
                  )
                else
                  TextButton.icon(
                    onPressed: _requestEdit,
                    icon: Icon(
                      widget.policy.lockLevel == ComputedLockLevel.professionalOnly
                          ? Icons.lock_open
                          : Icons.edit_outlined,
                      size: 16,
                    ),
                    label: Text(
                      widget.policy.lockLevel == ComputedLockLevel.professionalOnly
                          ? (widget.isProfessional ? 'Pro unlock' : 'Why locked?')
                          : 'Override…',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
