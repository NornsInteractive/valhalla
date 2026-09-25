enum ChatLaunchMode { rememberLast, fixed, blankDraft }

/// Persistent entry behavior for one server/agent/chat-mode tuple.
class ChatLaunchPreference {
  final ChatLaunchMode mode;
  final String? sessionId;

  const ChatLaunchPreference({
    this.mode = ChatLaunchMode.rememberLast,
    this.sessionId,
  });

  Map<String, dynamic> toJson() => {'mode': mode.name, 'sessionId': sessionId};

  factory ChatLaunchPreference.fromJson(Map<String, dynamic> json) {
    final mode = ChatLaunchMode.values
        .where((value) => value.name == json['mode'])
        .firstOrNull;
    return ChatLaunchPreference(
      mode: mode ?? ChatLaunchMode.rememberLast,
      sessionId: json['sessionId'] as String?,
    );
  }
}
