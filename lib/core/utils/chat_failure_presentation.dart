enum ChatFailureKind { auth, modelUnavailable, connection, history, other }

/// These are explicit UI actions; none retries a prompt or a permission reply.
enum ChatFailureAction { login, runSettings, reconnect, reloadHistory, details }

class ChatFailurePresentation {
  final ChatFailureKind kind;
  final ChatFailureAction suggestedAction;

  const ChatFailurePresentation(this.kind, this.suggestedAction);
}

final _authFailure = RegExp(
  r'\b(?:ACP_AUTH_[A-Z_]+|AGENT_MODEL_AUTH_[A-Z_]+|AGENT_MODEL_ACCOUNT_MISMATCH|authentication_error|invalid_api_key|token_expired)\b|'
  r'\bRpcError\(-32000\)|'
  r'\b(?:authentication required|authentication failed|unauthenticated|unauthorized|invalid api key|not logged in)\b',
  caseSensitive: false,
);

final _modelFailure = RegExp(
  r'\b(?:ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER|ACP_CUSTOM_MODEL_(?:INVALID|NOT_CONFIRMED)|model_not_found|unsupported_model|model_unavailable|ModelNotFoundError)\b|'
  r'\bACP_SETTING_UNAVAILABLE:\s*model\b|'
  r'\bmodel\b[^\r\n]{0,120}\b(?:not found|not supported|unavailable|does not exist|not available|not allowed)\b|'
  r'\b(?:unknown|unsupported|unavailable) model\b',
  caseSensitive: false,
);

final _connectionFailure = RegExp(
  r'\b(?:SSH_DISCONNECTED|ACP_DISCONNECTED|ACP_TRANSPORT_FAILURE|ACP_IDLE_TIMEOUT|ACP_AUTH_CONNECTION_EXPIRED)\b|'
  r'\b(?:SocketException|connection reset|connection refused|connection closed|connection lost|broken pipe|network is unreachable|transport unavailable)\b',
  caseSensitive: false,
);

final _rpcInternalFailure = RegExp(
  r'\bRpcError\(\s*-(?:32603|32700)\b',
  caseSensitive: false,
);

final _historyFailure = RegExp(
  r'\b(?:CHAT_HISTORY_LOAD_FAILED|CHAT_MESSAGES_LOAD_FAILED|CHAT_MIGRATION_FAILED|ACP_HISTORY_[A-Z_]+|ACP_REMOTE_HISTORY_UNSUPPORTED)\b',
);

/// Classifies known causes, including nested RPC errors; unknown failures stay
/// in details rather than suggesting a login or reconnect that cannot help.
/// Raw diagnostics remain separate and must only appear in sanitized details.
ChatFailurePresentation? classifyChatFailure(
  String? errorCode, {
  bool authenticationRequired = false,
}) {
  final error = errorCode?.trim() ?? '';
  if (error.isEmpty && !authenticationRequired) return null;
  if (error.toUpperCase().contains('ACP_AUTH_CONNECTION_EXPIRED')) {
    return const ChatFailurePresentation(
      ChatFailureKind.connection,
      ChatFailureAction.reconnect,
    );
  }
  if (authenticationRequired || _authFailure.hasMatch(error)) {
    if (error.contains('AGENT_MODEL_AUTH_UNSUPPORTED') ||
        error.contains('AGENT_MODEL_AUTH_STORAGE_UNSAFE')) {
      return const ChatFailurePresentation(
        ChatFailureKind.auth,
        ChatFailureAction.details,
      );
    }
    return const ChatFailurePresentation(
      ChatFailureKind.auth,
      ChatFailureAction.login,
    );
  }
  if (_modelFailure.hasMatch(error)) {
    return const ChatFailurePresentation(
      ChatFailureKind.modelUnavailable,
      ChatFailureAction.runSettings,
    );
  }
  // A transport wrapper can contain an agent's RPC response, not a lost link.
  if (_rpcInternalFailure.hasMatch(error)) {
    return const ChatFailurePresentation(
      ChatFailureKind.other,
      ChatFailureAction.details,
    );
  }
  if (_connectionFailure.hasMatch(error)) {
    return const ChatFailurePresentation(
      ChatFailureKind.connection,
      ChatFailureAction.reconnect,
    );
  }
  if (_historyFailure.hasMatch(error)) {
    if (error.contains('UNSUPPORTED') || error.contains('AMBIGUOUS')) {
      return const ChatFailurePresentation(
        ChatFailureKind.history,
        ChatFailureAction.details,
      );
    }
    return const ChatFailurePresentation(
      ChatFailureKind.history,
      ChatFailureAction.reloadHistory,
    );
  }
  return const ChatFailurePresentation(
    ChatFailureKind.other,
    ChatFailureAction.details,
  );
}
