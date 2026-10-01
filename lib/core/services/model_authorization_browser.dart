import 'package:flutter/services.dart';

/// Opens only the official authorization endpoint; never logs its query.
class ModelAuthorizationBrowser {
  static const channel = MethodChannel('valhalla/model_authorization');

  static Future<void> open(Uri url) async {
    if (url.scheme != 'https' ||
        url.host != 'auth.openai.com' ||
        url.userInfo.isNotEmpty ||
        url.port != 443) {
      throw StateError('AGENT_MODEL_ENDPOINT_INVALID');
    }
    try {
      final opened = await channel.invokeMethod<bool>('openBrowser', {
        'url': url.toString(),
      });
      if (opened != true) throw StateError('AGENT_MODEL_BROWSER_FAILED');
    } on PlatformException {
      throw StateError('AGENT_MODEL_BROWSER_FAILED');
    } on MissingPluginException {
      throw StateError('AGENT_MODEL_BROWSER_FAILED');
    }
  }
}
