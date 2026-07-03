import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_stok_product_model.dart';
import '../config/api_config.dart';

class UserStokProductService {
  static const String _baseUrl = ApiConfig.baseUrl;

  static Future<List<ProductStock>> getAllProductStocks() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/get_product_stocks1.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'success') {
          List<dynamic> stocksList = data['data'];
          return stocksList.map((json) => ProductStock.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to load product stocks');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getAllProductStocks: $e');
      rethrow;
    }
  }

  static Future<List<ProductStock>> searchProductStocks(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search_product_stocks.php?query=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'success') {
          List<dynamic> stocksList = data['data'];
          return stocksList.map((json) => ProductStock.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to search product stocks');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in searchProductStocks: $e');
      rethrow;
    }
  }

  static Future<bool> updateProductStock(int idSp, int stokTersedia, int updatedBy) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update_product_stock.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_sp': idSp,
          'stok_tersedia': stokTersedia,
          'updated_by': updatedBy,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['status'] == 'success';
      } else {
        return false;
      }
    } catch (e) {
      print('Error in updateProductStock: $e');
      return false;
    }
  }
}