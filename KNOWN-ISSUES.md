# 已知缺陷与风险

本文件只记录**已核实**的问题（有代码位置或实测证据）；未复现的猜测不写。
完整的审查背景见 `docs/reviews/2026-11-04-code-review.md`，待办见 `TODO.md`。
2026-11-05 更新：按 `v0.1.0` 发布结果与用户实测刷新；已解决项集中到文末「已解决」小节，
两项新反馈见「版本 / 发布口径」与「功能缺口」。

严重度：P0 发布/数据风险 · P1 正确性/安全 · P2 一致性/维护性。

## 版本 / 发布口径

| 级别 | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| P1 | 同一个 `v0.1.0` 安装包对外显示三套版本号：系统「应用详情」是 `2.0.0-beta.5.hotfix`（`+7`），应用内「关于」是 `v0.1.0`，README 徽章是 `v2.0.0` | `pubspec.yaml:19` 的 `version: 2.0.0-beta.5.hotfix+7` 决定 Android `versionName/versionCode` 与 Windows `Runner.rc` 的 `FLUTTER_VERSION`（`windows/runner/Runner.rc:66,72` 是无 define 时的兜底 `2.0.0`）；`lib/diagnostics/build_info.dart:11-12,27-30` 读 `--dart-define=LAZER_VERSION`，tag 构建由 `.github/workflows/build.yml:24` 取 `github.ref_name` = `v0.1.0`；`README.md:18`、`README.en.md:18` 徽章硬编码 `v2.0.0` | 用户无法判断所装版本；更新检查与侧载升级各自以不同数字为准 |
| P1 | 分支构建永远不会提示升级到 `v0.1.0` | `BuildInfo.version` 在 `LAZER_VERSION` 是分支名（解析失败）时回退 `2.0.0-beta.5.hotfix`；`lib/state/app_state.dart:320` 以此为 current，`lib/updates/update_checker.dart:116` 按 SemVer 比较，`0.1.0 < 2.0.0` → 判定无更新 | 用 run `41837109045` 等分支包测试的用户收不到正式版推送，只能手动下载 |
| P1 | 若把 pubspec 直接改成 `0.1.0+1`，Android `versionCode` 会从 7 降到 1 | `android/app/build.gradle.kts:79` 取 `flutter.versionCode`（即 `+N`）；CI 未覆盖该值（`.github/workflows/build.yml:356-358`） | 已装 `v0.1.0` 的设备无法就地升级，必须先卸载 |

**口径待定（需人决定，本轮未改任何版本字符串）**：以 fork 的 `0.1.x` 为唯一版本线，
还是继续沿用上游 `2.0.0-beta.x`。无论选哪条，都要同步 `pubspec.yaml`、两个 README 徽章、
tag 命名、`docs/releases/` notes 文件名与 `BuildInfo` 的兜底值；验收标准见 `TODO.md` §1。

## 功能缺口

| 级别 | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| P1 | 资料库只有「收藏专辑」，没有官方客户端的「已购专辑」tab | 官方客户端截图 vs `lib/ui/library_page.dart` 当前只渲染一个列表；`/album/sublist` 响应的 `paidCount` 语义未实测 | 已购专辑看不到 |
| P2 | 收藏专辑没有歌单那样的长按拖动排序 | 歌单：`lib/ui/library_page.dart:160-167` 用 `_PlaylistRowsSliver(onReorder:)` → `AppState.setPlaylistOrder`（`lib/state/app_state.dart:612-632`，持久化键 `lazer_playlist_order`），标题副文案「长按拖动排序」（`:117`）；专辑：`:231-248` 是纯 `SliverGrid.builder` + `_AlbumCard`（`:1077-1090` 只有 `onTap`），标题只有刷新按钮，`AppState` 无 `albumOrder` 对应物（`:1213` 的 `libraryAlbums` 直接按服务端顺序渲染） | 收藏专辑只能按接口返回顺序显示，无法自定义；与歌单交互不一致 |
| P2 | v1.5（`master` 分支）「我喜欢」列表上限 1000 | Kotlin `LazerPlaybackQueue.MAX_TRACKS = 1_000`，`loadCompletePlaylist` 取 `min(trackCount, 1000)` | 只影响老客户端；2.0/nextgen 已验证 1154 首完整加载（`test/liked_tracks_test.dart`） |

专辑排序还要处理分页：`:1352-1370` 的 `loadLibraryAlbums(more: true)` 会追加新页，
`:1912` 在会话变化时清空列表。若只对已加载项排序，刷新或「加载更多」会把用户顺序冲掉。

## 打包 / 发布

2026-11-04 已解决两处：4 个 keystore secrets 已配置（CI 日志 `APK signing certificate matches
the release keystore.`），仓库变量 `LAZER_BUILD_ALL_PLATFORMS=true` 已开启并跑通全量矩阵；
`v0.1.0` 的四个平台产物由 release job 自动发布。详见文末「已解决」。

| 级别 | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| P1 | 平台裁剪后与上游分叉 | 删除 `ios/`、`macos/` 与 4 个 CI job；fork `nextgen` 已快进到本 fork 最新提交 | 合并上游会冲突，需要人工过 |
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
| P2 | 文档漂移：ABI 写 v24 实为 29；Apple 引擎状态段落仍在；`THIRD-PARTY-NOTICES.md` 提到 macOS 许可 staging 路径；README 徽章仍写 `v2.0.0` | `docs/audio-engine.md:60`、`docs/audio-engine-status.md`、`docs/customization-and-audio.md`、`README.md:18`、`README.en.md:18` |
| P2 | 代码里的仓库链接已统一指向 fork，但 README 的 CI 徽章与 `docs/builds.md:3`、`docs/releases/*.md` 的下载徽章仍指向上游 | `README.md:16,99`、`README.en.md:16,101`、`docs/builds.md` |
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
- **`.gitignore`**：`e133f7a` 补 `android/app/upload-keystore.jks` 与 `android/key.properties`；
  此前 `docs/builds.md` 声称已忽略但并未忽略。
- **P1-3（会话 cookie 明文）仍未解决**，见「网关 / 网络」。

## 已确认不在本仓库的问题

- 「我喜欢的音乐」最多 1000 首：那是 **v1.5（`master` 分支 Kotlin）** 的队列上限
  （`LazerPlaybackQueue.MAX_TRACKS = 1_000`），不是 nextgen；nextgen 的 1154 首加载有回归测试。
- 「没有专辑入口」：1.5 里确实没实现（上游聊天确认“后面会补充”）；nextgen 本轮已加收藏专辑。
- 历史里的 `release.jks`（4422 字节 PKCS#8 私钥）由上游 `ed97c01` 引入，
  只在 `origin/master` 可达；fork 没有 `master` 分支，两个发布分支的树与历史均不含它。
  **绝不能复用上游密钥**；本 fork 的签名密钥是 2026-11-04 新生成的。
