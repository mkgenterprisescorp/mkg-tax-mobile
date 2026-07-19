import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/config/app_config.dart';

void main() {
  group('AppConfig.validateUrl', () {
    test('accepts the authoritative staging host', () {
      expect(
        () => AppConfig.validateUrl('https://app.mkgtaxconsultants.com/api/v1'),
        returnsNormally,
      );
    });

    test('rejects an empty value with no default fallback', () {
      expect(
        () => AppConfig.validateUrl(''),
        throwsA(isA<AppConfigError>().having((e) => e.message, 'message', contains('not supplied'))),
      );
    });

    test('rejects a non-/api/v1 host such as the web portal apex', () {
      expect(
        () => AppConfig.validateUrl('https://mkgtaxconsultants.com'),
        throwsA(isA<AppConfigError>().having((e) => e.message, 'message', contains('/api/v1'))),
      );
    });

    test('rejects a malformed URL', () {
      expect(
        () => AppConfig.validateUrl('not a url'),
        throwsA(isA<AppConfigError>()),
      );
    });

    test('rejects plain http by default', () {
      expect(
        () => AppConfig.validateUrl('http://app.mkgtaxconsultants.com/api/v1'),
        throwsA(isA<AppConfigError>().having((e) => e.message, 'message', contains('https'))),
      );
    });

    test('allows plain http only for permitted local-dev hosts with the flag set', () {
      expect(
        () => AppConfig.validateUrl('http://10.0.2.2:8000/api/v1', allowInsecureLocalDev: true),
        returnsNormally,
      );
      expect(
        () => AppConfig.validateUrl('http://10.0.2.2:8000/api/v1'),
        throwsA(isA<AppConfigError>()),
      );
    });

    test('rejects plain http for a non-local host even with the flag set', () {
      expect(
        () => AppConfig.validateUrl('http://app.mkgtaxconsultants.com/api/v1', allowInsecureLocalDev: true),
        throwsA(isA<AppConfigError>()),
      );
    });

    test('rejects a duplicated /api/v1 path segment', () {
      expect(
        () => AppConfig.validateUrl('https://app.mkgtaxconsultants.com/api/v1/api/v1'),
        throwsA(isA<AppConfigError>().having((e) => e.message, 'message', contains('duplicated'))),
      );
    });

    test('rejects a URL missing the /api/v1 suffix entirely', () {
      expect(
        () => AppConfig.validateUrl('https://app.mkgtaxconsultants.com'),
        throwsA(isA<AppConfigError>().having((e) => e.message, 'message', contains('/api/v1'))),
      );
    });
  });

  group('AppConfig derived getters', () {
    test('usesLaravelAuth is true for a valid /api/v1 root', () {
      // apiRoot/apiBaseUrl are compile-time consts fixed at test-binary
      // build time; this suite doesn't override them, so we only assert
      // the getter's logic is host-string-based and not a hardcoded guess.
      expect(AppConfig.usesLaravelAuth, AppConfig.apiRoot.toLowerCase().contains('/api/v1'));
    });

    test('paymentsWebUrl targets web portal apex and never financemkgtax.com', () {
      expect(AppConfig.paymentsWebUrl, contains('mkgtaxconsultants.com'));
      expect(AppConfig.paymentsWebUrl, contains('/payments'));
      expect(AppConfig.paymentsWebUrl.contains('financemkgtax.com'), isFalse);
      // Payments stay on the portal; mobile website is a different host.
      expect(AppConfig.paymentsWebUrl.contains('finance.mkgtaxconsultants.com'), isFalse);
    });

    test('webBaseUrl defaults to finance.mkgtaxconsultants.com mobile website', () {
      expect(AppConfig.canonicalMobileWebHost, 'finance.mkgtaxconsultants.com');
      expect(AppConfig.webRoot, contains('finance.mkgtaxconsultants.com'));
      expect(AppConfig.portalRoot, 'https://mkgtaxconsultants.com');
      expect(AppConfig.canonicalPortalHost, 'mkgtaxconsultants.com');
      expect(AppConfig.canonicalMobileWebHost, isNot(AppConfig.canonicalPortalHost));
    });

    test('rewriteLegacyPortalUri remaps financemkgtax.com payments deep links', () {
      final rewritten = AppConfig.rewriteLegacyPortalUri(
        Uri.parse('https://financemkgtax.com/payments'),
      );
      expect(rewritten.host, 'mkgtaxconsultants.com');
      expect(rewritten.path, '/payments');
      expect(rewritten.scheme, 'https');
    });

    test('rewriteLegacyPortalUri leaves Stripe checkout hosts alone', () {
      final stripe = Uri.parse('https://checkout.stripe.com/c/pay/cs_test_123');
      expect(AppConfig.rewriteLegacyPortalUri(stripe), stripe);
    });
  });
}
