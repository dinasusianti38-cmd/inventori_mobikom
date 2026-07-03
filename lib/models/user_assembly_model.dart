import 'package:flutter/material.dart';

class AssemblyProject {
  final int idP;
  final String codeP;
  final String nameP;
  final String? description;
  final int stokTersedia;
  final List<MaterialRequired> materials;
  final String status;
  final String statusMessage;
  final int availableMaterial;
  final int totalMaterial;

  AssemblyProject({
    required this.idP,
    required this.codeP,
    required this.nameP,
    this.description,
    required this.stokTersedia,
    required this.materials,
    required this.status,
    required this.statusMessage,
    required this.availableMaterial,
    required this.totalMaterial,
  });

  factory AssemblyProject.fromJson(Map<String, dynamic> json) {
    return AssemblyProject(
      idP: int.parse(json['id_p'].toString()),
      codeP: json['code_p'] ?? '',
      nameP: json['name_p'] ?? '',
      description: json['description'],
      stokTersedia: int.parse(json['stok_tersedia'].toString()),
      materials: (json['materials'] as List?)
              ?.map((m) => MaterialRequired.fromJson(m))
              .toList() ??
          [],
      status: json['status'] ?? 'pending',
      statusMessage: json['status_message'] ?? 'Unknown',
      availableMaterial: json['available_material'] ?? 0,
      totalMaterial: json['total_material'] ?? 0,
    );
  }
  
  Color getStatusColor() {
    switch (status) {
      case 'ready':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'blocked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  IconData getStatusIcon() {
    switch (status) {
      case 'ready':
        return Icons.check_circle;
      case 'partial':
        return Icons.warning_amber_rounded;
      case 'blocked':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }
}

class MaterialRequired {
  final int idM;
  final String codeM;
  final String namaM;
  final String satuan;
  final int quantityRequired;
  final int stokTersedia;
  final bool isAvailable;

  MaterialRequired({
    required this.idM,
    required this.codeM,
    required this.namaM,
    required this.satuan,
    required this.quantityRequired,
    required this.stokTersedia,
    required this.isAvailable,
  });

  factory MaterialRequired.fromJson(Map<String, dynamic> json) {
    return MaterialRequired(
      idM: int.parse(json['id_m'].toString()),
      codeM: json['code_m'] ?? '',
      namaM: json['nama_m'] ?? '',
      satuan: json['satuan'] ?? '',
      quantityRequired: int.parse(json['quantity_required'].toString()),
      stokTersedia: int.parse(json['stok_tersedia'].toString()),
      isAvailable: json['is_available'] == 1 || json['is_available'] == true,
    );
  }
}