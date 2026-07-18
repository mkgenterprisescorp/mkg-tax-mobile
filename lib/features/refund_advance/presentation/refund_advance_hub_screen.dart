import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Icon hub — walk through Refund Advance sections (Loan Estimate → TILA → Apply).
class RefundAdvanceHubScreen extends StatelessWidget {
  const RefundAdvanceHubScreen({super.key});

  static const sections = <_AdvanceSection>[
    _AdvanceSection(
      title: 'Program overview',
      cue: '0% no-cost & 36% APR larger advances',
      icon: Icons.info_outline,
      path: '/refund-advance/overview',
      accent: MkgColors.primary,
    ),
    _AdvanceSection(
      title: 'Refund calculator',
      cue: 'Federal estimate · organizer prefill',
      icon: Icons.savings_outlined,
      path: '/refund-advance/estimate',
      accent: MkgColors.green,
    ),
    _AdvanceSection(
      title: 'Loan Estimate',
      cue: 'Pick tier · see APR & repayment',
      icon: Icons.request_quote_outlined,
      path: '/refund-advance/loan-estimate',
      accent: MkgColors.accent,
    ),
    _AdvanceSection(
      title: 'TILA disclosure',
      cue: 'Truth in Lending · Pathward, N.A.',
      icon: Icons.gavel_outlined,
      path: '/refund-advance/tila',
      accent: MkgColors.primary,
    ),
    _AdvanceSection(
      title: 'Written guarantee',
      cue: 'MKG accuracy & year-round support',
      icon: Icons.verified_outlined,
      path: '/refund-advance/guarantee',
      accent: MkgColors.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const Text('Tax Refund Advances', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Tap each section to walk through and complete — Loan Estimate and TILA required before apply.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 14),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pathward, N.A., Member FDIC', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'Optional advance on your expected IRS refund — not the refund itself. '
                'No-cost \$250 / \$500 / \$1,000 at 0% APR. Larger advances (25% / 50% / 75%) at 36.0% APR.',
                style: TextStyle(color: MkgColors.textGrey, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.go('/refund-advance/loan-estimate'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start walkthrough'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 18, bottom: 10),
          child: Text('Sections to complete', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sections.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.02,
          ),
          itemBuilder: (context, i) {
            final s = sections[i];
            return _Tile(section: s, onTap: () => context.go(s.path));
          },
        ),
      ],
    );
  }
}

class _AdvanceSection {
  const _AdvanceSection({
    required this.title,
    required this.cue,
    required this.icon,
    required this.path,
    required this.accent,
  });

  final String title;
  final String cue;
  final IconData icon;
  final String path;
  final Color accent;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.section, required this.onTap});

  final _AdvanceSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = section.accent;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(section.icon, color: color),
              ),
              const Spacer(),
              Text(section.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                section.cue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: MkgColors.textGrey, fontSize: 12, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared quote state across Loan Estimate → TILA → Apply.
class RefundAdvanceQuote {
  const RefundAdvanceQuote({
    required this.tierLabel,
    required this.amount,
    required this.apr,
    required this.expectedRefund,
    this.quote,
    this.tilaAccepted = false,
  });

  final String tierLabel;
  final num amount;
  final double apr;
  final num expectedRefund;
  final Map<String, dynamic>? quote;
  final bool tilaAccepted;

  RefundAdvanceQuote copyWith({
    String? tierLabel,
    num? amount,
    double? apr,
    num? expectedRefund,
    Map<String, dynamic>? quote,
    bool? tilaAccepted,
  }) {
    return RefundAdvanceQuote(
      tierLabel: tierLabel ?? this.tierLabel,
      amount: amount ?? this.amount,
      apr: apr ?? this.apr,
      expectedRefund: expectedRefund ?? this.expectedRefund,
      quote: quote ?? this.quote,
      tilaAccepted: tilaAccepted ?? this.tilaAccepted,
    );
  }
}

class RefundAdvanceNotifier extends Notifier<RefundAdvanceQuote?> {
  @override
  RefundAdvanceQuote? build() => null;

  void setQuote(RefundAdvanceQuote q) => state = q;

  void acceptTila() {
    final cur = state;
    if (cur == null) return;
    state = cur.copyWith(tilaAccepted: true);
  }

  void clear() => state = null;
}

final refundAdvanceProvider =
    NotifierProvider<RefundAdvanceNotifier, RefundAdvanceQuote?>(RefundAdvanceNotifier.new);
