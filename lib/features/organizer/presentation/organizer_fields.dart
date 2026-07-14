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

class OrganizerTextField extends StatelessWidget {
  const OrganizerTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        obscureText: obscure,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

class OrganizerMoneyField extends StatelessWidget {
  const OrganizerMoneyField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final dynamic value;
  final ValueChanged<num> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value == null || value == 0 ? '' : '$value';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: text,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: label, prefixText: '\$ '),
        onChanged: (v) => onChanged(num.tryParse(v) ?? 0),
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

/// Renders scalar fields from a nested map (entity forms / schedule C).
class NestedMapEditor extends StatelessWidget {
  const NestedMapEditor({
    super.key,
    required this.data,
    required this.onChanged,
    this.moneyKeys = const {},
    this.excludeKeys = const {},
    this.onlyKeys,
  });

  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Set<String> moneyKeys;
  final Set<String> excludeKeys;
  final List<String>? onlyKeys;

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
        label: humanizeKey(key),
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
        key.toLowerCase().contains('comp');
    if (treatMoney && value is! String) {
      return OrganizerMoneyField(
        label: humanizeKey(key),
        value: value,
        onChanged: (v) {
          final next = Map<String, dynamic>.from(data)..[key] = v;
          onChanged(next);
        },
      );
    }
    return OrganizerTextField(
      label: humanizeKey(key),
      value: '${value ?? ''}',
      onChanged: (v) {
        final next = Map<String, dynamic>.from(data)..[key] = v;
        onChanged(next);
      },
    );
  }
}
