class ProductModel {
  final int id;
  final String code;
  final String name;
  final String? description;
  final int? stokTersedia;

  ProductModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.stokTersedia,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: int.parse(json['id_p'].toString()),
      code: json['code_p'] ?? '',
      name: json['name_p'] ?? '',
      description: json['description'],
      stokTersedia: json['stok_tersedia'] != null 
          ? int.parse(json['stok_tersedia'].toString()) 
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_p': id,
      'code_p': code,
      'name_p': name,
      'description': description,
      'stok_tersedia': stokTersedia,
    };
  }
}

class ProductTransactionModel {
  final int? id;
  final String transactionCode;
  final int productId;
  final String productName;
  final String transactionType;
  final int jumlah;
  final int? stokSebelum;
  final int? stokSesudah;
  final String transactionDate;
  final String? notes;
  final int? createdBy;
  final String? createdAt;

  ProductTransactionModel({
    this.id,
    required this.transactionCode,
    required this.productId,
    required this.productName,
    required this.transactionType,
    required this.jumlah,
    this.stokSebelum,
    this.stokSesudah,
    required this.transactionDate,
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  factory ProductTransactionModel.fromJson(Map<String, dynamic> json) {
    return ProductTransactionModel(
      id: json['id_pm'] != null ? int.parse(json['id_pm'].toString()) : null,
      transactionCode: json['transaction_code'] ?? '',
      productId: int.parse(json['product_id'].toString()),
      productName: json['product_name'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      jumlah: int.parse(json['jumlah'].toString()),
      stokSebelum: json['stok_sebelum'] != null 
          ? int.parse(json['stok_sebelum'].toString()) 
          : null,
      stokSesudah: json['stok_sesudah'] != null 
          ? int.parse(json['stok_sesudah'].toString()) 
          : null,
      transactionDate: json['transaction_date'] ?? '',
      notes: json['notes'],
      createdBy: json['created_by'] != null 
          ? int.parse(json['created_by'].toString()) 
          : null,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'transaction_code': transactionCode,
      'product_id': productId,
      'product_name': productName,
      'transaction_type': transactionType,
      'jumlah': jumlah,
      'stok_sebelum': stokSebelum,
      'stok_sesudah': stokSesudah,
      'transaction_date': transactionDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
    };
  }
}