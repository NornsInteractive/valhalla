# 1.0.8+9 终端快捷键同版本覆盖发布

用户要求构建并推送至GitHub最新Release及原分发平台项目。本轮沿用1.0.8+9，
正式签名Android三架构APK／AAB和Linux x64本地构建，不启动Actions，不安装ADB。
包括紧凑快捷键、一体常驻倒T方向组和此前已完成的相关设置、多语言与回归。
不再改产品UI，沿用固定正式证书与`com.norns.valhalla`应用身份。

## 发布约束与进度

- 原GitHub `v1.0.8` Release和标签保持身份、版本及目标提交不变；BUILD-INFO与说明记录新包实际源码。
- 构建和验证交OpenCode，主／辅助模型均固定确认免费的模型；未授权主代理接管本轮构建。
- 既有产品回归161项通过、静态分析无问题，见[终端实施台账](2026-10-16-terminal-single-row.md)。
- 远端main与本地HEAD同步；已只读查询最新Release和分发平台六个版本、当前MCP schema。
- MCP没有原地包哈希更新接口。用户已明确允许备份后仅重新登记当前四个external-only包；
  准备阶段未获确认时保持线上不变，确认后才覆盖附件及原包记录。原始响应已归档，历史五个版本不动。
- 版本与四个正式分发包均保持`use_proxy=true`，最终整包SHA256和Range200／206闭环后才算完成。

产物／证据目录：`build/local-packages/v1.0.8-terminal-refresh-20261016/`。
当前状态：正式包已覆盖GitHub最新v1.0.8 Release，四个分发外链包已重新登记，公开代理下载闭环通过，发布说明已更新。
同版本用户可能需要手动重新下载；不通过虚增目录code强制更新。

## 已完成构建与校验

实际构建源码：`57f25a78d6de228cfda31dcd75171232ae4df95e`，已推送main，提交包含`[skip ci]`；
按完整源码SHA查询Actions运行数为0。原`v1.0.8`标签仍指向
`2205d9d85f85b600f2739a47c446e323e0749874`，不移动标签。

执行者OpenCode `opencode/mimo-v2.6-flash-free`，主模型和辅助模型均固定该已核实免费模型。
发布前复跑161项终端回归、27项更新清单回归通过，静态分析无问题。
首次APK构建遇本机全局init.gradle仓库策略冲突；保留失败日志，仅通过mktemp隔离
GRADLE_USER_HOME并链接已核实的缓存重试，没有修改全局配置或清理缓存。
正式APK、AAB、Linux构建最终均exit0；源码前后哈希一致、工作树干净。

固定正式证书SHA256：`73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`。
APK包名／ABI／版本码与签名验证通过；AAB签名／证书通过，保留自签名链、无时间戳、
POSIX属性及JarInputStream清单顺序警告，不能表述为无警告或应用商店验收。
ZIP CRC、重复条目、凭据／私钥载荷扫描通过。Linux48个运行时文件逐项一致，
ELF x64／依赖可解析／许可证检查通过；旧调试kernel_blob仅从暂存副本移出保留，未删除原输出。
Linux runner为未变更的增量原生程序，校验新编译libapp.so时间，不以旧runner时间误判旧包。

| 产物 | 字节数 | SHA256 |
| --- | ---: | --- |
| Android arm64-v8a APK | 48702924 | `e021e0c4d910db39fa6dc9dd0b13949b11757e1d5b1fa97d5c530de108ede229` |
| Android armeabi-v7a APK | 47008116 | `dc0c6f50b5f3095aa4cdb4b2d60d659520090634ede45169f47d05616fb7cd0b` |
| Android x86_64 APK | 53723444 | `4a7c07d37757f6ad9e25bd970c25f010c0250b6725046d1bff512618ac517645` |
| Android AAB | 83473037 | `6ec627f874fb2c9231c1d5a43f1b69fbd8a76f56c01ccaced21da89c88f15c5c` |
| Linux x64 tar.gz | 24455630 | `ec16bb44ff03e55602c8c2268ff6783556ced33318c3fa749ec8b6b2c84c706a` |

8个主产物／sidecar／SHA256SUMS共17文件已冻结，UTC `2026-10-16T14:54:31Z`。
构建和冻结脚本、原始日志、签名记录、旧Release全部17附件及其摘要核对、MCP schema／六版本快照
均在本轮证据目录。原Release ID `414822326`、分发版本`ver_mvatgmro2wfp`保持原样。
已获批准移除的旧包仅限`pkg_mvatlnliykxs`、`pkg_mvatloczlw2e`、`pkg_mvatlp467j63`、`pkg_mvatlpvb2sj7`；
已核实四包file_key为空，属于当前1.0.8+9的GitHub外链记录；不涉及R2对象或其他历史版本。
准备阶段曾保持Release附件与分发记录不变；后续用户明确回复“允许”后完成下方发布操作。
本轮未ADB安装或ARM实体机／Linux GUI验收。

## 授权后覆盖发布（完成）

OpenCode免费MiMo重新核对17个冻结文件、17个原附件备份、产品源码清单、Release身份、
四个已批准external-only包及六个分发版本快照，exit0。随后仅覆盖冻结清单内17个同名附件，
逐个核对GitHub API digest／size／uploaded状态；四个下载包上传后即时同步对应包记录。
发布脚本首次Python HTTP只读请求返回403；未有MCP写入。按手册使用已验证返回200的普通curl入口继续，
未更改鉴权、伪装UA或轮换账户。已完成的APK上传先按远端摘要确认，未盲目重复覆盖。

| 平台／架构 | 原包记录（已备份后移除） | 新包记录 |
| --- | --- | --- |
| Android arm64-v8a | `pkg_mvatlnliykxs` | `pkg_mvb5xudrbd7z` |
| Android armeabi-v7a | `pkg_mvatloczlw2e` | `pkg_mvb5y9z1wb70` |
| Android x86_64 | `pkg_mvatlp467j63` | `pkg_mvb5yrd5ndua` |
| Linux x86_64 | `pkg_mvatlpvb2sj7` | `pkg_mvb5z6uyib7r` |

四包均在原`ver_mvatgmro2wfp`版本下保持唯一，GitHub源地址／大小／SHA256正确，且`use_proxy=true`。
未删除R2对象或安装包，未增删其他版本；原记录ID和包级下载计数不能原样恢复，内容和元数据备份保留。
原版本default渠道、is_published=true、is_force_update=false、min_version_code=0保持不变，只更新说明及确认代理开关。

OpenCode免费MiMo执行公开下载验收，UTC **2026-10-16 16:13:00至16:15:27**，exit0：

- 四目标公开检查API按platform／arch返回唯一正确新包，版本仍为1.0.8+9。
- 四次完整下载均直接200，字节数和SHA256与冻结文件相同，最终host为ygg.norns.cc.cd，无Location跳转。
- 开头／中段各65536字节，合计八次Range均206，Content-Range和实际字节准确。
- GitHub17附件摘要、公开update.json／SHA256SUMS逐字节一致；原标签和Release ID／published_at／target_commitish不变。
- 按构建源码SHA查询Actions运行数为0。其他五个历史分发版本在排除自然增长的download_count后完全相同。

验收后更新GitHub Release说明与分发changelog，再次读取确认实际源码说明、版本策略及历史版本均正确。
证据：`proxy-verification-refreshed.json`、`public-downloads-refreshed/`、`github-final.json`、
`distribution-final-raw.json`、四包即时删除前快照／增删回执／ID映射及OpenCode原始输出，均在本轮目录。

发布入口：[GitHub v1.0.8](https://github.com/NornsInteractive/valhalla/releases/tag/v1.0.8)、
[分发平台代理下载](https://ygg.norns.cc.cd/d/com.norns.valhalla)。同版本可能需手动重新下载覆盖安装。
文档后续提交不是本批二进制源码；构建源码保持上方57f25a7，未移动Git标签或启动Actions。
