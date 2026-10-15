import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent_profile.dart';

class AgentUpdateLockNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  bool acquire(AgentProfile profile) {
    // Names/IDs and implicit/explicit users may alias the same installation.
    final key = 'server:${profile.serverId}';
    if (state.contains(key)) return false;
    state = {...state, key};
    return true;
  }

  void release(AgentProfile profile) {
    final key = 'server:${profile.serverId}';
    state = {...state}..remove(key);
  }
}

final agentUpdateLockProvider =
    NotifierProvider<AgentUpdateLockNotifier, Set<String>>(
      AgentUpdateLockNotifier.new,
    );

bool isAgentUpdateLocked(Ref ref, AgentProfile profile) =>
    ref.read(agentUpdateLockProvider).contains('server:${profile.serverId}');
