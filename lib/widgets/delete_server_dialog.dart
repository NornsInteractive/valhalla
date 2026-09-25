import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../data/models/server_profile.dart';

Future<bool> showDeleteServerConfirmDialog(
  BuildContext context,
  ServerProfile server,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.delete_forever_rounded,
          color: Color(0xFFEF4444),
          size: 32,
        ),
      ),
      title: Text(
        context.l10n.confirmDeleteServerTitle,
        style: const TextStyle(
          color: Color(0xFFEF4444),
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Text(
          context.l10n.confirmDeleteServerMessage(server.name),
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
