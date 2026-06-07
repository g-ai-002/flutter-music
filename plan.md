# Flutter 音乐播放器 — 项目规划

## 长期目标
- 跨 Android + Windows 双平台的本地音乐播放器
- 完全离线、零依赖云端，尊重用户对本地文件夹的控制权
- 精美克制的界面，操作与主流音乐 App 一致
- 持续可演进：每个版本可独立交付，可观测、可回滚

## 中期目标
- [x] 自定义扫描目录（多目录、可增删）
- [x] 支持主流音频格式（mp3/flac/wav/m4a/aac/ogg/wma/ape/opus）
- [x] 元数据展示（标题/艺术家/专辑/时长）
- [x] 同目录封面图自动匹配（cover/folder/album/front.{jpg,png}）
- [x] 同名 .lrc 歌词解析与滚动高亮
- [x] 列表循环 / 单曲循环 / 随机播放
- [x] 日志系统（按日落盘到用户目录 logs/）
- [x] 嵌入式封面（ID3/Vorbis APIC）展示
- [x] 收藏 / 最近播放
- [x] 后台播放 + 通知栏控制（just_audio_background）
- [x] 歌单（用户自建）
- [ ] 均衡器 / 倍速播放
- [ ] 音频可视化（频谱）
- [ ] 自适应布局（折叠屏/平板/桌面）进一步打磨

## 短期目标
- 持续按 prompt.md 的版本节奏：新功能 → patch 修复 → patch 重构

---

## 版本历史

### v0.3.1 (PATCH)
- **状态**: 已提交 🚧
- **目标**: 修复 Windows + Android 平台音乐无法播放 & Android 签名不一致
- **任务**:
  - [x] Windows: 添加 just_audio_windows 0.2.3 提供 WinRT MediaPlayer 后端
  - [x] Windows: 生成 windows/ 平台目录完成插件注册
  - [x] Android: 修复 audio_service engine ID 不匹配导致 wrongEngineDetected
  - [x] Android: 新增 MainApplication.kt 在 Application.onCreate 中设置正确的 engine ID
  - [x] Android: 新增项目级 debug.keystore 解决构建签名不一致无法覆盖安装

### v0.3.0 (MINOR)
- **状态**: 已发布 ✅
- **目标**: 用户自建歌单（创建 / 重命名 / 删除 / 增删歌曲 / 一键播放）
- **任务**:
  - [x] 数据模型 `Playlist`（id、name、songPaths、createdAt、updatedAt），JSON 序列化
  - [x] StorageService 扩展：`loadPlaylists` / `savePlaylists`（独立 key `playlists_v1`）
  - [x] `PlaylistsProvider`：创建 / 重命名 / 删除歌单，添加 / 移除 / 重排歌曲，重名校验
  - [x] 音乐库新增「歌单」Tab：列表 + 新建按钮 + 长按重命名/删除
  - [x] 歌单详情页 `PlaylistPage`：歌曲列表 + 顶部「播放全部」+ 单曲移除 + 空态引导
  - [x] 「歌曲 / 收藏 / 最近」行尾溢出菜单：添加到歌单（含「新建歌单」）；大播放器追加同入口
  - [x] main 注册 `PlaylistsProvider`
  - [x] 单元测试：Playlist 序列化、PlaylistsProvider CRUD / 重名 / 持久化
  - [x] README / 版本号 0.3.0

### v0.2.1 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 代码重构与性能优化（无新功能）
- **任务**:
  - [x] 提取 FavoriteToggleButton 公共组件，消除 SongTile / PlayerPage 中收藏按钮重复实现
  - [x] 抽出 PlayerPositionBuilder / PlayingStateBuilder 公共组件，去除 MiniPlayer / PlayerPage 进度条嵌套 ValueListenableBuilder 重复
  - [x] PlayerProvider：新增 `playingListenable`，MiniPlayer / 播放控制改用 ValueListenable 避免暂停/播放时整页重建
  - [x] PlayerProvider：改进随机模式下一首质量（Fisher-Yates shuffle 生成完整下一轮顺序，一轮内每首歌只播一次）
  - [x] PlayerProvider：用 StreamSubscription 列表管理流订阅，简化析构
  - [x] LibraryProvider：缓存 `filtered` 搜索结果避免每次 build 重新过滤；trim 后等价的关键字不再重复 notify
  - [x] LibraryPage：拆分 Tab 为独立 widget；合并 `_buildEmpty` / `_buildTabEmpty` 空态组件；搜索栏改用 controller 自身的 ValueListenable 触发清除按钮显隐，移除多余 `setState`
  - [x] 单测：LibraryProvider 搜索过滤、LyricParser 边界（无时间戳行/负 offset/三位毫秒精度）

### v0.2.0 (MINOR)
- **状态**: 已发布 ✅
- **目标**: 嵌入式封面 + 收藏 / 最近播放 + 后台播放 & 通知栏
- **任务**:
  - [x] 嵌入式封面读取（ID3 APIC / Vorbis METADATA_BLOCK_PICTURE）并按内存 LRU 缓存
  - [x] 大播放器与 MiniPlayer 自动回退顺序：同目录封面 → 嵌入封面 → 占位
  - [x] 收藏：在歌曲行 / 大播放器添加心形按钮，持久化到 SharedPreferences
  - [x] 最近播放：每次播放写入头部，去重，最多 100 条
  - [x] 音乐库新增 Tab：歌曲 / 收藏 / 最近
  - [x] 接入 just_audio_background：Android Manifest service + permission；初始化锁屏 / 通知栏元数据
  - [x] 通知栏元数据（标题 / 艺术家 / 专辑 / 封面 URI）随切歌实时更新
  - [x] Windows 上不调用 just_audio_background.init（避免无效启动）
  - [x] 新增工具：内存安全的封面字节 LRU
  - [x] 单测：收藏存取、最近播放截断、LRU 行为
  - [x] 文档与版本号更新

### v0.1.3 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 代码重构与性能优化（无新功能）
- **任务**:
  - [x] 拆分播放进度高频流为 `ValueListenable<Duration>`，避免每 200ms 触发音乐库列表 / MiniPlayer / 整页重建
  - [x] `MiniPlayer` / 大播放器进度条 / `LyricView` 改为订阅 positionListenable
  - [x] 替换已废弃的 `Color.withOpacity` → `withValues(alpha:)`
  - [x] `CoverImage` 去除 build 中的同步 IO（`existsSync`），新增 `cacheWidth/cacheHeight` 限制位图解码尺寸
  - [x] 公共 `formatDuration` 工具，去除 `player_page` / `song_tile` 重复实现
  - [x] 扫描目录路径规范化（trim + 去末尾分隔符 + 去重），避免同一目录多种表示重复添加
  - [x] 移除未使用的 `fileExistsSync` 工具及多余 `dart:io` 导入
  - [x] 单测新增：`formatDuration`、`normalizeDirPath`

### v0.1.2 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 v0.1.1 Android APK 构建失败
- **任务**:
  - [x] file_picker 11.0.2 → 10.3.10（11.x 在 Android 端缺失 FilePickerPlugin 类导致 `compileReleaseJavaWithJavac` 失败）
  - [x] settings_page: 还原为 `FilePicker.platform.getDirectoryPath`
  - [x] 版本号升至 0.1.2

### v0.1.1 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 v0.1.0 的 CI 报错
- **任务**:
  - [x] 修复 `FilePicker.platform.getDirectoryPath` → `FilePicker.getDirectoryPath`（file_picker 11.x API 变更）
  - [x] 移除 analysis_options 中已废弃的 lint 规则 `use_key_in_widgets`
  - [x] 清理 StorageService 未使用的 `_instance` 字段
  - [x] 版本号升至 0.1.1

### v0.1.0 (MINOR)
- **状态**: 已发布 ✅
- **目标**: 首个版本：本地音乐播放器最小可用集
- **任务**:
  - [x] 项目脚手架（pubspec/analysis_options/.gitignore）
  - [x] Android 平台文件（manifest、build.gradle、签名、minSdk=34/targetSdk=36/compileSdk=36）
  - [x] 主题（Material 3 浅/深色、Windows YaHei UI、克制扁平风）
  - [x] 数据模型 Song / Lyrics
  - [x] 服务层：日志、文件系统、存储、扫描、歌词解析
  - [x] 状态层：SettingsProvider / LibraryProvider / PlayerProvider
  - [x] 界面：音乐库 / 播放器 / 设置 + MiniPlayer
  - [x] 同目录封面 + 同名 .lrc 歌词滚动
  - [x] 单元测试：LRC 解析、Song 序列化
  - [x] GitHub Actions：lint + 单测 + Android APK + Windows ZIP + tag 自动 release
  - [x] README/plan

---

## 设计原则
- **离线优先**：所有数据来自本地文件系统，不联网。
- **目录原则**：封面与歌词都按"同目录/同名"约定，遵循发烧友本地音乐组织习惯。
- **元数据降级**：读取 ID3 失败时退化到文件名作为标题。
- **可观测**：所有扫描、加载、错误都写入日志文件，方便排障。
- **包体克制**：当前依赖均为成熟稳定的纯 Dart / Flutter 插件，避免引入大型原生 SDK。

## 依赖与版本基线
- Flutter: 3.44.1
- just_audio: 0.10.5
- audio_session: 0.2.3
- audio_metadata_reader: 1.6.0
- file_picker: 11.0.2
- permission_handler: 12.0.3
- provider: 6.1.5+1
- window_manager: 0.5.1
- shared_preferences: 2.5.5
- path_provider: 2.1.5
- path: 1.9.1
