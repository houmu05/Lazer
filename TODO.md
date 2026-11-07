# TODO

按优先级排列。每条都写了「动哪儿」和「怎么算完成」，接手时可直接挑一条做。
缺陷与风险见 `KNOWN-ISSUES.md`，状态与命令见 `docs/HANDOVER.md`。
2026-11-05 更新：§0 已由用户实测通过；§2 的全量构建与正式签名已完成；
版本口径已定为 `0.1.x` 并实施（§1 首条已勾选），分支改为 `master` 正式主线 +
`nextgen` 预览；§1 的收藏专辑拖动排序与喜欢排序已于 2026-11-07 完成。

## 0. 已完成验证（2026-11-04，用户侧）

- [x] **Windows 包「资料库 → 专辑」**：用 CI run `41809995086` 的
      `Lazer-Windows-x86_64.zip`（head `711f73a`），登录后看到 31 张收藏专辑，
      点进任意一张能加载曲目。用户已确认「目前可用」。
      `KNOWN-ISSUES.md` 中「专辑详情未真机验证」因此关闭。
- [x] 若日后专辑详情出现缺曲目：按 `docs/HANDOVER.md` §5 的方法用真实会话探针抓
      `/album` 响应，先修解析再改 UI（参考 `test/collected_albums_parse_test.dart`）。
      当前未触发。

## 1. 功能补全

- [x] **统一版本口径（2026-11-05 已定并实施）**：采用 fork 的 `0.1.x` 版本线。
      `pubspec.yaml` = `0.1.0+8`（版本名对齐 `v0.1.0`，`+8` 让 Android `versionCode`
      从 7 递增）、`BuildInfo._fallbackVersion` = `0.1.0`、`Runner.rc` 兜底 = `0.1.0`，
      README 版本徽章改为动态读取 GitHub 最新 release。分支包回退值不再大于 `0.1.x`，
      后续 `v0.1.1` 能正常提示升级。
      **后续发版纪律**：tag 去掉 `v` 后等于 pubspec 版本名、`+N` 只增不减、同步
      `BuildInfo` 兜底值；正式 tag 从 `master` 打（不带 `-`），beta tag 从 `nextgen` 打（带 `-`）。
- [x] **收藏专辑长按拖动排序（与歌单一致，2026-11-07 完成）**：
      `_PlaylistRowsSliver` 已抽成通用网格 `_ReorderableItemsSliver<T>`（id + tile + still +
      onReorder），歌单与专辑共用同一套长按/鼠标拖拽、预览、回弹；专辑网格替换了原来的
      `SliverGrid.builder`。`AppState` 新增 `albumOrder` / `setAlbumOrder`（持久化
      `lazer_album_order`），未记录的专辑保持服务端顺序在后；分页加载与会话清空不冲掉顺序。
      标题副文案「长按拖动排序」；回归：`test/library_album_order_test.dart`（拖拽写入偏好、
      排序生效、未知 id 靠后、重启加载）。
- [x] **「我喜欢的音乐」按歌曲名称/歌手名称排序（2026-11-07 完成）**：
      喜欢页头部新增排序菜单（默认顺序 / 歌曲名称 / 歌手名称），排序同时作用于行、头部
      播放/下载、定位与点按生成的队列；平局回退服务端顺序，避免每次重建乱序。
      持久化 `lazer_liked_sort`，回归：`test/liked_sort_test.dart`。
- [ ] **「已购专辑」**：官方客户端在「我的收藏 → 专辑」下有 `收藏专辑 / 已购专辑` 两个 tab。
      目前只做了收藏。先实测接口（很可能仍是 `/album/sublist` 的 `paidCount`/`paid` 变体，
      未确认，禁止猜字段），再在 `lib/data/catalog.dart` + `lib/ui/library_page.dart` 加第二个 tab。
      验收：两个 tab 都能分页、空态正确，新增解析测试。
- [x] **专辑详情页真机验证**（`/album?id=`）：TODO §0 已实测通过。
- [ ] **收藏专辑缓存策略**：目前每页 10 分钟 TTL + 手动刷新。若用户常改收藏，
      考虑在「收藏/取消收藏专辑」入口处 `_expire('user-albums:v2:...')`（尚无该入口时先不做）。

## 2. 打包与发布

- [x] **恢复全量构建**：仓库变量 `LAZER_BUILD_ALL_PLATFORMS=true` 已设置；
      run `41831366536`、`41837109045` 的 check + Windows + 两个 Linux AppImage + Android
      全绿，4 个产物齐全、sha256 校验通过。
- [x] **Android 正式签名**：4 个 secrets 已配置；run `41837109045` 的
      `Verify the APK signature` 输出 `APK signing certificate matches the release keystore.`。
      **密钥原件 `dist/android-signing/` 仍需离线备份**（见 `KNOWN-ISSUES.md` 已解决小节），
      CI 只存可重建的 secrets，不保管密钥文件。
- [x] **Windows MSI 安装包**：`ci/package-windows-msi.ps1` + `ci/windows/lazer.wxs`
      （WiX v3）出 `Lazer-Windows-x86_64.msi`，保留 ZIP 作为免安装版；CI 里先解包
      验证再上传，release job 再用 `msiextract` 复核引擎/FFmpeg/libmpv。
      作者文件改动时用 `Windows MSI smoke` 手动工作流（假包，几分钟）验证。
- [x] **发 beta `v0.1.1-beta.2`（2026-11-07，修复 beta.1 的排序入口与计数）**：tag 指向 `e701279`；beta.1 的 tag 指向 `bca76bb`，已被 beta.2 取代。原始记录：prerelease 由 tag 构建的
      `release` job 发布（含 Windows ZIP+MSI、Linux AppImage×2、Android APK）。
- [ ] **收集 beta 反馈并准备正式版**：beta 版本号 `v0.1.1-beta.1`（仅 `nextgen`），
      `pubspec.yaml` = `0.1.1-beta.1+9`、`Runner.rc` 兜底同步、`docs/releases/` 写说明；
      CI 全绿后打 tag → release job 出 prerelease（含 ZIP+MSI+AppImage+APK）。
      用户验证通过后把 `nextgen` 合回 `master`，用正式 tag（不带 `-`）再发一次。
- [ ] **上游同步策略**（需人决定）：`master` 是默认分支与正式版主线，`nextgen` 是
      预览/beta；`review/2026-11-04` 已删除，两分支都包含原 review 的全部提交。
      上游 `origin/nextgen` 仍是 `7c56023`；本地 `nextgen` 可能还跟踪着上游
      （见 `docs/HANDOVER.md` §1 分支陷阱）。合并上游会因删除 `ios/`/`macos/`
      与文档改写冲突。选项：
      (a) 长期维护 fork，定期 `git rebase`/`merge -X ours` 手工过；
      (b) 把本轮改动整理成上游 PR（专辑功能 + 许可 + CI 修复），上游合并后回退 fork；
      (c) 保持分叉，只定期挑选上游修复。

## 3. 代码质量（来自 `docs/reviews/2026-11-04-code-review.md` 的 P1/P2）

- [ ] `lib/gateway/transport.dart:453`：给响应体读取加超时（现在只超时连接与 `close()`），
      顺带给 429 一个重试/退避分支。验收：新增 transport 测试模拟半开连接/429。
- [ ] 会话 cookie 从 `SharedPreferences` 迁到系统安全存储（`app_state.dart:442/1922`）。
      需要平台插件并重新生成 `pubspec.lock`（CI 有 7 处 `--enforce-lockfile`），
      改动面中等，单独立项。
- [ ] `last_error` 的 FFI 指针竞态（`native/lazer-audio/src/api.cpp:175`、
      `lib/audio/native/lazer_audio_abi.dart:629`）：改成调用方提供缓冲区或返回快照。
- [ ] 输出设备选择真正生效（`lazer_audio_worker.dart:111-116`/`:532`），
      并检查 `setDevice` 返回码后回显失败（`lazer_audio_engine.dart:474`）。
- [ ] `AppState`（3,720 行）按域拆分/不可变快照——长期项，需单独立项。
- [ ] 文档漂移清尾：`docs/audio-engine.md:60` ABI v24 vs 头文件 29；
      `docs/audio-engine-status.md`、`docs/customization-and-audio.md` 里仍残留 Apple 引擎段落；
      `THIRD-PARTY-NOTICES.md` 仍提到 macOS 的 FFmpeg 许可 staging 路径；
      `docs/releases/v2.0.0-*.md` 的历史下载徽章仍指向上游（属历史说明，建议保留不改）。
      README 版本徽章与 CI 链接、`docs/builds.md` 的 CI 链接已于 2026-11-05 修正。
- [ ] 卫生项：删 `lib/screens/catalog_detail_page.dart`（无引用）、
      `test/goldens/` 三张孤儿 PNG 或接上 `matchesGoldenFile`、
      把 `tool/check_i18n.py` 接进 CI。
- [ ] UAC2 决策：`native/lazer-audio` 里 `lazer-uac2` 目标（libusb + JNI）默认不构建、
      无 Kotlin/Dart 消费者。要么接入（jniLibs + `System.loadLibrary` + Dart 面），
      要么删除源码与 CI 残留。

## 4. 运维

- [x] CI 产物保留 30 天；`v0.1.0` 已打 tag 并推送，tag run `41844471311` 全绿，
      release job 在校验桌面包内含原生引擎后自动创建 Release，挂载 4 个平台产物、
      `.sha256` 与 3 个 Android Audio-Relink `tar.gz`。
      发布页：<https://github.com/houmu05/Lazer/releases/tag/v0.1.0>。
      `docs/releases/` 没有 `v0.1.0.md`，本次 notes 走 `--generate-notes`；
      下次若要固定发布说明，按 tag 名补该文件。
- [ ] Windows job 每次重编 FFmpeg（约 20–25 分钟）。若频率高，考虑缓存 FFmpeg 产物
      （`actions/cache` 按 `build_dsd_ffmpeg.sh` 的版本+hash 做 key）。
