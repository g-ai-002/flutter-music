# Flutter 音乐播放器

一个跨 **Android** 与 **Windows** 平台的本地音乐播放器，使用 Flutter 开发。

支持：
- 🎵 自定义扫描多个本地音乐目录
- 🖼️ 同目录封面（`cover.jpg/png`、`folder.jpg/png`、`album.jpg/png` 等）
- 📝 同名 LRC 歌词解析、居中滚动高亮
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
- just_audio + audio_session（音频播放）
- audio_metadata_reader（元数据）
- file_picker（目录选择）
- permission_handler（Android 13+ 媒体权限）
- provider（状态管理）

## 版本历史

- **v0.1.3**：重构优化（无新功能）。拆分播放进度高频流为 ValueListenable，列表/迷你播放器不再被 200ms 节奏触发重建；替换 withOpacity → withValues；CoverImage 去同步 IO + cacheWidth；公共 formatDuration 工具；扫描目录路径规范化去重。
- **v0.1.2**：修复 v0.1.1 Android APK 构建失败（file_picker 11.x → 10.3.10）
- **v0.1.1**：修复 v0.1.0 CI 报错（lint 规则、file_picker API、未使用字段清理）
- **v0.1.0**：首个版本。最小可用：自定义扫描目录、播放、同目录封面、LRC 歌词滚动、日志系统、自适应布局、CI 出包。

更多详情见 [plan.md](./plan.md)。

## 许可

详见 [LICENSE](./LICENSE)。
