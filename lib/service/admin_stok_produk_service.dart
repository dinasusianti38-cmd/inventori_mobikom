import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/produk_stok_models.dart';
import '../config/api_config.dart';

class AdminStokProdukService {
  static const String _baseUrl = ApiConfig.baseUrl;

  static Future<ProdukStokResponse> getStokProduk({
    String search = '',
    String status = '',
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/stok_produk.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return ProdukStokResponse.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> addStokProduk({
    required int productId,
    required int stokMinimal,
    required int stokTersedia,
    int updatedBy = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/stok_produk.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'product_id': productId,
          'stok_minimal': stokMinimal,
          'stok_tersedia': stokTersedia,
          'updated_by': updatedBy,
        }),
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200) {
        return jsonResponse;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to add data');
      }
    } catch (e) {
      throw Exception('Error adding data: $e');
    }
  }

  static Future<Map<String, dynamic>> updateStokProduk({
    required int idSp,
    int? stokMinimal,
    int? stokTersedia,
    int updatedBy = 1,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'id_sp': idSp,
        'updated_by': updatedBy,
      };

      if (stokMinimal != null) {
        body['stok_minimal'] = stokMinimal;
      }

      if (stokTersedia != null) {
        body['stok_tersedia'] = stokTersedia;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/stok_produk.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200) {
        return jsonResponse;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to update data');
      }
    } catch (e) {
      throw Exception('Error updating data: $e');
    }
  }

   static Future<Map<String, dynamic>> deleteStokProduk(int idSp) async {
    try {
      print('Attempting to delete product stock with ID: $idSp'); // Debug log
      
      final response = await http.delete(
        Uri.parse('$_baseUrl/stok_produk.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'id_sp': idSp,
        }),
      );

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      // Check if response body is empty
      if (response.body.isEmpty) {
        throw Exception('Empty response from server');
      }

      // Try to decode JSON
      Map<String, dynamic> jsonResponse;
      try {
        jsonResponse = json.decode(response.body);
      } catch (e) {
        print('JSON decode error: $e');
        print('Response body that failed to decode: ${response.body}');
        throw Exception('Invalid JSON response from server. Response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      }

      if (response.statusCode == 200) {
        return jsonResponse;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to delete data (Status: ${response.statusCode})');
      }
    } on http.ClientException catch (e) {
      print('HTTP Client Exception: $e');
      throw Exception('Network error: $e');
    } catch (e) {
      print('General Exception: $e');
      throw Exception('Error deleting data: $e');
    }
  }
}