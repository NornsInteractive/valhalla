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
- MCP没有原地包哈希更新接口。已请求用户允许备份后仅重新登记当前四个external-only包；
  未确认之前不能覆盖GitHub附件或删除分发记录。原始响应本地归档，历史五个版本不动。
- 版本与四个正式分发包均保持`use_proxy=true`，最终整包SHA256和Range200／206闭环后才算完成。

产物／证据目录：`build/local-packages/v1.0.8-terminal-refresh-20261016/`。
当前状态：构建、签名及冻结校验已完成；源码已推送，GitHub附件和分发记录未覆盖，等待四包重新登记许可。
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
等待批准的旧包仅限`pkg_mvatlnliykxs`、`pkg_mvatloczlw2e`、`pkg_mvatlp467j63`、`pkg_mvatlpvb2sj7`；
已核实四包file_key为空，属于当前1.0.8+9的GitHub外链记录；不涉及R2对象或其他历史版本。
截至本记录未上传或替换任何Release附件，未增删分发包、未更改分发版本；没有虚报发布完成。
本轮未ADB安装或ARM实体机／Linux GUI验收。
