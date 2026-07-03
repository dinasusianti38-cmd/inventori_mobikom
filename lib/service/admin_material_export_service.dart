import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/material_stock_models.dart';
import '../config/api_config.dart';

class MaterialExportModel {
  final int idM;
  final String kodeMaterial;
  final String namaMaterial;
  final String kategory;
  final int jumlah;
  final String satuan;
  final String status;
  final String lastUpdate;
  final int? stokMinimal;

  MaterialExportModel({
    required this.idM,
    required this.kodeMaterial,
    required this.namaMaterial,
    required this.kategory,
    required this.jumlah,
    required this.satuan,
    required this.status,
    required this.lastUpdate,
    this.stokMinimal,
  });

  factory MaterialExportModel.fromJson(Map<String, dynamic> json) {
    return MaterialExportModel(
      idM: json['id_m'] ?? 0,
      kodeMaterial: json['code_m'] ?? '',
      namaMaterial: json['nama_m'] ?? '',
      kategory: json['kategory'] ?? 'Tidak Berkategori',
      jumlah: json['jumlah'] ?? 0,
      satuan: json['satuan'] ?? '',
      status: json['status'] ?? 'stok normal',
      lastUpdate: json['last_update'] ?? '',
      stokMinimal: json['stok_minimal'],
    );
  }
}

class MaterialSummary {
  final int totalMaterials;
  final int stokNormal;
  final int stokMenipis;
  final int stokHabis;

  MaterialSummary({
    required this.totalMaterials,
    required this.stokNormal,
    required this.stokMenipis,
    required this.stokHabis,
  });
}

class AdminMaterialExportService {
  static const String baseUrl = ApiConfig.baseUrl;

  /// Mengambil data material untuk export dengan data real-time
  static Future<Map<String, dynamic>> getMaterialsForExport() async {
    try {
      // Ambil data terbaru dari API yang sama dengan tampilan
      final response = await http.get(
        Uri.parse('$baseUrl/get_stok_data_export.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['status'] == 'success') {
          List<MaterialExportModel> materials = [];
          
          // Parse materials
          for (var item in responseData['data']) {
            materials.add(MaterialExportModel.fromJson(item));
          }

          // Hitung summary berdasarkan data yang sudah diparse
          int stokNormal = 0;
          int stokMenipis = 0;
          int stokHabis = 0;

          for (var material in materials) {
            // Validasi ulang status berdasarkan jumlah real-time
            String actualStatus;
            if (material.jumlah == 0) {
              actualStatus = 'stok habis';
              stokHabis++;
            } else if (material.jumlah <= (material.stokMinimal ?? 10)) {
              actualStatus = 'stok menipis';
              stokMenipis++;
            } else {
              actualStatus = 'stok normal';
              stokNormal++;
            }
          }

          MaterialSummary summary = MaterialSummary(
            totalMaterials: materials.length,
            stokNormal: stokNormal,
            stokMenipis: stokMenipis,
            stokHabis: stokHabis,
          );

          return {
            'materials': materials,
            'summary': summary,
          };
        } else {
          throw Exception(responseData['message'] ?? 'Failed to load data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching export data: $e');
    }
  }
}