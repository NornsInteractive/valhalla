import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/server_provider.dart';
import '../../data/models/server_profile.dart';
import '../../widgets/delete_server_dialog.dart';

class ServerFormDialog extends ConsumerStatefulWidget {
  final ServerProfile? serverToEdit;

  const ServerFormDialog({super.key, this.serverToEdit});

  @override
  ConsumerState<ServerFormDialog> createState() => _ServerFormDialogState();
}

class _ServerFormDialogState extends ConsumerState<ServerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _privateKeyController;

  AuthType _authType = AuthType.password;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;
  String? _saveError;
  bool _isPrivateKeyExpanded = false;

  @override
  void initState() {
    super.initState();
    final s = widget.serverToEdit;
    _nameController = TextEditingController(text: s?.name ?? '');
    _hostController = TextEditingController(text: s?.host ?? '');
    _portController = TextEditingController(text: (s?.port ?? 22).toString());
    _usernameController = TextEditingController(text: s?.username ?? 'root');
    _passwordController = TextEditingController();
    _privateKeyController = TextEditingController();
    _authType = s?.authType ?? AuthType.password;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    if (host.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = true;
          _testResult = context.l10n.serverPortReachable(port);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResult = context.l10n.serverConnectionFailed(e.toString());
        });
      }
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDeleteServerConfirmDialog(
      context,
      widget.serverToEdit!,
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(serverListProvider.notifier)
        .deleteServer(widget.serverToEdit!.id);
    if (mounted) navigator.pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saveError = null;
    });

    final id = widget.serverToEdit?.id ?? const Uuid().v4();
    final server = ServerProfile(
      id: id,
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _usernameController.text.trim(),
      authType: _authType,
      tags: widget.serverToEdit?.tags ?? ['Linux', 'SSH'],
      lastConnectedAt: DateTime.now(),
    );

    final isNewServer = widget.serverToEdit == null;

    try {
      await ref
          .read(serverListProvider.notifier)
          .addOrUpdate(
            server,
            password: _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
            privateKey: _privateKeyController.text.isNotEmpty
                ? _privateKeyController.text
                : null,
          );

      if (isNewServer) {
        await ref.read(activeServerProvider.notifier).selectServer(server.id);
      }

      if (mounted) {
        Navigator.pop(context, server);
      }
    } catch (_) {
      if (mounted) {
        final errorText = context.l10n.serverSaveFailedGeneric;
        setState(() {
          _saveError = errorText;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText), backgroundColor: context.vDanger),
        );
      }
    }
  }

  Widget _buildFormFields(BuildContext context) {
    final testColor = _testSuccess == true ? context.vSuccess : context.vDanger;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_saveError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.vDanger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: context.vDanger.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: context.vDanger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _saveError!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.vDanger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Entrance(
            index: 0,
            child: TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.serverName,
                hintText: 'e.g. prod-cluster-us-east',
                prefixIcon: const Icon(Icons.dns),
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? context.l10n.serverFieldRequired
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Entrance(
            index: 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: context.l10n.serverHost,
                      hintText: '192.168.1.100',
                      prefixIcon: const Icon(Icons.link),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? context.l10n.serverFieldRequired
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.serverPort,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return context.l10n.serverFieldRequired;
                      }
                      final p = int.tryParse(val.trim());
                      if (p == null || p < 1 || p > 65535) {
                        return context.l10n.serverPortInvalid;
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Entrance(
            index: 2,
            child: TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: context.l10n.serverUsername,
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? context.l10n.serverFieldRequired
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Entrance(
            index: 3,
            child: SegmentedButton<AuthType>(
              segments: [
                ButtonSegment(
                  value: AuthType.password,
                  label: Text(context.l10n.serverPassword),
                  icon: const Icon(Icons.password),
                ),
                ButtonSegment(
                  value: AuthType.privateKey,
                  label: Text(context.l10n.serverPrivateKey),
                  icon: const Icon(Icons.vpn_key),
                ),
              ],
              selected: {_authType},
              onSelectionChanged: (set) =>
                  setState(() => _authType = set.first),
            ),
          ),
          const SizedBox(height: 12),
          if (_authType == AuthType.password)
            Entrance(
              index: 4,
              child: TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.serverPassword,
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            )
          else ...[
            Entrance(
              index: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.serverPrivateKey,
                    style: context.textTheme.titleSmall,
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _isPrivateKeyExpanded = !_isPrivateKeyExpanded,
                    ),
                    icon: Icon(
                      _isPrivateKeyExpanded
                          ? Icons.unfold_less
                          : Icons.unfold_more,
                      size: 16,
                    ),
                    label: Text(
                      _isPrivateKeyExpanded
                          ? context.l10n.serverHidePrivateKey
                          : context.l10n.serverViewPrivateKey,
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Entrance(
              index: 4,
              child: TextFormField(
                controller: _privateKeyController,
                maxLines: _isPrivateKeyExpanded ? 10 : 4,
                minLines: 3,
                style: monoTextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                decoration: const InputDecoration(
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
                  prefixIcon: Icon(Icons.key),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Entrance(
            index: 5,
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check, size: 16),
              label: Text(context.l10n.serverTestReachability),
            ),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: testColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: testColor.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess == true
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 18,
                    color: testColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: testColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, {required bool isEditing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          top: BorderSide(color: context.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (isEditing)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: context.vDanger,
              ),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(context.l10n.delete),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _save, child: Text(context.l10n.serverSave)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    final isEditing = widget.serverToEdit != null;

    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(
              isEditing ? context.l10n.editServer : context.l10n.addServer,
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (isEditing)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: context.vDanger),
                  tooltip: context.l10n.delete,
                  onPressed: _delete,
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildFormFields(context),
                  ),
                ),
                _buildBottomBar(context, isEditing: isEditing),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.dialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Text(
                    isEditing
                        ? context.l10n.editServer
                        : context.l10n.addServer,
                    style: context.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildFormFields(context),
              ),
            ),
            _buildBottomBar(context, isEditing: isEditing),
          ],
        ),
      ),
    );
  }
}
