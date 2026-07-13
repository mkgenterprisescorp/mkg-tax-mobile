import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../home/presentation/main_tabs.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docs = const [
      ('W-2 · ACME Corp', 'Uploaded', Icons.picture_as_pdf),
      ('1099-NEC · Consulting', 'Needs review', Icons.description_outlined),
      ('Driver license', 'Verified', Icons.badge_outlined),
      ('Prior year return', 'Requested', Icons.request_page_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo: document scanner / upload next.')),
            );
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload or scan document'),
        ),
        const SectionHeader('My documents'),
        for (final d in docs)
          Card(
            child: ListTile(
              leading: Icon(d.$3, color: MkgColors.primary),
              title: Text(d.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(d.$2),
              trailing: const Icon(Icons.more_vert),
            ),
          ),
      ],
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AccountOverviewScreen();
  }
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SectionHeader('Secure messages'),
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.support_agent)),
            title: Text('MKG Support'),
            subtitle: Text('We received your W-2. Please confirm employer name.'),
            trailing: Text('Today'),
          ),
        ),
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.smart_toy_outlined)),
            title: Text('Tessa'),
            subtitle: Text('I can help you finish the Client Data Sheet.'),
            trailing: Text('Mon'),
          ),
        ),
      ],
    );
  }
}

class TessaScreen extends StatefulWidget {
  const TessaScreen({super.key});

  @override
  State<TessaScreen> createState() => _TessaScreenState();
}

class _TessaScreenState extends State<TessaScreen> {
  final _controller = TextEditingController();
  final _messages = <(bool isUser, String text)>[
    (false, 'Hi — I am Tessa. Ask me about your organizer, documents, or refund status. (Demo replies only.)'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add((true, text));
      _messages.add((false, 'Thanks! In production I will call /api/v1/tessa. For now this is a UI demo.'));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[i];
              final align = msg.$1 ? Alignment.centerRight : Alignment.centerLeft;
              final color = msg.$1 ? MkgColors.primary : MkgColors.surfaceGrey;
              final textColor = msg.$1 ? Colors.white : MkgColors.dark;
              return Align(
                alignment: align,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                  child: Text(msg.$2, style: TextStyle(color: textColor)),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Ask Tessa...'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SectionHeader('Technology fee'),
        Card(
          child: ListTile(
            title: Text('2025 Tax Prep Package'),
            subtitle: Text('Invoice #1042 · Due on filing'),
            trailing: StatusChip(label: 'Unpaid', color: MkgColors.orange),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('Prior year balance'),
            subtitle: Text('Invoice #981'),
            trailing: StatusChip(label: 'Paid', color: MkgColors.green),
          ),
        ),
      ],
    );
  }
}

class BookkeepingScreen extends StatelessWidget {
  const BookkeepingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SectionHeader('Bookkeeping'),
        Card(child: ListTile(title: Text('Monthly close'), subtitle: Text('March · In review'), trailing: Icon(Icons.chevron_right))),
        Card(child: ListTile(title: Text('Transactions to categorize'), subtitle: Text('18 pending'), trailing: Icon(Icons.chevron_right))),
        Card(child: ListTile(title: Text('P&L snapshot'), subtitle: Text('YTD demo numbers'), trailing: Icon(Icons.chevron_right))),
      ],
    );
  }
}

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Tax tools'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calculate_outlined, color: MkgColors.primary),
            title: const Text('Loan calculator'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calculator demo'))),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.percent, color: MkgColors.primary),
            title: const Text('Estimated refund helper'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refund helper demo'))),
          ),
        ),
      ],
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Support'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.video_camera_front_outlined, color: MkgColors.primary),
            title: const Text('Schedule Zoom'),
            subtitle: const Text('Talk with an MKG specialist'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zoom scheduling demo'))),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.chat_outlined, color: MkgColors.primary),
            title: const Text('Live chat / Messenger'),
            onTap: () => context.go('/messages'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.help_outline, color: MkgColors.primary),
            title: const Text('FAQs'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FAQ demo'))),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.phone, color: MkgColors.primary),
            title: Text('Call office'),
            subtitle: Text('Demo contact card'),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: MkgColors.lightPrimary,
            child: Icon(Icons.person, size: 48, color: MkgColors.primary),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(user?.displayName ?? 'Client', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        Center(child: Text(user?.email ?? '', style: const TextStyle(color: MkgColors.textGrey))),
        if (user?.phone != null) ...[
          const SizedBox(height: 4),
          Center(child: Text(user!.phone!, style: const TextStyle(color: MkgColors.textGrey))),
        ],
        const SizedBox(height: 8),
        Center(child: StatusChip(label: 'KYC: ${user?.kycStatus ?? 'unknown'}', color: MkgColors.orange)),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Verify identity'),
                subtitle: const Text('Uses financemkgtaxpro /api/kyc/*'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('KYC camera flow coming next.')),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Update profile'),
                subtitle: const Text('PUT /api/user/profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile editor coming next.')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

class EngagementsScreen extends StatelessWidget {
  const EngagementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SectionHeader('Engagements'),
        Card(child: ListTile(title: Text('2025 Individual Tax'), subtitle: Text('TAX · Assigned'), trailing: StatusChip(label: 'Active', color: MkgColors.green))),
        Card(child: ListTile(title: Text('Monthly Bookkeeping',), subtitle: Text('BOOK · Assigned'), trailing: StatusChip(label: 'Active', color: MkgColors.green))),
      ],
    );
  }
}
