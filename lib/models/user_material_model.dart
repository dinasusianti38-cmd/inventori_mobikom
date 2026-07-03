class UserMaterialStock {
  final int id;
  final String namaMaterial;
  final String kodeMaterial;
  final String jumlah;
  final String kategory;
  final String status;
  final String lastUpdate;

  UserMaterialStock({
    required this.id,
    required this.namaMaterial,
    required this.kodeMaterial,
    required this.jumlah,
    required this.kategory,
    required this.status,
    required this.lastUpdate,
  });

factory UserMaterialStock.fromJson(Map<String, dynamic> json) {
    return UserMaterialStock(
      id: _parseInt(json['id']) ?? 0,
      namaMaterial: json['nama_material']?.toString() ?? '',
      kodeMaterial: json['kode_material']?.toString() ?? '',
      jumlah: json['jumlah']?.toString() ?? '',
      kategory: json['kategory']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lastUpdate: json['last_update']?.toString() ?? '',
    );
}

static int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_material': namaMaterial,
      'kode_material': kodeMaterial,
      'jumlah': jumlah,
      'kategory': kategory,
      'status': status,
      'last_update': lastUpdate,
    };
  }
}

class MaterialStockResponse {
  final String status;
  final List<UserMaterialStock> data;
  final PaginationInfo pagination;

  MaterialStockResponse({
    required this.status,
    required this.data,
    required this.pagination,
  });

  factory MaterialStockResponse.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] as List;
    List<UserMaterialStock> materials = dataList
        .map((item) => UserMaterialStock.fromJson(item))
        .toList();

    return MaterialStockResponse(
      status: json['status'],
      data: materials,
      pagination: PaginationInfo.fromJson(json['pagination']),
    );
  }
}

class PaginationInfo {
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final int perPage;
  final int showingFrom;
  final int showingTo;

  PaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.perPage,
    required this.showingFrom,
    required this.showingTo,
  });

factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: _parseInt(json['current_page']) ?? 1,
      totalPages: _parseInt(json['total_pages']) ?? 1,
      totalRecords: _parseInt(json['total_records']) ?? 0,
      perPage: _parseInt(json['per_page']) ?? 10,
      showingFrom: _parseInt(json['showing_from']) ?? 0,
      showingTo: _parseInt(json['showing_to']) ?? 0,
    );
}

// Helper method untuk parsing integer
static int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
}

class CategoriesResponse {
  final String status;
  final List<String> data;

  CategoriesResponse({
    required this.status,
    required this.data,
  });

  factory CategoriesResponse.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] as List;
    List<String> categories = dataList.map((item) => item.toString()).toList();

    return CategoriesResponse(
      status: json['status'],
      data: categories,
    );
  }
}