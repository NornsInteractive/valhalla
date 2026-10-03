import 'dart:async';

import 'package:acpd/acpd.dart';

import '../../data/models/agent_profile.dart';
import 'acp_client_adapter.dart';
import 'agent_environment_service.dart';

/// Revalidate existing official credentials without a chat session or browser.
/// A new OAuth challenge ends this probe immediately; explicit login owns it.
Future<AgentAuthenticationStatus> probeAgySavedAuth(
  AgentProfile profile,
  String methodId,
  Future<Transport> Function() openTransport,
) async {
  ACPClientAdapter? adapter;
  StreamSubscription<ACPEvent>? subscription;
  var expired = false;
  final needsLogin = Completer<AgentAuthenticationStatus>();
  try {
    return await (() async {
      final transport = await openTransport();
      if (expired) {
        await transport.close();
        return AgentAuthenticationStatus.unknown;
      }
      final current = adapter = ACPClientAdapter(
        profile: profile,
        transport: transport,
        requestTimeout: const Duration(seconds: 15),
      );
      subscription = current.eventStream.listen((event) {
        if (event is ACPAuthorizationRequestEvent && !needsLogin.isCompleted) {
          needsLogin.complete(AgentAuthenticationStatus.unauthenticated);
          // Finally disposes after dispatch; closing a synchronous event
          // controller from its own listener would throw during cancellation.
        }
      });
      return Future.any<AgentAuthenticationStatus>([
        current
            .authenticateNow(methodId)
            .then(
              (_) => current.authenticationConfirmed
                  ? AgentAuthenticationStatus.authenticated
                  : AgentAuthenticationStatus.unknown,
            ),
        needsLogin.future,
      ]);
    })().timeout(const Duration(seconds: 20));
  } catch (error) {
    return needsLogin.isCompleted || error is RpcError && error.code == -32000
        ? AgentAuthenticationStatus.unauthenticated
        : AgentAuthenticationStatus.unknown;
  } finally {
    expired = true;
    adapter?.dispose();
    await subscription?.cancel();
  }
}
