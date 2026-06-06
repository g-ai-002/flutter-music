import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import 'settings_page.dart';

/// 歌曲库主页（默认页）
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rescan() {
    final settings = context.read<SettingsProvider>();
    context.read<LibraryProvider>().scan(settings.scanDirs);
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          _buildScanStatus(context),
          const Divider(height: 0.5),
          Expanded(child: _buildList(context)),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        onChanged: (v) {
          context.read<LibraryProvider>().updateSearch(v);
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: '搜索 歌曲 / 艺术家 / 专辑',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    context.read<LibraryProvider>().updateSearch('');
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildScanStatus(BuildContext context) {
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

  String _shortDir(String d) {
    if (d.length <= 50) return d;
    return '…${d.substring(d.length - 48)}';
  }

  Widget _buildList(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        final list = lib.filtered;
        if (list.isEmpty) {
          return _buildEmpty(context, lib);
        }
        return Selector<PlayerProvider, ({String? path, bool playing})>(
          selector: (_, p) => (path: p.currentSong?.path, playing: p.playing),
          builder: (context, snap, _) {
            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 76),
              itemBuilder: (context, i) {
                final s = list[i];
                final active = snap.path == s.path;
                return SongTile(
                  song: s,
                  active: active,
                  playing: snap.playing,
                  onTap: () async {
                    final player = context.read<PlayerProvider>();
                    await player.setQueue(list);
                    await player.playSong(s);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, LibraryProvider lib) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final noDirs = settings.scanDirs.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_outlined,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              lib.searchKeyword.isNotEmpty
                  ? '没有匹配的歌曲'
                  : (noDirs ? '还没有扫描目录' : '没有发现音乐'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              lib.searchKeyword.isNotEmpty
                  ? '试试其他关键字'
                  : (noDirs ? '前往「设置」添加扫描目录' : '点击右上角刷新重新扫描'),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (lib.searchKeyword.isEmpty && noDirs) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('打开设置'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
