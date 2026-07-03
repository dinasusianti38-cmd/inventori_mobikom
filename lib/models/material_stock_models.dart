class MaterialStok {
  final int idM;
  final String kodeMaterial;
  final String namaMaterial;
  final String satuan;
  final String description;
  final int categoryId;
  final String kategory;
  final int jumlah;
  final String status;
  final String lastUpdate;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaterialStok({
    required this.idM,
    required this.kodeMaterial,
    required this.namaMaterial,
    required this.satuan,
    required this.description,
    required this.categoryId,
    required this.kategory,
    required this.jumlah,
    required this.status,
    required this.lastUpdate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaterialStok.fromJson(Map<String, dynamic> json) {
    return MaterialStok(
      idM: int.parse(json['id_m'].toString()),
      kodeMaterial: json['code_m'] ?? '',
      namaMaterial: json['nama_m'] ?? '',
      satuan: json['satuan'] ?? '',
      description: json['description'] ?? '',
      categoryId: int.parse(json['category_id'].toString()),
      kategory: json['kategory'] ?? '',
      jumlah: int.parse(json['jumlah'].toString()),
      status: json['status'] ?? '',
      lastUpdate: json['last_update'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_m': idM,
      'code_m': kodeMaterial,
      'nama_m': namaMaterial,
      'satuan': satuan,
      'description': description,
      'category_id': categoryId,
      'kategory': kategory,
      'jumlah': jumlah,
      'status': status,
      'last_update': lastUpdate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class Category {
  final int idC;
  final String namaC;
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    required this.idC,
    required this.namaC,
    required this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      idC: int.parse(json['id_c'].toString()),
      namaC: json['nama_c'] ?? '',
      description: json['description'] ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_c': idC,
      'nama_c': namaC,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class MaterialTransaction {
  final int idTm;
  final String transactionCode;
  final int materialId;
  final String transactionType;
  final int jumlah;
  final int stokSebelum;
  final int stokSesudah;
  final DateTime transactionDate;
  final String notes;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaterialTransaction({
    required this.idTm,
    required this.transactionCode,
    required this.materialId,
    required this.transactionType,
    required this.jumlah,
    required this.stokSebelum,
    required this.stokSesudah,
    required this.transactionDate,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaterialTransaction.fromJson(Map<String, dynamic> json) {
    return MaterialTransaction(
      idTm: int.parse(json['id_tm'].toString()),
      transactionCode: json['transaction_code'] ?? '',
      materialId: int.parse(json['material_id'].toString()),
      transactionType: json['transaction_type'] ?? '',
      jumlah: int.parse(json['jumlah'].toString()),
      stokSebelum: int.parse(json['stok_sebelum'].toString()),
      stokSesudah: int.parse(json['stok_sesudah'].toString()),
      transactionDate: DateTime.parse(json['transaction_date']),
      notes: json['notes'] ?? '',
      createdBy: int.parse(json['created_by'].toString()),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_tm': idTm,
      'transaction_code': transactionCode,
      'material_id': materialId,
      'transaction_type': transactionType,
      'jumlah': jumlah,
      'stok_sebelum': stokSebelum,
      'stok_sesudah': stokSesudah,
      'transaction_date': transactionDate.toIso8601String().split('T')[0],
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}