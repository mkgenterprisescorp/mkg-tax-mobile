import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<String> saveDocumentBytesLocally({
  required Uint8List bytes,
  required String filename,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
  return file.path;
}
