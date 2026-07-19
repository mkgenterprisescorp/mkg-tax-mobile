import 'package:cookie_jar/cookie_jar.dart';

/// Browser builds keep Sanctum bearer tokens in secure storage; cookie jar is
/// in-memory only (no dart:io PersistCookieJar).
Future<CookieJar> createAppCookieJar() async => CookieJar();
