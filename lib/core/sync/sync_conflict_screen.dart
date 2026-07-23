import 'package:flutter/material.dart';

import '../theme/mkg_theme.dart';
import '../widgets/mkg_widgets.dart';
import 'sync_models.dart';

enum SyncConflictResolution { keepServer, retryWithServerVersion }

class SyncConflictScreen extends StatelessWidget {
  const SyncConflictScreen({super.key, required this.conflict});

  final SyncConflict conflict;

  @override
  Widget build(BuildContext context) {
    final fields = conflict.fields;
    return Scaffold(
      appBar: AppBar(title: const Text('Review changes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const MkgErrorBanner(
            message:
                'This information changed in the client portal or on another device.',
          ),
          const SizedBox(height: 16),
          const SectionHeader('Field conflicts'),
          for (final field in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MkgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(field.path),
                      style: const TextStyle(
                        color: MkgColors.dark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ValueRow(label: 'Server', value: field.serverValue),
                    const Divider(height: 20),
                    _ValueRow(label: 'Your change', value: field.localValue),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(SyncConflictResolution.retryWithServerVersion),
            child: const Text('Retry with server version'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pop(SyncConflictResolution.keepServer),
            child: const Text('Keep server values'),
          ),
        ],
      ),
    );
  }

  String _label(String path) {
    return path
        .split('.')
        .where((part) => part.isNotEmpty)
        .map((part) => part.replaceAll('_', ' '))
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' / ');
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(
              color: MkgColors.textGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _display(value),
            style: const TextStyle(color: MkgColors.dark),
          ),
        ),
      ],
    );
  }

  String _display(Object? value) {
    if (value == null || '$value'.isEmpty) return 'Blank';
    return '$value';
  }
}
