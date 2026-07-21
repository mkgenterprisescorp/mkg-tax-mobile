import 'rollout_regions.dart';
import 'state_tax_regimes.dart';

/// Regions whose personal estimate facades are wired in Flutter.
///
/// Region 1 (West) was first; Regions 2–5 are built out here. Region 6
/// (Northwest) uses the same regional estimate API and is included so every
/// unlocked region can run estimates when the state has broad PIT.
const estimateUiRegionIds = <String>{'1', '2', '3', '4', '5', '6'};

/// Regions explicitly requested for this build-out (Midwest → Northeast).
const regions2Through5 = <String>{'2', '3', '4', '5'};

/// Whether the nationwide form should show a personal estimate action.
///
/// California stays on Form 540. No-broad-PIT states stay intake-only in UI
/// (backend may still return structured regime results).
bool supportsRegionalPersonalEstimate(String stateCode, {String? family}) {
  final code = stateCode.toUpperCase();
  if (code == 'CA') return false;
  if (family != null && family != 'individual') return false;
  if (!shouldShowResidentPersonalWorkflow(code)) return false;
  final region = regionForState(code);
  if (region == null) return false;
  return estimateUiRegionIds.contains(region.id) &&
      enabledRegionIds.contains(region.id);
}

/// True when [stateCode] is in Regions 2–5 and estimate-capable.
bool isRegion2Through5EstimateState(String stateCode) {
  final region = regionForState(stateCode);
  if (region == null) return false;
  if (!regions2Through5.contains(region.id)) return false;
  return supportsRegionalPersonalEstimate(stateCode);
}

List<String> estimateCapableStatesForRegions(Set<String> regionIds) {
  return [
    for (final region in rolloutRegions)
      if (regionIds.contains(region.id))
        for (final code in region.states)
          if (supportsRegionalPersonalEstimate(code)) code,
  ]..sort();
}
