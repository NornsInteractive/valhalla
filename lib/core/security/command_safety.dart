enum CommandRiskLevel { safe, warning, danger }

class CommandRisk {
  final CommandRiskLevel level;
  final String? matchedPattern;

  const CommandRisk(this.level, {this.matchedPattern});

  bool get isDangerous => level == CommandRiskLevel.danger;
  bool get requiresConfirmation => level != CommandRiskLevel.safe;
}

class CommandSafety {
  static final _dangerPatterns = <RegExp>[
    RegExp(r'\brm\s+-rf\b', caseSensitive: false),
    RegExp(r'\bmkfs(?:\.|\s)', caseSensitive: false),
    RegExp(r'\bdocker\s+system\s+prune\b', caseSensitive: false),
    RegExp(r'\b(?:reboot|shutdown|poweroff)\b', caseSensitive: false),
    RegExp(r'\bdd\s+if=', caseSensitive: false),
  ];

  static final _warningPatterns = <RegExp>[
    RegExp(r'\bkill\s+-9\b', caseSensitive: false),
    RegExp(r'\bsystemctl\s+(?:stop|restart|disable)\b', caseSensitive: false),
    RegExp(r'\bdocker\s+(?:stop|restart|rm)\b', caseSensitive: false),
  ];

  static CommandRisk classify(String command) {
    for (final pattern in _dangerPatterns) {
      if (pattern.hasMatch(command)) {
        return CommandRisk(
          CommandRiskLevel.danger,
          matchedPattern: pattern.pattern,
        );
      }
    }
    for (final pattern in _warningPatterns) {
      if (pattern.hasMatch(command)) {
        return CommandRisk(
          CommandRiskLevel.warning,
          matchedPattern: pattern.pattern,
        );
      }
    }
    return const CommandRisk(CommandRiskLevel.safe);
  }

  static bool requiresConfirmation(String command) =>
      classify(command).requiresConfirmation;
}
