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
  static const ca100Pdf = 'https://www.ftb.ca.gov/forms/2025/2025-100.pdf';
  static const ca100sPdf = 'https://www.ftb.ca.gov/forms/2025/2025-100s.pdf';
  static const ca565Pdf = 'https://www.ftb.ca.gov/forms/2025/2025-565.pdf';
  static const ca541Pdf = 'https://www.ftb.ca.gov/forms/2025/2025-541.pdf';
  static const ca199Pdf = 'https://www.ftb.ca.gov/forms/2025/2025-199.pdf';
  static const caScheduleRPdf = 'https://www.ftb.ca.gov/forms/2025/2025-100-r.pdf';
  static const ca568Pdf = 'https://www.ftb.ca.gov/forms/2025/2025-568.pdf';
  static const form1040xAbout = 'https://www.irs.gov/forms-pubs/about-form-1040x';
  static const form1040xPdf = 'https://www.irs.gov/pub/irs-pdf/f1040x.pdf';
  static const form1040Pdf = 'https://www.irs.gov/pub/irs-pdf/f1040.pdf';
  static const form1040Instructions = 'https://www.irs.gov/instructions/i1040gi';
  static const form1040 = form1040Pdf;
  static const schedule1Pdf = 'https://www.irs.gov/pub/irs-pdf/f1040s1.pdf';
  static const scheduleAPdf = 'https://www.irs.gov/pub/irs-pdf/f1040sa.pdf';
  static const scheduleCPdf = 'https://www.irs.gov/pub/irs-pdf/f1040sc.pdf';
  static const scheduleC = scheduleCPdf;
  static const scheduleDPdf = 'https://www.irs.gov/pub/irs-pdf/f1040sd.pdf';
  static const scheduleD = scheduleDPdf;
  static const schedule3Pdf = 'https://www.irs.gov/pub/irs-pdf/f1040s3.pdf';
  static const schedule8812Pdf = 'https://www.irs.gov/pub/irs-pdf/f8812.pdf';
  static const formW2Pdf = 'https://www.irs.gov/pub/irs-pdf/fw2.pdf';
  static const formW2 = formW2Pdf;
  static const form1099NecPdf = 'https://www.irs.gov/pub/irs-pdf/f1099nec.pdf';
  static const form1099IntPdf = 'https://www.irs.gov/pub/irs-pdf/f1099int.pdf';
  static const form1099Int = form1099IntPdf;
  static const form1099DivPdf = 'https://www.irs.gov/pub/irs-pdf/f1099div.pdf';
  static const form1099Div = form1099DivPdf;
  static const form1099RPdf = 'https://www.irs.gov/pub/irs-pdf/f1099r.pdf';
  static const form1099GPdf = 'https://www.irs.gov/pub/irs-pdf/f1099g.pdf';
  static const ssa1099About = 'https://www.ssa.gov/myaccount/replacement-ssa-1099.html';

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
