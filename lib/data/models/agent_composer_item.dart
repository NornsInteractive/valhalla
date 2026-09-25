enum AgentComposerItemKind { skill, command, file, workingDirectory }

class AgentComposerItem {
  final AgentComposerItemKind kind;
  final String id;
  final String label;
  final String insertion;
  final String? description;

  const AgentComposerItem({
    required this.kind,
    required this.id,
    required this.label,
    required this.insertion,
    this.description,
  });
}

class AgentComposerCatalog {
  final List<AgentComposerItem> skills;
  final List<AgentComposerItem> commands;

  const AgentComposerCatalog({
    this.skills = const [],
    this.commands = const [],
  });

  bool get isEmpty => skills.isEmpty && commands.isEmpty;
}
