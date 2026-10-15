# 手动新建才允许创建 tmux

## 已确认规则

- 无默认历史时，首次进入 SSH 页自动创建普通 SSH，不探测或创建 tmux，
  不加入可恢复历史；重复进入保留当前 tab 与输出。
- 用户点击“新建”时，沿用终端页 useTmux 设置；开启才新建 tmux，关闭则普通。
- 保留用户已设置的默认历史自动恢复：精确 attach 已存在会话，不创建替代 tmux。
- 默认历史确认消失后的自动回退仍为普通 SSH；查询失败不能擅自开替代会话。
- 已有会话、默认设置、历史、远端 tmux 均不清理或迁移；普通重连不升级 tmux。
- 本需求替代上一条“临时会话／执行命令后持久化”的设计，不引入命令识别、
  Shell hook、临时标记或自动 kill 逻辑。

## 最小实施范围

`terminal_provider.dart` 的 `_addFresh` 接收显式 `preferTmux`，默认 false。
只有 `addNewTab` 传入现有设置；自动初始化和默认缺失回退沿用 false。
`_restore`、`startupApplied`、服务器隔离与重连防陈旧回调逻辑保持不变。

AgY 原 Valhalla 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b`，
Gemini 3.8 Flash／high，仅澄清各语种终端模式标题和说明：设置针对手动新建，
自动新终端始终普通，恢复已有历史不受该开关影响。不改布局。
OpenCode 优先负责验证；MiMo／Big Pickle 超时，免费 Step 5 完成语言生成，
但测试修改未完成。用户随后授权主代理仅本轮补齐回归、生成和静态检查，
不含打包／安装／推送。历史测试种子改为显式手动创建，真实冷启动／默认
恢复用例保留 ensureInitialized，未全局替换。

## 验证

本轮相关 8 个文件 **155 项通过／0 失败**，退出码 0；其中 provider 39 项
包含在上述总数内，不重复累计。`flutter analyze --no-pub` 零问题，
`dart format --output=none --set-exit-if-changed` 与 `git diff --check` 通过。
`flutter gen-l10n` 由 OpenCode 成功执行，AgY 两个文案键覆盖 17 个 ARB。

已验证：开启 tmux 时自动普通且无远端 tmux、手动按开关、重复进入保留
tab／输出、已有非默认历史不自动恢复或新增 tmux、缺失默认回退为普通、
已有默认即使开关关闭也可恢复、普通重连保留输出且不升级 tmux，以及
历史删除／重命名／隔离／竞态／持久化失败、设置 UI 和输入法回归。

证据目录 `/tmp/valhalla-manual-tmux.3SdG6F`：
- `opencode-step-generate.jsonl`：语言生成成功；MiMo／Big Pickle 超时日志和
  Step 5 未完成测试日志同目录保留，未计为验证通过。
- `root-provider-tests-final.log`：39 项通过。
- `root-terminal-regression.log`：8 文件 155 项通过。
- `root-analyze.log`：全项目分析零问题。
- 首轮测试草稿误用“关闭最后标签”的循环已修正；失败／中止日志保留，
  不计入最终通过结果，未为测试修改“至少保留一个标签”的生产行为。

本轮不打包、不安装、不提交、不推送或发布，不执行生产服务器命令。
这是模拟 SSH 与 Widget 回归，不是实机或真实服务端验收；已有远端 tmux
不会被清理。服务器自己的 Shell 启动脚本若主动启动 tmux，不在本改动控制内。

## 用户追加：主代理正式打包，暂不推送

用户随后明确“你来打正式包，不推送”，主代理已使用原发布证书完成通用
Android APK，版本保持 `1.0.6+7`，包名 `com.norns.valhalla`。本次构建开始
`2026-10-14 16:47:53 UTC`，完成 `16:49:29 UTC`，退出码 0；当前环境本地
时间为 2026-10-15，与本节日期一致。

产物：`build/local-packages/release-1.0.6.T5RMyL/Valhalla-1.0.6+7-android-universal-signed.apk`，
141935500 字节，ARM64／ARMv7／x86_64。SHA256：
`aaea88e199be207d0d444471ab2dc3484f80ebc6d4339addd6ac1315269256e0`。
固定证书指纹、APK 签名、ZIP CRC、包内版本／身份／架构、构建前后 743 个
源码文件哈希均通过。构建使用当前未提交工作区，不能仅以 HEAD 代表源码；
同目录保存源码状态、哈希清单、完整日志、时间、退出码与 BUILD-INFO。
沿用已核实的独立 Gradle 目录避免全局 init.gradle 仓库注入，未修改全局配置。

没有安装、提交、推送、发布或生成其他平台包。新包名不能直接覆盖旧包名的
安装；本次也没有执行私有数据迁移或实体设备验收。
