# 一条命令本地发布

从仓库根目录运行（由OpenCode免费模型执行；主代理负责发布登记）：

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

失败后查看打印的日志，在同一源码干净工作区续跑：

```bash
python3 tool/release.py --resume build/local-packages/v1.0.14-release
```

同批失败不再次升号，不覆盖附件、重试不确定的新增请求或改动历史版本。失败暂存文件移动到
带时间戳的证据目录保留，不删除缓存。若首次准备阶段因未选中的改动停止，先人工核对index及
state，完成相同版本的提交并登记source，不能重新发起新批次。

分发平台当前会自动生成无文件/URL/哈希的主包占位。脚本只对自己创建的本批隐藏版本、
下载0/大小0且无R2文件/URL/哈希的占位备份并移除，再登记真实包；不删除任何历史包或实际文件。
版本和各包均`use_proxy=true`，下载不跟随重定向，哈希或Range不匹配不报告完成。

依赖：Flutter/Android SDK、Java、Linux编译依赖、Python3.11+、gh、curl、git。
GitHub用现有gh登录或GH_TOKEN；分发可选`YGG_TOKEN`环境变量，不写入文件/日志。
签名目录默认`/home/dev/.local/share/valhalla-signing`，可由`VALHALLA_SIGN_DIR`覆盖，需包含
`android-release.p12`和`android-release.password`，别名valhalla；证书指纹固定校验。
本地证据在忽略的`build/local-packages/v版本-release`，包含各步骤退出码、UTC、原始输出及状态。

该脚本包含外部写入，只在用户要求发布或当前长期自动发布规则适用时执行，不能用于只读审查。
