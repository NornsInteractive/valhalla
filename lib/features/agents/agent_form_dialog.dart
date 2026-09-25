import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/agent_registry_provider.dart';
import '../../core/providers/infrastructure_providers.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/builtin_agent_preset.dart';
import '../../infrastructure/docker/docker_cli_service.dart';

enum AgentPresetType { claudeCode, codex, openCode, agy, custom }

class AgentFormDialog extends ConsumerStatefulWidget {
  final String serverId;
  final AgentProfile? initialProfile;

  const AgentFormDialog({
    super.key,
    required this.serverId,
    this.initialProfile,
  });

  @override
  ConsumerState<AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends ConsumerState<AgentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  static const _uuid = Uuid();

  bool get _isEditing => widget.initialProfile != null;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cliController;
  late final TextEditingController _acpController;
  late final TextEditingController _installController;
  late final TextEditingController _acpInstallController;
  late final TextEditingController _loginCheckController;
  late final TextEditingController _loginController;
  late final TextEditingController _containerReferenceController;
  late final TextEditingController _containerUserController;

  AgentPresetType _selectedPreset = AgentPresetType.claudeCode;

  String _executionTarget = 'host';
  String _containerBinding = 'id';

  bool _isLoadingContainers = false;
  String? _containersError;
  List<DockerContainer>? _containers;

  bool _isLoadingContainerUsers = false;
  String? _containerUsersError;
  List<DockerContainerUser>? _containerUsers;
  String? _selectedContainerUser;
  Timer? _containerRefDebounce;
  int _containerUsersRequestId = 0;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialProfile;
    _nameController = TextEditingController(text: init?.name ?? '');
    _descriptionController = TextEditingController(
      text: init?.description ?? '',
    );
    _cliController = TextEditingController(text: init?.cliCommand ?? '');
    _acpController = TextEditingController(text: init?.acpCommand ?? '');
    _installController = TextEditingController(
      text: init?.installCommand ?? '',
    );
    _acpInstallController = TextEditingController(
      text: init?.acpInstallCommand ?? '',
    );
    _loginCheckController = TextEditingController(
      text: init?.loginCheckCommand ?? '',
    );
    _loginController = TextEditingController(text: init?.loginCommand ?? '');

    _executionTarget = init?.executionTarget ?? 'host';
    _containerBinding = init?.containerBinding ?? 'id';
    _containerReferenceController = TextEditingController(
      text: init?.containerReference ?? '',
    );
    _containerUserController = TextEditingController(
      text: init?.containerUser ?? '',
    );
    _containerUserController.addListener(_onManualContainerUserChanged);

    if (init == null) {
      _applyPreset(AgentPresetType.claudeCode);
    }
    if (_executionTarget == 'docker') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchContainers();
          if (_containerReferenceController.text.trim().isNotEmpty) {
            _fetchContainerUsers();
          }
        }
      });
    }
  }

  void _onManualContainerUserChanged() {
    if (_selectedContainerUser != null &&
        _containerUserController.text != _selectedContainerUser) {
      setState(() {
        _selectedContainerUser = null;
      });
    }
  }

  @override
  void dispose() {
    _containerRefDebounce?.cancel();
    _containerUserController.removeListener(_onManualContainerUserChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _cliController.dispose();
    _acpController.dispose();
    _installController.dispose();
    _acpInstallController.dispose();
    _loginCheckController.dispose();
    _loginController.dispose();
    _containerReferenceController.dispose();
    _containerUserController.dispose();
    super.dispose();
  }

  Future<void> _fetchContainers() async {
    setState(() {
      _isLoadingContainers = true;
      _containersError = null;
    });
    try {
      final cli = ref.read(dockerCliServiceProvider);
      final list = await cli.listContainers(widget.serverId);
      if (mounted) {
        setState(() {
          _containers = list;
          _isLoadingContainers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _containersError = e.toString();
          _isLoadingContainers = false;
        });
      }
    }
  }

  Future<void> _fetchContainerUsers() async {
    final refText = _containerReferenceController.text.trim();
    if (refText.isEmpty || _executionTarget != 'docker') {
      if (mounted) {
        setState(() {
          _containerUsers = null;
          _isLoadingContainerUsers = false;
          _containerUsersError = null;
        });
      }
      return;
    }

    final requestId = ++_containerUsersRequestId;
    setState(() {
      _isLoadingContainerUsers = true;
      _containerUsersError = null;
    });
    try {
      final cli = ref.read(dockerCliServiceProvider);
      final list = await cli.listContainerUsers(widget.serverId, refText);
      if (mounted && requestId == _containerUsersRequestId) {
        setState(() {
          _containerUsers = list;
          _isLoadingContainerUsers = false;
          final current = _containerUserController.text.trim();
          if (current.isNotEmpty &&
              list.any((u) => u.executionValue == current)) {
            _selectedContainerUser = current;
          }
        });
      }
    } catch (e) {
      if (mounted && requestId == _containerUsersRequestId) {
        setState(() {
          _containerUsersError = e.toString();
          _isLoadingContainerUsers = false;
        });
      }
    }
  }

  void _applyPreset(AgentPresetType preset) {
    setState(() {
      _selectedPreset = preset;
      final presetKey = switch (preset) {
        AgentPresetType.claudeCode => 'builtin-claude-code',
        AgentPresetType.codex => 'builtin-codex',
        AgentPresetType.openCode => 'builtin-opencode',
        AgentPresetType.agy => 'builtin-agy',
        AgentPresetType.custom => null,
      };

      if (presetKey != null) {
        final data = kBuiltinAgentPresets[presetKey];
        if (data != null) {
          _nameController.text = data.name;
          _descriptionController.text = data.description;
          _cliController.text = data.cliCommand;
          _acpController.text = data.acpCommand ?? '';
          _installController.text = data.cliInstallCommand ?? '';
          _acpInstallController.text = data.acpInstallCommand ?? '';
          _loginCheckController.text = data.loginCheckCommand ?? '';
          _loginController.text = data.loginCommand ?? '';
        }
      } else {
        _nameController.clear();
        _descriptionController.clear();
        _cliController.clear();
        _acpController.clear();
        _installController.clear();
        _acpInstallController.clear();
        _loginCheckController.clear();
        _loginController.clear();
      }
    });
  }

  String _resolveAgentId(AgentRegistryState registryState) {
    String candidateId;
    switch (_selectedPreset) {
      case AgentPresetType.claudeCode:
        candidateId = 'builtin-claude-code';
        break;
      case AgentPresetType.codex:
        candidateId = 'builtin-codex';
        break;
      case AgentPresetType.openCode:
        candidateId = 'builtin-opencode';
        break;
      case AgentPresetType.agy:
        candidateId = 'builtin-agy';
        break;
      case AgentPresetType.custom:
        return 'custom-${_uuid.v4().substring(0, 8)}';
    }

    // Check if candidateId already exists on this server
    final exists = registryState.agents.any((a) => a.profile.id == candidateId);
    if (exists) {
      return '$candidateId-${_uuid.v4().substring(0, 6)}';
    }
    return candidateId;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final cli = _cliController.text.trim();
    final acp = _acpController.text.trim();
    if (cli.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final containerUser =
          _executionTarget == 'docker' &&
              _containerUserController.text.trim().isNotEmpty
          ? _containerUserController.text.trim()
          : null;

      if (_isEditing) {
        final profile = AgentProfile(
          id: widget.initialProfile!.id,
          serverId: widget.initialProfile!.serverId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          cliCommand: cli,
          executionTarget: _executionTarget,
          containerBinding: _containerBinding,
          containerReference: _executionTarget == 'docker'
              ? _containerReferenceController.text.trim()
              : null,
          containerUser: containerUser,
          acpCommand: acp.isEmpty ? null : acp,
          installCommand: _installController.text.trim().isNotEmpty
              ? _installController.text.trim()
              : null,
          acpInstallCommand: _acpInstallController.text.trim().isNotEmpty
              ? _acpInstallController.text.trim()
              : null,
          loginCheckCommand: _loginCheckController.text.trim().isNotEmpty
              ? _loginCheckController.text.trim()
              : null,
          loginCommand: _loginController.text.trim().isNotEmpty
              ? _loginController.text.trim()
              : null,
          createdAt: widget.initialProfile!.createdAt,
          updatedAt: DateTime.now(),
        );
        await ref.read(agentRegistryProvider.notifier).updateAgent(profile);
      } else {
        final registryState = ref.read(agentRegistryProvider);
        final agentId = _resolveAgentId(registryState);

        final profile = AgentProfile(
          id: agentId,
          serverId: widget.serverId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          cliCommand: cli,
          executionTarget: _executionTarget,
          containerBinding: _containerBinding,
          containerReference: _executionTarget == 'docker'
              ? _containerReferenceController.text.trim()
              : null,
          containerUser: containerUser,
          acpCommand: acp.isEmpty ? null : acp,
          installCommand: _installController.text.trim().isNotEmpty
              ? _installController.text.trim()
              : null,
          acpInstallCommand: _acpInstallController.text.trim().isNotEmpty
              ? _acpInstallController.text.trim()
              : null,
          loginCheckCommand: _loginCheckController.text.trim().isNotEmpty
              ? _loginCheckController.text.trim()
              : null,
          loginCommand: _loginController.text.trim().isNotEmpty
              ? _loginController.text.trim()
              : null,
        );
        await ref.read(agentRegistryProvider.notifier).addAgent(profile);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text(context.l10n.cancel, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    context.l10n.agentSaveButton,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group 1: Preset selector (only for new agents)
          if (!_isEditing) ...[
            _buildSectionHeader(
              context,
              context.l10n.agentPresetTitle,
              Icons.auto_awesome_outlined,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetChoice(
                  AgentPresetType.claudeCode,
                  context.l10n.agentPresetClaudeCode,
                ),
                _buildPresetChoice(
                  AgentPresetType.codex,
                  context.l10n.agentPresetCodex,
                ),
                _buildPresetChoice(
                  AgentPresetType.openCode,
                  context.l10n.agentPresetOpenCode,
                ),
                _buildPresetChoice(
                  AgentPresetType.agy,
                  context.l10n.agentPresetAgy,
                ),
                _buildPresetChoice(
                  AgentPresetType.custom,
                  context.l10n.agentPresetCustom,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Group 2: Basic info
          _buildSectionHeader(
            context,
            context.l10n.agentGroupBasic,
            Icons.badge_outlined,
          ),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '${context.l10n.agentNameLabel} *',
              hintText: context.l10n.agentNameHint,
              prefixIcon: const Icon(Icons.badge_outlined, size: 18),
              border: const OutlineInputBorder(),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return context.l10n.agentNameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: context.l10n.agentDescriptionLabel,
              hintText: context.l10n.agentDescriptionHint,
              prefixIcon: const Icon(Icons.description_outlined, size: 18),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),

          // Group: Execution Target (host vs docker)
          _buildSectionHeader(
            context,
            context.l10n.agentExecutionTarget,
            Icons.dns_outlined,
          ),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'host',
                label: Text(
                  context.l10n.agentExecutionHost,
                  key: const Key('agent_target_host'),
                ),
                icon: const Icon(Icons.computer, size: 16),
              ),
              ButtonSegment<String>(
                value: 'docker',
                label: Text(
                  context.l10n.agentExecutionDocker,
                  key: const Key('agent_target_docker'),
                ),
                icon: const Icon(Icons.layers_outlined, size: 16),
              ),
            ],
            selected: {_executionTarget},
            onSelectionChanged: (selected) {
              if (selected.isNotEmpty) {
                final newTarget = selected.first;
                setState(() {
                  _executionTarget = newTarget;
                  if (newTarget == 'docker') {
                    if (_containers == null && !_isLoadingContainers) {
                      _fetchContainers();
                    }
                    if (_containerReferenceController.text.trim().isNotEmpty &&
                        _containerUsers == null &&
                        !_isLoadingContainerUsers) {
                      _fetchContainerUsers();
                    }
                  }
                });
              }
            },
          ),
          if (_executionTarget == 'docker') ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.agentContainerBinding,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'id',
                  label: Text(
                    context.l10n.agentContainerBindingId,
                    key: const Key('agent_binding_id'),
                  ),
                ),
                ButtonSegment<String>(
                  value: 'name',
                  label: Text(
                    context.l10n.agentContainerBindingName,
                    key: const Key('agent_binding_name'),
                  ),
                ),
              ],
              selected: {_containerBinding},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) {
                  setState(() {
                    _containerBinding = selected.first;
                    if (_containers != null && _containers!.isNotEmpty) {
                      final current = _containerReferenceController.text.trim();
                      final match = _containers!.firstWhere(
                        (c) => c.id == current || c.name == current,
                        orElse: () => _containers!.first,
                      );
                      _containerReferenceController.text =
                          _containerBinding == 'id' ? match.id : match.name;
                    }
                    _containerUsers = null;
                    _selectedContainerUser = null;
                    _containerUsersError = null;
                  });
                  _containerRefDebounce?.cancel();
                  if (_containerReferenceController.text.trim().isNotEmpty) {
                    _fetchContainerUsers();
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            if (_isLoadingContainers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.agentLoadingContainers,
                      key: const Key('agent_loading_containers'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              )
            else if (_containersError != null)
              Container(
                key: const Key('agent_containers_error'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.agentContainersLoadFailed(
                          _containersError!,
                        ),
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                    IconButton(
                      key: const Key('agent_containers_refresh_button'),
                      icon: const Icon(Icons.refresh, size: 16),
                      tooltip: context.l10n.agentActionRefresh,
                      onPressed: _fetchContainers,
                    ),
                  ],
                ),
              )
            else if (_containers != null) ...[
              if (_containers!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    context.l10n.agentNoContainersFound,
                    key: const Key('agent_no_containers'),
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: context.colorScheme.outline,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('agent_container_dropdown'),
                        decoration: InputDecoration(
                          labelText: context.l10n.agentContainerReferenceHint,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.layers, size: 18),
                        ),
                        initialValue:
                            _containers!.any(
                              (c) =>
                                  (_containerBinding == 'id' ? c.id : c.name) ==
                                  _containerReferenceController.text.trim(),
                            )
                            ? (_containerBinding == 'id'
                                  ? _containers!
                                        .firstWhere(
                                          (c) =>
                                              c.id ==
                                              _containerReferenceController.text
                                                  .trim(),
                                        )
                                        .id
                                  : _containers!
                                        .firstWhere(
                                          (c) =>
                                              c.name ==
                                              _containerReferenceController.text
                                                  .trim(),
                                        )
                                        .name)
                            : null,
                        items: _containers!.map((c) {
                          final val = _containerBinding == 'id' ? c.id : c.name;
                          final display =
                              '${c.name} (${c.id.length > 12 ? c.id.substring(0, 12) : c.id})';
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(
                              display,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (selected) {
                          if (selected != null) {
                            setState(() {
                              _containerReferenceController.text = selected;
                              _containerUsers = null;
                              _selectedContainerUser = null;
                              _containerUsersError = null;
                            });
                            _containerRefDebounce?.cancel();
                            _fetchContainerUsers();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const Key('agent_containers_refresh_button'),
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: context.l10n.agentActionRefresh,
                      onPressed: _fetchContainers,
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('agent_container_reference_field'),
              controller: _containerReferenceController,
              decoration: InputDecoration(
                labelText: '${context.l10n.agentContainerReference} *',
                hintText: context.l10n.agentContainerReferenceHint,
                prefixIcon: const Icon(Icons.pin, size: 18),
                border: const OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'JetBrains Mono'),
              onChanged: (val) {
                _containerRefDebounce?.cancel();
                final trimmed = val.trim();
                setState(() {
                  _containerUsers = null;
                  _selectedContainerUser = null;
                  _containerUsersError = null;
                  if (trimmed.isEmpty) {
                    _isLoadingContainerUsers = false;
                  }
                });
                if (trimmed.isNotEmpty) {
                  _containerRefDebounce = Timer(
                    const Duration(milliseconds: 350),
                    () {
                      if (mounted &&
                          _executionTarget == 'docker' &&
                          _containerReferenceController.text
                              .trim()
                              .isNotEmpty) {
                        _fetchContainerUsers();
                      }
                    },
                  );
                }
              },
              validator: (val) {
                if (_executionTarget == 'docker' &&
                    (val == null || val.trim().isEmpty)) {
                  return context.l10n.agentContainerRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 500;

                final userDropdownWidget = InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.l10n.agentContainerUserSelect,
                    hintText: _isLoadingContainerUsers
                        ? context.l10n.agentContainerUsersLoading
                        : (_containerUsersError != null
                              ? context.l10n.agentContainerUsersFailed(
                                  _containerUsersError!,
                                )
                              : (_containerUsers != null &&
                                        _containerUsers!.isEmpty
                                    ? context.l10n.agentContainerUsersEmpty
                                    : context.l10n.agentContainerUserSelect)),
                    prefixIcon: const Icon(Icons.group_outlined, size: 18),
                    suffixIcon: _isLoadingContainerUsers
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_containerUsersError != null
                              ? Tooltip(
                                  message: context.l10n
                                      .agentContainerUsersFailed(
                                        _containerUsersError!,
                                      ),
                                  child: const Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                )
                              : null),
                    helperText: _containerUsersError != null
                        ? context.l10n.agentContainerUsersFailed(
                            _containerUsersError!,
                          )
                        : null,
                    helperStyle: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                    ),
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('agent_container_user_dropdown'),
                      isDense: true,
                      isExpanded: true,
                      value:
                          (_containerUsers != null &&
                              _containerUsers!.any(
                                (u) =>
                                    u.executionValue == _selectedContainerUser,
                              ))
                          ? _selectedContainerUser
                          : null,
                      items: (_containerUsers ?? []).map((u) {
                        return DropdownMenuItem<String>(
                          value: u.executionValue,
                          child: Text(
                            '${u.name} · UID ${u.uid} · GID ${u.gid}',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged:
                          (_isLoadingContainerUsers ||
                              _containerUsers == null ||
                              _containerUsers!.isEmpty)
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedContainerUser = val;
                                  _containerUserController.text = val;
                                });
                              }
                            },
                    ),
                  ),
                );

                final manualFieldWidget = TextFormField(
                  key: const Key('agent_container_user_field'),
                  controller: _containerUserController,
                  decoration: InputDecoration(
                    labelText: context.l10n.agentContainerUser,
                    hintText: context.l10n.agentContainerUserHint,
                    helperText: context.l10n.agentContainerUserHelper,
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'JetBrains Mono'),
                );

                if (isNarrow) {
                  return Column(
                    key: const Key('agent_container_user_layout_narrow'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      userDropdownWidget,
                      const SizedBox(height: 10),
                      manualFieldWidget,
                    ],
                  );
                }

                return Row(
                  key: const Key('agent_container_user_layout_wide'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: userDropdownWidget),
                    const SizedBox(width: 10),
                    Expanded(child: manualFieldWidget),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 10),

          // Group 3: Commands
          _buildSectionHeader(
            context,
            context.l10n.agentGroupCommands,
            Icons.terminal_outlined,
          ),
          TextFormField(
            controller: _cliController,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: '${context.l10n.agentCliCommandLabel} *',
              hintText: context.l10n.agentCliCommandHint,
              prefixIcon: const Icon(Icons.terminal, size: 18),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'JetBrains Mono'),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return context.l10n.agentCliRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _acpController,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.l10n.agentAcpCommandLabel,
              hintText: context.l10n.agentAcpCommandHint,
              helperText: context.l10n.agentAcpOptional,
              prefixIcon: const Icon(Icons.cable, size: 18),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'JetBrains Mono'),
          ),
          const SizedBox(height: 10),

          // Group 4: Install & Login
          _buildSectionHeader(
            context,
            context.l10n.agentGroupAuth,
            Icons.verified_user_outlined,
          ),
          TextFormField(
            controller: _installController,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.l10n.agentInstallCommandLabel,
              hintText: context.l10n.agentInstallCommandHint,
              prefixIcon: const Icon(Icons.download_outlined, size: 18),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'JetBrains Mono'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _acpInstallController,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.l10n.agentInstallCommandAcpLabel,
              hintText: context.l10n.agentInstallCommandAcpHint,
              prefixIcon: const Icon(
                Icons.download_for_offline_outlined,
                size: 18,
              ),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'JetBrains Mono'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loginCheckController,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.l10n.agentLoginCheckCommandLabel,
              hintText: context.l10n.agentLoginCheckCommandHint,
              prefixIcon: const Icon(Icons.fact_check_outlined, size: 18),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'JetBrains Mono'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loginController,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.l10n.agentLoginCommandLabel,
              hintText: context.l10n.agentLoginCommandHint,
              prefixIcon: const Icon(Icons.login_outlined, size: 18),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'JetBrains Mono'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    final dialogTitle = _isEditing
        ? context.l10n.editAgent
        : context.l10n.addAgentButton;

    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  color: context.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(dialogTitle, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _isSaving ? null : () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _buildFormContent(context),
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ),
            child: SafeArea(top: false, child: _buildActionButtons(context)),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy,
                    color: context.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dialogTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildFormContent(context),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildActionButtons(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChoice(AgentPresetType preset, String label) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => _applyPreset(preset),
    );
  }
}
