import '../models/quick_command.dart';
import '../storage/local_storage_service.dart';
import '../../core/constants/app_constants.dart';

class CommandRepository {
  final LocalStorageService _localStorage;

  CommandRepository(this._localStorage);

  List<QuickCommand> getAllCommands() {
    final list = _localStorage.getQuickCommands();
    if (list.isEmpty) {
      final initial = AppConstants.defaultQuickCommands;
      _localStorage.saveQuickCommands(initial);
      return initial;
    }
    return list;
  }

  List<QuickCommand> getCommandsByCategory(String category) {
    return getAllCommands().where((c) => c.category == category).toList();
  }

  Future<void> addOrUpdateCommand(QuickCommand command) async {
    final list = getAllCommands().toList();
    final index = list.indexWhere((c) => c.id == command.id);
    if (index >= 0) {
      list[index] = command;
    } else {
      list.add(command);
    }
    await _localStorage.saveQuickCommands(list);
  }

  Future<void> deleteCommand(String commandId) async {
    final list = getAllCommands().where((c) => c.id != commandId).toList();
    await _localStorage.saveQuickCommands(list);
  }
}
