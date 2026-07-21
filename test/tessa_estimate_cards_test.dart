import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mkg_tax_mobile/features/tessa/presentation/tessa_estimate_cards.dart';

void main() {
  Widget wrap(Widget child) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(body: SingleChildScrollView(child: child)),
        ),
        GoRoute(path: '/organizer/form-1040', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/refund-advance/estimate', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/ca-540', builder: (_, __) => const SizedBox()),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('Form 1040 card shows Laravel credits and deductions', (tester) async {
    await tester.pumpWidget(
      wrap(
        TessaEstimateCards.forAction(
          type: 'run_federal_1040_preview',
          ok: true,
          summary: 'Form 1040 intake preview ready',
          payload: {
            'form': {
              'filing_status': 'single',
              'tax_year': 2025,
              'taxpayer': {'first_name': 'Ada', 'last_name': 'Lovelace'},
              'income': {'wages_line1': 80000, 'tax_withheld': 12000},
              'deductions': {'standard': 14600, 'type': 'standard'},
              'credits': {'child_tax_credit': 2000},
            },
            'refund_estimate': {
              'agi': 80000,
              'deduction': 14600,
              'taxableIncome': 65400,
              'totalTax': 9500,
              'totalCredits': 2000,
              'refund': 4500,
              'childTaxCredit': 2000,
            },
          },
        ),
      ),
    );

    expect(find.text('Form 1040 preview'), findsOneWidget);
    expect(find.textContaining('Ada Lovelace'), findsOneWidget);
    expect(find.textContaining('Child tax credit'), findsWidgets);
    expect(find.text('Open full Form 1040 preview'), findsOneWidget);
    // Display-only money from payload — no Flutter math asserted.
    expect(find.textContaining('4500'), findsWidgets);
  });

  testWidgets('CA 540 card shows line estimates from Laravel payload', (tester) async {
    await tester.pumpWidget(
      wrap(
        TessaEstimateCards.forAction(
          type: 'run_ca540_estimate',
          ok: true,
          summary: 'CA Form 540 estimate loaded',
          payload: {
            'lines': {
              'line_13_federal_agi': 80000,
              'line_17_ca_agi': 78000,
              'line_19_taxable_income': 60000,
              'line_31_ca_tax': 2100,
              'refund_or_owed': 400,
            },
          },
        ),
      ),
    );

    expect(find.text('CA Form 540 estimate'), findsOneWidget);
    expect(find.text('Open full CA Form 540'), findsOneWidget);
    expect(find.textContaining('2100'), findsWidgets);
  });
}
