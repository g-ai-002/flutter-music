import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/favorites_provider.dart';
import '../utils/constants.dart';
import 'cover_image.dart';

/// 歌曲列表行
class SongTile extends StatelessWidget {
  final Song song;
  final bool active;
  final bool playing;
  final VoidCallback onTap;
  final bool showFavorite;

  const SongTile({
    super.key,
    required this.song,
    required this.active,
    required this.playing,
    required this.onTap,
    this.showFavorite = false,
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
              Selector<FavoritesProvider, bool>(
                selector: (_, fav) => fav.isFavorite(song.path),
                builder: (context, fav, _) => IconButton(
                  tooltip: fav ? '取消收藏' : '收藏',
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    fav ? Icons.favorite : Icons.favorite_outline,
                    color: fav ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      context.read<FavoritesProvider>().toggleFavorite(song.path),
                ),
              ),
          ],
        ),
      ),
    );
  }
}