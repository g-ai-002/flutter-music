import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlists_provider.dart';
import '../utils/constants.dart';
import '../widgets/cover_image.dart';
import '../widgets/mini_player.dart';
import '../widgets/playlist_dialogs.dart';

/// 单个歌单详情：歌曲列表 + 播放全部 + 删除单首 + 编辑歌单名
class PlaylistPage extends StatelessWidget {
  final String playlistId;
  const PlaylistPage({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlaylistsProvider, LibraryProvider>(
      builder: (context, plProv, lib, _) {
        final pl = plProv.byId(playlistId);
        if (pl == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('歌单')),
            body: const Center(child: Text('歌单已被删除')),
          );
        }
        final songMap = {for (final s in lib.songs) s.path: s};
        final songs = <Song>[];
        final missing = <String>[];
        for (final p in pl.songPaths) {
          final s = songMap[p];
          if (s != null) {
            songs.add(s);
          } else {
            missing.add(p);
          }
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: '重命名',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final name = await showPlaylistNameDialog(
                    context,
                    initial: pl.name,
                    title: '重命名歌单',
                  );
                  if (name == null) return;
                  try {
                    await plProv.rename(pl.id, name);
                  } on ArgumentError catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.message.toString())));
                  }
                },
              ),
              IconButton(
                tooltip: '删除歌单',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirmDeletePlaylist(context, pl);
                  if (!ok) return;
                  await plProv.remove(pl.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _Header(playlist: pl, playableSongs: songs, missingCount: missing.length),
              Expanded(
                child: songs.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        itemCount: songs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 0.5, indent: 76),
                        itemBuilder: (context, i) {
                          final s = songs[i];
                          return _SongRow(
                            song: s,
                            onRemove: () => plProv.removeSong(pl.id, s.path),
                            onPlay: () async {
                              final player = context.read<PlayerProvider>();
                              await player.setQueue(songs);
                              await player.playSong(s);
                            },
                          );
                        },
                      ),
              ),
              const MiniPlayer(),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Playlist playlist;
  final List<Song> playableSongs;
  final int missingCount;
  const _Header({
    required this.playlist,
    required this.playableSongs,
    required this.missingCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  missingCount == 0
                      ? '${playableSongs.length} 首'
                      : '${playableSongs.length} 首（${missingCount} 首已失效）',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('播放全部'),
            onPressed: playableSongs.isEmpty
                ? null
                : () async {
                    final player = context.read<PlayerProvider>();
                    await player.setQueue(playableSongs);
                    await player.playSong(playableSongs.first);
                  },
          ),
        ],
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final Song song;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  const _SongRow({required this.song, required this.onPlay, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CoverImage(song: song, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text('${song.artist} · ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (song.duration != null) ...[
              const SizedBox(width: 8),
              Text(formatDuration(song.duration!), style: theme.textTheme.bodySmall),
            ],
            IconButton(
              tooltip: '从歌单移除',
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('歌单为空', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '回到「歌曲」Tab，点击歌曲行尾的「…」即可添加',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
