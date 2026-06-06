import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';

/// 收藏切换按钮：仅订阅当前歌曲的收藏状态，避免整列表重建
class FavoriteToggleButton extends StatelessWidget {
  final String songPath;
  final double iconSize;
  final bool compact;

  const FavoriteToggleButton({
    super.key,
    required this.songPath,
    this.iconSize = 24,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<FavoritesProvider, bool>(
      selector: (_, fav) => fav.isFavorite(songPath),
      builder: (context, fav, _) => IconButton(
        tooltip: fav ? '取消收藏' : '收藏',
        iconSize: iconSize,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        icon: Icon(
          fav ? Icons.favorite : Icons.favorite_outline,
          color: fav ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: () =>
            context.read<FavoritesProvider>().toggleFavorite(songPath),
      ),
    );
  }
}
