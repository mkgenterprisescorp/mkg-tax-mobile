import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/mkg_theme.dart';

String humanizeKey(String key) {
  final spaced = key
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'\b([a-z])'), (m) => m[1]!.toUpperCase());
  return spaced;
}

class OrganizerSection extends StatelessWidget {
  const OrganizerSection({super.key, required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Text field that keeps typing local and only notifies the parent on a short debounce
/// (or blur / dispose). Prevents full Organizer rebuilds on every keystroke.
class OrganizerTextField extends StatefulWidget {
  const OrganizerTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.commitDebounce = const Duration(milliseconds: 280),
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final Duration commitDebounce;

  @override
  State<OrganizerTextField> createState() => _OrganizerTextFieldState();
}

class _OrganizerTextFieldState extends State<OrganizerTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  Timer? _debounce;
  String _lastCommitted = '';

  @override
  void initState() {
    super.initState();
    _lastCommitted = widget.value;
    _controller = TextEditingController(text: widget.value);
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant OrganizerTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External autofill / prep-type change — sync only when not editing.
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
      _lastCommitted = widget.value;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _commit(force: true);
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      _commit(force: true);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.commitDebounce, () => _commit(force: false));
  }

  void _commit({required bool force}) {
    _debounce?.cancel();
    final text = _controller.text;
    if (!force && text == _lastCommitted) return;
    if (text == _lastCommitted) return;
    _lastCommitted = text;
    widget.onChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _controller,
        focusNode: _focus,
        obscureText: widget.obscure,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: _onChanged,
        onEditingComplete: () => _commit(force: true),
        onFieldSubmitted: (_) => _commit(force: true),
      ),
    );
  }
}

class OrganizerMoneyField extends StatefulWidget {
  const OrganizerMoneyField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.commitDebounce = const Duration(milliseconds: 280),
  });

  final String label;
  final dynamic value;
  final ValueChanged<num> onChanged;
  final Duration commitDebounce;

  @override
  State<OrganizerMoneyField> createState() => _OrganizerMoneyFieldState();
}

class _OrganizerMoneyFieldState extends State<OrganizerMoneyField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  Timer? _debounce;
  num _lastCommitted = 0;

  static String _format(dynamic value) =>
      value == null || value == 0 ? '' : '$value';

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _lastCommitted = v is num ? v : (num.tryParse('$v') ?? 0);
    _controller = TextEditingController(text: _format(v));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant OrganizerMoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus) {
      final next = _format(widget.value);
      if (next != _controller.text) {
        _controller.text = next;
        _lastCommitted = widget.value is num
            ? widget.value as num
            : (num.tryParse('${widget.value}') ?? 0);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _commit(force: true);
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit(force: true);
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(widget.commitDebounce, () => _commit(force: false));
  }

  void _commit({required bool force}) {
    _debounce?.cancel();
    final parsed = num.tryParse(_controller.text) ?? 0;
    if (!force && parsed == _lastCommitted) return;
    if (parsed == _lastCommitted) return;
    _lastCommitted = parsed;
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: widget.label, prefixText: '\$ '),
        onChanged: _onChanged,
        onEditingComplete: () => _commit(force: true),
        onFieldSubmitted: (_) => _commit(force: true),
      ),
    );
  }
}

class OrganizerDropdown<T> extends StatelessWidget {
  const OrganizerDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<T>(
        // Rebuild when parent value changes (e.g. address/ZIP autofill).
        key: ValueKey<Object?>('dd-$label-$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in items)
            DropdownMenuItem(value: item.$1, child: Text(item.$2, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class OrganizerCheckbox extends StatelessWidget {
  const OrganizerCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      activeColor: MkgColors.primary,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

/// Collapsible section that does not keep children alive when closed (faster State step).
class OrganizerLazyExpansion extends StatelessWidget {
  const OrganizerLazyExpansion({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: false,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Renders scalar fields from a nested map (entity forms / schedule C).
class NestedMapEditor extends StatelessWidget {
  const NestedMapEditor({
    super.key,
    required this.data,
    required this.onChanged,
    this.moneyKeys = const {},
    this.excludeKeys = const {},
    this.onlyKeys,
    this.labels = const {},
  });

  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Set<String> moneyKeys;
  final Set<String> excludeKeys;
  final List<String>? onlyKeys;
  /// Optional Form 1040 / schedule line labels keyed by schema field.
  final Map<String, String> labels;

  String _label(String key) => labels[key] ?? humanizeKey(key);

  @override
  Widget build(BuildContext context) {
    final keys = onlyKeys ?? data.keys.where((k) => !excludeKeys.contains(k)).toList();
    return Column(
      children: [
        for (final key in keys)
          if (data[key] is! Map && data[key] is! List)
            _fieldFor(key, data[key]),
      ],
    );
  }

  Widget _fieldFor(String key, dynamic value) {
    if (value is bool) {
      return OrganizerCheckbox(
        label: _label(key),
        value: value,
        onChanged: (v) {
          final next = Map<String, dynamic>.from(data)..[key] = v;
          onChanged(next);
        },
      );
    }
    final treatMoney = moneyKeys.contains(key) ||
        value is num ||
        key.toLowerCase().contains('income') ||
        key.toLowerCase().contains('expense') ||
        key.toLowerCase().contains('receipt') ||
        key.toLowerCase().contains('wage') ||
        key.toLowerCase().contains('tax') ||
        key.toLowerCase().contains('deduction') ||
        key.toLowerCase().contains('asset') ||
        key.toLowerCase().contains('liabilit') ||
        key.toLowerCase().contains('payment') ||
        key.toLowerCase().contains('amount') ||
        key.toLowerCase().contains('gross') ||
        key.toLowerCase().contains('rent') ||
        key.toLowerCase().contains('interest') ||
        key.toLowerCase().contains('dividend') ||
        key.toLowerCase().contains('depreciat') ||
        key.toLowerCase().contains('comp') ||
        key.toLowerCase().contains('credit');
    if (treatMoney && value is! String) {
      return OrganizerMoneyField(
        label: _label(key),
        value: value,
        onChanged: (v) {
          final next = Map<String, dynamic>.from(data)..[key] = v;
          onChanged(next);
        },
      );
    }
    return OrganizerTextField(
      label: _label(key),
      value: '${value ?? ''}',
      onChanged: (v) {
        final next = Map<String, dynamic>.from(data)..[key] = v;
        onChanged(next);
      },
    );
  }
}
