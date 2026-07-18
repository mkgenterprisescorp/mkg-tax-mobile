/// Pathward/MKG loan estimate math — mirrors Laravel `LoanCalculator`
/// and financemkgtaxpro `calculateLoan()`.
class LoanCalculator {
  static const termDaysDefault = 29;
  static const zeroAprTiers = {250, 500, 1000};
  static const lateFee = 15.0;
  static const creditor = 'Pathward, N.A., Member FDIC';
  static const product = 'Tax Refund Advance';

  static Map<String, dynamic> calculate(num amount, {int termDays = termDaysDefault}) {
    final principal = (amount < 0 ? 0 : amount).toDouble();
    final days = termDays.clamp(1, 90);
    final roundedPrincipal = double.parse(principal.toStringAsFixed(2));
    final isZeroApr = zeroAprTiers.contains(roundedPrincipal.round());
    final apr = isZeroApr ? 0.0 : 36.0;
    final dailyRate = (apr / 100) / 365;
    final interest = double.parse((roundedPrincipal * dailyRate * days).toStringAsFixed(2));
    return {
      'principal': roundedPrincipal,
      'interest': interest,
      'totalRepayment': double.parse((roundedPrincipal + interest).toStringAsFixed(2)),
      'apr': apr,
      'dailyRate': double.parse((dailyRate * 100).toStringAsFixed(4)),
      'lateFee': lateFee,
      'term_days': days,
      'creditor': creditor,
      'product': product,
      'source': 'local',
    };
  }
}
