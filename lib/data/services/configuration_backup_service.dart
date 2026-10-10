import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../infrastructure/cli/agent_execution_target.dart';
import '../models/agent_profile.dart';
import '../models/quick_command.dart';
import '../models/server_profile.dart';
import '../storage/local_storage_service.dart';

class ConfigurationBackup {
  final List<ServerProfile> servers;
  final List<AgentProfile> agents;
  final List<QuickCommand> commands;
  final Map<String, List<String>> bookmarks;
  final Map<String, Map<String, String>> defaultAgents;
  final Map<String, Object> preferences;

  ConfigurationBackup({
    required this.servers,
    required this.agents,
    required this.commands,
    required this.bookmarks,
    required this.defaultAgents,
    required this.preferences,
  });

  Map<String, Object> toJson() => {
    'format': 'valhalla-configuration',
    'version': 1,
    'servers': servers
        .map(
          (server) => server.toJson()
            ..remove('privateKeyPath')
            ..remove('lastConnectedAt'),
        )
        .toList(),
    'agents': agents.map((agent) => agent.toJson()).toList(),
    'commands': commands.map((command) => command.toJson()).toList(),
    'bookmarks': bookmarks,
    'defaultAgents': defaultAgents,
    'preferences': preferences,
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class ConfigurationBackupService {
  ConfigurationBackupService(this.storage);
  final LocalStorageService storage;
  static const maxBytes = 8 * 1024 * 1024;

  ConfigurationBackup exportConfiguration() {
    final servers = storage.getServers();
    final serverIds = servers.map((server) => server.id).toSet();
    final agents = storage
        .getAgents()
        .where((a) => serverIds.contains(a.serverId))
        .toList();
    return decode(
      ConfigurationBackup(
        servers: servers,
        agents: agents,
        commands: storage.getQuickCommands(),
        bookmarks: {
          for (final server in servers)
            server.id: storage.getFileBookmarks(server.id),
        },
        defaultAgents: {
          for (final server in servers)
            server.id: {
              for (final cli in [false, true])
                if (storage.getDefaultAgentId(server.id, cli: cli)
                    case final String id)
                  if (agents.any(
                    (a) =>
                        a.serverId == server.id &&
                        a.id == id &&
                        (cli || (a.acpCommand?.trim().isNotEmpty ?? false)),
                  ))
                    (cli ? 'cli' : 'acp'): id,
            },
        },
        preferences: storage.exportConfigurationPreferences(),
      ).encode(),
    );
  }

  static ConfigurationBackup decode(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('CONFIG_TOO_LARGE');
    }
    try {
      final raw = jsonDecode(text) as Map<String, dynamic>;
      if (raw['format'] != 'valhalla-configuration' || raw['version'] != 1) {
        throw const FormatException('CONFIG_VERSION_UNSUPPORTED');
      }
      List<Map<String, dynamic>> records(String name) {
        final list = raw[name] as List;
        if (list.length > 10000) {
          throw const FormatException('CONFIG_TOO_MANY_ITEMS');
        }
        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      final serverRecords = records('servers');
      for (final rawServer in serverRecords) {
        if (!{'password', 'privateKey'}.contains(rawServer['authType'])) {
          throw const FormatException('CONFIG_AUTH_TYPE_INVALID');
        }
        if (rawServer['port'] != null && rawServer['port'] is! int) {
          throw const FormatException('CONFIG_SERVER_INVALID');
        }
        rawServer.remove('privateKeyPath');
        rawServer.remove('lastConnectedAt');
      }
      final servers = serverRecords.map(ServerProfile.fromJson).toList();
      final agents = records('agents').map(AgentProfile.fromJson).toList();
      final commands = records('commands').map(QuickCommand.fromJson).toList();
      bool nonEmpty(String value) =>
          value.trim().isNotEmpty && !value.contains('\x00');
      final serverIds = servers.map((s) => s.id).toSet();
      if (serverIds.length != servers.length ||
          servers.any(
            (s) =>
                !nonEmpty(s.id) ||
                !nonEmpty(s.name) ||
                !nonEmpty(s.host) ||
                !nonEmpty(s.username) ||
                s.port < 1 ||
                s.port > 65535,
          )) {
        throw const FormatException('CONFIG_SERVER_INVALID');
      }
      if (agents.map((a) => (a.serverId, a.id)).toSet().length !=
              agents.length ||
          agents.any(
            (a) =>
                !nonEmpty(a.id) ||
                !nonEmpty(a.name) ||
                !nonEmpty(a.cliCommand) ||
                !serverIds.contains(a.serverId) ||
                !{'host', 'docker'}.contains(a.executionTarget) ||
                !{'id', 'name'}.contains(a.containerBinding) ||
                (a.executionTarget == 'docker' &&
                    !nonEmpty(a.containerReference ?? '')),
          )) {
        throw const FormatException('CONFIG_AGENT_INVALID');
      }
      for (final agent in agents) {
        // Reuse execution-target validation without opening SSH or running a command.
        agentTargetCommand(agent, ':');
      }
      if (commands.map((c) => c.id).toSet().length != commands.length ||
          commands.any(
            (c) =>
                !nonEmpty(c.id) || !nonEmpty(c.title) || !nonEmpty(c.command),
          )) {
        throw const FormatException('CONFIG_COMMAND_INVALID');
      }
      final bookmarks = <String, List<String>>{};
      for (final entry in (raw['bookmarks'] as Map).entries) {
        if (!serverIds.contains(entry.key)) {
          throw const FormatException('CONFIG_REFERENCE_INVALID');
        }
        final paths = (entry.value as List).cast<String>();
        if (paths.any((p) => !p.startsWith('/') || p.contains('\x00'))) {
          throw const FormatException('CONFIG_PATH_INVALID');
        }
        bookmarks[entry.key as String] = paths.toSet().toList();
      }
      final defaults = <String, Map<String, String>>{};
      for (final server in (raw['defaultAgents'] as Map).entries) {
        if (!serverIds.contains(server.key)) {
          throw const FormatException('CONFIG_REFERENCE_INVALID');
        }
        defaults[server.key as String] = {};
        for (final mode in (server.value as Map).entries) {
          if (!{'acp', 'cli'}.contains(mode.key) ||
              !agents.any(
                (a) =>
                    a.id == mode.value &&
                    a.serverId == server.key &&
                    (mode.key == 'cli' ||
                        (a.acpCommand?.trim().isNotEmpty ?? false)),
              )) {
            throw const FormatException('CONFIG_REFERENCE_INVALID');
          }
          defaults[server.key]![mode.key as String] = mode.value as String;
        }
      }
      final prefs = <String, Object>{};
      for (final entry in (raw['preferences'] as Map).entries) {
        final type =
            LocalStorageService.configurationPreferenceTypes[entry.key];
        final value = entry.value;
        if (type == 'strings' &&
            value is List &&
            value.every((v) => v is String)) {
          prefs[entry.key as String] = value.cast<String>().toList();
        } else if ((type == 'string' && value is String) ||
            (type == 'bool' && value is bool) ||
            (type == 'int' && value is int)) {
          prefs[entry.key as String] = value as Object;
        } else {
          throw const FormatException('CONFIG_PREFERENCE_INVALID');
        }
      }
      return ConfigurationBackup(
        servers: servers,
        agents: agents,
        commands: commands,
        bookmarks: bookmarks,
        defaultAgents: defaults,
        preferences: prefs,
      );
    } on FormatException catch (error) {
      if (error.message.startsWith('CONFIG_')) rethrow;
      throw const FormatException('CONFIG_FORMAT_INVALID');
    } catch (_) {
      throw const FormatException('CONFIG_FORMAT_INVALID');
    }
  }

  Future<void> importConfiguration(
    ConfigurationBackup backup, {
    bool applyPreferences = false,
  }) async {
    final checked = decode(backup.encode());
    final serverIds = {
      for (final s in checked.servers) s.id: const Uuid().v4(),
    };
    final agentIds = {
      for (final a in checked.agents) (a.serverId, a.id): const Uuid().v4(),
    };
    await storage.appendConfiguration(
      servers: checked.servers
          .map((s) => s.copyWith(id: serverIds[s.id]!))
          .toList(),
      agents: checked.agents
          .map(
            (a) => AgentProfile.fromJson({
              ...a.toJson(),
              'id': agentIds[(a.serverId, a.id)]!,
              'serverId': serverIds[a.serverId]!,
            }),
          )
          .toList(),
      commands: checked.commands
          .map((c) => c.copyWith(id: const Uuid().v4()))
          .toList(),
      bookmarks: {
        for (final entry in checked.bookmarks.entries)
          serverIds[entry.key]!: entry.value,
      },
      defaultAgents: {
        for (final server in checked.defaultAgents.entries)
          serverIds[server.key]!: {
            for (final mode in server.value.entries)
              mode.key: agentIds[(server.key, mode.value)]!,
          },
      },
      preferences: applyPreferences ? checked.preferences : const {},
    );
  }
}
