class ProdukStok {
  final int idSp;
  final int productId;
  final String codeP;
  final String nameP;
  final int stokMinimal;
  final int stokTersedia;
  final String lastUpdated;
  final String? updatedByName;
  final String status;

  ProdukStok({
    required this.idSp,
    required this.productId,
    required this.codeP,
    required this.nameP,
    required this.stokMinimal,
    required this.stokTersedia,
    required this.lastUpdated,
    this.updatedByName,
    required this.status,
  });

  factory ProdukStok.fromJson(Map<String, dynamic> json) {
    try {
      return ProdukStok(
        idSp: _parseToInt(json['id_sp']),
        productId: _parseToInt(json['product_id']),
        codeP: json['code_p']?.toString() ?? '',
        nameP: json['name_p']?.toString() ?? 'Unknown Product',
        stokMinimal: _parseToInt(json['stok_minimal']),
        stokTersedia: _parseToInt(json['stok_tersedia']),
        lastUpdated: json['last_updated']?.toString() ?? '',
        updatedByName: json['updated_by_name']?.toString(),
        status: json['status']?.toString() ?? 'unknown',
      );
    } catch (e) {
      throw Exception('Error parsing ProdukStok: $e');
    }
  }

  // Helper method to safely parse integers
  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) return value.toInt();
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id_sp': idSp,
      'product_id': productId,
      'code_p': codeP,
      'name_p': nameP,
      'stok_minimal': stokMinimal,
      'stok_tersedia': stokTersedia,
      'last_updated': lastUpdated,
      'updated_by_name': updatedByName,
      'status': status,
    };
  }
}

class ProdukStokResponse {
  final String status;
  final List<ProdukStok> data;
  final int total;
  final int limit;
  final int offset;

  ProdukStokResponse({
    required this.status,
    required this.data,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ProdukStokResponse.fromJson(Map<String, dynamic> json) {
    try {
      return ProdukStokResponse(
        status: json['status']?.toString() ?? 'error',
        data: (json['data'] as List?)
                ?.map((item) => ProdukStok.fromJson(item))
                .toList() ?? [],
        total: ProdukStok._parseToInt(json['total']),
        limit: ProdukStok._parseToInt(json['limit']),
        offset: ProdukStok._parseToInt(json['offset']),
      );
    } catch (e) {
      throw Exception('Error parsing ProdukStokResponse: $e');
    }
  }
}