class Category {
  final int id;
  final String name;
  final String description;
  final int isActive;
  final String? createdAt;
  final String? updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: _parseToInt(json['id_c']) ?? 0,
      name: json['nama_c']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isActive: _parseToInt(json['is_active']) ?? 1,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}