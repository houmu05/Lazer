# 接手须知（Handover）

写给下一个接手的人或 AI：这个仓库现在是什么状态、怎么跑、从哪儿继续。
最后更新：2026-11-04。`nextgen` 与 `review/2026-11-04` 保持同一提交，以 `git log -1` 为准。

## 1. 这是什么

`houmu05/Lazer` 是 [chuxuehaocai/Lazer](https://github.com/chuxuehaocai/Lazer) 的 fork，
分支 `nextgen` 是 Flutter 重写的 2.0 客户端（网易云音乐第三方客户端，WEAPI/EAPI 自带、
原生 Hi-Fi 音频引擎）。上游的 `master` 是 Kotlin 的 1.5 老客户端，本 fork 不维护它。

当前 fork 相对上游 `nextgen`（`7c56023`）多出 11 个提交：

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
| `d5b40e5` | 接手文档：`docs/HANDOVER.md`、`TODO.md`、`KNOWN-ISSUES.md` |

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
flutter test --no-pub            # 基线：1065 passed / 0 failed（约 4 分钟）
```

不要改 `pubspec.lock` 去迁就旧 SDK；CI 里 7 处 `--enforce-lockfile`。

## 4. 当前功能边界

- 平台：**Windows / Android / Linux**。macOS/iOS 目标已删除（暂无设备实测），
  `native/` 里的 CoreAudio/RemoteIO 后端源码保留但不再构建。
- 资料库（Library）：本地音乐 + 歌单 + **收藏专辑**（本轮新增）+ 推荐歌单。
- 全量打包目前被仓库变量关掉，只出 Windows 包（见 §6）。

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

- 当前 **只跑 `check` + `windows`**：`linux`、`android`、`release` 的 `if` 是
  `vars.LAZER_BUILD_ALL_PLATFORMS == 'true'`。要恢复全量，在仓库
  Settings → Secrets and variables → Actions → Variables 里把该变量设为 `true`。
- 触发方式：推 `nextgen`（`on.push`）或 `gh workflow run build.yml --ref <branch> -R houmu05/Lazer`。
  fork 的 Actions 需要先在网页 Actions 页启用一次（若报 workflow 404 就是这个原因）。
- Windows job 约 20–25 分钟，大头是每次现场编 FFmpeg（`native/lazer-audio/tools/build_dsd_ffmpeg.sh`）。
- 产物：`Lazer-Windows-x86_64.zip`、两个 `Lazer-Linux-*.AppImage`、`Lazer-Android-universal.apk`；
  下载：`gh run download <run_id> -R houmu05/Lazer -D dist/ci`，每个包都有 `.sha256`。
- Android 没有配 keystore secrets 时是 **debug 签名**（CI 日志有 warning），正式签名需要
  `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。
- 最近一次全量成功：run `41809995086`（head `711f73a`），Windows 包可直接用于测试。

## 7. 已知坑（操作层面）

- 本机没有 Windows/Android 工具链；Windows 包只能由 CI 出，Linux 包需要 GTK/clang/libmpv 等系统依赖。
- fork 的 `nextgen` 已被快进到这里的分支内容，和上游 `7c56023` 分叉；
  合并上游会因删除 `ios/`、`macos/` 与文档改写而冲突。同步策略见 `TODO.md`。
- Windows 测试的是新包还是旧包：看文件名旁的 commit/时间，或进设置页 About 看构建信息。
- 缓存位置（Windows）：`%LOCALAPPDATA%\dev.naominet\lazer_nextgen\lazer_cache_v1`（排查脏缓存直接删）。

## 8. 测试与验证习惯

- 任何改动：`flutter analyze --no-pub` + `flutter test --no-pub` 全绿再提交。
- 网络/协议相关：先写临时探针用真实账号验证响应结构（见 §5 方法），再写解析与 fake 测试，
  参考 `test/collected_albums_parse_test.dart`。
- 文档/CI 改动：用 Dart 的 `package:yaml` 写个几行的临时脚本解析工作流
  （`dart --packages=.dart_tool/package_config.json <脚本>`，脚本放 `build/diag/`），
  并用 grep 确认没有指向已删除路径（`macos/`、`ios/`、`ci/tests/` 之类）。
- 日志与临时探针放 `build/review/`、`build/diag/`（均被 gitignore）。
