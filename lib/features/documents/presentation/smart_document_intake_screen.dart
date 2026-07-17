import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mkg_theme.dart';
import '../data/document_intelligence_repository.dart';

/// Skeleton intake UI for smart document upload / OCR verification.
/// Does not call real Adobe credentials or process real taxpayer documents.
class SmartDocumentIntakeScreen extends ConsumerStatefulWidget {
  const SmartDocumentIntakeScreen({super.key});

  @override
  ConsumerState<SmartDocumentIntakeScreen> createState() => _SmartDocumentIntakeScreenState();
}

class _SmartDocumentIntakeScreenState extends ConsumerState<SmartDocumentIntakeScreen> {
  List<Map<String, dynamic>> _types = const [];
  String? _selected;
  String? _healthNote;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(documentIntelligenceRepositoryProvider);
    final types = await repo.documentTypes();
    final health = await repo.extractionHealth();
    if (!mounted) return;
    setState(() {
      _types = types;
      _selected = types.isEmpty ? null : types.first['code']?.toString();
      _healthNote = health == null
          ? 'Extraction status unavailable'
          : 'Provider: ${health['provider']} · real credentials: ${health['real_credentials_enabled']}';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document intake')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Capture W-2 and other tax documents for review. Extracted values stay unverified until you confirm them.',
                  style: TextStyle(color: MkgColors.textGrey),
                ),
                const SizedBox(height: 12),
                Text(_healthNote ?? '', style: const TextStyle(fontSize: 12, color: MkgColors.textGrey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _selected,
                  decoration: const InputDecoration(labelText: 'Document type'),
                  items: [
                    for (final t in _types)
                      DropdownMenuItem(
                        value: t['code']?.toString(),
                        child: Text(t['label']?.toString() ?? t['code']?.toString() ?? ''),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selected = v),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quality tips before upload:\n'
                  '• Move closer and include all four corners.\n'
                  '• Retake blurry images.\n'
                  '• Avoid glare covering part of the document.\n'
                  '• Add remaining pages before continuing.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Upload uses the secure staging document API. Real OCR credentials are not enabled yet.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Continue to secure upload'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExtractionVerificationSkeletonScreen()),
                  ),
                  child: const Text('Review extraction (preview)'),
                ),
              ],
            ),
    );
  }
}

class ExtractionVerificationSkeletonScreen extends StatelessWidget {
  const ExtractionVerificationSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review extracted information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Original document page, bounding boxes, confidence, and accept/edit/reject controls will appear here after server extraction.',
            style: TextStyle(color: MkgColors.textGrey),
          ),
          SizedBox(height: 16),
          ListTile(
            title: Text('Wages (example)'),
            subtitle: Text('Normalized value shown only after verification — never silent autofill of SSN'),
            trailing: Text('High'),
          ),
          ListTile(
            title: Text('Status'),
            subtitle: Text('Review extracted information'),
          ),
        ],
      ),
    );
  }
}
