import '../../organizer/data/rollout_regions.dart';
import '../../organizer/data/us_states.dart';

/// One row in the Tax Returns "Select a state return" picker.
class StateReturnPickerRow {
  const StateReturnPickerRow({
    required this.code,
    required this.displayName,
    required this.hasPersonalIncomeTax,
    required this.taxFilingSupport,
    required this.regionId,
    required this.regionName,
    required this.rolloutPhase,
  });

  final String code;
  final String displayName;
  final bool hasPersonalIncomeTax;
  final String taxFilingSupport;
  final String regionId;
  final String regionName;
  final int rolloutPhase;

  String get subtitle {
    final tax = hasPersonalIncomeTax ? 'Personal income tax' : 'No personal income tax';
    return 'Region $regionId · $regionName · $tax';
  }
}

/// Region section for the picker (Regions 1–6).
class StateReturnPickerSection {
  const StateReturnPickerSection({
    required this.region,
    required this.rows,
  });

  final RolloutRegion region;
  final List<StateReturnPickerRow> rows;
}

/// Builds the full nationwide picker catalog.
///
/// Always includes every state/DC from [usStateOptions], grouped by
/// [rolloutRegions] (1–6). Optional API [enrichment] rows (from
/// `/api/v1/reference/states`) overlay display/support metadata when present.
List<StateReturnPickerSection> buildStateReturnPickerSections({
  List<Map<String, dynamic>> enrichment = const [],
}) {
  final byCode = <String, Map<String, dynamic>>{
    for (final opt in usStateOptions)
      opt.$1: {
        'code': opt.$1,
        'display_name': opt.$2,
        'has_personal_income_tax': statesWithIncomeTax.contains(opt.$1),
        'tax_filing_support': opt.$1 == 'CA'
            ? 'organizer_supported'
            : (statesWithIncomeTax.contains(opt.$1) ? 'organizer_intake' : 'no_income_tax'),
      },
  };

  for (final row in enrichment) {
    final raw = (row['code'] ?? row['state_code'] ?? '').toString().trim().toUpperCase();
    if (raw.isEmpty) continue;
    final prior = byCode[raw] ?? <String, dynamic>{'code': raw};
    byCode[raw] = {
      ...prior,
      ...row,
      'code': raw,
      'display_name': (row['display_name'] ?? prior['display_name'] ?? displayNameForState(raw))
          .toString(),
      'has_personal_income_tax': row['has_personal_income_tax'] == true ||
          statesWithIncomeTax.contains(raw),
    };
  }

  StateReturnPickerRow rowFor(String code, RolloutRegion region) {
    final raw = byCode[code] ??
        {
          'code': code,
          'display_name': displayNameForState(code),
          'has_personal_income_tax': statesWithIncomeTax.contains(code),
          'tax_filing_support': code == 'CA'
              ? 'organizer_supported'
              : (statesWithIncomeTax.contains(code) ? 'organizer_intake' : 'no_income_tax'),
        };
    return StateReturnPickerRow(
      code: code,
      displayName: (raw['display_name'] ?? displayNameForState(code)).toString(),
      hasPersonalIncomeTax: raw['has_personal_income_tax'] == true ||
          statesWithIncomeTax.contains(code),
      taxFilingSupport: (raw['tax_filing_support'] ?? 'organizer_intake').toString(),
      regionId: region.id,
      regionName: region.name,
      rolloutPhase: region.phase,
    );
  }

  final sections = <StateReturnPickerSection>[
    for (final region in rolloutRegions)
      StateReturnPickerSection(
        region: region,
        rows: [
          for (final code in region.states) rowFor(code, region),
        ],
      ),
  ];

  // Safety: any US jurisdiction missing from region tables still appears.
  final covered = <String>{
    for (final section in sections)
      for (final row in section.rows) row.code,
  };
  final missing = [
    for (final opt in usStateOptions)
      if (!covered.contains(opt.$1)) opt.$1,
  ];
  if (missing.isNotEmpty) {
    final orphanRegion = RolloutRegion(
      id: '0',
      name: 'Other',
      slug: 'other',
      phase: 0,
      states: missing,
    );
    sections.add(
      StateReturnPickerSection(
        region: orphanRegion,
        rows: [for (final code in missing) rowFor(code, orphanRegion)],
      ),
    );
  }

  return sections;
}

/// Flat list of all picker rows (Regions 1–6 order).
List<StateReturnPickerRow> buildStateReturnPickerRows({
  List<Map<String, dynamic>> enrichment = const [],
}) =>
    [
      for (final section in buildStateReturnPickerSections(enrichment: enrichment))
        ...section.rows,
    ];
