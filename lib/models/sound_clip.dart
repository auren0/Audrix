class SoundClip {
  const SoundClip({
    required this.id,
    required this.name,
    required this.fileName,
    this.volume = 1.0,
    this.colorIndex = 0,
  });

  final String id;
  final String name;
  final String fileName;
  final double volume;
  final int colorIndex;

  SoundClip copyWith({
    String? name,
    String? fileName,
    double? volume,
    int? colorIndex,
  }) {
    return SoundClip(
      id: id,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      volume: volume ?? this.volume,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'fileName': fileName,
        'volume': volume,
        'colorIndex': colorIndex,
      };

  factory SoundClip.fromJson(Map<String, Object?> json) {
    return SoundClip(
      id: json['id'] as String,
      name: json['name'] as String,
      fileName: json['fileName'] as String,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      colorIndex: json['colorIndex'] as int? ?? 0,
    );
  }
}
