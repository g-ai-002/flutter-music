import 'package:flutter/material.dart';
import '../models/song.dart';
import '../utils/constants.dart';
import 'cover_image.dart';
import 'favorite_toggle_button.dart';

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
              FavoriteToggleButton(
                songPath: song.path,
                iconSize: 20,
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}