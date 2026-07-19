/// Geographic rollout for nationwide (non-CA) state organizer workflows.
/// Mirrors Laravel `StateRolloutRegions` / state-engine `rollout-regions-ty2025`.
///
/// Regions 1–6 are all unlocked for intake.
/// California is Region 1 geographically but filing stays on Form 540 paths.

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
    states: ['AK', 'AZ', 'CA', 'HI', 'NV', 'NM', 'UT'],
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
    name: 'South',
    slug: 'south',
    phase: 3,
    states: ['AL', 'AR', 'FL', 'GA', 'KY', 'LA', 'MS', 'NC', 'OK', 'SC', 'TN', 'TX', 'VA', 'WV'],
  ),
  RolloutRegion(
    id: '4',
    name: 'East',
    slug: 'east',
    phase: 4,
    states: ['DE', 'DC', 'MD', 'NJ', 'PA'],
  ),
  RolloutRegion(
    id: '5',
    name: 'Northeast',
    slug: 'northeast',
    phase: 5,
    states: ['CT', 'ME', 'MA', 'NH', 'NY', 'RI', 'VT'],
  ),
  RolloutRegion(
    id: '6',
    name: 'Northwest',
    slug: 'northwest',
    phase: 6,
    states: ['CO', 'ID', 'MT', 'OR', 'WA', 'WY'],
  ),
];

const enabledRegionIds = <String>{'1', '2', '3', '4', '5', '6'};

const phaseOneLabel = 'Regions 1–6 · nationwide intake (all regions active)';

const unassignedStates = <String>{};

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

/// All nationwide-enabled states (excludes CA).
Set<String> get phaseOneEnabledStates => {
      for (final region in rolloutRegions)
        if (enabledRegionIds.contains(region.id))
          for (final code in region.states)
            if (code != 'CA') code,
    };

List<RolloutRegion> get enabledRolloutRegions => [
      for (final region in rolloutRegions)
        if (enabledRegionIds.contains(region.id)) region,
    ];

List<RolloutRegion> get lockedRolloutRegions => [
      for (final region in rolloutRegions)
        if (!enabledRegionIds.contains(region.id)) region,
    ];
