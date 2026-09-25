/// 判断远端文件能否以纯文本方式预览（纯逻辑，无 IO）。
///
/// 采用**扩展名白名单**而不是 MIME 嗅探：SFTP 不提供 content-type，而按内容
/// 嗅探需要先把整份文件读进内存——对一个大二进制文件来说，那恰恰是最坏的结果
/// （既卡住又没意义）。白名单让「不支持」成为一个廉价、可预测的结论。
///
/// 明确不支持图片：本轮范围只有文本预览，其余类型一律提示不支持，不在此处
/// 预留图片分支，避免出现「看起来支持但实际没人实现」的接口。
abstract final class FilePreview {
  /// 可安全按 UTF-8 文本预览的扩展名（全部小写，不含点）。
  ///
  /// 只收录纯文本/源码/配置这类「读出来就是给人看的」格式。刻意不收
  /// `.pdf`、`.docx` 等二进制文档容器——扩展名看着像文档，内容却是二进制。
  static const textExtensions = <String>{
    // 纯文本与标记
    'txt', 'log', 'md', 'markdown', 'rst', 'csv', 'tsv',
    // 结构化数据与配置
    'json', 'yaml', 'yml', 'toml', 'ini', 'cfg', 'conf', 'env', 'properties',
    // 脚本
    'sh', 'bash', 'zsh', 'fish', 'ps1', 'bat', 'cmd',
    // 源码
    'dart', 'js', 'mjs', 'cjs', 'ts', 'tsx', 'jsx', 'py', 'rb', 'go', 'rs',
    'java', 'kt', 'kts', 'swift', 'c', 'h', 'cc', 'cpp', 'hpp', 'cs', 'php',
    'pl', 'lua', 'r', 'sql', 'vue', 'svelte',
    // 网页与样式
    'html', 'htm', 'xml', 'css', 'scss', 'sass', 'less',
    // 其他常见文本
    'gitignore', 'dockerignore', 'editorconfig', 'lock', 'pem', 'pubspec',
  };

  /// 无扩展名但约定为文本的文件名（小写比较）。
  static const _extensionlessTextNames = <String>{
    'dockerfile',
    'makefile',
    'rakefile',
    'gemfile',
    'procfile',
    'readme',
    'license',
    'changelog',
    '.gitignore',
    '.dockerignore',
    '.env',
    '.editorconfig',
    '.bashrc',
    '.zshrc',
    '.profile',
    '.gitconfig',
  };

  /// 该文件名是否可按文本预览。
  ///
  /// 只看名字，不读内容；目录应在调用方先被排除。
  static bool isTextPreviewable(String fileName) {
    final name = fileName.trim().toLowerCase();
    if (name.isEmpty) return false;

    if (_extensionlessTextNames.contains(name)) return true;

    final dot = name.lastIndexOf('.');
    // 前导点（`.bashrc`）或完全没有点都交给上面的完整名判断，
    // 不把 `.bashrc` 当成扩展名 `bashrc`。
    if (dot <= 0) return false;

    final ext = name.substring(dot + 1);
    return textExtensions.contains(ext);
  }
}
