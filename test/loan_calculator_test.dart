import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/refund_advance/data/loan_calculator.dart';

void main() {
  test('zero-APR tiers for \$250/\$500/\$1000', () {
    for (final amount in [250, 500, 1000]) {
      final q = LoanCalculator.calculate(amount);
      expect(q['apr'], 0);
      expect(q['interest'], 0);
      expect(q['principal'], amount);
      expect(q['totalRepayment'], amount);
    }
  });

  test('50% of \$7500 (\$3750) uses 36% APR with 29-day finance charge', () {
    final q = LoanCalculator.calculate(3750);
    expect(q['apr'], 36);
    expect(q['principal'], 3750);
    expect(q['interest'], 107.26);
    expect(q['totalRepayment'], 3857.26);
    expect(q['lateFee'], 15);
    expect(q['term_days'], 29);
  });
}
