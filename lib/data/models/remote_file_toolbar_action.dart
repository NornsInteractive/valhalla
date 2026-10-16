/// Stable identifiers shared by pinned actions and the More menu.
enum RemoteFileToolbarAction {
  upload,
  create,
  view,
  transfers,
  hidden,
  sort,
  selection,
  bookmarks,
  refresh,
}

enum RemotePathDisplayMode { scroll, collapsed }

RemotePathDisplayMode remotePathDisplayModeFromStorage(String? value) =>
    value == 'collapsed'
    ? RemotePathDisplayMode.collapsed
    : RemotePathDisplayMode.scroll;

const defaultRemoteFileToolbarActions = <RemoteFileToolbarAction>[
  RemoteFileToolbarAction.upload,
  RemoteFileToolbarAction.create,
  RemoteFileToolbarAction.view,
  RemoteFileToolbarAction.transfers,
  RemoteFileToolbarAction.sort,
];

List<RemoteFileToolbarAction> remoteFileToolbarActionsFromStorage(
  List<String>? raw,
) {
  if (raw == null) return defaultRemoteFileToolbarActions;
  // An explicit empty selection keeps every action in More.
  return List.unmodifiable(
    RemoteFileToolbarAction.values.where((action) => raw.contains(action.name)),
  );
}
