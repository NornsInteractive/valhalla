# 一条命令本地发布

从仓库根目录运行（优先由 OpenCode 已核验免费模型执行；额度耗尽后按当前授权使用 CodeBuddy 已核验免费模型，主代理负责发布登记）：

```bash
python3 tool/release.py --notes-file agent-workflow/next-release-notes.md \
  --files lib/本批文件.dart test/本批测试.dart docs/本批文档.md
```

`--files`必须逐项列出本批全部变更（包括新脚本自身）；不使用`git add .`，不自动纳入陌生改动。
输入更新说明应包含用户可见变更、实际验证及未覆盖范围。不在说明里放凭据。
每批自动patch版本+1、build+1，提交含`[skip ci]`；Android三架构APK/AAB和Linux x64本地构建，
沿用Norns Interactive固定签名。无Windows/Apple构建、不启动Actions、不自动ADB安装。

流程：语言生成→分析→更新清单/脚本测试→终端相关回归→正式构建→身份/签名/归档/敏感数据审计
→17附件冻结→推送main→新增GitHub草稿并核对全部digest后公开→分发平台暂存四包
→公开默认渠道→四包平台代理整包SHA256和八项Range验证→历史版本及标签/Actions核对。
UI仍只交给AgY，不由发布脚本修改UI。

需要装机验收后再公开时，在首次命令附加 `--build-only`。它仍递增版本、提交显式文件、完成本地构建与冻结，但不推送或创建任何外部发布；验收完成后用同一目录 `--resume` 继续，无需再升号。设备离线时保持此状态，不能把未安装当作通过。

失败后查看打印的日志，在同一源码干净工作区续跑：

```bash
python3 tool/release.py --resume build/local-packages/v1.0.14-release
```

同批失败不再次升号，不覆盖附件、重试不确定的新增请求或改动历史版本。失败暂存文件移动到
带时间戳的证据目录保留，不删除缓存。若首次准备阶段因未选中的改动停止，先人工核对index及
state，完成相同版本的提交并登记source，不能重新发起新批次。

已冻结构建后允许独立提交仅tool/docs/agent-workflow的发布流程修复再续跑；要求原源码是当前HEAD祖先，
产品树没有变化，二进制仍标注原实际源码提交，不移动原标签。MCP和公开API沿用curl传输，避免运行环境对Python客户端的403。

分发平台当前会自动生成无文件/URL/哈希的主包占位。脚本只对自己创建的本批隐藏版本、
下载0/大小0且无R2文件/URL/哈希的占位备份并移除，再登记真实包；不删除任何历史包或实际文件。
最后一条真实包删除后，平台可能返回`pkg_def_<version_id>`虚拟兼容项；脚本不删除它，且不把它当作已登记包。
版本和各包均`use_proxy=true`，下载不跟随重定向，哈希或Range不匹配不报告完成。

依赖：Flutter/Android SDK、Java、Linux编译依赖、Python3.11+、gh、curl、git、tmux（隔离会话回归）。
GitHub用现有gh登录或GH_TOKEN；分发可选`YGG_TOKEN`环境变量，不写入文件/日志。
签名目录默认`/home/dev/.local/share/valhalla-signing`，可由`VALHALLA_SIGN_DIR`覆盖，需包含
`android-release.p12`和`android-release.password`，别名valhalla；证书指纹固定校验。
本地证据在忽略的`build/local-packages/v版本-release`，包含各步骤退出码、UTC、原始输出及状态。

该脚本包含外部写入，只在用户要求发布或当前长期自动发布规则适用时执行，不能用于只读审查。

长构建/发布应使用独立 tmux socket 与会话，避免开发 CLI 的进程清理终止任务；不操作开发者的默认 tmux 或真实 Agent 会话。一次网络读取失败后先确认远端状态，保留失败日志并在同批 `--resume`，不重新升号、覆盖已公开资产或盲目重复不确定的新增请求。
官网项目/产品信息同步使用既有 Norns MCP 项目 ID 与产品 ID，先读取版本及 revision，再更新、核对发布预览、发布和回读。项目发布可能把产品主入口改成分发页，最终应保留原六个分架构下载/商店链接 ID；不新增重复产品。认证只经现有进程环境或内存，不写值入文档。

免费执行器约束：OpenCode 的主模型免费不代表标题等辅助 Agent 也免费。运行时显式设置任务标题并核验辅助模型成本；若日志出现默认非免费辅助请求，停止该次执行，不能依赖余额拒绝来防止计费。不在本流程充值、开启付费回退或改动用户全局模型配置。CodeBuddy 同样只使用当次已核验零成本模型。长门禁与发布由执行器一次性启动独立 tmux 任务后交主代理读回执，不因工具等待超时重复启动。

构建前门禁失败、尚未冻结或外发时，修正应保留本批版本：先备份失败state/日志，提交精确修正并核对差异，确认built/github/ygg均未完成且没有frozen-assets，再将本批state.source登记为实际修正后的提交，使用相同目录--resume（装机前仍带--build-only）。不得把失败源码登记为成功构建源码，也不得用此方式替换已发布附件。
