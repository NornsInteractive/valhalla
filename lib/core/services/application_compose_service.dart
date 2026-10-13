import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import '../../data/models/application_center.dart';

class ApplicationComposeService {
  static bool supportsJellyfinSoftwareMode(ApplicationTemplate template) {
    final app = template.application;
    if (app.sourceId != ApplicationSource.official.id ||
        app.id != 'org.icewhale.jellyfin') {
      return false;
    }
    return const {
      'https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages/apps/org.icewhale.jellyfin/docker-compose.yml',
      'https://raw.githubusercontent.com/IceWhaleTech/CasaOS-AppStore/gh-pages/apps/org.icewhale.jellyfin/docker-compose.yml',
    }.contains(app.composeUrl);
  }

  /// A reviewed capability reduction, never a bypass of generic validation.
  static ApplicationTemplate jellyfinSoftwareTemplate(
    ApplicationTemplate template,
  ) {
    if (!supportsJellyfinSoftwareMode(template)) {
      throw const ApplicationCenterException(
        'APP_CENTER_JELLYFIN_PROFILE_UNAVAILABLE',
      );
    }
    final compose =
        jsonDecode(jsonEncode(template.compose)) as Map<String, dynamic>;
    const hardwarePaths = {
      '/dev/dri',
      '/dev/vcsm',
      '/dev/vchiq',
      '/dev/video10',
      '/dev/video11',
      '/dev/video12',
    };
    for (final raw in (compose['services'] as Map).values) {
      final service = raw as Map;
      if (service.containsKey('devices')) {
        final devices = service['devices'];
        if (devices is! List ||
            devices.any((device) {
              if (device is! String) return true;
              final parts = device.split(':');
              return parts.length != 2 ||
                  !hardwarePaths.contains(parts.first) ||
                  parts.first != parts.last;
            })) {
          throw const ApplicationCenterException(
            'APP_CENTER_JELLYFIN_PROFILE_UNAVAILABLE',
          );
        }
        service.remove('devices');
      }
      final volumes = service['volumes'];
      if (volumes is List) {
        final reduced = <dynamic>[];
        for (final volume in volumes) {
          if (volume is Map &&
              volume['type'] == 'bind' &&
              volume['source'] == '/opt/vc/lib' &&
              volume['target'] == '/opt/vc/lib') {
            continue;
          }
          if (volume is String &&
              const {
                '/opt/vc/lib:/opt/vc/lib',
                '/opt/vc/lib:/opt/vc/lib:ro',
                '/opt/vc/lib:/opt/vc/lib:rw',
              }.contains(volume)) {
            continue;
          }
          if (volume is Map && volume['target'] == '/Media') {
            reduced.add({...volume, 'read_only': true});
          } else if (volume is String) {
            final parts = volume.split(':');
            if ((parts.length == 2 || parts.length == 3) &&
                parts.first.startsWith('/') &&
                parts[1] == '/Media') {
              final options = parts.length == 3
                  ? parts.last.split(',')
                  : <String>[];
              options.removeWhere(
                (value) => value == 'ro' || value == 'rw' || value.isEmpty,
              );
              reduced.add('${parts[0]}:/Media:${[...options, 'ro'].join(',')}');
            } else {
              reduced.add(volume);
            }
          } else {
            reduced.add(volume);
          }
        }
        service['volumes'] = reduced;
      }
    }
    return ApplicationTemplate(
      application: template.application,
      compose: compose,
      metadata: template.metadata,
      variables: variables(compose),
      blockers: {
        ...template.blockers.where(
          (code) => code != 'APP_CENTER_TEMPLATE_UNSUPPORTED:devices',
        ),
        ...blockers(compose),
      }.toList(),
    );
  }

  static Map<String, dynamic> parse(String content) {
    if (utf8.encode(content).length > 1024 * 1024) {
      throw const ApplicationCenterException('APP_CENTER_TEMPLATE_TOO_LARGE');
    }
    var nodes = 0, expandedBytes = 0;
    dynamic plain(dynamic value, int depth) {
      if (++nodes > 20000 || depth > 24) {
        throw const ApplicationCenterException('APP_CENTER_TEMPLATE_TOO_LARGE');
      }
      if (value is Map) {
        return value.map((key, item) {
          if (key is! String) {
            throw const ApplicationCenterException(
              'APP_CENTER_TEMPLATE_INVALID',
            );
          }
          return MapEntry(key, plain(item, depth + 1));
        });
      }
      if (value is List) {
        return value.map((item) => plain(item, depth + 1)).toList();
      }
      if (value is String) {
        expandedBytes += utf8.encode(value).length;
        if (expandedBytes > 1024 * 1024) {
          throw const ApplicationCenterException(
            'APP_CENTER_TEMPLATE_TOO_LARGE',
          );
        }
        return value;
      }
      if (value == null || value is num || value is bool) {
        return value;
      }
      throw const ApplicationCenterException('APP_CENTER_TEMPLATE_INVALID');
    }

    final decoded = plain(loadYaml(content), 0);
    if (decoded is! Map<String, dynamic> ||
        decoded['services'] is! Map ||
        (decoded['services'] as Map).isEmpty ||
        (decoded['services'] as Map).length > 20) {
      throw const ApplicationCenterException('APP_CENTER_TEMPLATE_INVALID');
    }
    if (utf8.encode(jsonEncode(decoded)).length > 1024 * 1024) {
      throw const ApplicationCenterException('APP_CENTER_TEMPLATE_TOO_LARGE');
    }
    return decoded;
  }

  static final _variable = RegExp(
    r'\$\$|\$\{([A-Za-z_][A-Za-z0-9_]*)(?:(:-|-|:\?|\?|:\+|\+)([^}]*))?\}|\$([A-Za-z_][A-Za-z0-9_]*)',
  );
  static Set<String> variables(Map<String, dynamic> compose) {
    final result = <String>{};
    void visit(dynamic value) {
      if (value is String) {
        for (final match in _variable.allMatches(value)) {
          final name = match.group(1) ?? match.group(4);
          if (name != null) result.add(name);
        }
      } else if (value is Map) {
        value.values.forEach(visit);
      } else if (value is List) {
        value.forEach(visit);
      }
    }

    visit(compose);
    return result;
  }

  static List<String> blockers(Map<String, dynamic> compose) {
    final reasons = <String>{};
    void block(String name) =>
        reasons.add('APP_CENTER_TEMPLATE_UNSUPPORTED:$name');
    for (final key in ['include', 'configs', 'secrets']) {
      if (compose.containsKey(key)) block(key);
    }
    for (final section in ['volumes', 'networks']) {
      for (final value in (compose[section] as Map? ?? {}).values) {
        if (value is Map &&
            (value['external'] == true ||
                value.containsKey('name') ||
                value.containsKey('driver_opts') ||
                (value['driver'] != null &&
                    !['local', 'bridge'].contains(value['driver'])))) {
          block(section);
        }
      }
    }
    for (final entry in (compose['services'] as Map).entries) {
      if (entry.key is! String ||
          !RegExp(
            r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$',
          ).hasMatch(entry.key as String) ||
          entry.value is! Map) {
        block('services');
        continue;
      }
      final service = entry.value as Map;
      if (service['image'] is! String || (service['image'] as String).isEmpty) {
        block('image');
      }
      for (final field in [
        'build',
        'extends',
        'env_file',
        'devices',
        'device_cgroup_rules',
        'cap_add',
        'security_opt',
        'runtime',
        'sysctls',
        'credential_spec',
        'volumes_from',
        'external_links',
        'post_start',
        'pre_stop',
        'provider',
        'profiles',
        'develop',
        'use_api_socket',
      ]) {
        if (service.containsKey(field)) block(field);
      }
      if (service.containsKey('privileged') && service['privileged'] != false) {
        block('privileged');
      }
      final deploy = service['deploy'];
      if (deploy is Map &&
          deploy['resources'] is Map &&
          (deploy['resources'] as Map)['reservations'] is Map &&
          ((deploy['resources'] as Map)['reservations'] as Map).containsKey(
            'devices',
          )) {
        block('devices');
      }
      for (final field in [
        'network_mode',
        'pid',
        'ipc',
        'uts',
        'userns_mode',
      ]) {
        if (service[field] != null &&
            !['bridge', 'private'].contains(service[field])) {
          block(field);
        }
      }
      for (final volume in service['volumes'] as List? ?? []) {
        final source = volume is Map
            ? volume['source']
            : volume is String
            ? volume.split(':').first
            : null;
        if (source is String &&
            (source.contains('docker.sock') ||
                source == '/' ||
                source.startsWith('/proc') ||
                source.startsWith('/sys') ||
                source.startsWith('/dev'))) {
          block('host_mount');
        }
        if (source is String &&
            (source.startsWith('.') || source.startsWith('~'))) {
          block('relative_host_mount');
        }
      }
    }
    return reasons.toList();
  }

  static String _literal(String value) => value.replaceAll(r'$', r'$$');

  // Only remove directory suffixes; never normalize away traversal segments.
  static String _directoryPath(String value) =>
      value.replaceFirst(RegExp(r'/+$'), '');

  static ApplicationConfiguration canonicalDirectoryPaths(
    ApplicationConfiguration config,
  ) => config.copyWith(
    dataRoot: _directoryPath(config.dataRoot),
    mounts: [
      for (final mount in config.mounts)
        ApplicationMount(
          service: mount.service,
          source: _directoryPath(mount.source),
          target: _directoryPath(mount.target),
          readOnly: mount.readOnly,
        ),
    ],
  );

  static dynamic _resolve(
    dynamic value,
    Map<String, String> values, {
    bool allowMissing = false,
  }) {
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(
          k as String,
          _resolve(v, values, allowMissing: allowMissing),
        ),
      );
    }
    if (value is List) {
      return value
          .map((v) => _resolve(v, values, allowMissing: allowMissing))
          .toList();
    }
    if (value is! String) return value;
    return value.replaceAllMapped(_variable, (match) {
      if (match.group(0) == r'$$') return r'$$';
      final name = match.group(1) ?? match.group(4)!;
      final mode = match.group(2);
      final fallback = match.group(3) ?? '';
      final present = values.containsKey(name);
      final actual = values[name] ?? '';
      if (mode == ':-' && actual.isEmpty || mode == '-' && !present) {
        return _literal(fallback);
      }
      if (mode == ':+' || mode == '+') {
        return (mode == ':+' ? actual.isNotEmpty : present)
            ? _literal(fallback)
            : '';
      }
      if (!present || (mode == ':?' && actual.isEmpty)) {
        if (allowMissing) return '';
        throw ApplicationCenterException('APP_CENTER_VARIABLE_REQUIRED', name);
      }
      return _literal(actual);
    });
  }

  static List<ApplicationPort> _ports(String service, Map definition) {
    final result = <ApplicationPort>[];
    for (final raw in definition['ports'] as List? ?? []) {
      String protocol = 'tcp';
      int? target, published;
      if (raw is Map) {
        target = int.tryParse('${raw['target']}');
        published = int.tryParse('${raw['published'] ?? raw['target']}');
        protocol = raw['protocol'] as String? ?? 'tcp';
      } else if (raw is String || raw is int) {
        final parts = '$raw'.split('/');
        protocol = parts.length > 1 ? parts.last : 'tcp';
        final numbers = parts.first.split(':');
        target = int.tryParse(numbers.last);
        published = int.tryParse(
          numbers.length > 1 ? numbers[numbers.length - 2] : numbers.last,
        );
      }
      if (target == null ||
          published == null ||
          target < 1 ||
          target > 65535 ||
          published < 1 ||
          published > 65535 ||
          !{'tcp', 'udp'}.contains(protocol)) {
        throw const ApplicationCenterException('APP_CENTER_PORT_INVALID');
      }
      result.add(
        ApplicationPort(
          service: service,
          target: target,
          published: published,
          protocol: protocol,
        ),
      );
    }
    return result;
  }

  static List<ApplicationMount> _mounts(
    String service,
    Map definition,
    String dataRoot,
  ) {
    final mounts = <ApplicationMount>[];
    for (final raw in definition['volumes'] as List? ?? []) {
      String? source, target;
      bool readOnly = false;
      if (raw is Map &&
          (raw['type'] == 'bind' || '${raw['source']}'.startsWith('/'))) {
        source = raw['source'] as String?;
        target = raw['target'] as String?;
        readOnly = raw['read_only'] == true;
      } else if (raw is String) {
        final parts = raw.split(':');
        if (parts.length >= 2 && parts.first.startsWith('/')) {
          source = parts.first;
          target = parts[1];
          readOnly = parts.length > 2 && parts[2].split(',').contains('ro');
        }
      }
      if (source != null && target != null) {
        final casaData = RegExp(
          r'^/DATA/AppData/[^/]+(.*)$',
        ).firstMatch(source);
        if (casaData != null) source = '$dataRoot${casaData.group(1)}';
        mounts.add(
          ApplicationMount(
            service: service,
            source: _directoryPath(source),
            target: _directoryPath(target),
            readOnly: readOnly,
          ),
        );
      }
    }
    return mounts;
  }

  static List<String> serviceNames(ApplicationTemplate template) =>
      List<String>.unmodifiable(
        (template.compose['services'] as Map).keys.cast<String>(),
      );

  static String? suggestedMainService(ApplicationTemplate template) {
    final names = serviceNames(template);
    if (names.length == 1) return names.single;
    final casa = template.compose['x-casaos'];
    final declared =
        (casa is Map ? casa['main'] : null) ?? template.metadata['main'];
    return declared is String && names.contains(declared) ? declared : null;
  }

  static bool isValidContainerName(String name) =>
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]*$').stringMatch(name) == name &&
      name.length <= 120;

  static Map<String, String> containerNames(
    ApplicationTemplate template,
    ApplicationConfiguration config,
  ) {
    if (!config.instanceContainerNames) return const {};
    if (!isValidContainerName(config.name)) {
      throw const ApplicationCenterException(
        'APP_CENTER_CONTAINER_NAME_INVALID',
      );
    }
    final names = serviceNames(template);
    final main = config.mainService ?? suggestedMainService(template);
    if (main == null || !names.contains(main)) {
      throw const ApplicationCenterException(
        'APP_CENTER_MAIN_SERVICE_REQUIRED',
      );
    }
    for (final raw in (template.compose['services'] as Map).values) {
      final service = raw as Map;
      final deploy = service['deploy'];
      final replicas = deploy is Map ? deploy['replicas'] : null;
      if ((replicas != null && replicas.toString() != '1') ||
          (service['scale'] != null && service['scale'].toString() != '1') ||
          (deploy is Map &&
              deploy['mode'] != null &&
              deploy['mode'] != 'replicated')) {
        throw const ApplicationCenterException(
          'APP_CENTER_CONTAINER_REPLICAS_UNSUPPORTED',
        );
      }
    }
    return Map<String, String>.unmodifiable({
      for (final service in names)
        service: service == main ? config.name : '${config.name}-$service',
    });
  }

  static ApplicationConfiguration defaults(
    ApplicationTemplate template,
    ApplicationEnvironment environment,
    String instanceId, {
    Map<String, String> variables = const {},
    bool jellyfinSoftwareMode = false,
  }) {
    if (jellyfinSoftwareMode) template = jellyfinSoftwareTemplate(template);
    final root = '${environment.home}/.local/share/valhalla/apps/$instanceId';
    final values = <String, String>{
      'PUID': '${environment.uid}',
      'PGID': '${environment.gid}',
      'TZ': 'UTC',
      ...variables,
      'AppID': instanceId,
    };
    // Unknown placeholders become editable inputs; they are required at preview.
    for (final name in template.variables) {
      values.putIfAbsent(name, () => '');
    }
    final resolving = Map<String, String>.from(values)
      ..removeWhere(
        (key, value) =>
            value.isEmpty && !{'AppID', 'PUID', 'PGID', 'TZ'}.contains(key),
      );
    final resolved =
        _resolve(template.compose, resolving, allowMissing: true) as Map;
    final ports = <ApplicationPort>[], mounts = <ApplicationMount>[];
    final environments = <String, Map<String, String>>{};
    for (final entry in (resolved['services'] as Map).entries) {
      final name = entry.key as String;
      final definition = entry.value as Map;
      ports.addAll(_ports(name, definition));
      mounts.addAll(_mounts(name, definition, root));
      final raw = definition['environment'];
      environments[name] = raw is Map
          ? raw.map(
              (k, v) => MapEntry(
                k as String,
                v == null ? '' : '$v'.replaceAll(r'$$', r'$'),
              ),
            )
          : {
              for (final item in raw as List? ?? [])
                if (item is String)
                  item.split('=').first: item.contains('=')
                      ? item
                            .substring(item.indexOf('=') + 1)
                            .replaceAll(r'$$', r'$')
                      : '',
            };
    }
    return ApplicationConfiguration(
      name: isValidContainerName(template.application.id)
          ? template.application.id
          : template.application.title,
      dataRoot: root,
      jellyfinSoftwareMode: jellyfinSoftwareMode,
      instanceContainerNames: true,
      mainService: suggestedMainService(template),
      ports: ports,
      mounts: mounts,
      variables: values,
      environment: environments,
    );
  }

  static String build(
    ApplicationTemplate template,
    ApplicationConfiguration config,
    String instanceId,
    String project,
  ) {
    config = canonicalDirectoryPaths(config);
    if (config.jellyfinSoftwareMode) {
      template = jellyfinSoftwareTemplate(template);
    }
    final unsupported = {...template.blockers, ...blockers(template.compose)};
    if (unsupported.isNotEmpty) {
      throw ApplicationCenterException(
        'APP_CENTER_TEMPLATE_UNSUPPORTED',
        unsupported.join(', '),
      );
    }
    validatePath(config.dataRoot, field: 'dataRoot');
    if (config.name.trim().isEmpty ||
        config.name.length > 120 ||
        !{'127.0.0.1', '0.0.0.0'}.contains(config.bindAddress)) {
      throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
    }
    for (final variable in template.variables) {
      if (!{'AppID', 'PUID', 'PGID', 'TZ'}.contains(variable) &&
          (config.variables[variable]?.isEmpty ?? true)) {
        // Defaults in the template are allowed even if the user leaves the input blank.
        final encoded = jsonEncode(template.compose);
        if (!encoded.contains('\${$variable:-') &&
            !encoded.contains('\${$variable-')) {
          throw ApplicationCenterException(
            'APP_CENTER_VARIABLE_REQUIRED',
            variable,
          );
        }
      }
    }
    final values = Map<String, String>.from(config.variables)
      ..['AppID'] = instanceId;
    values.removeWhere(
      (key, value) =>
          value.isEmpty && !{'AppID', 'PUID', 'PGID', 'TZ'}.contains(key),
    );
    final resolved = _resolve(template.compose, values) as Map<String, dynamic>;
    final services = resolved['services'] as Map;
    final names = containerNames(
      ApplicationTemplate(
        application: template.application,
        compose: resolved,
        metadata: template.metadata,
      ),
      config,
    );
    final portsSeen = <String>{};
    for (final entry in services.entries) {
      final service = entry.value as Map<String, dynamic>;
      final name = entry.key as String;
      final containerName = service.remove('container_name');
      if (names.containsKey(name)) service['container_name'] = names[name];
      if (service['network_mode'] == 'bridge') {
        service.remove('network_mode');
      }
      if (containerName is String && containerName.isNotEmpty) {
        final rawNetworks = service['networks'];
        final networks = rawNetworks is Map
            ? Map<String, dynamic>.from(rawNetworks)
            : <String, dynamic>{
                for (final name in rawNetworks as List? ?? ['default'])
                  name as String: null,
              };
        for (final name in networks.keys.toList()) {
          final options = Map<String, dynamic>.from(
            networks[name] as Map? ?? {},
          );
          options['aliases'] = {
            ...(options['aliases'] as List? ?? []).cast<String>(),
            containerName,
          }.toList();
          networks[name] = options;
        }
        service['networks'] = networks;
      }
      service.remove('x-casaos');
      final labels = service['labels'];
      final merged = labels is Map
          ? Map<String, dynamic>.from(labels)
          : <String, dynamic>{
              for (final value in labels as List? ?? [])
                if (value is String && value.contains('='))
                  value.split('=').first: value.substring(
                    value.indexOf('=') + 1,
                  ),
            };
      merged['com.valhalla.app.instance'] = instanceId;
      service['labels'] = merged;
      final expectedPorts = _ports(name, service);
      service['ports'] = [
        for (final port in expectedPorts)
          (() {
            final selected = config.ports
                .where((p) => p.key == port.key)
                .toList();
            if (selected.length != 1 ||
                selected.single.published < 1 ||
                selected.single.published > 65535 ||
                !{'127.0.0.1', '0.0.0.0'}.contains(
                  selected.single.effectiveBindAddress(config.bindAddress),
                ) ||
                !portsSeen.add(
                  '${selected.single.published}/${port.protocol}',
                )) {
              throw const ApplicationCenterException('APP_CENTER_PORT_INVALID');
            }
            return {
              'target': port.target,
              'published': '${selected.single.published}',
              'host_ip': selected.single.effectiveBindAddress(
                config.bindAddress,
              ),
              'protocol': port.protocol,
            };
          })(),
      ];
      final expectedMounts = _mounts(name, service, config.dataRoot);
      final overrides = <String, Map<String, dynamic>>{};
      for (final mount in expectedMounts) {
        final selected = config.mounts
            .where((m) => m.key == mount.key)
            .toList();
        if (selected.length != 1) {
          throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
        }
        final chosen = selected.single;
        validatePath(chosen.source, field: 'mountSource');
        validatePath(chosen.target, field: 'mountTarget');
        if (chosen.source == '/' ||
            chosen.source.contains('docker.sock') ||
            ['/proc', '/sys', '/dev', '/etc', '/root/.ssh'].any(
              (p) => chosen.source == p || chosen.source.startsWith('$p/'),
            )) {
          throw const ApplicationCenterException('APP_CENTER_MOUNT_FORBIDDEN');
        }
        overrides[mount.target] = {
          'type': 'bind',
          'source': _literal(chosen.source),
          'target': _literal(chosen.target),
          'read_only': config.jellyfinSoftwareMode && mount.target == '/Media'
              ? true
              : chosen.readOnly,
          'bind': {'create_host_path': false},
        };
      }
      final mounts = <dynamic>[];
      for (final raw in service['volumes'] as List? ?? []) {
        final target = raw is Map
            ? raw['target']
            : raw is String
            ? (raw.split(':').length >= 2 ? raw.split(':')[1] : raw)
            : null;
        mounts.add(
          (target is String ? overrides[_directoryPath(target)] : null) ?? raw,
        );
      }
      if (mounts.isNotEmpty) service['volumes'] = mounts;
      if (config.environment.containsKey(name)) {
        service['environment'] = config.environment[name]!.map((k, v) {
          if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(k) ||
              v.contains('\x00')) {
            throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
          }
          return MapEntry(k, _literal(v));
        });
      }
    }
    resolved.remove('x-casaos');
    resolved.remove('version');
    resolved['name'] = project;
    return const JsonEncoder.withIndent('  ').convert(resolved);
  }

  static ApplicationConfiguration mergeDefaults(
    ApplicationTemplate template,
    ApplicationEnvironment environment,
    String instanceId,
    ApplicationConfiguration current,
  ) {
    final next = defaults(
      template,
      environment,
      instanceId,
      variables: current.variables,
      jellyfinSoftwareMode: current.jellyfinSoftwareMode,
    );
    return current.copyWith(
      variables: {...next.variables, ...current.variables, 'AppID': instanceId},
      ports: [
        for (final port in next.ports)
          current.ports.where((p) => p.key == port.key).firstOrNull ?? port,
      ],
      mounts: [
        for (final mount in next.mounts)
          current.mounts.where((m) => m.key == mount.key).firstOrNull ??
              ApplicationMount(
                service: mount.service,
                target: mount.target,
                readOnly: mount.readOnly,
                source: mount.source == next.dataRoot
                    ? current.dataRoot
                    : path.posix.isWithin(next.dataRoot, mount.source)
                    ? '${current.dataRoot}/${path.posix.relative(mount.source, from: next.dataRoot)}'
                    : mount.source,
              ),
      ],
      environment: {
        for (final entry in next.environment.entries)
          entry.key: {...entry.value, ...?current.environment[entry.key]},
      },
    );
  }

  static ApplicationConfiguration changeVariables(
    ApplicationTemplate template,
    ApplicationEnvironment environment,
    String instanceId,
    ApplicationConfiguration current,
    Map<String, String> variables,
  ) {
    final old = defaults(
      template,
      environment,
      instanceId,
      variables: current.variables,
      jellyfinSoftwareMode: current.jellyfinSoftwareMode,
    );
    final next = defaults(
      template,
      environment,
      instanceId,
      variables: variables,
      jellyfinSoftwareMode: current.jellyfinSoftwareMode,
    );
    final updated = mergeDefaults(
      template,
      environment,
      instanceId,
      current.copyWith(variables: variables),
    );
    String relocate(String root, String source) => source == root
        ? current.dataRoot
        : path.posix.isWithin(root, source)
        ? '${current.dataRoot}/${path.posix.relative(source, from: root)}'
        : source;
    final environments = <String, Map<String, String>>{};
    for (final entry in updated.environment.entries) {
      final before = old.environment[entry.key] ?? const <String, String>{};
      final selected =
          current.environment[entry.key] ?? const <String, String>{};
      final after = next.environment[entry.key] ?? const <String, String>{};
      environments[entry.key] = entry.value.map(
        (key, value) => MapEntry(
          key,
          before[key] == selected[key] ? after[key] ?? value : value,
        ),
      );
    }
    return updated.copyWith(
      ports: [
        for (final port in updated.ports)
          old.ports.any(
                (p) => p.key == port.key && p.published == port.published,
              )
              ? ApplicationPort(
                  service: port.service,
                  target: port.target,
                  published: next.ports
                      .firstWhere((p) => p.key == port.key)
                      .published,
                  protocol: port.protocol,
                  bindAddress: port.bindAddress,
                )
              : port,
      ],
      mounts: [
        for (final mount in updated.mounts)
          old.mounts.any(
                (m) =>
                    m.key == mount.key &&
                    relocate(old.dataRoot, m.source) == mount.source,
              )
              ? ApplicationMount(
                  service: mount.service,
                  target: mount.target,
                  source: relocate(
                    next.dataRoot,
                    next.mounts.firstWhere((m) => m.key == mount.key).source,
                  ),
                  readOnly: mount.readOnly,
                )
              : mount,
      ],
      environment: environments,
    );
  }

  static void validatePath(String value, {String? field}) {
    if (!value.startsWith('/') ||
        value == '/' ||
        value.contains('\x00') ||
        value.contains('\n') ||
        value.contains('\r') ||
        path.posix.normalize(value) != value ||
        value.length > 4096) {
      throw ApplicationCenterException('APP_CENTER_PATH_INVALID', field);
    }
  }

  static ApplicationPort? webPort(
    ApplicationTemplate template,
    ApplicationConfiguration config,
  ) {
    final casa =
        _resolve(
              template.compose['x-casaos'] ?? {},
              config.variables,
              allowMissing: true,
            )
            as Map;
    final main = config.instanceContainerNames
        ? config.mainService ?? suggestedMainService(template)
        : casa['main'] as String? ??
              (template.compose['services'] as Map).keys.first as String;
    final ports = config.ports
        .where((p) => p.service == main && p.protocol == 'tcp')
        .toList();
    if (ports.isEmpty) return null;
    final declared = int.tryParse('${casa['port_map']}');
    return ports.where((p) => p.target == declared).firstOrNull ??
        ports.where((p) => p.published == declared).firstOrNull ??
        ports.first;
  }

  static Uri? endpoint(
    ApplicationTemplate template,
    ApplicationConfiguration config,
  ) {
    final rawEntry = (template.compose['x-casaos'] as Map?)?['index'];
    if (rawEntry is String &&
        variables({
          'index': rawEntry,
        }).any((name) => !{'AppID', 'PUID', 'PGID', 'TZ'}.contains(name))) {
      throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
    }
    final port = webPort(template, config);
    if (port == null) return null;
    final casa =
        _resolve(
              template.compose['x-casaos'] ?? {},
              config.variables,
              allowMissing: true,
            )
            as Map;
    final scheme = casa['scheme'] == 'https' ? 'https' : 'http';
    final index = casa['index'] as String? ?? '/';
    final entry = Uri.tryParse(index);
    if (entry == null ||
        !index.startsWith('/') ||
        index.startsWith('//') ||
        index.contains('\\') ||
        entry.hasFragment) {
      throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
    }
    return Uri(
      scheme: scheme,
      host: '127.0.0.1',
      port: port.published,
      path: entry.path,
      query: entry.hasQuery ? entry.query : null,
    );
  }
}
