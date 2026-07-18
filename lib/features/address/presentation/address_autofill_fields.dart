import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../organizer/data/us_states.dart';
import '../../organizer/presentation/organizer_fields.dart';
import '../data/address_repository.dart';

/// Street + ZIP autocomplete with state dropdown (US states).
class AddressAutofillFields extends ConsumerStatefulWidget {
  const AddressAutofillFields({
    super.key,
    required this.data,
    required this.onChanged,
    this.streetKey = 'address',
    this.cityKey = 'city',
    this.stateKey = 'state',
    this.zipKey = 'zip',
    this.apartmentKey = 'apartment',
  });

  final Map<String, dynamic> data;
  final void Function(String key, dynamic value) onChanged;
  final String streetKey;
  final String cityKey;
  final String stateKey;
  final String zipKey;
  final String apartmentKey;

  @override
  ConsumerState<AddressAutofillFields> createState() => _AddressAutofillFieldsState();
}

class _AddressAutofillFieldsState extends ConsumerState<AddressAutofillFields> {
  final _streetCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _streetCtrl.text = '${widget.data[widget.streetKey] ?? ''}';
    _zipCtrl.text = '${widget.data[widget.zipKey] ?? ''}';
  }

  @override
  void didUpdateWidget(covariant AddressAutofillFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    final street = '${widget.data[widget.streetKey] ?? ''}';
    final zip = '${widget.data[widget.zipKey] ?? ''}';
    if (_streetCtrl.text != street) _streetCtrl.text = street;
    if (_zipCtrl.text != zip) _zipCtrl.text = zip;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _streetCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  void _queueSearch(String query) {
    widget.onChanged(widget.streetKey, query);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    setState(() => _loading = true);
    final rows = await ref.read(addressRepositoryProvider).suggest(query);
    if (!mounted) return;
    setState(() {
      _suggestions = rows;
      _loading = false;
    });
  }

  Future<void> _searchZip(String zip) async {
    widget.onChanged(widget.zipKey, zip);
    if (zip.trim().length < 5) return;
    setState(() => _loading = true);
    final rows = await ref.read(addressRepositoryProvider).suggest(zip.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (rows.isEmpty) return;
    _apply(rows.first);
  }

  void _apply(Map<String, dynamic> row) {
    final street = row['street']?.toString() ?? '';
    final city = row['city']?.toString() ?? '';
    final state = row['state']?.toString() ?? '';
    final zip = row['zip']?.toString() ?? '';
    if (street.isNotEmpty) {
      _streetCtrl.text = street;
      widget.onChanged(widget.streetKey, street);
    }
    if (city.isNotEmpty) widget.onChanged(widget.cityKey, city);
    if (state.isNotEmpty) widget.onChanged(widget.stateKey, state);
    if (zip.isNotEmpty) {
      _zipCtrl.text = zip;
      widget.onChanged(widget.zipKey, zip);
    }
    setState(() => _suggestions = const []);
  }

  @override
  Widget build(BuildContext context) {
    final stateValue = widget.data[widget.stateKey]?.toString() ?? '';
    final stateItems = <(String, String)>[
      ('', 'Select state'),
      for (final opt in usStateOptions) (opt.$1, '${opt.$1} — ${opt.$2}'),
    ];
    final validState = stateItems.any((e) => e.$1 == stateValue) ? stateValue : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _streetCtrl,
          decoration: InputDecoration(
            labelText: 'Street address',
            prefixIcon: const Icon(Icons.place_outlined),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          onChanged: _queueSearch,
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final s in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.map_outlined, color: MkgColors.primary),
                    title: Text(
                      s['description']?.toString() ??
                          '${s['street'] ?? ''}, ${s['city'] ?? ''} ${s['state'] ?? ''} ${s['zip'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () => _apply(s),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        OrganizerTextField(
          label: 'Apt / suite',
          value: widget.data[widget.apartmentKey]?.toString() ?? '',
          onChanged: (v) => widget.onChanged(widget.apartmentKey, v),
        ),
        OrganizerTextField(
          label: 'City',
          value: widget.data[widget.cityKey]?.toString() ?? '',
          onChanged: (v) => widget.onChanged(widget.cityKey, v),
        ),
        OrganizerDropdown<String>(
          label: 'State',
          value: validState,
          items: stateItems,
          onChanged: (v) {
            if (v != null) widget.onChanged(widget.stateKey, v);
          },
        ),
        TextField(
          controller: _zipCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'ZIP code',
            helperText: 'Enter ZIP to autofill city/state',
          ),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 450), () => _searchZip(v));
          },
        ),
      ],
    );
  }
}
