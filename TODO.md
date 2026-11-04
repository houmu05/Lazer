# TODO

按优先级排列。每条都写了「动哪儿」和「怎么算完成」，接手时可直接挑一条做。
缺陷与风险见 `KNOWN-ISSUES.md`，状态与命令见 `docs/HANDOVER.md`。

## 0. 等验证（用户侧，先做这个）

- [ ] **Windows 包验证「资料库 → 专辑」**：用 CI run `41809995086` 的
      `Lazer-Windows-x86_64.zip`（head `711f73a`），登录后应看到 31 张收藏专辑，
      点进任意一张应加载曲目。
      完成后：`flutter test --no-pub` 里补一条专辑详情的 fake 测试，或在 `KNOWN-ISSUES.md` 记结论。
- [ ] 若专辑详情异常：按 `docs/HANDOVER.md` §5 的方法用真实账号探针抓 `/album` 响应，
      先修解析再改 UI（参考 `test/collected_albums_parse_test.dart`）。

## 1. 功能补全

- [ ] **「已购专辑」**：官方客户端在「我的收藏 → 专辑」下有 `收藏专辑 / 已购专辑` 两个 tab。
      目前只做了收藏。先实测接口（很可能仍是 `/album/sublist` 的 `paidCount`/`paid` 变体，
      未确认，禁止猜字段），再在 `lib/data/catalog.dart` + `lib/ui/library_page.dart` 加第二个 tab。
      验收：两个 tab 都能分页、空态正确，新增解析测试。
- [ ] **专辑详情页真机验证**（`/album?id=`）：确认曲目、简介、发行信息，
      参考 `lib/data/catalog.dart:albumDetails` 与 `lib/_screens`/`player` 现有实现。
- [ ] **收藏专辑缓存策略**：目前每页 10 分钟 TTL + 手动刷新。若用户常改收藏，
      考虑在「收藏/取消收藏专辑」入口处 `_expire('user-albums:v2:...')`（尚无该入口时先不做）。

## 2. 打包与发布

- [ ] **恢复全量构建**：仓库变量 `LAZER_BUILD_ALL_PLATFORMS=true`
      （Settings → Secrets and variables → Actions → Variables），
      然后 `gh workflow run build.yml --ref nextgen -R houmu05/Lazer`。
      验收：check + Windows + 两个 Linux AppImage + Android 全绿，4 个产物齐全、sha256 校验通过。
- [ ] **Android 正式签名**：配置 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、
      `ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD` 四个 secrets；
      否则 APK 永远是 debug 签名（CI 有 warning）。
- [ ] **上游同步策略**（需人决定）：远端 `fork/nextgen` 与 `review/2026-11-04` 指向本 fork 最新提交，
      上游仍是 `7c56023`；注意本地 `nextgen` 默认跟踪 `origin/nextgen`（上游），
      直接用它会拿到旧代码（见 `docs/HANDOVER.md` §1 分支陷阱）。
      合并上游会因删除 `ios/`/`macos/` 与文档改写冲突。选项：
      (a) 长期维护 fork，定期 `git rebase`/`merge -X ours` 手工过；
      (b) 把本轮改动整理成上游 PR（专辑功能 + 许可 + CI 修复），上游合并后回退 fork；
      (c) 只保留 `review/2026-11-04` 分支，`nextgen` 强制回退到上游。

## 3. 代码质量（来自 `docs/reviews/2026-11-04-code-review.md` 的 P1/P2）

- [ ] `lib/gateway/transport.dart:453`：给响应体读取加超时（现在只超时连接与 `close()`），
      顺带给 429 一个重试/退避分支。验收：新增 transport 测试模拟半开连接/429。
- [ ] 会话 cookie 从 `SharedPreferences` 迁到系统安全存储（`app_state.dart:442/1922`）。
      需要平台插件，改动面中等。
- [ ] `last_error` 的 FFI 指针竞态（`native/lazer-audio/src/api.cpp:175`、
      `lib/audio/native/lazer_audio_abi.dart:629`）：改成调用方提供缓冲区或返回快照。
- [ ] 输出设备选择真正生效（`lazer_audio_worker.dart:111-116`/`:532`），
      并检查 `setDevice` 返回码后回显失败（`lazer_audio_engine.dart:474`）。
- [ ] `AppState`（3,720 行）按域拆分/不可变快照——长期项，需单独立项。
- [ ] 文档漂移清尾：`docs/audio-engine.md:60` ABI v24 vs 头文件 29；
      `docs/audio-engine-status.md`、`docs/customization-and-audio.md` 里仍残留 Apple 引擎段落；
      `THIRD-PARTY-NOTICES.md` 仍提到 macOS 的 FFmpeg 许可 staging 路径。
- [ ] 卫生项：删 `lib/screens/catalog_detail_page.dart`（无引用）、
      `test/goldens/` 三张孤儿 PNG 或接上 `matchesGoldenFile`、
      把 `tool/check_i18n.py` 接进 CI。
- [ ] UAC2 决策：`native/lazer-audio` 里 `lazer-uac2` 目标（libusb + JNI）默认不构建、
      无 Kotlin/Dart 消费者。要么接入（jniLibs + `System.loadLibrary` + Dart 面），
      要么删除源码与 CI 残留。

## 4. 运维

- [ ] CI 产物保留 30 天；需要长期留档时把 release 打 tag（`v*`）走 release job，
      但必须先满足 §2 的 `LAZER_BUILD_ALL_PLATFORMS=true`，否则 release 会因缺 Linux/Android 被跳过。
- [ ] Windows job 每次重编 FFmpeg（约 20–25 分钟）。若频率高，考虑缓存 FFmpeg 产物
      （`actions/cache` 按 `build_dsd_ffmpeg.sh` 的版本+hash 做 key）。
