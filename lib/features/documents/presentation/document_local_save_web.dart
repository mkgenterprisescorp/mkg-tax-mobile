import 'dart:typed_data';

/// Browser builds do not write to a local filesystem; callers should open the
/// portal vault instead. This stub keeps the conditional import API stable.
Future<String> saveDocumentBytesLocally({
  required Uint8List bytes,
  required String filename,
}) async {
  throw UnsupportedError('Local document save is not available on web ($filename, ${bytes.length} bytes).');
}
