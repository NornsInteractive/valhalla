import '../../data/models/nas_source.dart';
import '../ssh/ssh_client_manager.dart';
import '../ssh/ssh_http_tunnel_service.dart';

/// NAS validation remains here; loopback forwarding is shared with ACP previews.
class NasSshTunnelService {
  final SshHttpTunnelService _tunnels;
  NasSshTunnelService(SshCommandExecutor ssh)
    : _tunnels = SshHttpTunnelService(ssh);
  Future<Uri> forward(NasSource source) async {
    if (source.sshServerId == null ||
        source.type == NasSourceType.sftp ||
        source.type == NasSourceType.smb) {
      throw ArgumentError('NAS_TUNNEL_INVALID_SOURCE');
    }
    return _tunnels.forward(
      id: source.id,
      serverId: source.sshServerId!,
      remote: Uri.parse(source.endpoint),
    );
  }

  Future<void> closeSource(String sourceId) => _tunnels.closeSource(sourceId);
  Future<void> dispose() => _tunnels.dispose();
}
