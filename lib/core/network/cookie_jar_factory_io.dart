import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

Future<CookieJar> createAppCookieJar() async {
  final support = await getApplicationSupportDirectory();
  final cookiePath = '${support.path}/mkgtaxconsultants_cookies';
  await Directory(cookiePath).create(recursive: true);
  return PersistCookieJar(storage: FileStorage(cookiePath));
}
