class Product {
  final int? idP;
  final String codeP;
  final String nameP;
  final String? description;
  final String? createdAt;
  final String? updatedAt;
  final List<ProductMaterial>? materials;

  Product({
    this.idP,
    required this.codeP,
    required this.nameP,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.materials,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      idP: json['id_p'] != null ? int.tryParse(json['id_p'].toString()) : null,
      codeP: json['code_p']?.toString() ?? '',
      nameP: json['name_p']?.toString() ?? '',
      description: json['description']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      materials: json['materials'] != null
          ? (json['materials'] as List)
              .map((e) => ProductMaterial.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_p': idP,
      'code_p': codeP,
      'name_p': nameP,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'materials': materials?.map((e) => e.toJson()).toList(),
    };
  }
}

class ProductMaterial {
  final int? idPm;
  final int productId;
  final int materialId;
  final int quantity;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final String? materialName;
  final String? materialCode;

  ProductMaterial({
    this.idPm,
    required this.productId,
    required this.materialId,
    required this.quantity,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.materialName,
    this.materialCode,
  });

  factory ProductMaterial.fromJson(Map<String, dynamic> json) {
    return ProductMaterial(
      idPm: json['id_pm'] != null ? int.tryParse(json['id_pm'].toString()) : null,
      productId: json['product_id'] != null ? int.tryParse(json['product_id'].toString()) ?? 0 : 0,
      materialId: json['material_id'] != null ? int.tryParse(json['material_id'].toString()) ?? 0 : 0,
      quantity: json['quantity'] != null ? int.tryParse(json['quantity'].toString()) ?? 0 : 0,
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      materialName: json['material_name']?.toString(),
      materialCode: json['material_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_pm': idPm,
      'product_id': productId,
      'material_id': materialId,
      'quantity': quantity,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}