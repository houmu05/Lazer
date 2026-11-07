# 已知缺陷与风险

本文件只记录**已核实**的问题（有代码位置或实测证据）；未复现的猜测不写。
完整的审查背景见 `docs/reviews/2026-11-04-code-review.md`，待办见 `TODO.md`。
2026-11-05 更新：按 `v0.1.0` 发布结果与用户实测刷新，并统一为 `0.1.x` 版本线、
`master`/`nextgen` 双分支模型；已解决项集中到文末「已解决」小节。
版本口径已修，收藏专辑缺少长按排序仍未修（见「功能缺口」）。

严重度：P0 发布/数据风险 · P1 正确性/安全 · P2 一致性/维护性。

## 版本 / 发布口径（2026-11-05 已统一为 `0.1.x`）

三套版本号曾并存：系统「应用详情」`2.0.0-beta.5.hotfix`、应用内「关于」`v0.1.0`、
README 徽章 `v2.0.0`。根因是 `pubspec.yaml` 沿用上游版本号，而 `BuildInfo` 读 tag 构建
注入的 `LAZER_VERSION`（`.github/workflows/build.yml:24`）。现已统一：`pubspec.yaml`
= `0.1.0+8`，`BuildInfo._fallbackVersion` = `0.1.0`，`Runner.rc` 兜底 = `0.1.0`，
README 版本徽章改为动态读取 GitHub 最新 release。
注意：已发布的 `v0.1.0` 产物元数据不可追溯修改，仍显示 `2.0.0-beta.5.hotfix`；
三处一致从下一个 tag（`v0.1.1`）起才在产物上体现。

**长期约束（每次发版都要检查，勿凭记忆）**：

| 约束 | 原因 |
| --- | --- |
| pubspec 版本名 = tag 去掉 `v` 后的值 | 系统应用详情、应用内「关于」、更新检查三处才一致 |
| `+N` 只增不减（当前 8，`v0.1.0` 发布时 7） | `android/app/build.gradle.kts:79` 把 `+N` 当 Android `versionCode`，倒退则已装版本无法就地升级 |
| `BuildInfo._fallbackVersion` 同步到最新正式版 | 分支构建用它作 current；曾因回退 `2.0.0-beta.5.hotfix` > `0.1.0` 而不提示升级 |
| 正式 tag 从 `master` 打且不带 `-`；beta tag 从 `nextgen` 打且带 `-` | `release` job 按 tag 名是否含 `-` 判定 prerelease；见 `docs/HANDOVER.md` §1 |

## 功能缺口

| 级别 | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| P1 | 资料库只有「收藏专辑」，没有官方客户端的「已购专辑」tab | 官方客户端截图 vs `lib/ui/library_page.dart` 当前只渲染一个列表；`/album/sublist` 响应的 `paidCount` 语义未实测 | 已购专辑看不到 |
| P2 | v1.5（上游 `origin/master`）「我喜欢」列表上限 1000 | Kotlin `LazerPlaybackQueue.MAX_TRACKS = 1_000`，`loadCompletePlaylist` 取 `min(trackCount, 1000)` | 只影响老客户端；本 fork 的 Flutter 客户端已验证 1154 首完整加载（`test/liked_tracks_test.dart`） |

专辑排序还要处理分页：`:1352-1370` 的 `loadLibraryAlbums(more: true)` 会追加新页，
`:1912` 在会话变化时清空列表。若只对已加载项排序，刷新或「加载更多」会把用户顺序冲掉。

## 打包 / 发布

2026-11-04 已解决两处：4 个 keystore secrets 已配置（CI 日志 `APK signing certificate matches
the release keystore.`），仓库变量 `LAZER_BUILD_ALL_PLATFORMS=true` 已开启并跑通全量矩阵；
`v0.1.0` 的四个平台产物由 release job 自动发布。详见文末「已解决」。

| 级别 | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| P1 | 平台裁剪后与上游分叉 | 删除 `ios/`、`macos/` 与 4 个 CI job；`fork/master` 与 `fork/nextgen` 均为本 fork 最新提交 | 合并上游会冲突，需要人工过 |
| P2 | CI 每次重建 FFmpeg，Windows job 20–25 分钟 | `.github/workflows/build.yml` windows job → `native/lazer-audio/tools/build_dsd_ffmpeg.sh` | 迭代慢，浪费 runner 时间 |

## 网关 / 网络（来自审查，未修）

| 级别 | 问题 | 位置 |
| --- | --- | --- |
| P1 | 传输层无重试/退避/429 处理；响应体读取无超时，半开连接可无限挂起 | `lib/gateway/transport.dart`（`requestTimeout` 只包连接与 `close()`；body 读取在 `:453`） |
| P1 | 会话 cookie 明文存 `SharedPreferences`（P1-3，仍未做） | `lib/state/app_state.dart:442`（key `lazer_gateway_cookie`）、写入 `:1922`、读回 `:1667` |
| P2 | `/album/sublist` 旧解析曾把 `data`/`hasMore` 读成 `albums`/`more` | 已修于 `711f73a`；缓存 key 已升 `v2`，旧盘缓存不会命中 |

## 音频 / 原生

| 级别 | 问题 | 位置 |
| --- | --- | --- |
| P1 | 输出设备选择不生效：`deviceToken` 只作诊断，`_writeDevice` 把 `deviceId` 硬写 `nullptr` | `lib/audio/native/lazer_audio_worker.dart:111-116`、`:532-541` |
| P1 | 播放中改独占/bit-perfect/DSD 静默失效：引擎只在 Idle/Stopped/Failed 接受 `setDevice`，Dart 丢弃返回码 | `native/lazer-audio/src/engine.cpp:1166`、`lib/audio/native/lazer_audio_engine.dart:474` |
| P1 | `last_error` 返回 `std::string::c_str()`，写侧加锁、读侧不加，Dart 逐字节读取 → 可能撕裂 | `native/lazer-audio/src/api.cpp:175`、`lib/audio/native/lazer_audio_abi.dart:629` |
| P2 | UAC2（libusb + JNI）目标默认不构建、无 Kotlin/Dart 消费者 | `native/lazer-audio/CMakeLists.txt:67`、`ci/build-android-audio.sh`；文档见 `docs/android-audio.md` |
| P2 | arm32 引擎被打包但加载列表没有它 | `lib/audio/native/lazer_audio_library.dart:619`、`:632-641` |

## 设计 / 卫生

| 级别 | 问题 | 位置 |
| --- | --- | --- |
| P1 | `AppState` 3,720 行单例上帝对象：100 处通知、55 处偏好读写，反向 import UI | `lib/state/app_state.dart:136`、`:33` |
| P2 | 文档漂移：ABI 写 v24 实为 29；Apple 引擎状态段落仍在；`THIRD-PARTY-NOTICES.md` 提到 macOS 许可 staging 路径 | `docs/audio-engine.md:60`、`docs/audio-engine-status.md`、`docs/customization-and-audio.md` |
| P2 | `docs/releases/v2.0.0-*.md` 的历史下载徽章仍指向上游 release | 四个历史说明文件；属历史记录，建议保留不改 |
| P2 | 死代码/孤儿资产：`lib/screens/catalog_detail_page.dart` 无引用；`test/goldens/` 3 张 PNG 无 `matchesGoldenFile`；`tool/check_i18n.py` 未接 CI | 对应文件 |
| P2 | 三套设计 token 并存（Apple / lake-blue / 羊皮纸） | `lib/theme/apple_design.dart`、`tokens.dart`、`design_tokens.dart` |

## 已解决（保留记录，勿重复排查）

- **Android 正式签名**：2026-11-04 生成 4096 位新密钥并配置 4 个 secrets；
  run `41837109045` 的 `Verify the APK signature` 输出 `APK signing certificate matches
  the release keystore.`，无 debug 签名告警。密钥原件在 `dist/android-signing/`（gitignored），
  **仍需离线备份**。
- **全量构建**：`LAZER_BUILD_ALL_PLATFORMS=true`；run `41831366536`、`41837109045`
  的 check + Windows + Linux×2 + Android 全绿，四个产物齐全。
- **`v0.1.0` 发布**：tag run `41844471311` 全绿，release job 校验桌面包内含原生引擎后创建
  `draft=false`、`prerelease=false` 的 Release，挂载四个平台产物与 `.sha256`。
- **专辑详情真机验证**：TODO §0 由用户实测通过（31 张收藏专辑、可点进详情），
  原「未用真实账号验证」条目已关闭。
- **P1-1 / P1-2 / P1-4**：LAN 遥控器来源与令牌硬化（`5c99480`、`b0ed292`）、
  更新源与关于页指向 fork（`6cc9876`、`2714235`），共 9 条回归测试。
- **版本口径与分支模型**：2026-11-05 统一为 `0.1.x`（pubspec `0.1.0+8`、BuildInfo 兜底
  `0.1.0`、Runner.rc 兜底、README 动态徽章）；新增 `master` 默认分支（正式版），
  `nextgen` 保留为预览/beta，`review/2026-11-04` 已删除，CI 的 push/PR 分支已包含两者。
- **`.gitignore`**：`e133f7a` 补 `android/app/upload-keystore.jks` 与 `android/key.properties`；
  此前 `docs/builds.md` 声称已忽略但并未忽略。
- **P1-3（会话 cookie 明文）仍未解决**，见「网关 / 网络」。

## 已确认不在本仓库的问题

- 「我喜欢的音乐」最多 1000 首：那是 **v1.5（上游 `origin/master` Kotlin）** 的队列上限
  （`LazerPlaybackQueue.MAX_TRACKS = 1_000`），不是 nextgen；nextgen 的 1154 首加载有回归测试。
- 「没有专辑入口」：1.5 里确实没实现（上游聊天确认“后面会补充”）；nextgen 本轮已加收藏专辑。
- 历史里的 `release.jks`（4422 字节 PKCS#8 私钥）由上游 `ed97c01` 引入，
  只在 `origin/master` 可达；本 fork 的 `master`（2026-11-05 新建的 Flutter 正式版主线）
  与 `nextgen` 的树与历史均不含它，且与上游 `origin/master` 不是同一分支。
  **绝不能复用上游密钥**；本 fork 的签名密钥是 2026-11-04 新生成的。
