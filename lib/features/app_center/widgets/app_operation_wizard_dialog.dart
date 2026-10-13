import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/services/application_compose_service.dart';
import '../../../core/services/application_deployment_service.dart';
import '../../../core/services/remote_browser_service.dart';
import '../../../data/models/application_center.dart';
import '../../../data/models/remote_browser.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';
import '../../../widgets/remote_browser_dialog.dart';
import '../../nas/widgets/jellyfin_source_actions.dart';
import 'app_center_error_resolver.dart';

class AppOperationWizardDialog extends ConsumerStatefulWidget {
  final ApplicationOperation operation;
  final CatalogApplication? catalogApp;
  final ApplicationDeployment? deployment;
  final ApplicationTemplate? initialTemplate;
  final ApplicationConfiguration? initialConfiguration;
  final bool initialJellyfinSoftwareMode;
  final void Function(int tabIndex)? onNavigateToTab;

  const AppOperationWizardDialog({
    super.key,
    required this.operation,
    this.catalogApp,
    this.deployment,
    this.initialTemplate,
    this.initialConfiguration,
    this.initialJellyfinSoftwareMode = false,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    required ApplicationOperation operation,
    CatalogApplication? catalogApp,
    ApplicationDeployment? deployment,
    ApplicationTemplate? initialTemplate,
    ApplicationConfiguration? initialConfiguration,
    bool initialJellyfinSoftwareMode = false,
    void Function(int tabIndex)? onNavigateToTab,
  }) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    if (isCompact) {
      return Navigator.push<void>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AppOperationWizardDialog(
            operation: operation,
            catalogApp: catalogApp,
            deployment: deployment,
            initialTemplate: initialTemplate,
            initialConfiguration: initialConfiguration,
            initialJellyfinSoftwareMode: initialJellyfinSoftwareMode,
            onNavigateToTab: onNavigateToTab,
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppOperationWizardDialog(
        operation: operation,
        catalogApp: catalogApp,
        deployment: deployment,
        initialTemplate: initialTemplate,
        initialConfiguration: initialConfiguration,
        initialJellyfinSoftwareMode: initialJellyfinSoftwareMode,
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }

  @override
  ConsumerState<AppOperationWizardDialog> createState() =>
      _AppOperationWizardDialogState();
}

enum _WizardStep { environment, config, review, progress }

class _AppOperationWizardDialogState
    extends ConsumerState<AppOperationWizardDialog> {
  late final ApplicationCenterNotifier _appCenterNotifier;
  String? _observedTaskId;
  late _WizardStep _currentStep;
  late final String _instanceId;
  late bool _jellyfinSoftwareMode;
  Object? _capturedServerKey;
  String? _capturedDeploymentId;

  // Controllers & Form State
  final _sudoPasswordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _dataRootCtrl = TextEditingController();
  final Map<String, TextEditingController> _portControllers = {};
  final Map<String, TextEditingController> _mountControllers = {};
  final Map<String, TextEditingController> _variableControllers = {};
  final Map<String, TextEditingController> _envControllers = {};
  String _previousDataRoot = '';
  String _bindAddress = '127.0.0.1';
  bool _bindAddressExplicitlyChosen = false;
  bool _instanceContainerNames = true;
  String? _mainService;
  List<ApplicationPort> _ports = [];
  List<ApplicationMount> _mounts = [];
  Map<String, String> _variables = {};
  Map<String, Map<String, String>> _environment = {};

  ApplicationTemplate? _template;
  ApplicationOperationPlan? _plan;
  ApplicationTask? _runningTask;

  Timer? _tickTimer;
  DateTime? _terminalElapsedAt;
  bool _initialProgressLogScrolled = false;
  final ScrollController _progressLogScrollController = ScrollController();
  bool _followLatestProgress = true;

  bool _isLoading = false;
  bool _isCancelling = false;
  bool _isRechecking = false;
  String? _errorMessage;

  void _syncControllers() {
    for (final port in _ports) {
      final text = '${port.published}';
      final ctrl = _portControllers.putIfAbsent(
        port.key,
        () => TextEditingController(text: text),
      );
      if (ctrl.text != text) {
        ctrl.value = ctrl.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange.empty,
        );
      }
    }
    for (final mount in _mounts) {
      final ctrl = _mountControllers.putIfAbsent(
        mount.key,
        () => TextEditingController(text: mount.source),
      );
      if (ctrl.text != mount.source) {
        ctrl.value = ctrl.value.copyWith(
          text: mount.source,
          selection: TextSelection.collapsed(offset: mount.source.length),
          composing: TextRange.empty,
        );
      }
    }
    for (final entry in _variables.entries) {
      final ctrl = _variableControllers.putIfAbsent(
        entry.key,
        () => TextEditingController(text: entry.value),
      );
      if (ctrl.text != entry.value) {
        ctrl.value = ctrl.value.copyWith(
          text: entry.value,
          selection: TextSelection.collapsed(offset: entry.value.length),
          composing: TextRange.empty,
        );
      }
    }
    for (final svcEntry in _environment.entries) {
      for (final envEntry in svcEntry.value.entries) {
        final ctrlKey = '${svcEntry.key}/${envEntry.key}';
        final ctrl = _envControllers.putIfAbsent(
          ctrlKey,
          () => TextEditingController(text: envEntry.value),
        );
        if (ctrl.text != envEntry.value) {
          ctrl.value = ctrl.value.copyWith(
            text: envEntry.value,
            selection: TextSelection.collapsed(offset: envEntry.value.length),
            composing: TextRange.empty,
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _appCenterNotifier = ref.read(applicationCenterProvider.notifier);
    final activeServer = ref.read(activeServerProvider);
    _capturedServerKey = activeServer?.connectionKey;
    _capturedDeploymentId = widget.deployment?.id;
    _instanceId =
        widget.deployment?.id ??
        widget.initialConfiguration?.variables['AppID'] ??
        ApplicationDeploymentService.newId();
    _jellyfinSoftwareMode =
        widget.initialConfiguration?.jellyfinSoftwareMode ??
        widget.initialJellyfinSoftwareMode;

    _currentStep = _WizardStep.environment;
    _template = widget.initialTemplate;
    _initConfiguration();
    _inspectInitialEnv();

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _currentStep == _WizardStep.progress) {
        setState(() {});
      }
    });
    _progressLogScrollController.addListener(() {
      if (!_progressLogScrollController.hasClients) return;
      final max = _progressLogScrollController.position.maxScrollExtent;
      final current = _progressLogScrollController.position.pixels;
      if (max - current > 40) {
        if (_followLatestProgress) {
          setState(() => _followLatestProgress = false);
        }
      } else {
        if (!_followLatestProgress) {
          setState(() => _followLatestProgress = true);
        }
      }
    });
  }

  bool _isTargetValid() {
    if (!mounted) return false;
    final currentServer = ref.read(activeServerProvider);
    if (currentServer?.connectionKey != _capturedServerKey) return false;
    if (widget.deployment != null &&
        widget.deployment!.id != _capturedDeploymentId) {
      return false;
    }
    return true;
  }

  void _initConfiguration() {
    if (widget.initialConfiguration != null) {
      final config = widget.initialConfiguration!;
      _nameCtrl.text = config.name;
      _dataRootCtrl.text = config.dataRoot;
      _previousDataRoot = config.dataRoot;
      _bindAddress = config.bindAddress;
      _bindAddressExplicitlyChosen = true;
      _instanceContainerNames = config.instanceContainerNames;
      _mainService =
          config.mainService ??
          (_template != null
              ? ApplicationComposeService.suggestedMainService(_template!)
              : null);
      _ports = List.of(config.ports);
      _mounts = List.of(config.mounts);
      _variables = Map.of(config.variables);
      _variables['AppID'] = _instanceId;
      _environment = config.environment.map((k, v) => MapEntry(k, Map.of(v)));
    } else {
      _nameCtrl.text = widget.catalogApp?.id ?? 'app';
      _dataRootCtrl.text = '';
      _previousDataRoot = '';
      _bindAddress = '127.0.0.1';
      _bindAddressExplicitlyChosen = widget.deployment != null;
      _instanceContainerNames = true;
      _mainService = _template != null
          ? ApplicationComposeService.suggestedMainService(_template!)
          : null;
      _variables['AppID'] = _instanceId;
    }
    _syncControllers();
  }

  Future<void> _inspectInitialEnv() async {
    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(applicationCenterProvider.notifier);
      final env = await notifier.inspectEnvironment();
      if (!_isTargetValid()) return;

      if (_template == null && widget.catalogApp != null) {
        _template = await notifier.loadTemplate(widget.catalogApp!);
        if (!_isTargetValid()) return;
      }

      if (widget.initialConfiguration != null && _template != null) {
        try {
          final merged = notifier.configurationForTemplate(
            _template!,
            widget.initialConfiguration!,
            _instanceId,
          );
          _nameCtrl.text = merged.name;
          _dataRootCtrl.text = merged.dataRoot;
          _previousDataRoot = merged.dataRoot;
          _bindAddress = merged.bindAddress;
          _instanceContainerNames =
              widget.initialConfiguration!.instanceContainerNames;
          _mainService =
              widget.initialConfiguration!.mainService ??
              ApplicationComposeService.suggestedMainService(_template!);
          _ports = List.of(merged.ports);
          _mounts = List.of(merged.mounts);
          _variables = Map.of(merged.variables);
          _variables['AppID'] = _instanceId;
          _environment = merged.environment.map(
            (k, v) => MapEntry(k, Map.of(v)),
          );
          _syncControllers();
        } catch (_) {}
      } else if (widget.initialConfiguration == null && _template != null) {
        try {
          final def = notifier.defaultConfiguration(
            _template!,
            instanceId: _instanceId,
            variables: {..._variables, 'AppID': _instanceId},
            jellyfinSoftwareMode: _jellyfinSoftwareMode,
          );
          _nameCtrl.text = def.name;
          _dataRootCtrl.text = def.dataRoot;
          _previousDataRoot = def.dataRoot;
          _bindAddress = def.bindAddress;
          _instanceContainerNames = def.instanceContainerNames;
          _mainService =
              def.mainService ??
              ApplicationComposeService.suggestedMainService(_template!);
          _ports = List.of(def.ports);
          _mounts = List.of(def.mounts);
          _variables = Map.of(def.variables);
          _variables['AppID'] = _instanceId;
          _environment = def.environment.map((k, v) => MapEntry(k, Map.of(v)));
          _syncControllers();
        } catch (_) {
          for (final v in _template!.variables) {
            _variables.putIfAbsent(v, () => '');
          }
          _variables['AppID'] = _instanceId;
          if (_dataRootCtrl.text.isEmpty && env.ready) {
            _dataRootCtrl.text =
                '${env.home}/.local/share/valhalla/apps/$_instanceId';
            _previousDataRoot = _dataRootCtrl.text;
          }
          _syncControllers();
        }
      }

      if (mounted) {
        if (env.ready && widget.operation != ApplicationOperation.bootstrap) {
          _currentStep = _WizardStep.config;
        }
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _progressLogScrollController.dispose();
    if (_observedTaskId != null) {
      try {
        _appCenterNotifier.clearObservedTask(_observedTaskId!);
      } catch (_) {}
    }
    _sudoPasswordCtrl.dispose();
    _nameCtrl.dispose();
    _dataRootCtrl.dispose();
    for (final c in _portControllers.values) {
      c.dispose();
    }
    for (final c in _mountControllers.values) {
      c.dispose();
    }
    for (final c in _variableControllers.values) {
      c.dispose();
    }
    for (final c in _envControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0s';
    final s = d.inSeconds;
    if (s < 60) return '${s}s';
    final m = d.inMinutes;
    final remS = s % 60;
    if (m < 60) return '${m}m ${remS}s';
    final h = d.inHours;
    final remM = m % 60;
    return '${h}h ${remM}m';
  }

  Future<void> _bootstrapEnvironment() async {
    if (_isLoading ||
        !_isTargetValid() ||
        _currentStep != _WizardStep.environment) {
      return;
    }
    _isLoading = true;
    setState(() {
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(applicationCenterProvider.notifier);
      final plan = await notifier.prepare(
        ApplicationOperation.bootstrap,
        sudoPassword: _sudoPasswordCtrl.text.isNotEmpty
            ? _sudoPasswordCtrl.text
            : null,
      );
      if (!_isTargetValid()) return;
      setState(() {
        _plan = plan;
        _currentStep = _WizardStep.review;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApplicationCenterException
              ? resolveAppCenterErrorMessage(context, e.code, e.detail)
              : e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _preparePlan() async {
    if (_isLoading || !_isTargetValid() || _currentStep != _WizardStep.config) {
      return;
    }
    final isExistingDeployment =
        widget.deployment != null || widget.initialConfiguration != null;
    if (!isExistingDeployment && !_bindAddressExplicitlyChosen) {
      setState(() {
        _errorMessage = context.appCenterExternalPortWarningLabel;
      });
      return;
    }
    _isLoading = true;
    setState(() {
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(applicationCenterProvider.notifier);
      _variables['AppID'] = _instanceId;

      for (final ctrl in _portControllers.values) {
        final parsed = int.tryParse(ctrl.text.trim());
        if (parsed == null || parsed < 1 || parsed > 65535) {
          throw const ApplicationCenterException('APP_CENTER_PORT_INVALID');
        }
      }
      if (_ports.isNotEmpty) {
        final validatedPorts = <ApplicationPort>[];
        for (final port in _ports) {
          final ctrl = _portControllers[port.key];
          final rawText = (ctrl != null ? ctrl.text : '${port.published}')
              .trim();
          final parsed = int.tryParse(rawText);
          if (parsed == null || parsed < 1 || parsed > 65535) {
            throw const ApplicationCenterException('APP_CENTER_PORT_INVALID');
          }
          validatedPorts.add(
            ApplicationPort(
              service: port.service,
              target: port.target,
              published: parsed,
              protocol: port.protocol,
              bindAddress: port.bindAddress,
            ),
          );
        }
        _ports = validatedPorts;
      }

      if (_template != null) {
        if (_ports.isEmpty && _mounts.isEmpty) {
          final def = notifier.defaultConfiguration(
            _template!,
            instanceId: _instanceId,
            variables: {..._variables, 'AppID': _instanceId},
            jellyfinSoftwareMode: _jellyfinSoftwareMode,
          );
          _ports = List.of(def.ports);
          _mounts = List.of(def.mounts);
          _environment = def.environment.map((k, v) => MapEntry(k, Map.of(v)));
          _syncControllers();
        } else {
          final current = ApplicationConfiguration(
            name: _nameCtrl.text.trim(),
            dataRoot: _dataRootCtrl.text.trim(),
            bindAddress: _bindAddress,
            instanceContainerNames: _instanceContainerNames,
            mainService: _mainService,
            ports: _ports,
            mounts: _mounts,
            variables: {..._variables, 'AppID': _instanceId},
            environment: _environment,
            jellyfinSoftwareMode: _jellyfinSoftwareMode,
          );
          final updated = notifier.configurationWithVariables(
            _template!,
            current,
            _instanceId,
            {..._variables, 'AppID': _instanceId},
          );
          _ports = List.of(updated.ports);
          _mounts = List.of(updated.mounts);
          _environment = updated.environment.map(
            (k, v) => MapEntry(k, Map.of(v)),
          );
          _syncControllers();
        }
      }

      if (_instanceContainerNames) {
        if (!ApplicationComposeService.isValidContainerName(
          _nameCtrl.text.trim(),
        )) {
          setState(() {
            _errorMessage = context.l10n.appCenterContainerNameInvalid;
          });
          return;
        }
        if (_template != null) {
          final serviceNames = ApplicationComposeService.serviceNames(
            _template!,
          );
          final effectiveMain =
              _mainService ??
              ApplicationComposeService.suggestedMainService(_template!);
          if (serviceNames.length > 1 &&
              (effectiveMain == null ||
                  !serviceNames.contains(effectiveMain))) {
            setState(() {
              _errorMessage = context.l10n.appCenterMainService;
            });
            return;
          }
          if (_mainService == null && effectiveMain != null) {
            _mainService = effectiveMain;
          }
        }
      }

      final effectiveMain =
          _mainService ??
          (_template != null
              ? ApplicationComposeService.suggestedMainService(_template!)
              : null);
      final config = ApplicationConfiguration(
        name: _nameCtrl.text.trim(),
        dataRoot: _dataRootCtrl.text.trim(),
        bindAddress: _bindAddress,
        instanceContainerNames: _instanceContainerNames,
        mainService: effectiveMain,
        ports: _ports,
        mounts: _mounts,
        variables: {..._variables, 'AppID': _instanceId},
        environment: _environment,
        jellyfinSoftwareMode: _jellyfinSoftwareMode,
      );

      final plan = await notifier.prepare(
        widget.operation,
        template: _template,
        configuration: config,
        deployment: widget.deployment,
        sudoPassword: _sudoPasswordCtrl.text.isNotEmpty
            ? _sudoPasswordCtrl.text
            : null,
      );
      if (!_isTargetValid()) return;
      setState(() {
        _plan = plan;
        _currentStep = _WizardStep.review;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApplicationCenterException
              ? resolveAppCenterErrorMessage(context, e.code, e.detail)
              : e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _executePlan() async {
    if (_isLoading ||
        !_isTargetValid() ||
        _currentStep != _WizardStep.review ||
        _runningTask != null ||
        _plan == null) {
      return;
    }
    _isLoading = true;
    setState(() {
      _errorMessage = null;
    });
    try {
      final task = await _appCenterNotifier.execute(_plan!);
      if (!_isTargetValid()) return;
      _observedTaskId = task.id;
      _appCenterNotifier.setObservedTask(task.id);
      setState(() {
        _runningTask = task;
        _currentStep = _WizardStep.progress;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApplicationCenterException
              ? resolveAppCenterErrorMessage(context, e.code, e.detail)
              : e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _rebaseMounts(String oldRoot, String newRoot) {
    if (oldRoot.isEmpty || newRoot.isEmpty || oldRoot == newRoot) return;
    final oldPrefix = oldRoot.endsWith('/') ? oldRoot : '$oldRoot/';
    final newPrefix = newRoot.endsWith('/') ? newRoot : '$newRoot/';
    setState(() {
      _mounts = _mounts.map((m) {
        if (m.source == oldRoot) {
          return ApplicationMount(
            service: m.service,
            target: m.target,
            source: newRoot,
            readOnly: m.readOnly,
          );
        }
        if (m.source.startsWith(oldPrefix)) {
          final rel = m.source.substring(oldPrefix.length);
          return ApplicationMount(
            service: m.service,
            target: m.target,
            source: '$newPrefix$rel',
            readOnly: m.readOnly,
          );
        }
        return m;
      }).toList();
      _syncControllers();
    });
  }

  Future<void> _pickDataDirectory() async {
    final env = ref.read(applicationCenterProvider).environment;
    final current = _dataRootCtrl.text.trim();
    String initial = env?.home.isNotEmpty == true ? env!.home : '/home';
    if (current.isNotEmpty) {
      final trimmed = current.endsWith('/') && current.length > 1
          ? current.substring(0, current.length - 1)
          : current;
      final idx = trimmed.lastIndexOf('/');
      if (idx > 0) {
        initial = trimmed.substring(0, idx);
      } else if (idx == 0) {
        initial = '/';
      }
    }

    bool currentDraft() =>
        mounted && _isTargetValid() && _dataRootCtrl.text.trim() == current;
    final factory = ref.read(remoteBrowserFactoryProvider);
    RemoteBrowserSource? source;
    try {
      source = factory.host(initialPath: initial, isCurrent: currentDraft);
      final picked = await RemoteBrowserDialog.pickDirectory(
        context,
        source,
        initialPath: initial,
        title: context.l10n.appCenterBrowseDirectory,
      );
      if (picked != null && source.isCurrent && currentDraft()) {
        final String target;
        if (picked.endsWith('/$_instanceId')) {
          target = picked;
        } else if (picked == '/') {
          target = '/$_instanceId';
        } else if (picked.endsWith('/')) {
          target = '${picked.substring(0, picked.length - 1)}/$_instanceId';
        } else {
          target = '$picked/$_instanceId';
        }
        final oldRoot = _dataRootCtrl.text.trim();
        setState(() {
          _dataRootCtrl.text = target;
          _rebaseMounts(oldRoot, target);
          _previousDataRoot = target;
        });
      }
    } catch (_) {
      if (mounted && currentDraft()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.stateError)));
      }
    } finally {
      await source?.dispose();
    }
  }

  Future<void> _pickMountDirectory(int mountIndex) async {
    if (mountIndex < 0 || mountIndex >= _mounts.length) return;
    final mount = _mounts[mountIndex];
    final env = ref.read(applicationCenterProvider).environment;
    final initial = mount.source.isNotEmpty
        ? mount.source
        : (env?.home ?? '/home');
    bool currentDraft() =>
        mounted &&
        _isTargetValid() &&
        mountIndex < _mounts.length &&
        identical(_mounts[mountIndex], mount);
    final factory = ref.read(remoteBrowserFactoryProvider);
    RemoteBrowserSource? source;
    try {
      source = factory.host(initialPath: initial, isCurrent: currentDraft);
      final picked = await RemoteBrowserDialog.pickDirectory(
        context,
        source,
        initialPath: initial,
        title: context.l10n.appCenterBrowseDirectory,
      );
      if (picked != null && source.isCurrent && currentDraft()) {
        setState(() {
          final updated = List<ApplicationMount>.from(_mounts);
          final oldMount = updated[mountIndex];
          updated[mountIndex] = ApplicationMount(
            service: oldMount.service,
            target: oldMount.target,
            source: picked,
            readOnly: oldMount.readOnly,
          );
          _mounts = updated;
          _syncControllers();
        });
      }
    } catch (_) {
      if (mounted && currentDraft()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.stateError)));
      }
    } finally {
      await source?.dispose();
    }
  }

  void _onVariableChanged(String key, String val) {
    if (_variables[key] == val) return;
    final currentVariables = Map<String, String>.from(_variables);
    _variables[key] = val;
    _variables['AppID'] = _instanceId;
    if (_template == null) return;

    if (_ports.isEmpty && _mounts.isEmpty) {
      try {
        final def = ref
            .read(applicationCenterProvider.notifier)
            .defaultConfiguration(
              _template!,
              instanceId: _instanceId,
              variables: {..._variables, 'AppID': _instanceId},
              jellyfinSoftwareMode: _jellyfinSoftwareMode,
            );
        setState(() {
          _ports = List.of(def.ports);
          _mounts = List.of(def.mounts);
          _environment = def.environment.map((k, v) => MapEntry(k, Map.of(v)));
          _syncControllers();
        });
      } catch (_) {}
    } else {
      try {
        final currentConfig = ApplicationConfiguration(
          name: _nameCtrl.text.trim(),
          dataRoot: _dataRootCtrl.text.trim(),
          bindAddress: _bindAddress,
          ports: _ports,
          mounts: _mounts,
          variables: {...currentVariables, 'AppID': _instanceId},
          environment: _environment,
          jellyfinSoftwareMode: _jellyfinSoftwareMode,
        );
        final updated = ref
            .read(applicationCenterProvider.notifier)
            .configurationWithVariables(
              _template!,
              currentConfig,
              _instanceId,
              {..._variables, 'AppID': _instanceId},
            );
        setState(() {
          _ports = List.of(updated.ports);
          _mounts = List.of(updated.mounts);
          _environment = updated.environment.map(
            (k, v) => MapEntry(k, Map.of(v)),
          );
          _syncControllers();
        });
      } catch (_) {}
    }
  }

  Widget _buildEnvironmentStep(ApplicationEnvironment? env) {
    final l10n = context.l10n;
    final isReady = env?.ready ?? false;
    final blockers = env?.blockers ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appCenterEnvironmentCheck,
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  env?.dockerAvailable == true
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: env?.dockerAvailable == true
                      ? context.vSuccess
                      : context.vDanger,
                ),
                title: Text(
                  env?.dockerAvailable == true
                      ? l10n.appCenterDockerFound
                      : l10n.appCenterDockerMissing,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  env?.composeAvailable == true
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: env?.composeAvailable == true
                      ? context.vSuccess
                      : context.vDanger,
                ),
                title: Text(
                  env?.composeAvailable == true
                      ? l10n.appCenterComposeFound
                      : l10n.appCenterComposeMissing,
                ),
              ),
              if (env != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'OS: ${env.os} ${env.osVersion} (${env.architecture}) | UID: ${env.uid} GID: ${env.gid}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (blockers.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...blockers.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.block, size: 14, color: context.vDanger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      resolveAppCenterBlockerMessage(context, b),
                      style: TextStyle(fontSize: 11, color: context.vDanger),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _sudoPasswordCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.appCenterSudoPassword,
            hintText: l10n.appCenterSudoPasswordHint,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
        ),
        if (!isReady && (env?.canBootstrap ?? false)) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appCenterBootstrapPrompt,
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.build_outlined, size: 16),
                  label: Text(l10n.appCenterBootstrapButton),
                  onPressed: _isLoading ? null : _bootstrapEnvironment,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfigStep() {
    final l10n = context.l10n;
    final isExistingDeployment =
        widget.deployment != null || widget.initialConfiguration != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: const ValueKey('app-config-name'),
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l10n.appCenterInstanceName,
              errorText:
                  _instanceContainerNames &&
                      !ApplicationComposeService.isValidContainerName(
                        _nameCtrl.text.trim(),
                      )
                  ? l10n.appCenterContainerNameInvalid
                  : null,
            ),
            onChanged: (val) {
              setState(() {});
            },
          ),
          if (_template != null && _instanceContainerNames) ...[
            Builder(
              builder: (context) {
                final serviceNames = ApplicationComposeService.serviceNames(
                  _template!,
                );
                final suggested =
                    ApplicationComposeService.suggestedMainService(_template!);
                final currentMain =
                    _mainService ??
                    (serviceNames.length == 1
                        ? serviceNames.single
                        : suggested);
                final validContainerName =
                    ApplicationComposeService.isValidContainerName(
                      _nameCtrl.text.trim(),
                    );
                Map<String, String>? namesPreview;
                if (validContainerName && currentMain != null) {
                  try {
                    final previewConfig = ApplicationConfiguration(
                      name: _nameCtrl.text.trim(),
                      dataRoot: _dataRootCtrl.text.trim(),
                      instanceContainerNames: true,
                      mainService: currentMain,
                    );
                    namesPreview = ApplicationComposeService.containerNames(
                      _template!,
                      previewConfig,
                    );
                  } catch (_) {}
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (serviceNames.length > 1) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('app-config-main-service'),
                        initialValue: _mainService,
                        decoration: InputDecoration(
                          labelText: l10n.appCenterMainService,
                        ),
                        items: serviceNames
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() => _mainService = val);
                        },
                      ),
                    ],
                    if (namesPreview != null && namesPreview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.appCenterContainerNamesPreview,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: namesPreview.entries
                            .map(
                              (e) => Chip(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                label: Text(
                                  '${e.key}: ${e.value}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('app-config-data-root'),
                  controller: _dataRootCtrl,
                  readOnly: isExistingDeployment,
                  decoration: InputDecoration(
                    labelText: l10n.appCenterDataDirectory,
                  ),
                  onChanged: isExistingDeployment
                      ? null
                      : (val) {
                          final newRoot = val.trim();
                          if (_previousDataRoot.isNotEmpty &&
                              newRoot.isNotEmpty &&
                              _previousDataRoot != newRoot) {
                            _rebaseMounts(_previousDataRoot, newRoot);
                            _previousDataRoot = newRoot;
                          }
                        },
                ),
              ),
              if (!isExistingDeployment) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(Icons.folder_open),
                  tooltip: l10n.appCenterBrowseDirectory,
                  onPressed: _pickDataDirectory,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.appCenterBindAddress, style: context.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.appCenterBindLoopback),
                selected:
                    _bindAddressExplicitlyChosen && _bindAddress == '127.0.0.1',
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _bindAddress = '127.0.0.1';
                      _bindAddressExplicitlyChosen = true;
                    });
                  }
                },
              ),
              ChoiceChip(
                label: Text(l10n.appCenterBindAll),
                selected:
                    _bindAddressExplicitlyChosen && _bindAddress == '0.0.0.0',
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _bindAddress = '0.0.0.0';
                      _bindAddressExplicitlyChosen = true;
                    });
                  }
                },
              ),
            ],
          ),
          if (_ports.any(
            (p) => p.effectiveBindAddress(_bindAddress) == '0.0.0.0',
          )) ...[
            const SizedBox(height: 8),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_update_warning_outlined,
                    color: context.vWarning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.appCenterExternalPortWarningLabel,
                      style: TextStyle(fontSize: 11, color: context.vWarning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_ports.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.appCenterPortMapping,
              style: context.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ..._ports.asMap().entries.map((entry) {
              final idx = entry.key;
              final port = entry.value;
              final ctrl = _portControllers.putIfAbsent(
                port.key,
                () => TextEditingController(text: '${port.published}'),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${port.service} (${port.protocol.toUpperCase()}) · ${context.appCenterTargetLabel}: ${port.target}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            key: ValueKey('port-${port.key}'),
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.appCenterHostPortLabel(
                                port.target.toString(),
                              ),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed != null) {
                                final updated = List<ApplicationPort>.from(
                                  _ports,
                                );
                                final currentPort = _ports[idx];
                                updated[idx] = ApplicationPort(
                                  service: currentPort.service,
                                  target: currentPort.target,
                                  published: parsed,
                                  protocol: currentPort.protocol,
                                  bindAddress: currentPort.bindAddress,
                                );
                                _ports = updated;
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey(
                              'bind_addr_${port.target}_${port.bindAddress}',
                            ),
                            initialValue: port.bindAddress,
                            isDense: true,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.appCenterBindAddress,
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  '${context.appCenterPortBindInheritLabel} ($_bindAddress)',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              const DropdownMenuItem<String?>(
                                value: '127.0.0.1',
                                child: Text(
                                  '127.0.0.1 (SSH)',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              DropdownMenuItem<String?>(
                                value: '0.0.0.0',
                                child: Text(
                                  '0.0.0.0 (${context.appCenterExternalLabel})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                final updated = List<ApplicationPort>.from(
                                  _ports,
                                );
                                final currentPort = _ports[idx];
                                updated[idx] = ApplicationPort(
                                  service: currentPort.service,
                                  target: currentPort.target,
                                  published: currentPort.published,
                                  protocol: currentPort.protocol,
                                  bindAddress: val,
                                );
                                _ports = updated;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
          if (_mounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.appCenterMounts, style: context.textTheme.titleSmall),
            const SizedBox(height: 6),
            ..._mounts.asMap().entries.map((entry) {
              final idx = entry.key;
              final mount = entry.value;
              final ctrl = _mountControllers.putIfAbsent(
                mount.key,
                () => TextEditingController(text: mount.source),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('mount-${mount.key}'),
                        controller: ctrl,
                        decoration: InputDecoration(
                          labelText: l10n.appCenterHostMountLabel(mount.target),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final updated = List<ApplicationMount>.from(_mounts);
                          updated[idx] = ApplicationMount(
                            service: mount.service,
                            target: mount.target,
                            source: val.trim(),
                            readOnly: mount.readOnly,
                          );
                          _mounts = updated;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open, size: 18),
                      tooltip: l10n.appCenterBrowseDirectory,
                      onPressed: () => _pickMountDirectory(idx),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (_variables.isNotEmpty) ...[
            (() {
              final editableVariables = _variables.entries
                  .where((entry) => entry.key != 'AppID')
                  .toList();
              if (editableVariables.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    l10n.appCenterVariables,
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  ...editableVariables.map((entry) {
                    final key = entry.key;
                    final val = entry.value;
                    final ctrl = _variableControllers.putIfAbsent(
                      key,
                      () => TextEditingController(text: val),
                    );
                    final isSecret = RegExp(
                      r'password|secret|token|key',
                      caseSensitive: false,
                    ).hasMatch(key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        key: ValueKey('var-$key'),
                        controller: ctrl,
                        obscureText: isSecret,
                        decoration: InputDecoration(
                          labelText: key,
                          isDense: true,
                        ),
                        onChanged: (newVal) => _onVariableChanged(key, newVal),
                      ),
                    );
                  }),
                ],
              );
            })(),
          ],
          if (_environment.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.appCenterEnvironmentVariables,
              style: context.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ..._environment.entries.map((svcEntry) {
              final serviceName = svcEntry.key;
              final envMap = svcEntry.value;
              if (envMap.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...envMap.entries.map((e) {
                      final envKey = e.key;
                      final envVal = e.value;
                      final ctrlKey = '$serviceName/$envKey';
                      final ctrl = _envControllers.putIfAbsent(
                        ctrlKey,
                        () => TextEditingController(text: envVal),
                      );
                      final isSecret = RegExp(
                        r'password|secret|token|key',
                        caseSensitive: false,
                      ).hasMatch(envKey);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextFormField(
                          key: ValueKey('env-$ctrlKey'),
                          controller: ctrl,
                          obscureText: isSecret,
                          decoration: InputDecoration(
                            labelText: envKey,
                            isDense: true,
                          ),
                          onChanged: (newVal) {
                            _environment[serviceName]![envKey] = newVal;
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final l10n = context.l10n;
    final plan = _plan;
    final env = ref.watch(applicationCenterProvider).environment;
    final measuredSpace = plan?.availableBytes != null
        ? SftpFileItem.formatBytes(plan!.availableBytes!)
        : null;
    final isUpdate = plan?.operation == ApplicationOperation.update;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preflight Summary Section
          Container(
            width: double.maxFinite,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(VRadius.card),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 18,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.appCenterPreflightSummaryLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (measuredSpace != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          plan!.availableBytes! > 0
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 14,
                          color: plan.availableBytes! > 0
                              ? context.vSuccess
                              : context.vDanger,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${context.appCenterMeasuredAvailableSpaceLabel}: $measuredSpace',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: plan.availableBytes! > 0
                                ? null
                                : context.vDanger,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (env != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.computer,
                          size: 14,
                          color: context.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${context.l10n.hardwareDistribution}: ${env.architecture}${env.dockerAvailable ? " (Docker)" : ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (_ports.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lan_outlined,
                          size: 14,
                          color: context.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${context.resolveSectionLabel('ports')}: ${_ports.map((p) => '${p.effectiveBindAddress(_bindAddress)}:${p.published}->${p.target}/${p.protocol}').join(', ')}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_mounts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_shared_outlined,
                          size: 14,
                          color: context.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${context.resolveSectionLabel('volumes')}: ${_mounts.length} ${context.l10n.sftpSelectedCount(_mounts.length)}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (_ports.any(
            (p) => p.effectiveBindAddress(_bindAddress) == '0.0.0.0',
          )) ...[
            Container(
              width: double.maxFinite,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_update_warning_outlined,
                    color: context.vWarning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.appCenterExternalPortWarningLabel,
                      style: TextStyle(fontSize: 12, color: context.vWarning),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.deployment != null &&
              _instanceContainerNames &&
              (widget.initialConfiguration?.instanceContainerNames ?? false) &&
              widget.deployment!.name != _nameCtrl.text.trim()) ...[
            Container(
              width: double.maxFinite,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.vWarning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.appCenterContainersRecreationNotice,
                      style: TextStyle(fontSize: 12, color: context.vWarning),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Update Comparison Section (only for update operations)
          if (isUpdate)
            Container(
              width: double.maxFinite,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.compare_arrows_rounded,
                        size: 18,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.appCenterUpdateComparisonLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${widget.deployment?.version ?? "N/A"} → ${widget.catalogApp?.version ?? _template?.application.version ?? context.l10n.appCenterVersionLatest}',
                        style: monoTextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (plan?.changedSections.isNotEmpty == true)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final section in plan!.changedSections)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            label: Text(
                              context.resolveSectionLabel(section),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    )
                  else
                    Text(
                      context.appCenterNoChangesDetectedLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),

          Text(l10n.appCenterPlanPreview, style: context.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l10n.appCenterPlanSanitizedNotice,
            style: TextStyle(fontSize: 12, color: context.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: SelectableText(
              plan?.preview.isNotEmpty == true
                  ? plan!.preview
                  : l10n.appCenterNoPreviewAvailable,
              style: monoTextStyle(
                fontSize: 11,
                color: const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelTask(ApplicationTask task) async {
    if (_isCancelling || !task.canCancel) return;
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.appCenterErrorNotConnected),
          backgroundColor: context.vDanger,
        ),
      );
      return;
    }
    setState(() => _isCancelling = true);
    try {
      await ref.read(applicationCenterProvider.notifier).cancelTask(task);
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        final msg = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: context.vDanger),
        );
      }
    } finally {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Future<void> _handleRecheckServer() async {
    if (_isRechecking) return;
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.appCenterErrorNotConnected),
          backgroundColor: context.vDanger,
        ),
      );
      return;
    }
    setState(() => _isRechecking = true);
    try {
      await ref.read(applicationCenterProvider.notifier).refreshServer();
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        final msg = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: context.vDanger),
        );
      }
    } finally {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        setState(() => _isRechecking = false);
      }
    }
  }

  Future<void> _handleOpenReconciledApp(
    ApplicationDeployment deployment,
  ) async {
    if (!_isTargetValid() ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        !ref.read(serverConnectionProvider).isConnected) {
      return;
    }
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    try {
      await ref
          .read(applicationCenterProvider.notifier)
          .openApplication(deployment);
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        final msg = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: context.vDanger),
        );
      }
    }
  }

  Widget _buildProgressStep() {
    final l10n = context.l10n;
    final state = ref.watch(applicationCenterProvider);
    final currentTask =
        state.tasks.where((t) => t.id == _runningTask?.id).firstOrNull ??
        _runningTask;

    ref.listen(
      applicationCenterProvider.select(
        (s) =>
            s.tasks.where((t) => t.id == _runningTask?.id).firstOrNull?.logTail,
      ),
      (prev, next) {
        if (_followLatestProgress && next != null && next != prev) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _followLatestProgress &&
                _progressLogScrollController.hasClients) {
              _progressLogScrollController.jumpTo(
                _progressLogScrollController.position.maxScrollExtent,
              );
            }
          });
        }
      },
    );

    if (!_initialProgressLogScrolled &&
        currentTask?.logTail.isNotEmpty == true) {
      _initialProgressLogScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _followLatestProgress &&
            _progressLogScrollController.hasClients) {
          _progressLogScrollController.jumpTo(
            _progressLogScrollController.position.maxScrollExtent,
          );
        }
      });
    }

    final isTerminal =
        currentTask?.stage == ApplicationTaskStage.succeeded ||
        currentTask?.stage == ApplicationTaskStage.failed ||
        currentTask?.stage == ApplicationTaskStage.cancelled;

    if (isTerminal) {
      if (_tickTimer != null) {
        _tickTimer?.cancel();
        _tickTimer = null;
      }
      _terminalElapsedAt ??= currentTask?.lastSyncedAt ?? DateTime.now();
    } else {
      _terminalElapsedAt = null;
      if (currentTask != null && currentTask.isBusy && _tickTimer == null) {
        _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && _currentStep == _WizardStep.progress) {
            setState(() {});
          }
        });
      }
    }

    final isBusy = currentTask?.isBusy ?? false;
    final isSucceeded = currentTask?.stage == ApplicationTaskStage.succeeded;
    final isFailed = currentTask?.stage == ApplicationTaskStage.failed;
    final isNeedsInspection =
        currentTask?.stage == ApplicationTaskStage.needsInspection;

    final now = DateTime.now();
    final elapsed = _terminalElapsedAt != null
        ? _terminalElapsedAt!.difference(currentTask!.createdAt)
        : (currentTask != null ? now.difference(currentTask.createdAt) : null);
    final elapsedStr = elapsed != null ? _formatDuration(elapsed) : null;
    final lastOutputStr =
        (currentTask != null && isBusy && currentTask.lastOutputAt != null)
        ? _formatDuration(now.difference(currentTask.lastOutputAt!))
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isSucceeded)
                Icon(Icons.check_circle, color: context.vSuccess, size: 22)
              else if (isFailed)
                Icon(Icons.error, color: context.vDanger, size: 22)
              else if (isNeedsInspection)
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.vWarning,
                  size: 22,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  switch (currentTask?.stage) {
                    ApplicationTaskStage.queued =>
                      l10n.appCenterTaskStageQueued,
                    ApplicationTaskStage.preparing =>
                      l10n.appCenterTaskStagePreparing,
                    ApplicationTaskStage.pulling =>
                      l10n.appCenterTaskStagePulling,
                    ApplicationTaskStage.applying =>
                      l10n.appCenterTaskStageApplying,
                    ApplicationTaskStage.checking =>
                      l10n.appCenterTaskStageChecking,
                    ApplicationTaskStage.succeeded =>
                      l10n.appCenterTaskStageSucceeded,
                    ApplicationTaskStage.failed =>
                      l10n.appCenterTaskStageFailed,
                    ApplicationTaskStage.cancelled =>
                      l10n.appCenterTaskStageCancelled,
                    ApplicationTaskStage.needsInspection =>
                      l10n.appCenterTaskStageNeedsInspection,
                    null => l10n.appCenterTaskStagePreparing,
                  },
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (elapsedStr != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${context.appCenterElapsedLabel}: $elapsedStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
          if (lastOutputStr != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${context.appCenterLastOutputLabel}: $lastOutputStr',
                style: TextStyle(
                  fontSize: 10,
                  color: context.colorScheme.outline,
                ),
              ),
            ),
          if (currentTask?.syncError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: context.vWarning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.appCenterSyncUnavailableLabel}: ${currentTask!.syncError}',
                      style: TextStyle(fontSize: 11, color: context.vWarning),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (currentTask?.currentCommand.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 14,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.appCenterCurrentCommandLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.colorScheme.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: l10n.appCenterCopyLog,
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: currentTask!.currentCommand),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.appCenterLogsCopied),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    currentTask!.currentCommand,
                    style: monoTextStyle(
                      fontSize: 11,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isNeedsInspection) ...[
            const SizedBox(height: 12),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: context.vWarning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.appCenterTaskNeedsInspectionTitleLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: context.vWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.appCenterTaskNeedsInspectionMessageLabel,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                l10n.appCenterLogs,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_followLatestProgress && isBusy) ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.arrow_downward, size: 14),
                  label: Text(
                    context.appCenterFollowLatestLogsLabel,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    setState(() => _followLatestProgress = true);
                    if (_progressLogScrollController.hasClients) {
                      _progressLogScrollController.animateTo(
                        _progressLogScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
                const SizedBox(width: 4),
              ],
              if (currentTask?.logTail.isNotEmpty == true)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: l10n.appCenterCopyLog,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: currentTask!.logTail),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.appCenterLogsCopied)),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: SingleChildScrollView(
              controller: _progressLogScrollController,
              child: SelectableText(
                currentTask?.logTail.isNotEmpty == true
                    ? currentTask!.logTail
                    : l10n.appCenterWaitingForLogs,
                style: monoTextStyle(
                  fontSize: 11,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(applicationCenterProvider);
    final env = state.environment;

    final currentTask =
        state.tasks.where((t) => t.id == _runningTask?.id).firstOrNull ??
        _runningTask;
    final isBootstrapPlan = _plan?.operation == ApplicationOperation.bootstrap;
    final isBootstrapSucceeded =
        isBootstrapPlan && currentTask?.stage == ApplicationTaskStage.succeeded;
    final isExistingDeployment =
        widget.deployment != null || widget.initialConfiguration != null;

    final title = switch (widget.operation) {
      ApplicationOperation.install => l10n.appCenterWizardTitle(
        widget.catalogApp?.title ?? '',
      ),
      ApplicationOperation.configure => l10n.appCenterConfigureTitle(
        widget.deployment?.name ?? '',
      ),
      ApplicationOperation.update => l10n.appCenterUpdateTitle(
        widget.deployment?.name ?? '',
      ),
      ApplicationOperation.bootstrap => l10n.appCenterBootstrapButton,
      _ => l10n.appCenterOperation,
    };

    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    Widget body;
    switch (_currentStep) {
      case _WizardStep.environment:
        body = _buildEnvironmentStep(env);
        break;
      case _WizardStep.config:
        body = _buildConfigStep();
        break;
      case _WizardStep.review:
        body = _buildReviewStep();
        break;
      case _WizardStep.progress:
        body = _buildProgressStep();
        break;
    }

    final activeServer = ref.watch(activeServerProvider);
    final connected = ref.watch(
      serverConnectionProvider.select((value) => value.isConnected),
    );
    final currentServerKey = activeServer == null
        ? null
        : ApplicationDeploymentService.serverKey(activeServer);
    final reconciledDeployment = state.deployments
        .where(
          (d) =>
              d.id == currentTask?.deploymentId &&
              d.serverKey == currentTask?.serverKey &&
              d.serverKey == currentServerKey,
        )
        .firstOrNull;

    final jellyfinDeployment =
        activeServer != null && activeServer.connectionKey == _capturedServerKey
        ? jellyfinDeploymentForTask(
            currentTask,
            state.deployments,
            activeServer,
          )
        : null;
    if (_currentStep == _WizardStep.progress &&
        jellyfinDeployment != null &&
        activeServer != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JellyfinSourceActions(
            key: ValueKey('docker-source-${jellyfinDeployment.id}'),
            server: activeServer,
            endpoint: jellyfinDeployment.endpoint!,
            name: jellyfinDeployment.name,
            showSetup: false,
          ),
          const SizedBox(height: 16),
          body,
        ],
      );
    }

    final isSucceeded = currentTask?.stage == ApplicationTaskStage.succeeded;
    final isNeedsInspection =
        currentTask?.stage == ApplicationTaskStage.needsInspection;
    final isFailed = currentTask?.stage == ApplicationTaskStage.failed;
    final isBusy = currentTask?.isBusy ?? false;

    final actions = <Widget>[
      if (_currentStep == _WizardStep.progress) ...[
        if (currentTask?.canCancel == true)
          OutlinedButton(
            onPressed: _isCancelling
                ? null
                : () => _handleCancelTask(currentTask!),
            child: Text(l10n.appCenterCancelTask),
          ),
        if (isBusy)
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onNavigateToTab?.call(2);
            },
            child: Text(context.appCenterRunInBackgroundLabel),
          ),
        if (isBootstrapSucceeded &&
            widget.operation != ApplicationOperation.bootstrap)
          FilledButton.icon(
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(l10n.appCenterContinueInstall),
            onPressed: () async {
              await _inspectInitialEnv();
              if (mounted) {
                setState(() {
                  _plan = null;
                  _runningTask = null;
                  _currentStep = _WizardStep.config;
                });
              }
            },
          )
        else if (isSucceeded) ...[
          if (reconciledDeployment != null &&
              reconciledDeployment.status == 'running' &&
              reconciledDeployment.endpoint != null)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.launch, size: 16),
              label: Text(l10n.appCenterOpen),
              onPressed: connected && _isTargetValid()
                  ? () => _handleOpenReconciledApp(reconciledDeployment)
                  : null,
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onNavigateToTab?.call(1);
            },
            child: Text(context.appCenterViewInstalledLabel),
          ),
        ] else if (isNeedsInspection) ...[
          FilledButton.tonalIcon(
            icon: _isRechecking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(context.appCenterRecheckLabel),
            onPressed: _isRechecking ? null : _handleRecheckServer,
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onNavigateToTab?.call(2);
            },
            child: Text(context.appCenterViewTasksLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.confirm),
          ),
        ] else if (isFailed) ...[
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onNavigateToTab?.call(2);
            },
            child: Text(context.appCenterViewTasksLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.confirm),
          ),
        ] else ...[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.confirm),
          ),
        ],
      ] else ...[
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        if (_currentStep == _WizardStep.environment)
          FilledButton(
            onPressed: (env?.ready ?? false)
                ? () => setState(() => _currentStep = _WizardStep.config)
                : null,
            child: Text(l10n.appCenterNext),
          ),
        if (_currentStep == _WizardStep.config) ...[
          OutlinedButton(
            onPressed: () =>
                setState(() => _currentStep = _WizardStep.environment),
            child: Text(l10n.appCenterBack),
          ),
          FilledButton(
            onPressed:
                (_isLoading ||
                    (!isExistingDeployment && !_bindAddressExplicitlyChosen))
                ? null
                : _preparePlan,
            child: Text(l10n.appCenterNext),
          ),
        ],
        if (_currentStep == _WizardStep.review) ...[
          OutlinedButton(
            onPressed: () => setState(
              () => _currentStep = isBootstrapPlan
                  ? _WizardStep.environment
                  : _WizardStep.config,
            ),
            child: Text(l10n.appCenterBack),
          ),
          FilledButton(
            onPressed: _isLoading ? null : _executePlan,
            child: Text(l10n.appCenterConfirmAndExecute),
          ),
        ],
      ],
    ];

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_errorMessage != null)
                Container(
                  color: context.colorScheme.errorContainer,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: context.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              Expanded(
                child: Padding(padding: const EdgeInsets.all(16), child: body),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OverflowBar(
                    spacing: 8,
                    overflowSpacing: 8,
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    children: actions,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 560,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(VRadius.card),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Flexible(child: body),
            ],
          ),
        ),
      ),
      actions: actions,
    );
  }
}
