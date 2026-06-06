import 'dart:io' show Platform;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/library_page.dart';
import 'providers/favorites_provider.dart';
import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlists_provider.dart';
import 'providers/settings_provider.dart';
import 'services/log_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(1180, 760),
      minimumSize: Size(720, 480),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppConstants.appName,
    );
    windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 必须先初始化存储和日志，避免后续并发触发 late init 错误
  final storage = await StorageService.instance;
  await LogService.init();
  LogService.info('应用启动: ${AppConstants.appName} v${AppConstants.version}');

  // 后台播放 / 通知栏（Android / iOS / macOS 支持，Windows 桌面端跳过）
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.flutter.music.channel.audio',
        androidNotificationChannelName: '音乐播放',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      );
    } catch (e, st) {
      LogService.error('初始化后台播放失败', e, st);
    }
  }

  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    LogService.warning('配置音频会话失败: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(MusicApp(storage: storage));
}

class MusicApp extends StatelessWidget {
  final StorageService storage;
  const MusicApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final fontFamily = Platform.isWindows ? 'Microsoft YaHei UI' : null;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => LibraryProvider(storage)),
        ChangeNotifierProvider(create: (_) => FavoritesProvider(storage)),
        ChangeNotifierProvider(create: (_) => PlaylistsProvider(storage)),
        ChangeNotifierProxyProvider2<SettingsProvider, FavoritesProvider,
            PlayerProvider>(
          create: (ctx) {
            final p = PlayerProvider(storage, ctx.read<SettingsProvider>());
            p.onSongStart = (song) {
              ctx.read<FavoritesProvider>().recordPlay(song.path);
            };
            return p;
          },
          update: (_, __, ___, prev) => prev!,
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(fontFamily: fontFamily),
            darkTheme: buildDarkTheme(fontFamily: fontFamily),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            home: const _Boot(),
          );
        },
      ),
    );
  }
}

/// 启动后做一次初始化：恢复上次队列 / 触发首次扫描
class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final library = context.read<LibraryProvider>();
      final settings = context.read<SettingsProvider>();
      final player = context.read<PlayerProvider>();

      // 用缓存歌曲列表恢复队列（不自动播放）
      if (library.songs.isNotEmpty) {
        await player.setQueue(library.songs, resumeLast: true);
      }

      // 若设置了扫描目录但是缓存为空，则做一次扫描
      if (settings.scanDirs.isNotEmpty && library.songs.isEmpty) {
        await library.scan(settings.scanDirs);
        if (mounted) {
          await context.read<PlayerProvider>().setQueue(library.songs, resumeLast: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const LibraryPage();
  }
}
