# Flutter 音乐播放器

一个跨 **Android** 与 **Windows** 平台的本地音乐播放器，使用 Flutter 开发。

支持：
- 🎵 自定义扫描多个本地音乐目录
- 🖼️ 同目录封面（`cover.jpg/png`、`folder.jpg/png`、`album.jpg/png` 等），无封面文件时自动回退到嵌入式封面（ID3 APIC / Vorbis APIC）
- 📝 同名 LRC 歌词解析、居中滚动高亮
- ❤️ 收藏 / 最近播放，独立 Tab 查看
- 🎶 自建歌单（新建 / 重命名 / 删除，单曲添加到歌单，歌单一键播放全部）
- 🔔 后台播放与通知栏控制（Android 锁屏/通知栏可控制上一首 / 暂停 / 下一首）
- 🔁 列表循环 / 单曲循环 / 随机播放
- 🌗 浅色 / 深色主题
- 📦 主流格式：mp3 / flac / wav / m4a / aac / ogg / wma / ape / opus
- 📝 用户目录下的日志文件（方便排障）

## 截图
（首版本未提供截图，欢迎社区贡献）

## 下载
最新版本请前往 [Releases](../../releases) 页面下载：
- Windows：`flutter-music-x.y.z-windows-x86_64.zip`，解压后运行 `flutter_music.exe`
- Android：`flutter-music-x.y.z-android-aarch64.apk`，直接安装

最低系统要求：
- Windows 10 及以上
- Android 14（minSdk=34，targetSdk/compileSdk=36，仅打包 arm64-v8a）

## 使用

1. 首次启动后进入「设置」→「扫描目录」→「添加目录」，选择音乐所在文件夹。
2. 应用会自动递归扫描目录中的音频文件、同目录封面（`cover.*` 等）以及同名 `.lrc` 歌词。
3. 回到音乐库点击歌曲即可播放，点击底部迷你播放器进入大播放界面查看歌词。

> 同目录封面命名约定（不区分大小写）：`cover/folder/album/front` + `.jpg/.png/.jpeg`
>
> 歌词命名约定：与音频文件同名，仅扩展名替换为 `.lrc`，例如 `song.mp3` ↔ `song.lrc`

## 日志

日志写入到用户目录下的 `FlutterMusic/logs/app_YYYYMMDD.log`：
- Windows：`%USERPROFILE%\Documents\FlutterMusic\logs\`
- Android：`/storage/emulated/0/Android/data/com.flutter.music/files/FlutterMusic/logs/`

在「设置」→「关于」→「查看日志路径」可一键打开（桌面端）。

## 本地开发

```bash
# 仅本地开发使用阿里云 Maven 镜像
export USE_ALIYUN_MAVEN=true

flutter pub get
flutter analyze
flutter test
flutter run                  # 桌面 / 模拟器
flutter build apk            # Android
flutter build windows        # Windows（需在 Windows 上）
```

> 项目本地不附带 `windows/` 平台目录；构建 Windows 时由 `flutter create --platforms=windows .` 自动生成。

## 技术栈

- Flutter 3.44.1, Material 3
- just_audio + just_audio_background + audio_session（音频播放 / 后台 / 通知栏）
- audio_metadata_reader（元数据 + 嵌入封面）
- file_picker（目录选择）
- permission_handler（Android 13+ 媒体权限）
- provider（状态管理）

## 版本历史

- **v0.3.0**：用户自建歌单。新增「歌单」Tab，支持新建 / 重命名 / 删除（删除歌单不会删除磁盘上的歌曲）；歌曲行尾「…」菜单 / 大播放器新增「添加到歌单」入口，可直接选择已有歌单或现场新建；歌单详情页支持「播放全部」、单曲移除、失效曲目计数提示。歌单以歌曲绝对路径引用，独立于歌曲库缓存，重新扫描后引用关系保持不变。
- **v0.2.1**：代码重构与性能优化（无新功能）。提取 FavoriteToggleButton 公共组件；抽出 PlayerPositionBuilder / PlayingStateBuilder，去除嵌套 ValueListenableBuilder 重复；PlayerProvider 新增 playingListenable 避免播放/暂停时整页重建；随机播放改为 Fisher-Yates 洗牌，一轮内每首歌只播一次；LibraryProvider 缓存 filtered 避免每次 build 重新过滤；LibraryPage 拆分 Tab 为独立 widget，统一空态组件；新增 LibraryProvider 搜索 / LyricParser 边界单测。
- **v0.2.0**：嵌入式封面（无同目录封面时自动回退到 ID3/Vorbis 嵌入封面，带 LRU 缓存）；收藏 / 最近播放（音乐库新增「歌曲/收藏/最近」三个 Tab，歌曲行与大播放器加心形按钮，最近一键清空）；接入 `just_audio_background` 实现后台播放与通知栏元数据同步（标题/艺术家/专辑/封面）。
- **v0.1.x（v0.1.0 → v0.1.3）**：首个 MINOR 系列。v0.1.0 完成最小可用集（自定义扫描目录、播放、同目录封面、LRC 歌词滚动、日志、自适应布局、CI 出包）；v0.1.1/v0.1.2 修复 CI 与 Android 构建（lint 规则、file_picker API/版本兼容）；v0.1.3 重构优化（拆分高频播放进度流为 ValueListenable，列表/迷你播放器不再被 200ms 节奏触发重建；替换 withOpacity → withValues；CoverImage 去同步 IO + cacheWidth；扫描目录路径规范化去重）。

更多详情见 [plan.md](./plan.md)。

## 许可

详见 [LICENSE](./LICENSE)。
