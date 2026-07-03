class Material {
  final int? idM;
  final String codeM;
  final String namaM;
  final String satuan;
  final String? description;
  final int categoryId;
  final String? categoryName;
  final String? createdAt;
  final String? updatedAt;

  Material({
    this.idM,
    required this.codeM,
    required this.namaM,
    required this.satuan,
    this.description,
    required this.categoryId,
    this.categoryName,
    this.createdAt,
    this.updatedAt,
  });

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      idM: json['id_m'] != null ? int.tryParse(json['id_m'].toString()) : null,
      codeM: json['code_m']?.toString() ?? '',
      namaM: json['nama_m']?.toString() ?? '',
      satuan: json['satuan']?.toString() ?? '',
      description: json['description']?.toString(),
      categoryId: json['category_id'] != null ? int.tryParse(json['category_id'].toString()) ?? 0 : 0,
      categoryName: json['category_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_m': idM,
      'code_m': codeM,
      'nama_m': namaM,
      'satuan': satuan,
      'description': description,
      'category_id': categoryId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Material copyWith({
    int? idM,
    String? codeM,
    String? namaM,
    String? satuan,
    String? description,
    int? categoryId,
    String? categoryName,
    String? createdAt,
    String? updatedAt,
  }) {
    return Material(
      idM: idM ?? this.idM,
      codeM: codeM ?? this.codeM,
      namaM: namaM ?? this.namaM,
      satuan: satuan ?? this.satuan,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Category {
  final int? idC;
  final String namaC;
  final String? description;
  final bool isActive;

  Category({
    this.idC,
    required this.namaC,
    this.description,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      idC: json['id_c'] != null ? int.tryParse(json['id_c'].toString()) : null,
      namaC: json['nama_c']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_c': idC,
      'nama_c': namaC,
      'description': description,
      'is_active': isActive ? 1 : 0,
    };
  }
}