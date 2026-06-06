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
- [ ] 嵌入式封面（ID3/Vorbis APIC）展示
- [ ] 收藏 / 歌单 / 最近播放
- [ ] 后台播放 + 通知栏控制（just_audio_background）
- [ ] 均衡器 / 倍速播放
- [ ] 音频可视化（频谱）
- [ ] 自适应布局（折叠屏/平板/桌面）进一步打磨

## 短期目标
- 持续按 prompt.md 的版本节奏：新功能 → patch 修复 → patch 重构

---

## 版本历史

### v0.1.0 (MINOR) — 当前开发版本
- **状态**: 开发中 🔧
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
