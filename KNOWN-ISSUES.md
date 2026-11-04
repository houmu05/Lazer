# 已知缺陷与风险

本文件只记录**已核实**的问题（有代码位置或实测证据）；未复现的猜测不写。
完整的审查背景见 `docs/reviews/2026-11-04-code-review.md`，待办见 `TODO.md`。

严重度：P0 发布/数据风险 · P1 正确性/安全 · P2 一致性/维护性。

## 功能缺口

| 级别 | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| P1 | 资料库只有「收藏专辑」，没有官方客户端的「已购专辑」tab | 官方客户端截图 vs `lib/ui/library_page.dart` 当前只渲染一个列表；`/album/sublist` 响应的 `paidCount` 语义未实测 | 已购专辑看不到 |
| P1 | 专辑详情页未用真实账号验证 | 本轮只验证了 `/album/sublist`；`albumDetails` 走 `/album?id=`，未用真实会话探测 | 收藏列表能出来但点进去可能缺曲目/信息 |
| P2 | v1.5（`master` 分支）「我喜欢」列表上限 1000 | Kotlin `LazerPlaybackQueue.MAX_TRACKS = 1_000`，`loadCompletePlaylist` 取 `min(trackCount, 1000)` | 只影响老客户端；2.0/nextgen 已验证 1154 首完整加载（`test/liked_tracks_test.dart`） |

## 打包 / 发布

| 级别 | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| P1 | Android APK 是 debug 签名 | 无 keystore secrets，CI 日志 `Release signing secrets are not configured; building a debug-signed APK.` | 不能覆盖安装正式版；分发前必须配 secrets |
| P1 | 平台裁剪后与上游分叉 | 删除 `ios/`、`macos/` 与 4 个 CI job；fork `nextgen` 已快进到 `7a1b041` | 合并上游会冲突，需要人工过 |
| P2 | CI 每次重建 FFmpeg，Windows job 20–25 分钟 | `.github/workflows/build.yml` windows job → `native/lazer-audio/tools/build_dsd_ffmpeg.sh` | 迭代慢，浪费 runner 时间 |
| P2 | 全量打包被变量关闭 | `linux`/`android`/`release` 的 `if: vars.LAZER_BUILD_ALL_PLATFORMS == 'true'`，当前未设 | 只有 Windows 包；Linux/Android 需手动打开 |

## 网关 / 网络（来自审查，未修）

| 级别 | 问题 | 位置 |
| --- | --- | --- |
| P1 | 传输层无重试/退避/429 处理；响应体读取无超时，半开连接可无限挂起 | `lib/gateway/transport.dart`（`requestTimeout` 只包连接与 `close()`；body 读取在 `:453`） |
| P1 | 会话 cookie 明文存 `SharedPreferences` | `lib/state/app_state.dart:442`（key `lazer_gateway_cookie`）、写入 `:1922`、读回 `:1667` |
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
| P2 | 死代码/孤儿资产：`lib/screens/catalog_detail_page.dart` 无引用；`test/goldens/` 3 张 PNG 无 `matchesGoldenFile`；`tool/check_i18n.py` 未接 CI | 对应文件 |
| P2 | 三套设计 token 并存（Apple / lake-blue / 羊皮纸） | `lib/theme/apple_design.dart`、`tokens.dart`、`design_tokens.dart` |

## 已确认不在本仓库的问题

- 「我喜欢的音乐」最多 1000 首：那是 **v1.5（`master` 分支 Kotlin）** 的队列上限
  （`LazerPlaybackQueue.MAX_TRACKS = 1_000`），不是 nextgen；nextgen 的 1154 首加载有回归测试。
- 「没有专辑入口」：1.5 里确实没实现（上游聊天确认“后面会补充”）；nextgen 本轮已加收藏专辑。
