# AgY：本轮核心体验 UI 实施

先完整阅读 `agent-workflow/2026-10-15-core-experience.md`。只使用原 Valhalla
会话 Gemini 3.8 Flash high，不新建会话；核心正在并行实现，禁止编辑 lib/core、
lib/data、lib/infrastructure、tests、pubspec、平台或历史文档。仅改指定 UI 与
17个ARB（generated l10n由OpenCode生成）。不运行测试、生成、构建或ADB。
保留已有脏工作区，不reset、不提交、不推送、不执行远端命令、不读取认证文件。

第一批可独立完成：文件工具栏／共用折叠路径、终端历史搜索分组与页签标识、
设置紧凑分组／搜索、Agent卡详情展开。遵循原 Norse Steel tokens、44dp点击区、
320dp和2倍字号，动画150–250ms并尊重减少动画。既有widget keys及actions尽量保留。

第二批：传输筛选和紧凑行；SftpTransfer.pauseReason及pauseAllTransfers()／
resumePausedTransfers()将由核心提供，稍后以子交接文档实际API为准。
恢复顶部单入口及所有对象详情，核心会提供纯优先级投影；使用当前路由优先。
ACP界面拆分订阅和错误动作；核心会提供错误分类。不要自行增加Provider状态
或猜测尚未完成接口，先完成独立UI后汇报再接第二批。

每批完成必须列出修改文件、接口假设、剩余项及不能保证的部分。不要把源码
修改声明成验证通过；不允许跳过窄屏、旧操作或删除既有功能来缩短实现。
