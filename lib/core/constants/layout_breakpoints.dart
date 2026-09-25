/// 全局响应式布局断点与阈值集中定义。
///
/// 遵循统一的三档响应式分级（基于屏幕宽度）：
/// - 紧凑型（Compact / 移动端）：width < [compactMax] (600.0)
/// - 紧凑型（Compact / 移动端）：width < [compactMax] (300.0)
/// - 中屏型（Medium / 平板 / 侧边栏 Rail）：[compactMax] <= width <= [expandedMin] (300.0 ~ 1024.0)
/// - 扩展型（Expanded / 桌面端）：width > [expandedMin] (1024.0)
abstract final class LayoutBreakpoints {
  /// 紧凑型屏幕宽度上限（600.0）。
  ///
  /// 小于此阈值时走紧凑移动端布局（底栏 NavigationBar + 抽屉），
  /// 大于等于此阈值时启用 NavigationRail 侧边栏导航。
  static const double compactMax = 600.0;

  /// 扩展桌面型屏幕宽度下限（1024.0）。
  ///
  /// 大于此阈值时走扩展桌面布局（完整顶栏、Inspector 侧边栏、桌面多栏等），
  /// 且 `context.isDesktop` 判定为 true。
  /// 300.0 ~ 1024.0 区间内为中屏 Rail 布局，内部页面侧栏收起进抽屉，
  /// 保证 900~1024px 区间内不会因双重判定导致内容区被严重挤压。
  static const double expandedMin = 1024.0;

  /// 顶栏显示主机连接详情芯片（host:port 与连接状态）的宽度阈值（900.0）。
  ///
  /// 在中屏充裕区间及桌面端展示此芯片；在宽度不足时自动隐藏以避免顶栏溢出。
  static const double topBarHostInfo = 900.0;

  /// 仪表盘系统性能指标卡（CPU/内存/磁盘）从 2 列切到 4 列的容器宽度阈值（700.0）。
  static const double dashboardMetricsGrid = 700.0;

  /// 设置页外观/主题模式从单列切到双列选项卡片的容器宽度阈值（500.0）。
  static const double settingsThemeCardWide = 500.0;

  /// 大屏多列网格卡片的最大横轴宽度（maxCrossAxisExtent）：
  /// 仪表盘性能指标卡
  static const double gridMetricsMaxExtent = 280.0;

  /// 设置页主题选项卡
  static const double gridThemeCardMaxExtent = 320.0;

  /// SFTP 文件列表项
  static const double gridFileListMaxExtent = 380.0;

  /// Docker 容器卡片
  static const double gridDockerCardMaxExtent = 420.0;

  /// 快捷指令卡片
  static const double gridCommandCardMaxExtent = 400.0;

  /// 智能体管理卡片
  static const double gridAgentCardMaxExtent = 460.0;

  /// 宽屏底部弹窗（Sheet）的最大限制宽度：
  /// 常规底部弹窗（主题快切、服务器选择）
  static const double modalSheetMaxWidth = 560.0;

  /// 宽内容底部弹窗（Docker inspect、传输列表）
  static const double modalSheetWideMaxWidth = 640.0;

  /// 桌面窗口默认尺寸与最小尺寸约束：
  /// 默认窗口宽度（1280.0）
  static const double windowDefaultWidth = 1280.0;

  /// 默认窗口高度（800.0）
  static const double windowDefaultHeight = 800.0;

  /// 最小允许窗口宽度（480.0，容纳紧凑模式底栏 4 项及常见对话框且不发生溢出）
  static const double windowMinWidth = 480.0;

  /// 最小允许窗口高度（400.0）
  static const double windowMinHeight = 400.0;
}
