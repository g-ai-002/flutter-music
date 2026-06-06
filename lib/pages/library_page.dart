import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/favorites_provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import 'settings_page.dart';

/// 歌曲库主页（默认页），带 Tab：歌曲 / 收藏 / 最近
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rescan() {
    final settings = context.read<SettingsProvider>();
    context.read<LibraryProvider>().scan(settings.scanDirs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          Consumer<LibraryProvider>(
            builder: (context, lib, _) => IconButton(
              tooltip: '重新扫描',
              icon: lib.scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: lib.scanning ? null : _rescan,
            ),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: '歌曲'),
            Tab(text: '收藏'),
            Tab(text: '最近'),
          ],
        ),
      ),
      body: Column(
        children: [
          _SearchBar(controller: _searchCtrl),
          const _ScanStatusBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: const [
                _SongTab(),
                _FavoriteTab(),
                _RecentTab(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}

/// 搜索栏：通过 controller 自身的 listenable 触发清除按钮显示/隐藏，
/// 避免每次输入触发整个 LibraryPage 重建
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: context.read<LibraryProvider>().updateSearch,
          decoration: InputDecoration(
            hintText: '搜索 歌曲 / 艺术家 / 专辑',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      context.read<LibraryProvider>().updateSearch('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScanStatusBar extends StatelessWidget {
  const _ScanStatusBar();

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        if (!lib.scanning) return const SizedBox.shrink();
        final p = lib.progress;
        final text = p == null
            ? '正在扫描…'
            : '正在扫描 ${p.found} 首  ${_shortDir(p.currentDir)}';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  static String _shortDir(String d) {
    if (d.length <= 50) return d;
    return '…${d.substring(d.length - 48)}';
  }
}

class _SongTab extends StatelessWidget {
  const _SongTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        final list = lib.filtered;
        if (list.isEmpty) {
          return _LibraryEmpty(library: lib);
        }
        return _SongListView(songs: list);
      },
    );
  }
}

class _FavoriteTab extends StatelessWidget {
  const _FavoriteTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<LibraryProvider, FavoritesProvider>(
      builder: (context, lib, fav, _) {
        final favPaths = fav.favorites;
        if (favPaths.isEmpty) {
          return const _EmptyState(
            icon: Icons.favorite_outline,
            title: '还没有收藏的歌曲',
            subtitle: '点击歌曲旁的 ♡ 按钮收藏',
          );
        }
        final list =
            lib.songs.where((s) => favPaths.contains(s.path)).toList();
        if (list.isEmpty) {
          return const _EmptyState(
            icon: Icons.favorite_outline,
            title: '收藏的歌曲已被移除',
            subtitle: '请重新扫描',
          );
        }
        return _SongListView(songs: list);
      },
    );
  }
}

class _RecentTab extends StatelessWidget {
  const _RecentTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<LibraryProvider, FavoritesProvider>(
      builder: (context, lib, fav, _) {
        final recentPaths = fav.recent;
        if (recentPaths.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            title: '还没有播放记录',
            subtitle: '播放歌曲后将出现在这里',
          );
        }
        final songMap = {for (final s in lib.songs) s.path: s};
        final list = [
          for (final p in recentPaths)
            if (songMap[p] != null) songMap[p]!,
        ];
        return Stack(
          children: [
            _SongListView(songs: list),
            Positioned(
              right: 8,
              bottom: 8,
              child: FloatingActionButton.small(
                heroTag: 'clear-recent',
                tooltip: '清空最近播放',
                onPressed: () => context.read<FavoritesProvider>().clearRecent(),
                child: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 通用空态组件
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 歌曲 Tab 的空态：根据是否有搜索词 / 是否有扫描目录给出不同引导
class _LibraryEmpty extends StatelessWidget {
  final LibraryProvider library;
  const _LibraryEmpty({required this.library});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final searching = library.searchKeyword.isNotEmpty;
    final noDirs = settings.scanDirs.isEmpty;
    return _EmptyState(
      icon: Icons.library_music_outlined,
      title: searching
          ? '没有匹配的歌曲'
          : (noDirs ? '还没有扫描目录' : '没有发现音乐'),
      subtitle: searching
          ? '试试其他关键字'
          : (noDirs ? '前往「设置」添加扫描目录' : '点击右上角刷新重新扫描'),
      action: (!searching && noDirs)
          ? ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('打开设置'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            )
          : null,
    );
  }
}

class _SongListView extends StatelessWidget {
  final List<Song> songs;
  const _SongListView({required this.songs});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, ({String? path, bool playing})>(
      selector: (_, p) => (path: p.currentSong?.path, playing: p.playing),
      builder: (context, snap, _) {
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: songs.length,
          separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 76),
          itemBuilder: (context, i) {
            final s = songs[i];
            final active = snap.path == s.path;
            return SongTile(
              song: s,
              active: active,
              playing: snap.playing,
              onTap: () async {
                final player = context.read<PlayerProvider>();
                await player.setQueue(
                  context.read<LibraryProvider>().songs,
                );
                await player.playSong(s);
              },
              showFavorite: true,
            );
          },
        );
      },
    );
  }
}
