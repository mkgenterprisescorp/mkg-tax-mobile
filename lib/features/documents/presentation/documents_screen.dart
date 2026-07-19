import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/documents_repository.dart';

const _docTypes = <(String, String)>[
  ('w2', 'W-2'),
  ('1099', '1099'),
  ('id', 'Photo ID'),
  ('prior_return', 'Prior year return'),
  ('bank', 'Bank statement'),
  ('credit_card', 'Credit card statement'),
  ('receipt', 'Receipt / invoice'),
  ('business', 'Business records'),
  ('other', 'Other'),
];

/// Year-scoped document vault for personal + business filings.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  List<Map<String, dynamic>> _docs = const [];
  dynamic _returnId;
  bool _loading = true;
  bool _uploading = false;
  String _docType = 'w2';
  String? _error;
  int? _boundYear;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final year = ref.read(taxYearProvider).selectedYear ?? ref.read(taxYearProvider).currentFilingYear;
    if (year != null && year != _boundYear && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tax = ref.read(taxYearProvider);
      final year = tax.selectedYear ?? tax.currentFilingYear ?? DateTime.now().year - 1;

      if (AppConfig.usesLaravelAuth) {
        await ref.read(taxYearProvider.notifier).refreshWorkspace();
        final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
        final docs = workspaceId == null
            ? <Map<String, dynamic>>[]
            : await ref.read(documentsRepositoryProvider).list(workspaceId);
        if (!mounted) return;
        setState(() {
          _boundYear = year;
          _returnId = workspaceId;
          _docs = docs;
          _loading = false;
        });
        return;
      }

      final portal = ref.read(portalRepositoryProvider);
      final row = await portal.getOrCreateReturnForYear(year);
      final id = row['id'];
      final docs = id == null ? <Map<String, dynamic>>[] : await portal.listDocuments(id);
      if (!mounted) return;
      setState(() {
        _boundYear = year;
        _returnId = id;
        _docs = docs;
        _loading = false;
      });
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorMapper.map(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUpload() async {
    if (_returnId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tax-year workspace / return for this year yet.')),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _uploading = true);
    try {
      if (AppConfig.usesLaravelAuth) {
        final category = _docType == 'prior_return' ? 'other' : _docType;
        await ref.read(documentsRepositoryProvider).upload(
              workspaceId: _returnId.toString(),
              category: category,
              file: await MultipartFile.fromFile(path, filename: path.split('/').last),
            );
      } else {
        await ref.read(portalRepositoryProvider).uploadDocument(
              file: File(path),
              taxReturnId: _returnId,
              type: _docType,
            );
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_docTypes.firstWhere((e) => e.$1 == _docType).$2} uploaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorMapper.map(e))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _download(Map<String, dynamic> d) async {
    final id = d['id'];
    if (id == null) return;
    try {
      if (AppConfig.usesLaravelAuth) {
        final url = await ref.read(documentsRepositoryProvider).signedDownloadUrl(id.toString());
        if (url == null) throw Exception('No signed download URL');
        // Open signed URL; do not log query secrets.
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }
      final bytes = await ref.read(portalRepositoryProvider).downloadDocumentBytes(id);
      final dir = await getTemporaryDirectory();
      final name = (d['originalName'] ?? d['original_filename'] ?? d['filename'] ?? 'document-$id')
          .toString();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
      await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      final uri = Uri.parse('${AppConfig.portalRoot}/documents');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open web vault to finish download (OTP may apply). ${ApiErrorMapper.map(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taxYearProvider, (prev, next) {
      if (prev?.selectedYear != next.selectedYear) {
        _load();
      }
    });
    final year = ref.watch(taxYearProvider).selectedYear ??
        ref.watch(taxYearProvider).currentFilingYear ??
        DateTime.now().year - 1;

    return Column(
      children: [
        const TaxYearSelectorBar(dense: true),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Document vault · Tax year $year · Return #${_returnId ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload W-2s, 1099s, ID, and business records for this filing year.',
                  style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _docType,
                  decoration: const InputDecoration(labelText: 'Document type'),
                  items: [
                    for (final t in _docTypes)
                      DropdownMenuItem(value: t.$1, child: Text(t.$2)),
                  ],
                  onChanged: (v) => setState(() => _docType = v ?? 'other'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_uploading ? 'Uploading…' : 'Upload document'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/documents/smart-intake'),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('W-2 / smart document intake'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/organizer'),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Continue Tax Organizer'),
                ),
                const SectionHeader('Uploaded files'),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: MkgColors.red),
                      title: Text(_error!),
                      trailing: TextButton(onPressed: _load, child: const Text('Retry')),
                    ),
                  )
                else if (_docs.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.folder_open_outlined),
                      title: Text('No documents yet'),
                      subtitle: Text('Add W-2s, 1099s, ID, prior returns, or business records.'),
                    ),
                  )
                else
                  for (final d in _docs)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          (d['type']?.toString().toLowerCase().contains('w2') ?? false)
                              ? Icons.badge_outlined
                              : Icons.description_outlined,
                          color: MkgColors.primary,
                        ),
                        title: Text(
                          (d['originalName'] ?? d['filename'] ?? d['name'] ?? 'Document').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('Type: ${(d['type'] ?? 'other')} · ID ${(d['id'] ?? '—')}'),
                        trailing: IconButton(
                          tooltip: 'Download',
                          onPressed: () => _download(d),
                          icon: const Icon(Icons.download_outlined),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
