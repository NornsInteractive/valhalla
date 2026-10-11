import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/app_update_provider.dart';
import '../../../data/models/app_update.dart';
import '../../../widgets/valhalla_app_icon.dart';
import 'app_update_dialog.dart';
import 'privacy_policy_view.dart';
import 'license_view.dart';

const officialWebsiteUrl = 'https://norns.cc.cd';

class AboutPrivacyCard extends ConsumerStatefulWidget {
  const AboutPrivacyCard({super.key});

  @override
  ConsumerState<AboutPrivacyCard> createState() => _AboutPrivacyCardState();
}

class _AboutPrivacyCardState extends ConsumerState<AboutPrivacyCard> {
  late final _packageInfo = PackageInfo.fromPlatform();

  String _formatCheckedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _handleManualCheck(BuildContext context) async {
    final notifier = ref.read(appUpdateProvider.notifier);
    await notifier.check();
    if (!context.mounted) return;
    final state = ref.read(appUpdateProvider);
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizeUpdateError(context, state.error!)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (state.updateAvailable && state.release != null) {
      AppUpdateDialog.show(context);
    } else if (state.checkedAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.updateUpToDate),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updateState = ref.watch(appUpdateProvider);

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
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              final installedVer = info?.version ?? '';
              final hasChecked = updateState.checkedAt != null;
              final checkedTime = hasChecked
                  ? context.l10n.updateLastChecked(
                      _formatCheckedAt(updateState.checkedAt!),
                    )
                  : context.l10n.updateNeverChecked;

              Widget subtitleWidget;
              if (updateState.checking) {
                subtitleWidget = Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.updateChecking,
                        style: context.textTheme.bodySmall,
                      ),
                    ),
                  ],
                );
              } else if (updateState.error != null) {
                // Check errors remain visible even if older cached release exists
                subtitleWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizeUpdateError(context, updateState.error!),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${installedVer.isNotEmpty ? context.l10n.updateInstalledVersion(installedVer) : ''} · $checkedTime',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              } else if (updateState.updateAvailable &&
                  updateState.release != null) {
                subtitleWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.updateAvailableBadge(
                        updateState.release!.version,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${installedVer.isNotEmpty ? context.l10n.updateInstalledVersion(installedVer) : ''} · $checkedTime',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              } else {
                subtitleWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasChecked
                          ? context.l10n.updateUpToDate
                          : context.l10n.updateNeverChecked,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasChecked) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${installedVer.isNotEmpty ? context.l10n.updateInstalledVersion(installedVer) : ''} · $checkedTime',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );
              }

              Widget trailingWidget;
              if (updateState.checking) {
                trailingWidget = const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              } else if (updateState.updateAvailable && updateState.error == null) {
                trailingWidget = FilledButton.tonal(
                  key: const Key('settings_view_update_button'),
                  onPressed: () => AppUpdateDialog.show(context),
                  child: Text(context.l10n.updateViewUpdate),
                );
              } else {
                trailingWidget = OutlinedButton(
                  key: const Key('settings_check_update_button'),
                  onPressed: () => _handleManualCheck(context),
                  child: Text(context.l10n.updateCheckNow),
                );
              }

              return ListTile(
                key: const Key('settings_check_update_tile'),
                leading: const Icon(Icons.system_update_outlined),
                title: Text(context.l10n.updateCheckTitle),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: subtitleWidget,
                ),
                trailing: trailingWidget,
                onTap: updateState.checking
                    ? null
                    : (updateState.updateAvailable || updateState.release != null
                        ? () => AppUpdateDialog.show(context)
                        : () => _handleManualCheck(context)),
              );
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            key: const Key('settings_auto_check_update_tile'),
            secondary: const Icon(Icons.schedule_outlined),
            title: Text(context.l10n.updateAutoCheckTitle),
            subtitle: Text(context.l10n.updateAutoCheckSubtitle),
            value: updateState.automaticCheck,
            onChanged: (val) async {
              try {
                await ref
                    .read(appUpdateProvider.notifier)
                    .setAutomaticCheck(val);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.updateAutoCheckSaveFailed),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('settings_github_repository_tile'),
            leading: const Icon(Icons.code),
            title: Text(context.l10n.aboutRepository),
            subtitle: const Text(valhallaRepositoryUrl),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openPrivacyLink(
              context,
              Uri.parse(valhallaRepositoryUrl),
              failureMessage: context.l10n.aboutLinkFailed,
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
