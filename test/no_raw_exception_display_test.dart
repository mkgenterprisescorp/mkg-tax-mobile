import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repository-wide static check: no lib/ source file may interpolate a
/// caught exception's default string form directly into user-facing text
/// (`'$e'`, `'${e}'`, `'$error'`, `'${error}'`). Every API/network failure
/// must be routed through ApiErrorMapper (or read a value that is itself
/// already ApiErrorMapper-safe, like AuthException.message) before display.
///
/// This is a lexical scan, not a type-aware one — it does not understand
/// which local variable is actually a caught exception. It is deliberately
/// scoped to the `$e`/`$error` bare-interpolation spelling rather than
/// `e.toString()`, because `e`/`error` are also common non-exception
/// identifiers (e.g. list-map lambda parameters) and a `.toString()` scan
/// produces false positives on those. The bare-interpolation spelling this
/// test forbids had zero legitimate non-exception uses in this codebase at
/// the time this test was written (see the fresh-review remediation that
/// introduced it) — if a future legitimate `$e`/`$error` use is added, name
/// the variable something else rather than loosening this check.
void main() {
  test('no lib/ file interpolates a bare caught-exception variable into user-facing text', () {
    final libDir = Directory('lib');
    final forbidden = <RegExp>[
      RegExp(r"\$e\b"),
      RegExp(r"\$\{e\}"),
      RegExp(r"\$error\b"),
      RegExp(r"\$\{error\}"),
    ];

    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalizedPath = entity.path.replaceAll('\\', '/');
      // The mapper's own doc comment references this spelling as the thing
      // NOT to do — that reference is documentation, not a violation.
      if (normalizedPath.endsWith('core/network/api_error_mapper.dart')) continue;

      final content = entity.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.hasMatch(content)) {
          offenders.add('$normalizedPath (matched ${pattern.pattern})');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Raw exception text must be routed through ApiErrorMapper.map(e) '
          '(or an equally safe centralized mapper) before it reaches a user-facing '
          'widget. Offending files:\n${offenders.join('\n')}',
    );
  });
}
