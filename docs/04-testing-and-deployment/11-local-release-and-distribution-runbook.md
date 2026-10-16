# 本地构建 → GitHub Releases → 分发平台操作手册

最后核对：2026-10-16。适用于已获批准的 **Android 三架构 APK／AAB + Linux x64** 本地发布。
本文是可复用操作方法，不是执行授权；构建平台和 ADB 安装须按当轮要求决定。
不依赖历史 `/tmp` 发布脚本，不在本文存放密码、Token 或私钥。

**最新长期规则：每批新包都要新增版本。** 同时递增pubspec.yaml语义版本和build，新建GitHub标签／Release及分发版本；
不得再覆盖已发布的同版本附件、移动旧标签或重新登记旧版本包。失败重试仍属同批次，不能重复升号／创建重复记录。
本次升级为1.0.9+10。本文同版本章节只保留作历史审计和事故恢复参考，不适用于后续正常发布。

**1.0.8起的新发布策略：** 用户要求分发平台代理中转。新版本与**每个架构包**均设置
`use_proxy=true`；不能只改版本顶层开关。GitHub外链仍作为源站，客户端下载从分发API
返回200／206流式响应，不能302到GitHub。历史版本保持原设置，除非另有修改授权。

## 1. 固定身份和发布边界

| 项目 | 值／规则 |
| --- | --- |
| GitHub 仓库 | `NornsInteractive/valhalla` |
| 团队显示名称 | `Norns Interactive` |
| 当前源码 Android applicationId | `com.norns.valhalla`（已发布 1.0.6 仍是旧身份） |
| 分发平台 app_id | `com.norns.valhalla`，分发项目保持不变 |
| 分发入口 | <https://ygg.norns.cc.cd/d/com.norns.valhalla> |
| MCP | `https://ygg.norns.cc.cd/api/mcp`，Streamable HTTP |
| 公开检查／下载 | `/api/v1/app/latest`、`/api/v1/app/download` |
| 正式签名 SHA256 | `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d` |

构建、测试默认交 OpenCode，主／辅助模型均确认免费；服务不可用时，须取得当轮直接执行授权。
过去某轮允许主代理打包，不自动成为以后轮次的授权。UI 协作规则不因发布而改变。

本流程不启动 Actions、不修改服务器业务数据、不卸载设备应用或清数据。
不将旧平台包混入新版本；AAB 只作为 Release 附件，不能登记为直接安装的 APK。
正式签名包不能覆盖测试签名安装，不能通过卸载用户应用来绕过签名不一致。

### 应用标识迁移（1.0.7 已发布）

2026-10-14 当前源码将 Android、iOS、macOS、Linux 统一为 `com.norns.valhalla`，
Windows 商店身份不变，正式签名证书不变。历史 1.0.6 APK 的
`com.antigravity.valhalla.valhalla` 仍是当时真实身份；不篡改历史附件、标签或验证清单。
包名变化不能视作普通覆盖升级：Android 新旧应用并存，`adb install -r` 不能把
旧包私有数据迁移到新包；不得卸载旧包或清数据来绕过。发布前必须明示这一点，
并先让用户从旧应用导出配置，在新应用导入。现有配置备份不含凭据、私钥、
会话内容、终端历史、下载文件或 NAS 索引；凭据需重新配置。自定义 OAuth
scheme 保持 `valhalla`，新旧应用共存时回调可能需要用户选择目标应用。
新包清单生成器只接受新身份；同版本覆盖发布旧身份包的历史命令不可直接套用。
Apple 新 Bundle ID 还需匹配相应签名／配置描述，Linux 新 application-id 的
桌面集成需单独验证。1.0.7 已发布新身份 Android／Linux 包；并不代表已自动迁移旧包私有数据。

## 2. 先确认版本和源码，再构建

正常流程只允许**新增版本**：递增 `pubspec.yaml` 的版本与基础 build；新标签／新 Release／新分发版本保持一致。
先查GitHub和分发平台，版本号及各架构真实versionCode都须比上一批递增；不能仅虚增分发目录code或重命名旧包。
同批失败重试先读取已有草稿／暂存记录再续办，禁止盲目再次创建；已发布版本保持只读。

先查看工作区，保留他人改动；仅提交本轮明确属于发布的文件，提交信息带 `[skip ci]`，正常推送到 `main`。
不要自动 `git add .`、覆盖远端分支或提交密钥。远端领先／冲突时先处理，不强推。

以下 Bash 片段在仓库根目录、同一发布 shell 中逐段执行；遇到失败立即停止。
工具需有 Flutter、Android SDK/build-tools、Java、Linux 桌面编译依赖、Python 3.11+、`gh`、`jq`、`curl`。
GitHub 使用已配置的 `gh` 登录／`GITHUB_TOKEN`，不得输出凭据。

```bash
set -euo pipefail
set +x
git status --short
test -z "$(git status --porcelain)"
valhalla_repo=NornsInteractive/valhalla
valhalla_source=$(git rev-parse HEAD)
valhalla_version=$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+.*/\1/p' pubspec.yaml)
valhalla_build=$(sed -nE 's/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)[[:space:]]*$/\1/p' pubspec.yaml)
test -n "$valhalla_version"
test "$valhalla_build" -gt 0
test "$valhalla_build" -lt 1000
valhalla_tag="v$valhalla_version"
valhalla_work=$(mktemp -d /tmp/valhalla-release.XXXXXX)
valhalla_stage="$valhalla_work/artifacts"
mkdir -p "$valhalla_stage" "$valhalla_work/logs"
git ls-files -z lib android linux assets packages pubspec.yaml pubspec.lock |
  xargs -0 sha256sum > "$valhalla_work/source-before.sha256"
git push origin main
test "$(gh api "repos/$valhalla_repo/commits/main" --jq .sha)" = "$valhalla_source"
```

记录版本、完整提交、工具版本和实际测试结果。运行对应变更的回归、静态分析和更新清单工具测试；
大范围变更还需全量测试。复用旧结果必须证明源码相同，不能把历史测试数写成本轮结果。

```bash
flutter analyze
python3 -m unittest discover -s tool -p 'test_generate_update_manifest.py'
git diff --check
```

## 3. 本地正式签名构建

固定签名的备份、配置和兼容性详见 [Android 签名文档](05-android-release-signing.md)。
当前开发环境的签名资料位于仓库外 `/home/dev/.local/share/valhalla-signing`；其他机器需安全配置真实路径。
不要重新生成证书，不把签名文件放进暂存产物；读取密码时关闭 shell tracing。

```bash
(
  set -euo pipefail
  set +x
  valhalla_sign_dir=/home/dev/.local/share/valhalla-signing
  IFS= read -r VALHALLA_ANDROID_STORE_PASSWORD < "$valhalla_sign_dir/android-release.password"
  test -n "$VALHALLA_ANDROID_STORE_PASSWORD"
  export VALHALLA_ANDROID_STORE_PASSWORD
  export VALHALLA_ANDROID_KEYSTORE="$valhalla_sign_dir/android-release.p12"
  export VALHALLA_ANDROID_KEY_ALIAS=valhalla
  export VALHALLA_ANDROID_KEY_PASSWORD="$VALHALLA_ANDROID_STORE_PASSWORD"
  unset VALHALLA_CI_UNSIGNED
  flutter build apk --release --split-per-abi --target lib/main.dart
  flutter build appbundle --release --target lib/main.dart
)
flutter build linux --release --target lib/main.dart
sha256sum -c "$valhalla_work/source-before.sha256"
git diff --exit-code -- pubspec.yaml pubspec.lock
```

分别保留命令、开始／结束 UTC、自身退出码和原始输出文件时间，失败不能用后续命令的退出码冒充成功。
没有上述签名环境变量时，本项目本地 release 会使用 debug key，因此仅有 `--release` **不代表正式签名**。
显式 `lib/main.dart` 避免误用临时探针入口。

已知环境问题：

- 不加 `--no-pub`：本机曾残留 integration-test 插件注册，正常 Flutter 构建负责重新生成；不手改生成文件。
- 全局 `init.gradle` 注入 Maven 仓库可能导致 Flutter included build 报仓库策略冲突。
  先查看日志确认原因，再使用不含该全局脚本的独立 `GRADLE_USER_HOME`；可将其中 `caches`／`wrapper`
  链接到已核实的现有缓存。不要删除缓存、修改全局配置或硬编码历史 `/tmp` 目录为长期依赖。
- 磁盘不足时停止并说明占用，未经许可不清缓存。Flutter 缓存版本文字若与 SDK git 不一致，分别记录，不冒充升级。

仅在确认上述 Gradle 冲突后，可在当前开发容器中这样准备隔离目录，再重跑失败的构建；
其他机器应改用其已核实的缓存路径，不复制 init.gradle：

```bash
test -d /home/dev/.gradle/caches
test -d /home/dev/.gradle/wrapper
valhalla_gradle_home=$(mktemp -d /tmp/valhalla-gradle.XXXXXX)
ln -s /home/dev/.gradle/caches "$valhalla_gradle_home/caches"
ln -s /home/dev/.gradle/wrapper "$valhalla_gradle_home/wrapper"
export GRADLE_USER_HOME="$valhalla_gradle_home"
```

## 4. 暂存、验证、冻结产物

从本次成功构建输出复制到新建的空暂存目录，不能复用旧包冒充新包：

```bash
for valhalla_abi in arm64-v8a armeabi-v7a x86_64; do
  cp -p "build/app/outputs/flutter-apk/app-$valhalla_abi-release.apk" \
    "$valhalla_stage/valhalla-$valhalla_tag-android-$valhalla_abi-signed-$valhalla_build.apk"
done
cp -p build/app/outputs/bundle/release/app-release.aab \
  "$valhalla_stage/valhalla-$valhalla_tag-android-signed.aab"
mkdir -p "$valhalla_work/linux-stage"
cp -a build/linux/x64/release/bundle "$valhalla_work/linux-stage/valhalla"
```

创建 Android／Linux 两份 `valhalla-v<VERSION>-<平台>-BUILD-INFO.txt`，Linux 文件名为
`valhalla-v<VERSION>-linux-x64-BUILD-INFO.txt`；Linux 暂存目录内另放相同 `BUILD-INFO.txt`。
内容至少有：团队名称、版本／build、实际源码完整提交、原标签提交、构建命令／UTC／退出码、
工具版本、签名指纹、各架构版本码及哈希、测试与未验范围。不得复制环境变量全集或认证日志。

Linux 要保留整个 bundle 的可执行文件、`lib/`、`data/` 及许可声明；补充仓库 LICENSE／NOTICE、
xterm、dartssh2、libsmb2 的许可及补丁说明。若发现旧调试 `kernel_blob.bin`，核实为残留后，
仅从本次暂存副本移到证据目录保留，不删除原 build 或全局缓存。完成检查后归档：

```bash
tar -czf "$valhalla_stage/valhalla-$valhalla_tag-linux-x64.tar.gz" \
  -C "$valhalla_work/linux-stage" valhalla
```

上传前必须通过以下门禁：

1. 每份 APK 用 SDK 的 `apksigner verify --verbose --print-certs` 和 `aapt dump badging`，
   检查固定证书、包名、versionName、native ABI 与真实版本码，不能只检查文件名。
2. AAB 用 `jarsigner -verify` 和 `keytool -printcert -jarfile`，同时核对固定证书；如有自签名／时间戳等警告如实记录。
3. ZIP CRC／重复条目；Linux ELF x64、完整 runtime 逐文件一致、执行权限、归档无绝对路径／`..`／异常链接、依赖可解析。
   编译通过不等于 Linux GUI 验收。
4. 扫描产物和解压内容：没有签名密码、私钥库、Token、真实私钥载荷或本地测试入口；原始产物与暂存副本哈希一致。

复用仓库生成器，不自己拼更新清单；生成器检查 APK 身份但**不会代替固定证书比对或完整归档审查**：

```bash
python3 tool/generate_update_manifest.py "$valhalla_stage" \
  --pubspec pubspec.yaml --source-commit "$valhalla_source"
```

Android/Linux 当前范围应有 8 个主文件：3 APK、1 AAB、1 Linux tar、2 BUILD-INFO、1 update.json。
对这 8 个文件分别生成 `.sha256`，并将相同八行写入 `SHA256SUMS.txt`，共 **17 个附件**。
生成器已写 `update.json.sha256`，以下会以同一文件名重算，不新增重复记录：

```bash
valhalla_primary=(
  "valhalla-$valhalla_tag-android-arm64-v8a-signed-$valhalla_build.apk"
  "valhalla-$valhalla_tag-android-armeabi-v7a-signed-$valhalla_build.apk"
  "valhalla-$valhalla_tag-android-x86_64-signed-$valhalla_build.apk"
  "valhalla-$valhalla_tag-android-signed.aab"
  "valhalla-$valhalla_tag-linux-x64.tar.gz"
  "valhalla-$valhalla_tag-android-BUILD-INFO.txt"
  "valhalla-$valhalla_tag-linux-x64-BUILD-INFO.txt"
  "update.json"
)
(
  cd "$valhalla_stage"
  sha256sum "${valhalla_primary[@]}" > SHA256SUMS.txt
  for valhalla_asset in "${valhalla_primary[@]}"; do
    sha256sum "$valhalla_asset" > "$valhalla_asset.sha256"
  done
  sha256sum -c SHA256SUMS.txt
)
```

再冻结全部 17 个文件的名称、字节数、SHA256。
冻结后任何文件变动都必须重新校验并更新清单，不能只换二进制不换哈希。

## 5. 上传 GitHub Release

先准备暂存目录外的 `release-notes.md`，注明本次修复、构建范围、实际源码、签名／同版本限制和验证结果。

### 5.1 新版本

确认目标标签／Release 不存在才创建 draft，不删除或覆盖已有同名版本。源码已推送，提交带 `[skip ci]`；
创建后核对标签指向实际源码。现有工作流可能监听标签，必须检查实际 Actions 状态，不能只靠提交信息推断。

```bash
gh release create "$valhalla_tag" --repo "$valhalla_repo" \
  --target "$valhalla_source" --draft \
  --title "Valhalla $valhalla_tag — Norns Interactive" \
  --notes-file "$valhalla_work/release-notes.md"
```

草稿阶段标签可能尚未建立，按标签查询 Release 可能返回 404；这不等于创建失败。
先用已认证的 releases 列表按唯一 `tag_name`／`draft`／`target_commitish` 找到 ID，
再按 ID 查询并核对。不要因为此 404 重建草稿，公开后再核对真实 Git 标签。

只上传冻结清单中的文件。先上传二进制、BUILD-INFO 及其 sidecar，再上传 SHA256SUMS、
update.json.sha256，最后 update.json。逐个调用的命令形式如下（文件名从冻结清单取值）：

```bash
gh release upload "$valhalla_tag" --repo "$valhalla_repo" "$valhalla_stage/$valhalla_asset"
```

附件数量、API `digest`／size／uploaded 状态全部匹配后，才执行：

```bash
gh release edit "$valhalla_tag" --repo "$valhalla_repo" --draft=false --latest
```

### 5.2 历史审计：覆盖现有版本（后续正常发布禁止使用）

**覆盖前置条件：**先按第 6 节查询并备份分发平台原版本／架构包，确认当下可用的元数据修改方式及当轮权限；
如果需要删除重登记，须先取得准确范围和 ID／计数变化的许可。接口、凭据或权限未准备好时，
不要先覆盖 GitHub 同名文件，否则原分发记录的旧哈希将立即与新二进制不匹配。

先保存当前元数据、标签（包括 annotated tag 的解引用提交）和旧附件；下面的命令只下载备份：

```bash
gh api "repos/$valhalla_repo/releases/tags/$valhalla_tag" > "$valhalla_work/github-before.json"
git ls-remote origin "refs/tags/$valhalla_tag" "refs/tags/$valhalla_tag^{}" > "$valhalla_work/tag-before.txt"
gh release download "$valhalla_tag" --repo "$valhalla_repo" --dir "$valhalla_work/old-assets"
```

核对旧附件的本地备份与远端摘要相同，保留所有不在本次授权范围内的附件。
只有已确认替换的**准确文件名**才允许使用下列命令，上传顺序同上；不要将任意目录通配上传：

```bash
gh release upload "$valhalla_tag" --repo "$valhalla_repo" --clobber "$valhalla_stage/$valhalla_asset"
gh release edit "$valhalla_tag" --repo "$valhalla_repo" --notes-file "$valhalla_work/release-notes.md"
```

不得删除重建 Release、移动标签或更改原 published_at／target_commitish／公开状态。
用 GitHub API 再核对全部资产摘要，而不是只看“上传成功”。网络失败后先查询远端状态，
只补缺失／不匹配的授权附件；读取可以有限重试，新增分发记录等写入不能盲目重试。

## 6. 通过 MCP 同步分发平台

这里只登记 GitHub 的下载直链，不再次上传同一文件到 R2。
先通过连接器完成 MCP 初始化并 `tools/list`，以当时返回的 schema 为准；当前服务亦支持如下直接工具调用。
使用 `Accept: application/json, text/event-stream`。若返回 SSE，按 MCP/SSE 解析，不能强行当普通 JSON。
若服务要求 Bearer，使用已授权的安全配置，不将 Token 放进文档或终端输出；遇 401/403 停止，不绕过认证。

查询目标项目的只读例子：

```bash
curl --fail-with-body --silent --show-error 'https://ygg.norns.cc.cd/api/mcp' \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"ygg_get_app_details","arguments":{"app_id":"com.norns.valhalla"}}}'
```

每次从详情中定位真实 `version_id`／`package_id` 并备份响应；**不要复用历史文档里的 ID**。
检查 JSON-RPC error、`result.isError` 和工具返回内容，HTTP 200 不代表业务成功。

### 6.1 架构与版本对应

令 pubspec 为 `VERSION+B`，`0 < B < 1000`：

| 分发 platform / arch | Release 文件 | 原生版本码 |
| --- | --- | --- |
| android / arm64-v8a | `valhalla-vVERSION-android-arm64-v8a-signed-B.apk` | `2000+B` |
| android / armeabi-v7a | `valhalla-vVERSION-android-armeabi-v7a-signed-B.apk` | `1000+B` |
| android / x86_64 | `valhalla-vVERSION-android-x86_64-signed-B.apk` | `4000+B` |
| linux / x86_64 | `valhalla-vVERSION-linux-x64.tar.gz` | 基础 build 为 B |

当前共享目录约定 `version_name=VERSION+B`、`version_code=2000+B`；它不是所有架构 APK 的原生版本码。
新版本须同时确认目录 code 递增。Linux 文件名／清单使用 x64，分发接口参数使用 x86_64。
客户端按**应用架构**选择包，不按宿主 CPU、文件名猜测或顶层默认包强行替代。

### 6.2 新增版本与架构包

先确认版本不存在，再调用 `ygg_publish_version`，传入项目 ID、目录 code/name、主包直链／文件名／字节数、
`platform=android`、`arch=arm64-v8a`、`use_proxy=true`、更新说明。
先用唯一暂存 channel（例如 `staging-vVERSION`），非强制更新、最低兼容 code 保持原政策。
保存创建回执，不盲目重发创建调用。

先读取新版本详情并检查自动创建的主包，按下方“当前接口陷阱”处理；不要无条件再添加第二个 ARM64 主包。
逐个核对四个目标，仅为缺失目标或已授权重新登记的目标调用 `ygg_add_version_package`，其 arguments 为：

```json
{
  "version_id": "<本次查询得到的 version_id>",
  "platform": "android",
  "arch": "arm64-v8a",
  "external_url": "https://github.com/NornsInteractive/valhalla/releases/download/vVERSION/valhalla-vVERSION-android-arm64-v8a-signed-B.apk",
  "use_proxy": true,
  "file_name": "valhalla-vVERSION-android-arm64-v8a-signed-B.apk",
  "file_size": 1,
  "file_sha256": "<实际文件的64位SHA256>"
}
```

这是字段模板，`VERSION`、`B`、ID、`file_size` 和 SHA 必须替换为本次已验证值，不能直接提交示例。
直链格式为 `https://github.com/NornsInteractive/valhalla/releases/download/<tag>/<准确文件名>`。

**当前接口陷阱（2026-10-13 已验证）：** `ygg_publish_version` 自动创建主包，但不接受主包 SHA256；
`ygg_add_version_package` 是新增，不是 upsert；`ygg_update_version` 不支持包的 size/hash。
2026-10-14 补验：即使创建版本时省略主包 URL，仍会生成无 URL／文件／哈希的占位记录，
不能靠省略 URL 避开此问题。发现后保持暂存渠道并隐藏该版本，再核对和申请准确替换范围。
先检查自动生成的主包，避免无哈希或重复架构。若须替换，只能在已获相应授权后，
备份并核实它确属本轮新建暂存版本、`file_key` 为空、未被用户下载，再补齐哈希重建。
未获替换授权则停留暂存渠道，不带缺失哈希上线。

四个包均唯一、size/hash 正确、GitHub 已公开后，调用 `ygg_update_version`，
传真实 `version_id`、`channel=default`、`is_published=true`、`use_proxy=true`，其余策略不变。

### 6.3 历史审计：同版本重新登记（后续正常发布禁止使用）

优先使用平台未来提供的正式包更新接口；当前管理员 `PUT /api/admin/packages/:packageId`
可原地改包元数据，但需要独立且已授权的管理员会话，不等于 MCP 凭据，不能自行生成或绕过鉴权。

没有该权限且 MCP 仍不支持原地修改时，**必须先取得备份后重新登记指定外链包的许可**：

1. 快照原版本和包；核对项目／版本／平台／架构／旧 URL／哈希／ID，确认 `file_key` 为空。
2. GitHub 目标附件已校验后，新增相同目标的新包，保存返回的新 ID，重新读取并核对全部新字段。
3. 将原包即时快照存档，调用 `ygg_delete_version_package`，只传此授权旧包的准确 `package_id`。
4. 马上确认旧包已移除、新包仍在，且每个目标只有一条记录。其余版本不变，最后更新原版本 changelog。

删除工具可能同时删除 R2 对象；本流程仅允许经核实的 **external-only** 记录，不能把含 `file_key` 的包套用进来。
新增成功但响应丢失时先查询比对，不能重发造成重复。旧 ID／包下载计数无法按原值恢复，必须提前说明。
不要只新增不删除：应用会拒绝重复平台／架构的清单。

GitHub 换包与平台改元数据不是原子操作；短暂期间可能哈希不符，新增到删除间也可能出现重复目标。
先备齐权限和全部新包，再连续完成同步，避免中途停留；无法完成时使用备份恢复，不把半更新状态当交付。

## 7. 公开下载闭环与交付

通过公开 API 携带当前应用的平台、架构、版本检查。以下只读例子模拟 Android ARM64、目录旧版本：

```bash
curl --fail --silent --show-error --get 'https://ygg.norns.cc.cd/api/v1/app/latest' \
  --data-urlencode 'app_id=com.norns.valhalla' \
  --data-urlencode 'version_code=0' \
  --data-urlencode 'channel=default' \
  --data-urlencode 'platform=android' \
  --data-urlencode 'arch=arm64-v8a'
```

对四个目标分别检查 `packages[]` 中唯一匹配项的 ID、版本、文件名、size、SHA256 和下载 URL。
不只检查顶层 `has_update`／默认下载链接；不同 APK 版本码不能直接互相比大小。
从选中包返回的 `download_url` 下载，保留其 `package_id`、再携带 platform/arch；
校验最终 HTTPS 重定向目标，下载到独立证据目录，核对**完整实际字节数和 SHA256**，不能仅做 HEAD 请求。
代理策略要求四个下载不跟随重定向时就返回200且无外部Location；完整文件哈希一致。
另外发送 `Range: bytes=0-65535`，要求206、正确Content-Range及与源文件相同的65536字节。
若平台配置为true但返回502／重定向或忽略Range，不能宣称代理验收成功；保留证据并报告。

最终逐项核对：

- GitHub 附件清单、size、API `digest=sha256:…`、uploaded 状态与冻结结果一致；公开 update.json／SHA256SUMS 与本地相同。
- 四个实际下载通过；没有重复／错架构／无哈希包；其他历史版本未被更改（自然增长的下载计数除外）。
- 原标签／Release 身份在覆盖模式下不变；新模式的标签指向新源码；实际二进制源提交可追溯。
- `gh api "repos/$valhalla_repo/actions/runs?head_sha=$valhalla_source" --jq .total_count` 应为 0，不能只宣称未手动触发。
- 更新发布记录、实现状态和文档索引；文档提交带 `[skip ci]` 并推送，确认远端 main 与本地一致。文档提交不是新包源码。

记录实际构建、下载验证时间及未覆盖范围。发布包验收不等于 ADB／实体手机／真实服务器验收；
本流程不顺带安装设备应用。不要只写“已打包”，要给 Release 和分发链接及明确结果。

## 8. 失败恢复与参考

冻结的新包、旧附件、GitHub 发布前后 JSON、分发详情、创建／删除回执、签名和构建日志均需保留。
`mktemp` 只是隔离工作目录，不是长期备份；将必要证据安全归档到持久存储，密钥／密码单独保护。

需要回滚时，重新核实准确目标和授权：恢复旧附件及 notes，并将对应分发元数据恢复到旧 size/hash，
不能只回滚其中一端。新版本可先按授权撤下该版本；同版本不能靠移动 Git 标签恢复二进制。
备份可恢复内容，但被替换的 GitHub asset ID／下载计数、被删除的分发 package ID／计数不能原样恢复。
未知远端改动、签名不符、来源不明或凭据不足时停止发布并报告。

已实际成功的对照记录：

- [v1.0.9新增版本发布](../../agent-workflow/2026-10-17-v109-release.md)：落实每批递增版本／build的新长期规则，新标签和二进制同源，保留全部历史版本，四整包／八Range及旧端更新请求匹配通过。
- [v1.0.8终端同版本覆盖](../../agent-workflow/2026-10-16-v108-terminal-refresh-release.md)：用户批准后仅替换四条external-only记录，保留原标签／Release身份，17附件及四整包／八Range闭环通过。
- [v1.0.8代理分发](../../agent-workflow/2026-10-16-v108-release.md)：版本及四包代理开关、四次整包SHA256与八次Range验证，历史版本保持不变。
- [首次 v1.0.5 发布](10-v1.0.5-release.md)：新版本流程。
- [v1.0.6 本地发布与 ADB 验收](../../agent-workflow/2026-10-14-v106-release.md)：新标签、隐藏占位处理、四架构与旧 Windows 分流。
- [v1.0.5 同版本覆盖](../../agent-workflow/2026-10-13-v105-refresh-release.md)：原标签保留、正式包替换及四架构重新登记。
- [更新清单生成器](../../tool/generate_update_manifest.py)、[生成器回归](../../tool/test_generate_update_manifest.py)。

本手册不授权复用历史删除 ID、调用已消失的临时脚本、升级 SDK、替换签名或启用付费云端构建。
