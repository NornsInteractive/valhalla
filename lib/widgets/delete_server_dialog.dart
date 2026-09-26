import 'package:flutter/material.dart';
import '../core/design/motion_widgets.dart';
import '../core/design/tokens.dart';
import '../core/extensions/context_extensions.dart';
import '../data/models/server_profile.dart';

Future<bool> showDeleteServerConfirmDialog(
  BuildContext context,
  ServerProfile server,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final danger = ctx.vDanger;
      return AlertDialog(
        icon: Entrance(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_forever_rounded,
              color: danger,
              size: 32,
            ),
          ),
        ),
        title: Entrance(
          index: 1,
          child: Text(
            ctx.l10n.confirmDeleteServerTitle,
            style: ctx.textTheme.titleMedium?.copyWith(color: danger),
            textAlign: TextAlign.center,
          ),
        ),
        content: Entrance(
          index: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(
              ctx.l10n.confirmDeleteServerMessage(server.name),
              style: ctx.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: ctx.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
