/// Pure presentation helper that renders a self-contained HTML response
/// for the local ACP OAuth callback loopback server.
///
/// CRITICAL SECURITY REQUIREMENT:
/// No URL, authorization code, state parameter, or raw error string
/// is ever interpolated into this document.
String acpOAuthCallbackPage({required bool success}) {
  final title = success
      ? 'Authorization Successful / 授权成功'
      : 'Authorization Failed / 授权失败';
  final statusClass = success ? 'success' : 'failure';
  final iconSymbol = success ? '&#10003;' : '&#10005;';
  final heading = success
      ? 'Authorization Successful<br><small>授权成功</small>'
      : 'Authorization Failed<br><small>授权失败</small>';
  final bodyText = success
      ? '<p>You may now return to Valhalla. If the application does not open automatically, tap the button below.</p><p><small>您现在可以返回 Valhalla。若应用未自动打开，请点击下方按钮。</small></p>'
      : '<p>Authorization could not be completed. Please return to Valhalla and try requesting authentication again.</p><p><small>未能完成授权。请返回 Valhalla 并重新尝试请求认证。</small></p>';

  final autoRedirectScript = success
      ? '<script>\n'
            '  setTimeout(function() {\n'
            '    try {\n'
            '      window.location.href = "valhalla://oauth-return";\n'
            '    } catch (e) {}\n'
            '  }, 300);\n'
            '</script>'
      : '';

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
  <style>
    :root {
      --bg: #0f172a;
      --card-bg: #1e293b;
      --text-main: #f8fafc;
      --text-sub: #94a3b8;
      --accent-success: #10b981;
      --accent-failure: #ef4444;
      --btn-bg: #3b82f6;
      --btn-hover: #2563eb;
    }
    @media (prefers-color-scheme: light) {
      :root {
        --bg: #f8fafc;
        --card-bg: #ffffff;
        --text-main: #0f172a;
        --text-sub: #64748b;
        --btn-bg: #2563eb;
        --btn-hover: #1d4ed8;
      }
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text-main);
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
    }
    .card {
      background-color: var(--card-bg);
      border-radius: 16px;
      padding: 32px 24px;
      max-width: 440px;
      width: 100%;
      text-align: center;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1);
    }
    .icon {
      width: 64px;
      height: 64px;
      margin: 0 auto 20px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      line-height: 1;
    }
    .icon.success {
      background-color: rgba(16, 185, 129, 0.15);
      color: var(--accent-success);
    }
    .icon.failure {
      background-color: rgba(239, 68, 68, 0.15);
      color: var(--accent-failure);
    }
    h1 {
      font-size: 1.25rem;
      font-weight: 700;
      margin-bottom: 12px;
      line-height: 1.4;
    }
    h1 small {
      font-size: 0.95rem;
      font-weight: 500;
      color: var(--text-sub);
    }
    .desc {
      color: var(--text-sub);
      font-size: 0.95rem;
      line-height: 1.6;
      margin-bottom: 28px;
    }
    .desc small {
      display: block;
      margin-top: 4px;
      font-size: 0.85rem;
    }
    .btn {
      display: inline-block;
      width: 100%;
      padding: 12px 20px;
      background-color: var(--btn-bg);
      color: #ffffff;
      text-decoration: none;
      font-weight: 600;
      border-radius: 8px;
      font-size: 1rem;
      transition: background-color 0.15s ease;
    }
    .btn:hover {
      background-color: var(--btn-hover);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon $statusClass">
      $iconSymbol
    </div>
    <h1>$heading</h1>
    <div class="desc">
      $bodyText
    </div>
    <a href="valhalla://oauth-return" class="btn">
      ${success ? 'Return to Valhalla / 返回 Valhalla' : 'Back to Valhalla / 返回 Valhalla'}
    </a>
  </div>
  $autoRedirectScript
</body>
</html>''';
}
