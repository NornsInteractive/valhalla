import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_sources_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/nas_source.dart';
import '../../../data/models/remote_browser.dart';
import '../../../data/models/server_profile.dart';
import '../../../widgets/remote_browser_dialog.dart';
import '../../../widgets/remote_browser_view.dart';
import 'nas_localizations.dart';

class NasSourceDialog extends ConsumerStatefulWidget {
  final NasSource? source;
  final NasSource? initialDraft;

  const NasSourceDialog({super.key, this.source, this.initialDraft})
    : assert(
        source == null || initialDraft == null,
        'Cannot provide both source and initialDraft',
      );

  static Future<void> show(
    BuildContext context, {
    NasSource? source,
    NasSource? initialDraft,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) =>
          NasSourceDialog(source: source, initialDraft: initialDraft),
    );
  }

  @override
  ConsumerState<NasSourceDialog> createState() => _NasSourceDialogState();
}

class _NasSourceDialogState extends ConsumerState<NasSourceDialog> {
  late final String _stableId;
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
  bool _isBrowsing = false;
  bool _domainPending = false;
  bool _domainFailed = false;
  bool _domainEdited = false;
  bool _settingDomain = false;
  int _revision = 0;
  String? _libraryName;

  bool get _isEditing => widget.source != null;

  @override
  void initState() {
    super.initState();
    final s = widget.source ?? widget.initialDraft;
    _stableId =
        widget.source?.id ??
        ((widget.initialDraft?.id.isNotEmpty ?? false)
            ? widget.initialDraft!.id
            : const Uuid().v4());
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
    _watchText(_nameController, _draftChanged);
    _watchText(_rootPathController, _draftChanged);
    _watchText(_endpointController, _identityChanged);
    _watchText(_usernameController, _identityChanged);
    _watchText(_passwordController, _identityChanged);
    _watchText(_domainController, _domainChanged);

    if (!_isEditing && (_type == NasSourceType.sftp || _useSshTunnel)) {
      if (_selectedSshServerId == null) {
        final active = ref.read(activeServerProvider);
        final servers = ref.read(serverListProvider);
        _selectedSshServerId =
            (active != null && servers.any((svr) => svr.id == active.id))
            ? active.id
            : null;
      }
    }
    if (_isEditing && _type == NasSourceType.smb) {
      _domainPending = true;
      _loadDomain();
    }
  }

  void _draftChanged() => _revision++;

  void _watchText(TextEditingController controller, VoidCallback onChanged) {
    var text = controller.text;
    controller.addListener(() {
      if (text == controller.text) return;
      text = controller.text;
      onChanged();
    });
  }

  void _identityChanged() {
    _revision++;
    _authenticatedUserId = null;
    _token = null;
    _libraryName = null;
    if (mounted) setState(() {});
  }

  void _domainChanged() {
    if (_settingDomain) return;
    _domainEdited = true;
    _identityChanged();
  }

  Future<void> _loadDomain() async {
    final identity = (
      _type,
      _endpointController.text,
      _usernameController.text,
      _selectedSshServerId,
      _useSshTunnel,
    );
    try {
      final domain = await ref
          .read(nasSourcesProvider.notifier)
          .savedDomain(widget.source!);
      if (mounted &&
          !_domainEdited &&
          identity ==
              (
                _type,
                _endpointController.text,
                _usernameController.text,
                _selectedSshServerId,
                _useSshTunnel,
              )) {
        _settingDomain = true;
        _domainController.text = domain;
        _settingDomain = false;
      }
      _domainFailed = false;
    } catch (error) {
      if (mounted) {
        _statusMessage = context.nasBrowserError(error);
        _statusIsError = true;
        _domainFailed = true;
      }
    } finally {
      if (mounted) setState(() => _domainPending = false);
    }
  }

  Future<void> _browseRoot() async {
    if (_domainPending || _domainFailed || _isBrowsing || _isSaving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final revision = _revision;
    bool current() => mounted && _revision == revision;
    setState(() => _isBrowsing = true);
    RemoteBrowserSource? browser;
    try {
      final draft = _buildSource(
        rootPath: _type == NasSourceType.webdav ? '/' : null,
      );
      browser = await ref
          .read(nasSourcesProvider.notifier)
          .openBrowser(
            draft,
            _buildCredentials(),
            keepEmptySecrets: _isEditing && _passwordController.text.isEmpty,
            isCurrent: current,
          );
      if (!current() || !browser.isCurrent) return;
      if (!mounted) return;
      final result = await RemoteBrowserDialog.show(
        context,
        source: browser,
        mode: draft.isMediaServer
            ? RemoteBrowserMode.mediaLibrary
            : RemoteBrowserMode.directory,
        initialSelectedIds: draft.isMediaServer && draft.rootPath != '/'
            ? {draft.rootPath}
            : const {},
      );
      if (!current() ||
          !browser.isCurrent ||
          result == null ||
          result.entries.isEmpty) {
        return;
      }
      final entry = result.entries.single;
      setState(() {
        _rootPathController.text = entry.id;
        _libraryName = draft.isMediaServer ? entry.name : null;
      });
    } catch (error) {
      if (current()) {
        setState(() {
          _statusMessage = context.nasBrowserError(error);
          _statusIsError = true;
        });
      }
    } finally {
      await browser?.dispose();
      if (mounted) setState(() => _isBrowsing = false);
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

  NasSource _buildSource({String? id, String? rootPath}) {
    final effectiveId = id ?? _stableId;
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
      userId: _authenticatedUserId,
      rootPath:
          rootPath ??
          (_rootPathController.text.trim().isEmpty
              ? '/'
              : _rootPathController.text.trim()),
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
    if (_domainPending) return;
    if (_domainFailed) {
      setState(() => _domainPending = true);
      await _loadDomain();
      return;
    }
    final revision = _revision;
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
      if (mounted && revision == _revision) {
        setState(() {
          _statusMessage = context.nasProbeSuccess;
          _statusIsError = false;
        });
      }
    } catch (e) {
      if (mounted && revision == _revision) {
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
    final revision = _revision;
    setState(() {
      _isProbing = true;
      _statusMessage = null;
    });
    try {
      final source = _buildSource();
      final result = await ref
          .read(nasSourcesProvider.notifier)
          .authenticate(source, _passwordController.text);
      if (mounted && revision == _revision) {
        setState(() {
          _revision++;
          _authenticatedUserId = result.userId;
          _token = result.credentials.token;
          _statusMessage = context.nasAuthSuccess;
          _statusIsError = false;
        });
      }
    } catch (e) {
      if (mounted && revision == _revision) {
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
    if (_domainPending || _domainFailed || _isSaving) return;
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
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    if (isCompact) {
      return Dialog.fullscreen(
        key: const Key('nas_source_dialog'),
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _isEditing ? context.nasEditSource : context.nasAddSource,
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildFormFields(context, sshServers),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      );
    }

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
                        style: theme.textTheme.titleMedium,
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
                ..._buildFormFields(context, sshServers),
                const SizedBox(height: 16),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields(
    BuildContext context,
    List<ServerProfile> sshServers,
  ) {
    final theme = Theme.of(context);
    return [
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
                        _identityChanged();
                        _type = type;
                        _rootPathController.text = '/';
                        if (_type == NasSourceType.sftp &&
                            _selectedSshServerId == null) {
                          final active = ref.read(activeServerProvider);
                          final servers = ref.read(serverListProvider);
                          _selectedSshServerId =
                              (active != null &&
                                  servers.any((svr) => svr.id == active.id))
                              ? active.id
                              : null;
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
              borderRadius: BorderRadius.circular(VRadius.input),
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
            initialValue: sshServers.any((s) => s.id == _selectedSshServerId)
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
              setState(() {
                _identityChanged();
                _selectedSshServerId = val;
              });
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
            helperText: _useSshTunnel ? context.nasSshTunnelHint : null,
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
            helperText: _isEditing ? context.nasKeepEmptyPassword : null,
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
            helperText: _isEditing ? context.nasKeepEmptyPassword : null,
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
      if (_type == NasSourceType.jellyfin || _type == NasSourceType.emby) ...[
        _buildSshTunnelSection(context, sshServers),
        TextField(
          key: const Key('nas_source_endpoint_field'),
          controller: _endpointController,
          decoration: InputDecoration(
            labelText: context.nasEndpoint,
            hintText: _useSshTunnel
                ? 'http://127.0.0.1:8096'
                : 'http://192.168.1.100:8096',
            helperText: _useSshTunnel ? context.nasSshTunnelHint : null,
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
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('nas_source_auth_button'),
                    icon: const Icon(Icons.login, size: 16),
                    label: Text(context.nasAuthenticate),
                    onPressed: _isProbing ? null : _authenticate,
                  ),
                ],
              );
            }
            return Row(
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
            );
          },
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
                  style: monoTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('nas_source_root_path_field'),
          controller: _rootPathController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: context.l10n.remoteBrowserLibrariesTitle,
            helperText: _rootPathController.text == '/'
                ? context.l10n.nasAllLibraries
                : _libraryName,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _isSaving
                ? null
                : () => setState(() {
                    _rootPathController.text = '/';
                    _libraryName = null;
                  }),
            child: Text(context.l10n.nasAllLibraries),
          ),
        ),
      ],

      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('nas_source_browse_root'),
        onPressed: _domainPending || _domainFailed || _isBrowsing || _isSaving
            ? null
            : _browseRoot,
        icon: const Icon(Icons.folder_open_outlined),
        label: Text(
          _type == NasSourceType.jellyfin || _type == NasSourceType.emby
              ? context.l10n.remoteBrowserLibrariesTitle
              : context.l10n.remoteBrowserSelectDirectory,
        ),
      ),

      const SizedBox(height: 12),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(context.nasProbe),
        value: _probeOnSave,
        onChanged: (val) => setState(() => _probeOnSave = val ?? true),
      ),

      if (_statusMessage != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _statusIsError
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(VRadius.input),
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
    ];
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowSpacing: 8,
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
              onPressed: (_domainPending || _isProbing || _isSaving)
                  ? null
                  : _probe,
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
              onPressed: _domainPending || _domainFailed || _isSaving
                  ? null
                  : _save,
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
        borderRadius: BorderRadius.circular(VRadius.input),
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
                      style: theme.textTheme.titleSmall,
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
                    _identityChanged();
                    _useSshTunnel = val;
                    if (val && _selectedSshServerId == null && !_isEditing) {
                      final active = ref.read(activeServerProvider);
                      final servers = ref.read(serverListProvider);
                      _selectedSshServerId =
                          (active != null &&
                              servers.any((svr) => svr.id == active.id))
                          ? active.id
                          : null;
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
                  setState(() {
                    _identityChanged();
                    _selectedSshServerId = val;
                  });
                },
              ),
          ],
        ],
      ),
    );
  }
}
