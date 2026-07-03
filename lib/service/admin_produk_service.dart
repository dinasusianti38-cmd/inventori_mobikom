import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_models.dart';
import '../models/material_models.dart' as MaterialModel;
import '../config/api_config.dart';

class ProductService {
  static const String _baseUrl = ApiConfig.baseUrl;

  static Future<List<Product>> getAllProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/product.php?action=getAll'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final String responseBody = response.body.trim();

        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }

        final Map<String, dynamic> jsonResponse = json.decode(responseBody);

        if (jsonResponse['status'] == 'success') {
          final List<dynamic> productData = jsonResponse['data'] ?? [];
          return productData.map((item) => Product.fromJson(item)).toList();
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to load products');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error in getAllProducts: $e');
      rethrow;
    }
  }

  static Future<List<MaterialModel.Material>> getAllMaterials() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/material.php?action=getAll'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final String responseBody = response.body.trim();

        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }

        final Map<String, dynamic> jsonResponse = json.decode(responseBody);

        if (jsonResponse['status'] == 'success') {
          final List<dynamic> materialData = jsonResponse['data'] ?? [];
          return materialData
              .map((item) => MaterialModel.Material.fromJson(item))
              .toList();
        } else {
          throw Exception(
            jsonResponse['message'] ?? 'Failed to load materials',
          );
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error in getAllMaterials: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addProduct(Product product) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/product.php?action=add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toJson()),
      );

      final String responseBody = response.body.trim();

      if (responseBody.isEmpty) {
        return {'status': 'error', 'message': 'Empty response from server'};
      }

      final Map<String, dynamic> result = json.decode(responseBody);
      return result;
    } catch (e) {
      print('Error in addProduct: $e');
      return {'status': 'error', 'message': 'Failed to add product: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProduct(Product product) async {
    try {
      final response = await http.post(
        // Changed from PUT to POST
        Uri.parse('$_baseUrl/product.php?action=update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toJson()),
      );

      final String responseBody = response.body.trim();

      if (responseBody.isEmpty) {
        return {'status': 'error', 'message': 'Empty response from server'};
      }

      final Map<String, dynamic> result = json.decode(responseBody);
      return result;
    } catch (e) {
      print('Error in updateProduct: $e');
      return {'status': 'error', 'message': 'Failed to update product: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteProduct(int id) async {
    try {
      print('Mencoba menghapus produk dengan ID: $id');

      final response = await http.post(
        Uri.parse('$_baseUrl/product.php?action=delete&id=$id'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Status respons: ${response.statusCode}');
      print('Body respons: ${response.body}');

      if (response.statusCode == 200) {
        final String responseBody = response.body.trim();

        if (responseBody.isEmpty) {
          return {'status': 'error', 'message': 'Respons kosong dari server'};
        }

        try {
          final Map<String, dynamic> result = json.decode(responseBody);

          // Additional client-side error message improvement
          if (result['status'] == 'error' && result['message'] != null) {
            String message = result['message'];

            // Make error messages more user-friendly on client side too
            if (message.contains('foreign key constraint') ||
                message.contains('Cannot delete or update a parent row')) {
              message =
                  'Tidak dapat menghapus produk ini karena sedang digunakan dalam sistem';
            } else if (message.contains('product_transactions')) {
              message =
                  'Tidak dapat menghapus produk ini karena memiliki riwayat transaksi';
            }

            return {'status': 'error', 'message': message};
          }

          return result;
        } catch (jsonError) {
          print('Error decode JSON: $jsonError');
          print('Respons mentah: $responseBody');
          return {
            'status': 'error',
            'message': 'Terjadi kesalahan server saat memproses permintaan',
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Error server: Tidak dapat memproses permintaan hapus',
        };
      }
    } catch (e) {
      print('Error di deleteProduct: $e');
      return {
        'status': 'error',
        'message': 'Error jaringan: Silakan periksa koneksi Anda dan coba lagi',
      };
    }
  }
}
