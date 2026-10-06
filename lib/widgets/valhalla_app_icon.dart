import 'package:flutter/material.dart';

import '../core/extensions/context_extensions.dart';

/// The application icon used for Valhalla branding inside the UI.
class ValhallaAppIcon extends StatelessWidget {
  const ValhallaAppIcon({super.key, this.size = 40}) : assert(size > 0);

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/valhalla_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: context.l10n.appName,
    );
  }
}
