/// 歌单数据模型
class Playlist {
  final String id;
  String name;
  List<String> songPaths;
  final DateTime createdAt;
  DateTime updatedAt;

  Playlist({
    required this.id,
    required this.name,
    List<String>? songPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : songPaths = songPaths ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get songCount => songPaths.length;

  Playlist copyWith({String? name, List<String>? songPaths}) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songPaths: songPaths ?? List<String>.from(this.songPaths),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songPaths': songPaths,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        songPaths: (json['songPaths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
}