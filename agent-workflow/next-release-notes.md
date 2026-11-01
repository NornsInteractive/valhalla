# Valhalla 1.0.32+33

## 智能会话底部输入框操作按钮紧凑化与打字宽度优化
- 彻底解决输入框左侧附件菜单按钮与命令按钮尺寸占用过宽问题：
  - 穿透 Material 3 默认 `IconButtonTheme` 最小 40/48dp 约束，显式配置 `style: IconButton.styleFrom(minimumSize: Size.zero, fixedSize: const Size(26, 32), padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact)`。
  - 外层增加显式 `SizedBox(width: 26, height: 32)` 物理约束，彻底消解 Material 默认内边距与点击区域扩张。
  - 经由真实 Android ADB 实体设备（640dpi）`uiautomator dump` 实测验证：
    - 附件按钮宽度从 48dp (192px) 缩小至 26dp (104px)；
    - 命令按钮宽度从 40dp (160px) 缩小至 26dp (104px)；
    - 双按钮总占用从 88dp (352px) 紧缩至 52dp (208px)，输入框起始位置左移 36dp (144px)，右侧有效打字空间显著扩大。
- 组件回归测试断言两按钮宽度精确为 26.0dp。

## 发布与构建
- 正式证书签名 Android 各架构包（arm64-v8a、armeabi-v7a、x86_64）、AAB 与 Linux x64 包。
- 零静态分析警告（`flutter analyze --no-pub`），全量回归测试通过。
