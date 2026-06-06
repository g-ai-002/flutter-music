import 'package:flutter/material.dart';
import '../models/song.dart';
import '../utils/constants.dart';
import 'cover_image.dart';
import 'favorite_toggle_button.dart';
import 'playlist_dialogs.dart';

/// 歌曲列表行
class SongTile extends StatelessWidget {
  final Song song;
  final bool active;
  final bool playing;
  final VoidCallback onTap;
  final bool showFavorite;
  final VoidCallback? onRemove;

  const SongTile({
    super.key,
    required this.song,
    required this.active,
    required this.playing,
    required this.onTap,
    this.showFavorite = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = active ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
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
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: titleColor,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${song.artist} · ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (song.duration != null) ...[
              const SizedBox(width: 8),
              Text(
                formatDuration(song.duration!),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (active) ...[
              const SizedBox(width: 8),
              Icon(
                playing ? Icons.graphic_eq : Icons.pause_circle_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
            if (showFavorite)
              FavoriteToggleButton(
                songPath: song.path,
                iconSize: 20,
                compact: true,
              ),
            _MoreMenu(song: song, onRemove: onRemove),
          ],
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final Song song;
  final VoidCallback? onRemove;
  const _MoreMenu({required this.song, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '更多',
      icon: const Icon(Icons.more_vert, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (v) async {
        switch (v) {
          case 'add':
            await showAddToPlaylistSheet(context, songPaths: [song.path]);
            break;
          case 'remove':
            onRemove?.call();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'add',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.playlist_add),
            title: Text('添加到歌单'),
          ),
        ),
        if (onRemove != null)
          const PopupMenuItem(
            value: 'remove',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.remove_circle_outline),
              title: Text('从此处移除'),
            ),
          ),
      ],
    );
  }
}