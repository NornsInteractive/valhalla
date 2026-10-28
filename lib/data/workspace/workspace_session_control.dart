import 'dart:async';
import '../../infrastructure/workspace/remote_workspace_client.dart';
import 'workspace_gateway.dart';

/// A lease authorizes writes only; losing it never cancels the remote turn.
///
/// The control is scoped to one intrinsic `(serverId, sessionId)` pair.  It
/// must never be reused for whichever server happens to be active in the UI:
/// a background run on server A has to keep presenting A's workspace id and
/// A's lease even while the user is looking at server B.
class WorkspaceSessionControl {
  final WorkspaceGateway gateway;
  final String serverId, sessionId;
  final void Function() onChanged;
  final bool Function() isForeground;
  String? ownerDeviceId, token;
  int? generation;
  DateTime? expiresAt;
  Timer? _heartbeat;
  bool _disposed = false;
  bool busy = false;
  Future<bool>? _pending;
  WorkspaceSessionControl({
    required this.gateway,
    required this.serverId,
    required this.sessionId,
    required this.onChanged,
    required this.isForeground,
  });

  bool get hasControl =>
      !_disposed &&
      token != null &&
      generation != null &&
      ownerDeviceId == gateway.deviceId &&
      expiresAt?.isAfter(DateTime.now().toUtc()) == true;

  /// Serializes heartbeats and user-initiated acquisition so a renewal can
  /// never race a takeover and report a spurious failure.
  Future<bool> acquire({bool takeover = false}) {
    final previous = _pending ?? Future<bool>.value(true);
    late final Future<bool> next;
    next = previous
        .then(
          (_) => _acquireOnce(takeover: takeover),
          onError: (Object _, StackTrace stackTrace) =>
              _acquireOnce(takeover: takeover),
        )
        .whenComplete(() {
          if (identical(_pending, next)) _pending = null;
        });
    _pending = next;
    return next;
  }

  Future<Map<String, dynamic>> _lease({
    required bool takeover,
    required bool renew,
  }) => gateway.request(serverId, {
    'op': 'lease',
    'sessionId': sessionId,
    'action': takeover
        ? 'takeover'
        : renew && hasControl
        ? 'renew'
        : 'acquire',
    if (token != null) 'token': token,
    if (generation != null) 'generation': generation,
  });

  Future<bool> _acquireOnce({required bool takeover}) async {
    if (_disposed) return false;
    busy = true;
    onChanged();
    try {
      Map<String, dynamic> result;
      final renewing = !takeover && hasControl;
      try {
        result = await _lease(takeover: takeover, renew: renewing);
      } on WorkspaceException catch (error) {
        if (takeover) rethrow;
        if (error.code == 'WORKSPACE_CONTROL_HELD') {
          // Only reclaim when the server tells us the current holder is this
          // very device.  Another device's lease is never stolen silently.
          if (error.details['ownerDeviceId'] != gateway.deviceId) rethrow;
          result = await _lease(takeover: true, renew: false);
        } else if (error.code == 'WORKSPACE_LEASE_INVALID' ||
            error.code == 'WORKSPACE_LEASE_EXPIRED') {
          if (renewing) {
            // The lease may have expired locally or another device may have
            // taken over.  A fresh acquire distinguishes the two cases.
            try {
              result = await _lease(takeover: false, renew: false);
            } on WorkspaceException catch (retry) {
              if (retry.code == 'WORKSPACE_CONTROL_HELD' &&
                  retry.details['ownerDeviceId'] == gateway.deviceId) {
                result = await _lease(takeover: true, renew: false);
              } else if (retry.code == 'WORKSPACE_LEASE_INVALID') {
                // Acquire reports INVALID only when the row still belongs to
                // this device UUID but the local token was lost (app restart
                // within the TTL).  Reclaiming our own device is safe.
                result = await _lease(takeover: true, renew: false);
              } else {
                rethrow;
              }
            }
          } else {
            // A plain acquire cannot report INVALID for a foreign holder: the
            // server returns CONTROL_HELD with its owner instead.  Therefore
            // this is our own restarted device; reclaim it.
            result = await _lease(takeover: true, renew: false);
          }
        } else {
          rethrow;
        }
      }
      if (_disposed) return false;
      ownerDeviceId =
          result['ownerDeviceId'] as String? ??
          result['deviceId'] as String? ??
          gateway.deviceId;
      token = result['token'] as String?;
      generation = (result['generation'] as num?)?.toInt();
      final time = result['expiresAt'];
      expiresAt = time is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (time * 1000).toInt(),
              isUtc: true,
            )
          : DateTime.tryParse(time as String? ?? '');
      _heartbeat ??= Timer.periodic(const Duration(seconds: 20), (_) {
        if (isForeground() && !busy) {
          unawaited(acquire().catchError((Object _) => false));
        }
      });
      return hasControl;
    } on WorkspaceException catch (error) {
      ownerDeviceId = error.details['ownerDeviceId'] as String?;
      token = null;
      generation = null;
      expiresAt = null;
      if (error.code != 'WORKSPACE_CONTROL_HELD' &&
          error.code != 'WORKSPACE_CONTROL_REQUIRED' &&
          error.code != 'WORKSPACE_CONTROL_LOST' &&
          error.code != 'WORKSPACE_LEASE_INVALID' &&
          error.code != 'WORKSPACE_LEASE_EXPIRED') {
        rethrow;
      }
      return false;
    } finally {
      busy = false;
      if (!_disposed) onChanged();
    }
  }

  Map<String, dynamic> get context => {
    'workspaceSessionId': sessionId,
    'workspaceDeviceId': gateway.deviceId,
    'deviceId': gateway.deviceId,
    if (hasControl) 'controlToken': token,
    if (hasControl) 'controlGeneration': generation,
  };

  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    _heartbeat = null;
  }
}
