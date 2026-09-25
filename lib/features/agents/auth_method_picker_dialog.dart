import 'package:flutter/material.dart';
import '../../core/extensions/context_extensions.dart';
import '../../infrastructure/acp/acp_client_adapter.dart';

Future<String?> showAuthMethodPickerDialog({
  required BuildContext context,
  required String agentName,
  required List<AcpAuthMethod> methods,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) =>
        _AuthMethodPickerDialog(agentName: agentName, methods: methods),
  );
}

class _AuthMethodPickerDialog extends StatefulWidget {
  final String agentName;
  final List<AcpAuthMethod> methods;

  const _AuthMethodPickerDialog({
    required this.agentName,
    required this.methods,
  });

  @override
  State<_AuthMethodPickerDialog> createState() =>
      _AuthMethodPickerDialogState();
}

class _AuthMethodPickerDialogState extends State<_AuthMethodPickerDialog> {
  late String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.methods.isNotEmpty ? widget.methods.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.l10n.agentAuthPickerTitle(widget.agentName),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: RadioGroup<String>(
            groupValue: _selectedId,
            onChanged: (val) {
              setState(() => _selectedId = val);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.methods.map((method) {
                return RadioListTile<String>(
                  title: Text(method.name),
                  subtitle:
                      (method.description != null &&
                          method.description!.isNotEmpty)
                      ? Text(method.description!)
                      : null,
                  value: method.id,
                );
              }).toList(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(context.l10n.agentAuthCancelButton),
        ),
        FilledButton(
          onPressed: _selectedId != null
              ? () => Navigator.of(context).pop(_selectedId)
              : null,
          child: Text(context.l10n.agentAuthProceedButton),
        ),
      ],
    );
  }
}
