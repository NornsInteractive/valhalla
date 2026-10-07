import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/context_extensions.dart';

const privacyPolicyUrl =
    'https://gist.github.com/Naruto9Kurama/743fc88a1f2739f0a43ee733ca74afc6';
const privacyContactEmail = 'norns.soft@gmail.com';

Future<void> openPrivacyLink(
  BuildContext context,
  Uri uri, {
  String? failureMessage,
}) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Keep the policy readable when no browser/mail handler is available.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failureMessage ?? context.l10n.privacyLinkFailed)),
    );
  }
}

class PrivacyPolicyView extends StatefulWidget {
  const PrivacyPolicyView({super.key});

  @override
  State<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends State<PrivacyPolicyView> {
  bool? _chinese;
  late final _chinesePolicy = rootBundle.loadString('PRIVACY.md');
  late final _englishPolicy = rootBundle.loadString('PRIVACY.en.md');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chinese ??= Localizations.localeOf(context).languageCode == 'zh';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.privacyPolicyTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.privacyOnlineVersion,
            icon: const Icon(Icons.open_in_new),
            onPressed: () =>
                openPrivacyLink(context, Uri.parse(privacyPolicyUrl)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('简体中文')),
                ButtonSegment(value: false, label: Text('English')),
              ],
              selected: {_chinese!},
              onSelectionChanged: (value) =>
                  setState(() => _chinese = value.single),
            ),
          ),
          Expanded(
            child: FutureBuilder<String>(
              key: ValueKey(_chinese),
              future: _chinese! ? _chinesePolicy : _englishPolicy,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(context.l10n.privacyLoadFailed));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Language navigation is provided above, not by local file URLs.
                final content = snapshot.data!
                    .replaceAll('[English version](PRIVACY.en.md)', '')
                    .replaceAll('[简体中文](PRIVACY.md)', '');
                return Markdown(
                  key: ValueKey(_chinese),
                  data: content,
                  selectable: true,
                  padding: const EdgeInsets.all(20),
                  onTapLink: (_, href, _) {
                    final uri = Uri.tryParse(href ?? '');
                    if (uri != null &&
                        const ['https', 'mailto'].contains(uri.scheme)) {
                      openPrivacyLink(context, uri);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
