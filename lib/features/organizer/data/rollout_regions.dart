/// Geographic rollout for nationwide (non-CA) state organizer workflows.
/// Mirrors Laravel `StateRolloutRegions` / state-engine `rollout-regions-ty2025`.
///
/// Phase 1: Region 1 West + Region 6 Northwest.
/// California stays on Form 540 / CA business paths.

class RolloutRegion {
  const RolloutRegion({
    required this.id,
    required this.name,
    required this.slug,
    required this.phase,
    required this.states,
  });

  final String id;
  final String name;
  final String slug;
  final int phase;
  final List<String> states;
}

const rolloutRegions = <RolloutRegion>[
  RolloutRegion(
    id: '1',
    name: 'West',
    slug: 'west',
    phase: 1,
    states: ['AZ', 'CO', 'HI', 'NV', 'NM', 'UT'],
  ),
  RolloutRegion(
    id: '6',
    name: 'Northwest',
    slug: 'northwest',
    phase: 1,
    states: ['AK', 'ID', 'MT', 'OR', 'WA', 'WY'],
  ),
  RolloutRegion(
    id: '2',
    name: 'Midwest',
    slug: 'midwest',
    phase: 2,
    states: ['IL', 'IN', 'IA', 'KS', 'MI', 'MN', 'MO', 'NE', 'ND', 'OH', 'SD', 'WI'],
  ),
  RolloutRegion(
    id: '3',
    name: 'Southern',
    slug: 'southern',
    phase: 3,
    states: ['AL', 'AR', 'FL', 'GA', 'KY', 'LA', 'MS', 'NC', 'OK', 'SC', 'TN', 'TX'],
  ),
  RolloutRegion(
    id: '4',
    name: 'East',
    slug: 'east',
    phase: 4,
    states: ['DE', 'DC', 'MD', 'PA', 'VA', 'WV'],
  ),
  RolloutRegion(
    id: '5',
    name: 'Northeast',
    slug: 'northeast',
    phase: 5,
    states: ['CT', 'ME', 'MA', 'NH', 'NJ', 'NY', 'RI', 'VT'],
  ),
];

const enabledRegionIds = <String>{'1', '6'};

const phaseOneLabel = 'Phase 1 · Regions 1 (West) + 6 (Northwest)';

RolloutRegion? regionForState(String stateCode) {
  final code = stateCode.toUpperCase();
  for (final region in rolloutRegions) {
    if (region.states.contains(code)) return region;
  }
  return null;
}

bool isNationwideStateEnabled(String stateCode) {
  final code = stateCode.toUpperCase();
  if (code == 'CA') return false;
  final region = regionForState(code);
  return region != null && enabledRegionIds.contains(region.id);
}

/// Phase-1 enabled nationwide states (excludes CA).
Set<String> get phaseOneEnabledStates => {
      for (final region in rolloutRegions)
        if (enabledRegionIds.contains(region.id)) ...region.states,
    };

List<RolloutRegion> get enabledRolloutRegions => [
      for (final region in rolloutRegions)
        if (enabledRegionIds.contains(region.id)) region,
    ];

List<RolloutRegion> get lockedRolloutRegions => [
      for (final region in rolloutRegions)
        if (!enabledRegionIds.contains(region.id)) region,
    ];
