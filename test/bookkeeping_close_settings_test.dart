import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/bookkeeping/data/bookkeeping_close_settings.dart';

void main() {
  test('monthly close storage key is year-month scoped', () {
    expect(
      BookkeepingCloseSettings.storageKeyFor(DateTime(2026, 7, 18)),
      'bookkeeping_close_2026_07',
    );
  });

  test('checklist includes intake, statements, and review', () {
    expect(
      BookkeepingCloseSettings.checklistIds,
      containsAll(['intake', 'bank_statements', 'receipts', 'review']),
    );
  });
}
