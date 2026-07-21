import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/rollout_regions.dart';
import 'package:mkg_tax_mobile/features/organizer/data/us_states.dart';
import 'package:mkg_tax_mobile/features/returns/data/state_return_picker_catalog.dart';

void main() {
  test('picker includes all US states + DC across regions 1-6', () {
    final sections = buildStateReturnPickerSections();
    expect(sections.length, 6);
    expect(
      sections.map((s) => s.region.id).toList(),
      ['1', '2', '3', '4', '5', '6'],
    );

    final rows = buildStateReturnPickerRows();
    expect(rows.length, usStateOptions.length);
    expect(rows.length, 51);

    final codes = rows.map((r) => r.code).toSet();
    expect(codes.length, 51);
    for (final opt in usStateOptions) {
      expect(codes.contains(opt.$1), isTrue, reason: 'missing ${opt.$1}');
    }

    // Region membership matches rollout tables.
    for (final region in rolloutRegions) {
      final section = sections.firstWhere((s) => s.region.id == region.id);
      expect(section.rows.map((r) => r.code).toList(), region.states);
    }
  });

  test('API enrichment overlays support metadata without dropping states', () {
    final rows = buildStateReturnPickerRows(
      enrichment: [
        {
          'code': 'TX',
          'display_name': 'Texas',
          'has_personal_income_tax': false,
          'tax_filing_support': 'no_income_tax',
          'unsupported_message': 'No PIT',
        },
        {
          // Tolerate state_code alias from alternate payloads.
          'state_code': 'ny',
          'display_name': 'New York',
          'tax_filing_support': 'organizer_intake',
        },
      ],
    );
    expect(rows.length, 51);
    final tx = rows.firstWhere((r) => r.code == 'TX');
    expect(tx.hasPersonalIncomeTax, isFalse);
    expect(tx.taxFilingSupport, 'no_income_tax');
    final ny = rows.firstWhere((r) => r.code == 'NY');
    expect(ny.displayName, 'New York');
    expect(ny.regionId, '5');
  });

  test('enabled rollout regions cover every non-CA state exactly once', () {
    final covered = <String>{};
    for (final region in enabledRolloutRegions) {
      for (final code in region.states) {
        if (code == 'CA') continue;
        expect(covered.add(code), isTrue, reason: 'duplicate $code');
      }
    }
    for (final opt in usStateOptions) {
      if (opt.$1 == 'CA') continue;
      expect(covered.contains(opt.$1), isTrue, reason: 'unassigned ${opt.$1}');
    }
  });
}
