import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/mkg_theme.dart';
import 'tax_year_repository.dart';

/// Shared tax-year selector used across Returns / Organizer / Documents / Home.
class TaxYearSelectorBar extends ConsumerWidget {
  const TaxYearSelectorBar({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taxYearProvider);
    if (state.years.isEmpty) {
      return const SizedBox.shrink();
    }
    final selected = state.selectedYear ?? state.currentFilingYear;
    return Material(
      color: MkgColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 6 : 10),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: MkgColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: selected,
                  items: [
                    for (final y in state.years)
                      DropdownMenuItem(
                        value: y.taxYear,
                        child: Text(
                          y.label,
                          style: TextStyle(
                            fontWeight: y.isCurrentFilingYear ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                  onChanged: state.loading
                      ? null
                      : (v) {
                          if (v != null) ref.read(taxYearProvider.notifier).selectYear(v);
                        },
                ),
              ),
            ),
            if (state.source == 'local-fallback')
              const Tooltip(
                message: 'Using local year window — Laravel catalog unavailable',
                child: Icon(Icons.cloud_off_outlined, size: 18, color: MkgColors.textGrey),
              ),
          ],
        ),
      ),
    );
  }
}
