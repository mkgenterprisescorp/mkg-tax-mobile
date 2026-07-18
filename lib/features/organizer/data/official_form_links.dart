import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Official IRS / FTB form & instruction links (tax year 2025).
abstract final class OfficialFormLinks {
  static const ca540Instructions =
      'https://www.ftb.ca.gov/forms/2025/2025-540-instructions.html';
  static const ca540Booklet = 'https://www.ftb.ca.gov/forms/2025/2025-540-booklet.html';
  static const ca540Pdf = 'https://www.ftb.ca.gov/forms/2025/2025-540.pdf';
  static const ca540xPdf = 'https://www.ftb.ca.gov/forms/2025/2025-540-x.pdf';
  static const form1040xAbout = 'https://www.irs.gov/forms-pubs/about-form-1040x';
  static const form1040xPdf = 'https://www.irs.gov/pub/irs-pdf/f1040x.pdf';

  static Future<void> open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Compact card of official form links for organizer / tools screens.
class OfficialFormLinksCard extends StatelessWidget {
  const OfficialFormLinksCard({
    super.key,
    required this.title,
    required this.links,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<(String label, String url)> links;

  @override
  Widget build(BuildContext context) {
    return MkgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          for (final link in links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.open_in_new, color: MkgColors.primary, size: 20),
              title: Text(link.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () => OfficialFormLinks.open(link.$2),
            ),
        ],
      ),
    );
  }
}
