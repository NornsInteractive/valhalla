/// Quotes one login-shell argument and rejects control bytes.
String cliShellQuote(String value) {
  if (RegExp(r'[\r\n\x00]').hasMatch(value)) {
    throw ArgumentError('CLI_INVALID_ARGUMENT');
  }
  return "'${value.replaceAll("'", "'\\''")}'";
}
