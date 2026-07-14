import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Advisor Chat hub — TESSA AI + human advisor / contact paths.
class AdvisorChatScreen extends StatelessWidget {
  const AdvisorChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const Text('Advisor Chat', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Message TESSA AI or reach your MKG Tax / Finance Advisors team.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 16),
        MkgCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: MkgColors.primary,
              child: Icon(Icons.smart_toy_outlined, color: Colors.white),
            ),
            title: const Text('Ask TESSA AI', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Tax-year aware answers for organizers, documents, and filings.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/tessa'),
          ),
        ),
        const SizedBox(height: 12),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.support_agent_outlined, color: MkgColors.primary),
                title: const Text('Support & appointments'),
                subtitle: const Text('Schedule a call or open a support ticket.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/support'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_outlined, color: MkgColors.primary),
                title: const Text('Open web portal'),
                subtitle: const Text('financemkgtax.com messaging & scheduling'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchUrl(
                  Uri.parse('https://financemkgtax.com'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
