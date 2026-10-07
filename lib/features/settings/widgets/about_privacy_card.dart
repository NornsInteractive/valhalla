import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../widgets/valhalla_app_icon.dart';
import 'privacy_policy_view.dart';
import 'license_view.dart';

const officialWebsiteUrl = 'https://norns.cc.cd';

class AboutPrivacyCard extends StatefulWidget {
  const AboutPrivacyCard({super.key});

  @override
  State<AboutPrivacyCard> createState() => _AboutPrivacyCardState();
}

class _AboutPrivacyCardState extends State<AboutPrivacyCard> {
  late final _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('settings_about_privacy_card'),
      child: Column(
        children: [
          ListTile(
            leading: const ValhallaAppIcon(),
            title: const Text('Valhalla'),
            subtitle: FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Text(
                  '${info == null ? context.l10n.privacyVersionUnknown : 'v${info.version} (${info.buildNumber})'}\nNorns Interactive',
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('settings_website_button'),
            leading: const Icon(Icons.language),
            title: Text(context.l10n.aboutWebsite),
            subtitle: const Text(officialWebsiteUrl),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openPrivacyLink(
              context,
              Uri.parse(officialWebsiteUrl),
              failureMessage: context.l10n.aboutLinkFailed,
            ),
          ),
          ListTile(
            key: const Key('settings_license_button'),
            leading: const Icon(Icons.description_outlined),
            title: Text(context.l10n.aboutLicense),
            subtitle: const Text('PolyForm Noncommercial 1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LicenseView()),
            ),
          ),
          ListTile(
            key: const Key('settings_third_party_licenses_button'),
            leading: const Icon(Icons.code),
            title: Text(context.l10n.aboutThirdPartyLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final info = await _packageInfo;
              if (!context.mounted) return;
              showLicensePage(
                context: context,
                applicationName: 'Valhalla',
                applicationVersion: 'v${info.version} (${info.buildNumber})',
                applicationLegalese: 'Copyright © 2026 Norns',
              );
            },
          ),
          ListTile(
            key: const Key('settings_privacy_policy_button'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(context.l10n.privacyPolicyTitle),
            subtitle: Text(context.l10n.privacyPolicyDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyView(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(context.l10n.privacyContactTitle),
            subtitle: const Text(privacyContactEmail),
            onTap: () => openPrivacyLink(
              context,
              Uri(scheme: 'mailto', path: privacyContactEmail),
            ),
            trailing: IconButton(
              tooltip: context.l10n.privacyCopyEmail,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: privacyContactEmail),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.privacyEmailCopied)),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
