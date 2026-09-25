import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_sources_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/nas_source.dart';
import '../../../data/models/server_profile.dart';
import 'nas_localizations.dart';

class NasSourceDialog extends ConsumerStatefulWidget {
  final NasSource? source;

  const NasSourceDialog({super.key, this.source});

  static Future<void> show(BuildContext context, {NasSource? source}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => NasSourceDialog(source: source),
    );
  }

  @override
  ConsumerState<NasSourceDialog> createState() => _NasSourceDialogState();
}

class _NasSourceDialogState extends ConsumerState<NasSourceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _endpointController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _domainController;
  late final TextEditingController _rootPathController;

  late NasSourceType _type;
  String? _selectedSshServerId;
  bool _useSshTunnel = false;
  String? _authenticatedUserId;
  String? _token;

  bool _isSaving = false;
  bool _isProbing = false;
  bool _probeOnSave = true;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _isEditing => widget.source != null;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _type = s?.type ?? NasSourceType.sftp;
    _selectedSshServerId = s?.sshServerId;
    _useSshTunnel = s?.sshServerId != null && s?.type != NasSourceType.sftp;
    _authenticatedUserId = s?.userId;
    _nameController = TextEditingController(text: s?.name ?? '');
    _endpointController = TextEditingController(text: s?.endpoint ?? '');
    _usernameController = TextEditingController(text: s?.username ?? '');
    _passwordController = TextEditingController();
    _domainController = TextEditingController();
    _rootPathController = TextEditingController(text: s?.rootPath ?? '/');

    if (!_isEditing && (_type == NasSourceType.sftp || _useSshTunnel)) {
      final active = ref.read(activeServerProvider);
      final servers = ref.read(serverListProvider);
      _selectedSshServerId =
          (active != null && servers.any((svr) => svr.id == active.id))
          ? active.id
          : servers.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _domainController.dispose();
    _rootPathController.dispose();
    super.dispose();
  }

  NasSource _buildSource({String? id}) {
    final effectiveId = id ?? widget.source?.id ?? const Uuid().v4();
    final useTunnel =
        (_type == NasSourceType.sftp) ||
        ((_type == NasSourceType.webdav ||
                _type == NasSourceType.jellyfin ||
                _type == NasSourceType.emby) &&
            _useSshTunnel);
    return NasSource(
      id: effectiveId,
      name: _nameController.text.trim(),
      type: _type,
      endpoint: _endpointController.text.trim(),
      sshServerId: useTunnel ? _selectedSshServerId : null,
      username: _usernameController.text.trim(),
      userId: _authenticatedUserId ?? widget.source?.userId,
      rootPath: _rootPathController.text.trim().isEmpty
          ? '/'
          : _rootPathController.text.trim(),
    );
  }

  NasCredentials _buildCredentials() {
    return NasCredentials(
      password: _passwordController.text,
      token: _token ?? '',
      domain: _domainController.text.trim(),
    );
  }

  Future<void> _probe() async {
    setState(() {
      _isProbing = true;
      _statusMessage = null;
    });
    try {
      final source = _buildSource();
      final credentials = _buildCredentials();
      final notifier = ref.read(nasSourcesProvider.notifier);
      await notifier.probe(
        source,
        credentials,
        keepEmptySecrets: _isEditing && _passwordController.text.isEmpty,
      );
      if (mounted) {
        setState(() {
          _statusMessage = context.nasProbeSuccess;
          _statusIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = context.nasSanitizedError(e);
          _statusIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isProbing = false);
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isProbing = true;
      _statusMessage = null;
    });
    try {
      final source = _buildSource();
      final result = await ref
          .read(nasSourcesProvider.notifier)
          .authenticate(source, _passwordController.text);
      if (mounted) {
        setState(() {
          _authenticatedUserId = result.userId;
          _token = result.credentials.token;
          _statusMessage = context.nasAuthSuccess;
          _statusIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = context.nasSanitizedError(e);
          _statusIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isProbing = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _statusMessage = context.nasSourceNameRequired;
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final source = _buildSource();
      final credentials = _buildCredentials();
      await ref
          .read(nasSourcesProvider.notifier)
          .save(
            source,
            credentials,
            probe: _probeOnSave,
            keepEmptySecrets: _isEditing && _passwordController.text.isEmpty,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = context.nasSanitizedError(e);
          _statusIsError = true;
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmRemove() async {
    final s = widget.source;
    if (s == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.nasRemoveSource),
        content: Text(ctx.nasRemoveSourceConfirm(s.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            key: const Key('nas_confirm_remove_source_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(nasSourcesProvider.notifier).remove(s.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sshServers = ref.watch(serverListProvider);

    return Dialog(
      key: const Key('nas_source_dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _isEditing ? Icons.edit_note : Icons.add_to_photos,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isEditing
                            ? context.nasEditSource
                            : context.nasAddSource,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Source Type Selector
                Text(
                  context.nasSourceType,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: NasSourceType.values.map((type) {
                    final isSelected = _type == type;
                    return ChoiceChip(
                      key: Key('nas_source_type_${type.name}'),
                      label: Text(type.name.toUpperCase()),
                      selected: isSelected,
                      onSelected: _isEditing
                          ? null
                          : (sel) {
                              if (sel) {
                                setState(() {
                                  _type = type;
                                  if (_type == NasSourceType.sftp &&
                                      _selectedSshServerId == null) {
                                    final active = ref.read(
                                      activeServerProvider,
                                    );
                                    final servers = ref.read(
                                      serverListProvider,
                                    );
                                    _selectedSshServerId =
                                        (active != null &&
                                            servers.any(
                                              (svr) => svr.id == active.id,
                                            ))
                                        ? active.id
                                        : servers.firstOrNull?.id;
                                  }
                                });
                              }
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Source Name Field
                TextField(
                  key: const Key('nas_source_name_field'),
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.nasSourceName,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // SFTP-specific Fields
                if (_type == NasSourceType.sftp) ...[
                  if (sshServers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.nasSelectSshServer,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: const Key('nas_source_ssh_server_field'),
                      isExpanded: true,
                      initialValue:
                          sshServers.any((s) => s.id == _selectedSshServerId)
                          ? _selectedSshServerId
                          : null,
                      decoration: InputDecoration(
                        labelText: context.nasSshServer,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: sshServers.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.name} (${s.username}@${s.host}:${s.port})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedSshServerId = val);
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_root_path_field'),
                    controller: _rootPathController,
                    decoration: InputDecoration(
                      labelText: context.nasRootPath,
                      hintText: '/media',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],

                // WebDAV-specific Fields
                if (_type == NasSourceType.webdav) ...[
                  _buildSshTunnelSection(context, sshServers),
                  TextField(
                    key: const Key('nas_source_endpoint_field'),
                    controller: _endpointController,
                    decoration: InputDecoration(
                      labelText: context.nasEndpoint,
                      hintText: _useSshTunnel
                          ? 'http://127.0.0.1:8080/remote.php/webdav'
                          : 'https://dav.example.com/remote.php/webdav',
                      helperText: _useSshTunnel
                          ? context.nasSshTunnelHint
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_username_field'),
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: context.nasUsername,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_password_field'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.nasPassword,
                      hintText: _isEditing ? '******' : null,
                      helperText: _isEditing
                          ? context.nasKeepEmptyPassword
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_root_path_field'),
                    controller: _rootPathController,
                    decoration: InputDecoration(
                      labelText: context.nasRootPath,
                      hintText: '/',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],

                // SMB-specific Fields
                if (_type == NasSourceType.smb) ...[
                  TextField(
                    key: const Key('nas_source_endpoint_field'),
                    controller: _endpointController,
                    decoration: InputDecoration(
                      labelText: context.nasEndpoint,
                      hintText: 'smb://192.168.1.100/share',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_domain_field'),
                    controller: _domainController,
                    decoration: InputDecoration(
                      labelText: context.nasDomain,
                      hintText: 'WORKGROUP',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_username_field'),
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: context.nasUsername,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_password_field'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.nasPassword,
                      hintText: _isEditing ? '******' : null,
                      helperText: _isEditing
                          ? context.nasKeepEmptyPassword
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_root_path_field'),
                    controller: _rootPathController,
                    decoration: InputDecoration(
                      labelText: context.nasRootPath,
                      hintText: '/',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],

                // Jellyfin / Emby specific Fields
                if (_type == NasSourceType.jellyfin ||
                    _type == NasSourceType.emby) ...[
                  _buildSshTunnelSection(context, sshServers),
                  TextField(
                    key: const Key('nas_source_endpoint_field'),
                    controller: _endpointController,
                    decoration: InputDecoration(
                      labelText: context.nasEndpoint,
                      hintText: _useSshTunnel
                          ? 'http://127.0.0.1:8096'
                          : 'http://192.168.1.100:8096',
                      helperText: _useSshTunnel
                          ? context.nasSshTunnelHint
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nas_source_username_field'),
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: context.nasUsername,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('nas_source_password_field'),
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: context.nasPassword,
                            hintText: _isEditing ? '******' : null,
                            helperText: _isEditing
                                ? context.nasKeepEmptyPassword
                                : null,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('nas_source_auth_button'),
                        icon: const Icon(Icons.login, size: 16),
                        label: Text(context.nasAuthenticate),
                        onPressed: _isProbing ? null : _authenticate,
                      ),
                    ],
                  ),
                  if (_authenticatedUserId != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'User ID: $_authenticatedUserId',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'JetBrains Mono',
                              color: theme.colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(context.nasProbe),
                  value: _probeOnSave,
                  onChanged: (val) =>
                      setState(() => _probeOnSave = val ?? true),
                ),

                if (_statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusIsError
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusIsError
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_isEditing)
                      TextButton.icon(
                        key: const Key('nas_source_remove_button'),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        label: Text(context.nasRemoveSource),
                        onPressed: _isSaving ? null : _confirmRemove,
                      ),
                    OutlinedButton(
                      key: const Key('nas_source_probe_button'),
                      onPressed: (_isProbing || _isSaving) ? null : _probe,
                      child: _isProbing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.nasProbe),
                    ),
                    FilledButton(
                      key: const Key('nas_source_save_button'),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSshTunnelSection(
    BuildContext context,
    List<ServerProfile> sshServers,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.nasUseSshTunnel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.nasUseSshTunnelDesc,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('nas_source_ssh_tunnel_switch'),
                value: _useSshTunnel,
                onChanged: (val) {
                  setState(() {
                    _useSshTunnel = val;
                    if (val && _selectedSshServerId == null && !_isEditing) {
                      final active = ref.read(activeServerProvider);
                      final servers = ref.read(serverListProvider);
                      _selectedSshServerId =
                          (active != null &&
                              servers.any((svr) => svr.id == active.id))
                          ? active.id
                          : servers.firstOrNull?.id;
                    }
                  });
                },
              ),
            ],
          ),
          if (_useSshTunnel) ...[
            const SizedBox(height: 10),
            if (sshServers.isEmpty)
              Text(
                context.nasSelectSshServer,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              )
            else
              DropdownButtonFormField<String>(
                key: const Key('nas_source_ssh_server_field'),
                isExpanded: true,
                initialValue:
                    sshServers.any((s) => s.id == _selectedSshServerId)
                    ? _selectedSshServerId
                    : null,
                decoration: InputDecoration(
                  labelText: context.nasSshServer,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: sshServers.map((s) {
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.name} (${s.username}@${s.host}:${s.port})',
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedSshServerId = val);
                },
              ),
          ],
        ],
      ),
    );
  }
}
