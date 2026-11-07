# 接手须知（Handover）

写给下一个接手的人或 AI：这个仓库现在是什么状态、怎么跑、从哪儿继续。
最后更新：2026-11-07（`0.1.x` 版本线、`nextgen` 预览线 + `master` 稳定线、Windows MSI、首个 beta `v0.1.1-beta.1`）。
`master`（正式主线）与 `nextgen`（预览 beta）保持同一提交，以 `git log -1` 为准。
**唯一工作副本是 WSL `/home/seele/workspace/Lazer`**，
Windows 侧的副本已弃用（见 §9）。

## 1. 这是什么

`houmu05/Lazer` 是 [chuxuehaocai/Lazer](https://github.com/chuxuehaocai/Lazer) 的 fork，
`master` 是本 fork 的正式版主线，`nextgen` 是预览/beta 分支；两者都是 Flutter 重写的
2.0 客户端（网易云音乐第三方客户端，WEAPI/EAPI 自带、原生 Hi-Fi 音频引擎）。
上游 `origin/master` 是 Kotlin 的 1.5 老客户端，本 fork 不维护它，注意别与主线同名混淆。

相对上游 `origin/nextgen`（`7c56023`），远端 fork 的提交历史如下（**`master` 是稳定线，
`nextgen` 是预览线，两者不再同提交**）：

- `master`：`dd52d3a` 的稳定内容 + `a4cf519` 起的 CI 工具提交（Windows MSI 打包），不含本次功能。
- `nextgen`：`master` 之上再加 `1874b03`（专辑拖动排序 + 喜欢排序）与 beta 版本号，当前即
  `v0.1.1-beta.1` 的候选。功能只在 `nextgen` 验证，通过后再合回 `master` 出正式版。

历史提交（两条分支共有）：

| 提交 | 内容 |
| --- | --- |
| `230ee6b` | 代码审查报告（`docs/reviews/2026-11-04-code-review.md`） |
| `472c2fb` | LICENSE MIT → AGPL-3.0、`THIRD-PARTY-NOTICES.md`、UAC2 文档、`tool/check_toolchain.sh` + `docs/local-build.md` |
| `3479019` | 平台裁剪：删除 `ios/`、`macos/`、iOS CI 助手与 4 个 Apple job |
| `ccd2c07` | 资料库「收藏专辑」功能（gateway/catalog/state/UI + 测试） |
| `9c8b8e0` | 回归测试：>1000 首的「我喜欢」完整加载 |
| `1d7b949` | CI：删除空的 python unittest 步骤 |
| `d4c229a` | CI：AppImage 图标不再读 `macos/` |
| `dd37c52` | CI：补 256px 图标（linuxdeploy 不接受 1024） |
| `711f73a` | **修复 `/album/sublist` 解析**（`data`/`hasMore`，见 §5） |
| `7a1b041` | CI：暂时只打包 Windows（仓库变量控制，见 §6） |
| `6cc9876` | 更新检查改指本 fork（`houmu05/Lazer`） |
| `5c99480` | LAN 遥控器安全硬化：限制 LAN 来源、Origin 改由服务端构造、令牌改走 `Authorization` 头 + 6 条回归 |
| `b0ed292` | 删除冗余 import（CI analyzer 修复） |
| 最新一条（`git log -1`） | 关于页与检查更新统一指向本 fork、`.gitignore` 补密钥规则、交接文档 |
| `1874b03`（仅 `nextgen`） | 资料库「专辑」长按/鼠标拖动排序（`lazer_album_order`）+「我喜欢」按歌曲/歌手排序（`lazer_liked_sort`），+8 个测试 |
| `a4cf519`（`master`/`nextgen`） | Windows MSI 工具链：`ci/package-windows-msi.ps1` + `ci/windows/lazer.wxs` + `Windows MSI smoke` 工作流 |
| 2026-11-07（`git log -1`） | 资料库「专辑」支持长按/鼠标拖动排序（`lazer_album_order`，通用可排序网格）；「我喜欢的音乐」新增按歌曲名称/歌手名称排序（`lazer_liked_sort`），+8 个测试 |
 
> **分支陷阱（先看这个）**：本 fork 的代码在远端 `fork`（指向 `houmu05/Lazer`）的
> **`master`** 上（默认分支），`nextgen` 是同提交的预览分支。本地 clone 的 `nextgen`
> 默认跟踪 `origin/nextgen`（上游），通常仍停在 `7c56023`；直接 `git checkout nextgen`
> 会退回上游旧代码。接手时先 `git fetch fork`，再 `git checkout -B master fork/master`
> （正式主线）或 `git checkout -B nextgen fork/nextgen`（预览）。
> 用 `git ls-remote --heads fork` 确认远端实际指向，不要相信本地分支名。
> 上游的 Kotlin 1.5 老分支一律写作 `origin/master`，不要与本 fork 的 `master` 混淆。

### 分支模型（2026-11-05 起）

| 分支 | 用途 | tag 规则 | Release 类型 |
| --- | --- | --- | --- |
| `master`（默认分支） | 正式版主线，只收已验证的改动 | `v0.1.1` 这类不带 `-` 的 `0.1.x` tag | 正式 Release |
| `nextgen` | 预览 / beta，改动先落这里验证 | `v0.2.0-beta.1` 这类带 `-` 的 tag | prerelease（`build.yml` 按 tag 名含 `-` 判定） |

- `review/2026-11-04` 已于 2026-11-05 删除，全部提交都在 `master` / `nextgen` 上；
  如需恢复：`git push fork <该分支最后的 sha>:refs/heads/review/2026-11-04`。
- CI 的 `on.push.branches` 与 `on.pull_request.branches` 都列了 `master` 与 `nextgen`；
  少写 `master` 会导致主线推送完全不触发构建。`tags: ['v*']` 独立于分支。
- 版本线是 fork 的 `0.1.x`：`pubspec.yaml` 版本名 = tag 去掉 `v`，`+N` 是 Android
  `versionCode`，**只增不减**（`v0.1.0` 发布时 `+7`，现为 `+8`）；发版时还要同步
  `BuildInfo._fallbackVersion` 与 `docs/releases/<tag>.md`。

## 2. 先读什么

1. 本文件（状态、命令、坑）。
2. `TODO.md`（下一步做什么）与 `KNOWN-ISSUES.md`（已知缺陷与风险）。
3. `docs/reviews/2026-11-04-code-review.md`（完整架构地图 + P0–P2 风险清单，带 `file:line`）。
4. 需要改代码时再看 `docs/local-build.md`、`docs/builds.md`、`docs/audio-engine.md`。

## 3. 环境与基线（WSL/Linux）

```bash
# 官方 SDK 固定 3.47.0（Dart 3.13.0），详见 docs/local-build.md
export PATH=/home/seele/toolchains/flutter-3.47.0/bin:$PATH   # 本机路径；换机器按文档装
cd /home/seele/workspace/Lazer
tool/check_toolchain.sh          # 版本/依赖自检
flutter pub get --enforce-lockfile
flutter analyze --no-pub         # 基线：No issues found!
flutter test --no-pub            # 必须全绿（约 4 分钟）；数字口径见下方说明
```

不要改 `pubspec.lock` 去迁就旧 SDK；CI 里 7 处 `--enforce-lockfile`。

工作副本与工具链约定（2026-11-04 起）：

- **唯一工作副本**：WSL `/home/seele/workspace/Lazer`。不再维护 Windows 副本。
- Windows 侧只留构建产物与密钥备份；PowerShell 一律用 **PowerShell 7**（`pwsh` 7.6.9）。
  Windows PowerShell 5.1 向 `pwsh -Command` 传含双引号的脚本时会剥离引号；
  `-EncodedCommand` 会被安全策略拒绝，改用明文 `.ps1` + `pwsh -File`。
- 便携 JDK（只为 `keytool`）：Windows 侧 `~/.workbuddy-ai/tools/jdk17/jdk-17.0.21+9`。
- **受限会话可能禁止调用 `wsl.exe`**（安全策略黑名单，不可绕过）。此时只能通过
  `\\wsl.localhost\Debian\home\seele\workspace\Lazer` 读写文件、用 Windows 的
  `git -C` 操作仓库，**不能执行 WSL 内的 flutter/shell 命令**；这类命令请在 WSL 终端手动执行。

数字口径：审查当时的测试基线是 **1056**（静态扫描 936 个 `test()`/`testWidgets()` 调用点）；
随后新增 9 个用例（收藏专辑 3 + liked 1 + 资料库 widget 1 + `/album/sublist` 解析 4），
用户本机复跑确认 **1065 passed / 0 failed**（945 个调用点）。`docs/reviews/2026-11-04-code-review.md`
里的 1056 是审查当时的历史快照。2026-11-04 的安全修复又加了 9 条回归（更新检查 3、
LAN 遥控器 6），静态调用点现为 **954**（159 个测试文件）。2026-11-05 的 CI
（run `41978492846` / `41978501274`）在 `master` 与 `nextgen` 上分别实测
**`flutter analyze --no-pub` = 0 issues、`flutter test --no-pub` = 1082 passed / 0 failed**。
当前基线就是 **1082**（962 个调用点、161 个测试文件）；1074、1065 与 1056 都是历史快照，本地复跑若数字不同，先查是否有新增用例。

## 4. 当前功能边界

- 平台：**Windows / Android / Linux**。macOS/iOS 目标已删除（暂无设备实测），
  `native/` 里的 CoreAudio/RemoteIO 后端源码保留但不再构建。
- 资料库（Library）：本地音乐 + 歌单 + **收藏专辑**（本轮新增）+ 推荐歌单。
- 全量打包已恢复（`LAZER_BUILD_ALL_PLATFORMS=true`），四个产物齐全（见 §6）。

## 5. 关键接口契约（实测，勿凭记忆改）

`/album/sublist`（weapi，`web: true`，参数 `limit` / `offset` / `total`）真实返回：

```
{ code: 200, data: [ {id, name, picUrl, artists:[{id,name,...}], size, subTime, ...} ],
  count: 31, hasMore: true, paidCount: 0 }
```

- 列表在 **`data`**，分页标志是 **`hasMore`**；早期代码读 `albums`/`more` 导致空列表（`711f73a` 已修，兼容两种）。
- 专辑对象没有 `publishTime`，年份留空是正常现象；曲目数用 `size`。
- 目录缓存 key 版本：`user-albums:v2:<cookie sha256>:<uid>:<offset>`（v1 是坏解析，已弃用；
  若改解析逻辑记得再升版本，否则旧盘缓存还会命中）。
- 会话 cookie 存在 Windows 侧 `%APPDATA%\dev.naominet\lazer_nextgen\shared_preferences.json`
  的 `flutter.lazer_gateway_cookie`。调试真实接口时可临时写一个 `build/diag/*_test.dart`
  探针（`HttpOverrides.global = null`）读取它——**不要把 cookie 贴进日志、提交或对话**。

## 6. 构建与打包

CI：`.github/workflows/build.yml`，job = `check` + `windows` + `linux` + `android` + `release`。

- 全量已恢复：仓库变量 `LAZER_BUILD_ALL_PLATFORMS=true` 已设置，`linux`、`android`、
  `release` 的 `if` 因此成立。要临时回到只打 Windows，删除该变量或设为非 `true`。
- 触发方式：推 `master` 或 `nextgen`（`on.push.branches` 两者都列了）、推 `v*` tag，
  或 `gh workflow run build.yml --ref <branch> -R houmu05/Lazer`。
  fork 的 Actions 需要先在网页 Actions 页启用一次（若报 workflow 404 就是这个原因）。
- Windows job 约 20–25 分钟，大头是每次现场编 FFmpeg（`native/lazer-audio/tools/build_dsd_ffmpeg.sh`）。
- 产物：`Lazer-Windows-x86_64.zip`（免安装）、`Lazer-Windows-x86_64.msi`（安装版）、
  两个 `Lazer-Linux-*.AppImage`、`Lazer-Android-universal.apk`；
  下载：`gh run download <run_id> -R houmu05/Lazer -D dist/ci`，每个包都有 `.sha256`。
- Windows MSI：`ci/package-windows-msi.ps1` + `ci/windows/lazer.wxs`（WiX v3：开始菜单
  快捷方式、ARP 图标、MajorUpgrade）。脚本会先 `msiexec /a` 解包验证包内含
  `lazer_nextgen.exe` 才允许上传；`release` job 还会在 Linux 上用 `msiextract` 再验一次
  引擎/FFmpeg/libmpv 是否在包里。作者文件改动时可用手动工作流 `Windows MSI smoke`
  用假包在几分钟内验证，不必跑完整 Windows 构建。
- Android 签名：**4 个 secrets 已配置**（`ANDROID_KEYSTORE_BASE64`、
  `ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`），
  分支与 tag 构建都是正式签名。密钥原件在 `dist/android-signing/`
  （`upload-keystore.jks`、`upload-keystore.jks.base64.txt`、`github-secrets.txt`），
  **必须离线备份**：它是应用更新的信任根，丢失后已安装版本永远无法就地升级。
  tag 构建缺 secrets 会直接失败（`build.yml:326-329`）。
- 最近一次全量成功：run `41837109045`（head `b0ed292`，正式签名验证），4 个产物齐全。
- 发布：打 `v*` tag 并推送 → `release` job 下载全部产物（ZIP、MSI、AppImage、APK）、
  校验 ZIP 与 MSI 内含原生引擎、创建 GitHub Release。tag 名含 `-` 会被标为 prerelease。
  流程：
  1. beta：在 `nextgen` 上把 `pubspec.yaml` 版本名改成 tag 去掉 `v`、`+N` 递增，
     同步 `windows/runner/Runner.rc` 兜底值，写 `docs/releases/<tag>.md`；
  2. 推 `nextgen` 等 check/windows/linux/android 全绿；
  3. `git tag v0.1.1-beta.1 && git push fork v0.1.1-beta.1`，等 release job 出 prerelease；
  4. 用户验证 beta 后把 `nextgen` 合回 `master`，用正式 tag（不带 `-`）再发一次。

## 7. 已知坑（操作层面）

- 本机没有 Windows/Android 工具链；Windows 包只能由 CI 出，Linux 包需要 GTK/clang/libmpv 等系统依赖。
- fork 与上游已分叉：远端 `fork/master` 是稳定线（MSI 工具链提交），`fork/nextgen` 是
  预览线（本次功能 + beta 版本），上游 `origin/nextgen` 仍是 `7c56023`；
  本地 `nextgen` 可能还跟踪着 `origin/nextgen`（见 §1 的分支陷阱）。合并上游会因删除
  `ios/`、`macos/` 与文档改写而冲突，同步策略见 `TODO.md`。
- Windows 测试的是新包还是旧包：看文件名旁的 commit/时间，或进设置页 About 看构建信息。
- 缓存位置（Windows）：`%LOCALAPPDATA%\dev.naominet\lazer_nextgen\lazer_cache_v1`（排查脏缓存直接删）。
- **`wsl.exe` 可能被安全策略拦截**：受限会话里无法执行 WSL 命令，只能通过
  `\\wsl.localhost\Debian\home\seele\workspace\Lazer` 读写文件、用 Windows `git -C`
  操作仓库。要在 WSL 里跑 flutter/test，请在 WSL 终端执行。
- **发布密钥只此一份**：`dist/android-signing/` 不进 git，CI 也不保管原件。
  备份到离线介质；不要把 `.jks` 或 `github-secrets.txt` 贴进对话、日志或提交。

## 8. 测试与验证习惯

- 任何改动：`flutter analyze --no-pub` + `flutter test --no-pub` 全绿再提交。
- 网络/协议相关：先写临时探针用真实账号验证响应结构（见 §5 方法），再写解析与 fake 测试，
  参考 `test/collected_albums_parse_test.dart`。
- 文档/CI 改动：用 Dart 的 `package:yaml` 写个几行的临时脚本解析工作流
  （`dart --packages=.dart_tool/package_config.json <脚本>`，脚本放 `build/diag/`），
  并用 grep 确认没有指向已删除路径（`macos/`、`ios/`、`ci/tests/` 之类）。
- 日志与临时探针放 `build/review/`、`build/diag/`（均被 gitignore）。

## 9. 2026-11-04 发布与工作副本迁移

- **版本标签**：`v0.1.0`，本 fork 的首个发布标签。发布时 `pubspec.yaml` 仍是上游的
  `2.0.0-beta.5.hotfix+7`，造成三套版本号并存；2026-11-05 已统一为 `0.1.x`（见下方反馈 §1）。
  tag 不含 `-`，`release` job 按正式版发布；`docs/releases/` 没有 `v0.1.0.md`，
  notes 走 `--generate-notes`。
- **发布结果**：<https://github.com/houmu05/Lazer/releases/tag/v0.1.0>，
  run `41844471311` 全绿，`draft=false`、`prerelease=false`；4 个平台产物、
  `.sha256` 与 3 个 Android Audio-Relink `tar.gz` 已挂载。
- **工作副本**：从本次起只在 WSL `/home/seele/workspace/Lazer` 维护。
  Windows `C:\Users\houmu\WorkBuddy AI\LAZER` 仅保留历史副本、构建产物与密钥备份，
  不再更新，也不再与 WSL 双向同步。
- **本轮安全修复**（当时在 `review/2026-11-04` 分支，该分支已删除）：
  含 P1-1/P1-2（LAN 遥控器）、P1-4（更新源）修复与 9 条回归测试。P1-3（会话 cookie 明文）仍未做：需要平台安全存储插件并
  重新生成 `pubspec.lock`，而 CI 使用 `--enforce-lockfile`，属单独立项。
- **`.gitignore`**：已补 `android/app/upload-keystore.jks` 与 `android/key.properties`。
  此前 `docs/builds.md` 声称两者已忽略但实际没有，是真实缺陷（会导致私钥误提交）。
- **链接口径**：关于页（`lib/ui/settings_page.dart`）与检查更新
  （`lib/updates/update_checker.dart`）都指向 `https://github.com/houmu05/Lazer`，
  不再指向上游；`test/about_project_link_test.dart` 与 `test/update_checker_test.dart`
  已同步断言。
- **分支整理（2026-11-05）**：新增 `master` 作为默认分支与正式版主线，`nextgen` 保留为
  预览/beta，`review/2026-11-04` 已删除（两分支均含其全部提交）。`nextgen` 不改名 `main`。
- **残余风险**（沿用安全评估）：LAN 遥控器首次配对 URL 仍含令牌、传输仍是明文 HTTP；
  彻底解决需一次性配对码 + 本地 TLS。

### 2026-11-05 用户测试反馈（1 已修 / 2 未修，详见 `TODO.md` §1）

1. **版本显示不一致（已修）**：统一采用 fork 的 `0.1.x` 版本线。`pubspec.yaml` 改为
   `0.1.0+8`（版本名对齐 `v0.1.0`，`+8` 让 Android `versionCode` 从 7 递增而非倒退），
   `BuildInfo._fallbackVersion` 改为 `0.1.0`，`Runner.rc` 兜底同步，README 版本徽章
   改为动态读取 GitHub 最新 release。分支构建过去回退 `2.0.0-beta.5.hotfix`，
   按 SemVer 大于 `0.1.0` 所以不提示升级；现在回退 `0.1.0`，后续 `v0.1.1` 能正常提示。
   已发布的 `v0.1.0` 产物元数据不可追溯修改，仍显示旧版本号；从 `v0.1.1` 起才在产物上一致。
   **发版纪律**：打 tag 前同步 `pubspec.yaml`（版本名 = tag 去掉 `v`、`+N` 只增）、
   `BuildInfo` 兜底值与 `docs/releases/<tag>.md`；正式 tag 从 `master` 打，beta 从 `nextgen` 打。
2. **收藏专辑拖动排序与喜欢排序（2026-11-07 已实现，仅在 `nextgen`）**：
   歌单拖拽网格抽成通用 `_ReorderableItemsSliver<T>`，专辑复用同一套拖拽/预览/落位；
   `AppState` 增加 `albumOrder`（`lazer_album_order`）与 `likedSort`（`lazer_liked_sort`）。
   回归：`test/library_album_order_test.dart`、`test/liked_sort_test.dart`。
   版本号提到 `0.1.1-beta.1+9`，beta tag 从 `nextgen` 出；验证后合回 `master` 出正式版。

证据、影响与验收标准见 `KNOWN-ISSUES.md`「版本 / 发布口径」「功能缺口」两节。
