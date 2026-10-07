import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/extensions/context_extensions.dart';

/// The bundled legal text remains available without a network connection.
class LicenseView extends StatefulWidget {
  const LicenseView({super.key});

  @override
  State<LicenseView> createState() => _LicenseViewState();
}

class _LicenseViewState extends State<LicenseView> {
  late final _documents = Future.wait([
    rootBundle.loadString('LICENSE'),
    rootBundle.loadString('NOTICE'),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutLicense)),
      body: FutureBuilder<List<String>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.aboutLicenseLoadFailed));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PolyForm Noncommercial 1.0.0',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(context.l10n.aboutLicenseSummary),
                  const SizedBox(height: 24),
                  Text(snapshot.data![0], key: const Key('license_full_text')),
                  const Divider(height: 40),
                  Text(
                    context.l10n.aboutCopyrightNotice,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.data![1],
                    key: const Key('license_notice_text'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
