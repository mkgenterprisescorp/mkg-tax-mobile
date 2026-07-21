import 'package:flutter_test/flutter_test.dart';

/// Mirrors Laravel WorkflowTriggerBuilder LLC/Corp offset keys for client parity checks.
const kLlcCorpNoticeOffsetKeys = ['3w', '2w', '1w', '3d', '48h', '24h', '8h'];

bool isLlcOrCorporationPrepType(String? prepType) =>
    prepType == 'form1065' || prepType == 'form1120S' || prepType == 'form1120';

void main() {
  test('LLC/Corp dense notice cadence matches portal/Laravel SoT', () {
    expect(kLlcCorpNoticeOffsetKeys, ['3w', '2w', '1w', '3d', '48h', '24h', '8h']);
  });

  test('detects LLC and Corporation prep types', () {
    expect(isLlcOrCorporationPrepType('form1065'), isTrue);
    expect(isLlcOrCorporationPrepType('form1120'), isTrue);
    expect(isLlcOrCorporationPrepType('personal'), isFalse);
  });
}
