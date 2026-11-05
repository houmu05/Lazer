# TODO

按优先级排列。每条都写了「动哪儿」和「怎么算完成」，接手时可直接挑一条做。
缺陷与风险见 `KNOWN-ISSUES.md`，状态与命令见 `docs/HANDOVER.md`。
2026-11-05 更新：§0 已由用户实测通过；§2 的全量构建与正式签名已完成；
§1 开头加入两条用户测试反馈（版本口径、专辑长按排序）。

## 0. 已完成验证（2026-11-04，用户侧）

- [x] **Windows 包「资料库 → 专辑」**：用 CI run `41809995086` 的
      `Lazer-Windows-x86_64.zip`（head `711f73a`），登录后看到 31 张收藏专辑，
      点进任意一张能加载曲目。用户已确认「目前可用」。
      `KNOWN-ISSUES.md` 中「专辑详情未真机验证」因此关闭。
- [x] 若日后专辑详情出现缺曲目：按 `docs/HANDOVER.md` §5 的方法用真实会话探针抓
      `/album` 响应，先修解析再改 UI（参考 `test/collected_albums_parse_test.dart`）。
      当前未触发。

## 1. 功能补全

- [ ] **统一版本口径（P1，先定策略再动手）**：见 `KNOWN-ISSUES.md`「版本 / 发布口径」。
      需人决定用 fork 的 `0.1.x`，还是继续沿用上游 `2.0.0-beta.x`；确定后同步
      `pubspec.yaml:19`、`README.md:18` / `README.en.md:18` 徽章、tag 命名、
      `docs/releases/` notes 文件名与 `lib/diagnostics/build_info.dart` 的兜底值。
      **硬约束**：`android/app/build.gradle.kts:79` 的 `versionCode` 取 pubspec 的 `+N`，
      当前是 7；改成 `0.1.0+N` 时 `N` 必须 ≥ 8，否则已装 `v0.1.0` 的设备无法就地升级。
      分支包的 `BuildInfo.version` 回退值 `2.0.0-beta.5.hotfix` 比 `0.1.0` 大，
      按 SemVer 比较会判定「无更新」，也要一并处理。
      验收：同一个构建里系统「应用详情」、应用内「关于」、README 徽章三处版本一致；
      分支包能正确提示升级到最新 tag；补 `release_version` / `build_info` 的版本比较测试；
      `flutter analyze --no-pub` 与 `flutter test --no-pub` 全绿。
- [ ] **收藏专辑长按拖动排序（与歌单一致）**：
      复用 `lib/ui/library_page.dart:331` 的 `_PlaylistRowsSliver`（当前绑定 `Playlist`，
      需抽成「id + builder」的通用网格），替换 `:231-248` 的 `SliverGrid.builder`；
      在 `AppState` 加 `albumOrder` / `setAlbumOrder`（参照 `:612-632` 的 `playlistOrder`，
      持久化键建议 `lazer_album_order`），渲染前按 id 排列，未记录的专辑保持服务端顺序在后。
      **注意分页**：`:1352-1370` 的 `loadLibraryAlbums(more: true)` 追加新页、
      `:1912` 在会话变化时清空列表，两者都不得冲掉用户顺序；排序只作用于已加载的专辑。
      验收：长按/鼠标拖拽能预览并落位，点按仍打开专辑详情；刷新与「加载更多」后顺序保持；
      重启后仍在；「专辑」区块标题补 `长按拖动排序` 副文案；
      参照 `test/library_arrangement_test.dart` 补拖拽、持久化、未知 id 三类回归。
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
- [ ] **上游同步策略**（需人决定）：远端 `fork/nextgen` 与 `review/2026-11-04` 指向本 fork
      最新提交，上游仍是 `7c56023`；注意本地 `nextgen` 默认跟踪 `origin/nextgen`（上游），
      直接用它会拿到旧代码（见 `docs/HANDOVER.md` §1 分支陷阱）。用户已决定**保持
      `nextgen` 不改名**，`review` → `nextgen` 的合并在测试通过后由用户执行（TODO §0 已通过）。
      合并上游会因删除 `ios/`/`macos/` 与文档改写冲突。选项：
      (a) 长期维护 fork，定期 `git rebase`/`merge -X ours` 手工过；
      (b) 把本轮改动整理成上游 PR（专辑功能 + 许可 + CI 修复），上游合并后回退 fork；
      (c) 只保留 `review/2026-11-04` 分支，`nextgen` 强制回退到上游。

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
      README 的 CI 徽章与 `docs/builds.md`、`docs/releases/*.md` 的下载徽章仍指向上游；
      README 版本徽章仍是 `v2.0.0`（与 `v0.1.0` 发布不一致，随 §1 的版本口径一起改）。
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
