import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../organizer/data/laravel_organizer_repository.dart';
import '../../organizer/data/organizer_defaults.dart';
import '../../organizer/data/organizer_section_mapper.dart';
import '../data/document_extraction_mapper.dart';
import '../data/document_intelligence_repository.dart';
import '../data/documents_repository.dart';

/// Smart upload → AI extract (portal OpenAI via Laravel) → verify → apply to organizer.
/// Secrets stay on DigitalOcean; Flutter never embeds Stripe/OpenAI/Adobe keys.
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
  bool _busy = false;

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
    final enabled = health?['real_credentials_enabled'] == true;
    final provider = health?['provider']?.toString() ?? 'unavailable';
    setState(() {
      _types = types;
      _selected = _preferType(types);
      _healthNote = health == null
          ? 'Extraction status unavailable'
          : enabled
              ? 'AI extraction ready ($provider). Confirm every value before it enters your organizer.'
              : 'AI extraction bridge not ready yet ($provider). You can still upload documents securely.';
      _loading = false;
    });
  }

  String? _preferType(List<Map<String, dynamic>> types) {
    for (final code in ['w2', '1040', 'prior_return']) {
      if (types.any((t) => t['code']?.toString() == code)) return code;
    }
    return types.isEmpty ? null : types.first['code']?.toString();
  }

  String _categoryForCode(String? code) {
    switch (code) {
      case 'w2':
        return 'w2';
      case '1040':
      case 'prior_return':
        return '1040';
      case '1099_int':
      case '1099_div':
      case '1099_nec':
      case '1099':
        return '1099';
      case 'k1':
        return 'k1';
      case 'identity':
      case 'id':
        return 'id';
      case 'bank':
        return 'bank';
      case 'business_income':
      case 'business':
        return 'business';
      default:
        return 'other';
    }
  }

  String? _hintForCode(String? code) {
    switch (code) {
      case 'w2':
        return 'W-2';
      case '1040':
      case 'prior_return':
        return '1040';
      case 'k1':
        return 'K-1';
      case 'business':
      case 'business_income':
        return 'business_income';
      default:
        if (code?.startsWith('1099') == true) return '1099';
        return null;
    }
  }

  Future<void> _pickUploadExtract() async {
    final tax = ref.read(taxYearProvider);
    await ref.read(taxYearProvider.notifier).refreshWorkspace();
    final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId ?? tax.workspace?.workspaceId;
    if (workspaceId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a tax year workspace before uploading.')),
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final category = _categoryForCode(_selected);
      final uploaded = await ref.read(documentsRepositoryProvider).upload(
            workspaceId: workspaceId,
            category: category,
            file: MultipartFile.fromBytes(bytes, filename: file.name),
          );
      if (uploaded == null) {
        throw StateError('Upload failed');
      }
      final documentId = uploaded['id']?.toString();
      if (documentId == null) throw StateError('Upload missing document id');

      final extract = await ref.read(documentIntelligenceRepositoryProvider).extractDocument(
            documentId: documentId,
            documentTypeHint: _hintForCode(_selected),
            idempotencyKey: 'mobile-ext-$documentId-${DateTime.now().millisecondsSinceEpoch}',
          );
      if (!mounted) return;
      if (extract == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded. Extraction is unavailable right now — a preparer can review it.'),
          ),
        );
        return;
      }

      final extraction = Map<String, dynamic>.from(extract['extraction'] as Map? ?? extract);
      final fieldsRaw = extraction['fields'];
      final fields = <String, dynamic>{};
      if (fieldsRaw is Map) {
        fields.addAll(Map<String, dynamic>.from(fieldsRaw));
      } else if (fieldsRaw is List) {
        for (final row in fieldsRaw.whereType<Map>()) {
          final key = row['field']?.toString() ?? row['organizerPath']?.toString();
          final value = row['normalizedValue'] ?? row['rawValue'] ?? row['value'];
          if (key != null) fields[key] = value;
        }
      }

      final docType = extraction['document_type']?.toString() ?? _hintForCode(_selected) ?? 'other';
      final applied = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ExtractionVerificationScreen(
            documentId: documentId,
            documentType: docType,
            fields: fields,
            confidence: (extraction['confidence'] as num?)?.toDouble(),
            workspaceId: workspaceId,
          ),
        ),
      );
      if (!mounted) return;
      if (applied == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verified fields were applied to your tax organizer.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMapper.map(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart document intake')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Upload a W-2 or Form 1040. AI extracts visible fields for your review — nothing is silent-autofilled into your return.',
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
                  onChanged: _busy ? null : (v) => setState(() => _selected = v),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quality tips before upload:\n'
                  '• Include all four corners.\n'
                  '• Retake blurry images.\n'
                  '• Avoid glare covering boxes.\n'
                  '• Prefer a multi-page PDF when available.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _pickUploadExtract,
                  child: Text(_busy ? 'Working…' : 'Upload & extract'),
                ),
              ],
            ),
    );
  }
}

class ExtractionVerificationScreen extends ConsumerStatefulWidget {
  const ExtractionVerificationScreen({
    super.key,
    required this.documentId,
    required this.documentType,
    required this.fields,
    required this.workspaceId,
    this.confidence,
  });

  final String documentId;
  final String documentType;
  final Map<String, dynamic> fields;
  final String workspaceId;
  final double? confidence;

  @override
  ConsumerState<ExtractionVerificationScreen> createState() => _ExtractionVerificationScreenState();
}

class _ExtractionVerificationScreenState extends ConsumerState<ExtractionVerificationScreen> {
  late List<Map<String, dynamic>> _rows;
  bool _saving = false;
  final _mapper = const DocumentExtractionMapper();

  @override
  void initState() {
    super.initState();
    _rows = _mapper.reviewRows(widget.fields);
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      final accepted = <String, dynamic>{};
      for (final row in _rows) {
        if (row['accepted'] == true && row['sensitive'] != true) {
          accepted[row['key'].toString()] = row['value'];
        }
      }
      final orgRepo = ref.read(laravelOrganizerRepositoryProvider);
      final existing = await orgRepo.show(widget.workspaceId);
      final defaults = await OrganizerDefaults.load();
      final year = ref.read(taxYearProvider).workspace?.taxYear ??
          ref.read(taxYearProvider).selectedYear ??
          DateTime.now().year - 1;
      final organizer = OrganizerSectionMapper.hydrateFromServer(
        defaults: defaults,
        organizer: existing,
        fallbackYear: year,
      );

      final patched = _mapper.applyToOrganizer(
        organizer: organizer,
        documentType: widget.documentType,
        fields: accepted,
      );

      await orgRepo.saveAllSections(
        workspaceId: widget.workspaceId,
        data: patched,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMapper.map(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confidence = widget.confidence;
    return Scaffold(
      appBar: AppBar(title: const Text('Review extracted information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Document: ${widget.documentType}'
            '${confidence != null ? ' · confidence ${(confidence * 100).round()}%' : ''}',
            style: const TextStyle(color: MkgColors.textGrey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accept only values you can see on the document. Taxpayer ID numbers are never silent-autofilled.',
            style: TextStyle(color: MkgColors.textGrey),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _rows.length; i++)
            CheckboxListTile(
              value: _rows[i]['accepted'] == true,
              onChanged: _rows[i]['sensitive'] == true
                  ? null
                  : (v) => setState(() => _rows[i]['accepted'] = v ?? false),
              title: Text(_rows[i]['label']?.toString() ?? _rows[i]['key']?.toString() ?? ''),
              subtitle: Text(
                _rows[i]['sensitive'] == true
                    ? 'Sensitive identifier — enter manually in the organizer if needed'
                    : (_rows[i]['value']?.toString() ?? ''),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _apply,
            child: Text(_saving ? 'Applying…' : 'Apply accepted fields to organizer'),
          ),
        ],
      ),
    );
  }
}

/// Kept for existing widget tests — policy reminder UI without provider jargon.
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
