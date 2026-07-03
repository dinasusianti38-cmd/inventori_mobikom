class ProductStock {
  final int idSp;
  final int productId;
  final String productCode;
  final String productName;
  final String? description;
  final int stokMinimal;
  final int stokTersedia;
  final String lastUpdated;
  final int updatedBy;
  final String updatedByName;

  ProductStock({
    required this.idSp,
    required this.productId,
    required this.productCode,
    required this.productName,
    this.description,
    required this.stokMinimal,
    required this.stokTersedia,
    required this.lastUpdated,
    required this.updatedBy,
    required this.updatedByName,
  });

  factory ProductStock.fromJson(Map<String, dynamic> json) {
    return ProductStock(
      idSp: int.parse(json['id_sp'].toString()),
      productId: int.parse(json['product_id'].toString()),
      productCode: json['code_p'] ?? '',
      productName: json['name_p'] ?? '',
      description: json['description'],
      stokMinimal: int.parse(json['stok_minimal'].toString()),
      stokTersedia: int.parse(json['stok_tersedia'].toString()),
      lastUpdated: json['last_updated'] ?? '',
      updatedBy: int.parse(json['updated_by'].toString()),
      updatedByName: json['updated_by_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_sp': idSp,
      'product_id': productId,
      'code_p': productCode,
      'name_p': productName,
      'description': description,
      'stok_minimal': stokMinimal,
      'stok_tersedia': stokTersedia,
      'last_updated': lastUpdated,
      'updated_by': updatedBy,
      'updated_by_name': updatedByName,
    };
  }

  String get status {
    if (stokTersedia <= 0) {
      return 'stok habis';
    } else if (stokTersedia <= stokMinimal) {
      return 'stok menipis';
    } else {
      return 'stok normal';
    }
  }

  String get kategori {
    // Bisa disesuaikan dengan logika bisnis atau ditambahkan field kategori di database
    if (productName.toLowerCase().contains('printer') || 
        productName.toLowerCase().contains('elektronik')) {
      return 'Elektronik';
    } else if (productName.toLowerCase().contains('kabel') || 
               productName.toLowerCase().contains('aksesoris')) {
      return 'Aksesoris';
    }
    return 'Lainnya';
  }
}