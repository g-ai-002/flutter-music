import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/playlists_provider.dart';

/// 显示「添加到歌单」选择对话框：列出所有歌单 + 「新建歌单」入口
///
/// 添加完成后顶部弹出 SnackBar 提示加入了几首。
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required List<String> songPaths,
}) async {
  if (songPaths.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final provider = context.read<PlaylistsProvider>();

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: ListenableBuilder(
          listenable: provider,
          builder: (ctx, _) {
            final items = provider.items;
            return ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    songPaths.length == 1 ? '添加到歌单' : '添加 ${songPaths.length} 首到歌单',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('新建歌单'),
                  onTap: () async {
                    final name = await _promptName(ctx);
                    if (name == null) return;
                    try {
                      final pl = await provider.create(name);
                      final n = await provider.addSongs(pl.id, songPaths);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(content: Text('已新建「${pl.name}」并添加 $n 首')),
                      );
                    } on ArgumentError catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text(e.message.toString())));
                    }
                  },
                ),
                if (items.isNotEmpty) const Divider(height: 1),
                for (final pl in items)
                  ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(pl.name),
                    subtitle: Text('${pl.songCount} 首'),
                    onTap: () async {
                      final n = await provider.addSongs(pl.id, songPaths);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(n == 0
                              ? '已在「${pl.name}」中，未重复添加'
                              : '已添加 $n 首到「${pl.name}」'),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      );
    },
  );
}

/// 输入歌单名（用于新建 / 重命名）
Future<String?> _promptName(BuildContext context, {String? initial}) {
  return showPlaylistNameDialog(context, initial: initial);
}

/// 公共：弹出输入歌单名对话框。返回 trim 后的名称；取消返回 null。
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  String? initial,
  String title = '歌单名',
}) async {
  final ctrl = TextEditingController(text: initial ?? '');
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '例如：日常通勤'),
            maxLength: 30,
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return '名称不能为空';
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  ctrl.dispose();
  return result;
}

/// 删除歌单的二次确认
Future<bool> confirmDeletePlaylist(BuildContext context, Playlist pl) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除歌单'),
      content: Text('确定删除「${pl.name}」？歌单中的歌曲不会被删除。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton.tonal(
          style: FilledButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
