import 'product_models.dart';
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

class ProductWithMaterials {
  final Product product;
  final List<ProductMaterial> materials;

  ProductWithMaterials({
    required this.product,
    required this.materials,
  });
}