import '../models/chat_session.dart';
import '../storage/local_storage_service.dart';

class ChatRepository {
  final LocalStorageService _localStorage;

  ChatRepository(this._localStorage);

  List<ChatSession> getSessions() => _localStorage.getChatSessions();

  List<ChatSession> getSessionsForServer(String serverId) {
    _localStorage.claimLegacyOwnership(serverId);
    var sessions = getSessions();
    if (_localStorage.legacyOwnershipServerId == serverId &&
        sessions.any((s) => s.serverId == null)) {
      sessions = sessions
          .map((s) => s.serverId == null ? s.copyWith(serverId: serverId) : s)
          .toList();
      _localStorage.saveChatSessions(sessions);
    }
    return sessions.where((s) => s.serverId == serverId).toList();
  }

  Future<void> saveSession(ChatSession session) async {
    final list = getSessions().toList();
    final index = list.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      list[index] = session;
    } else {
      list.insert(0, session);
    }
    await _localStorage.saveChatSessions(list);
  }

  Future<void> deleteSession(String sessionId) async {
    final list = getSessions().where((s) => s.id != sessionId).toList();
    await _localStorage.saveChatSessions(list);
  }
}
