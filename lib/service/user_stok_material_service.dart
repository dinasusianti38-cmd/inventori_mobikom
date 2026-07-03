import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_material_model.dart';
import '../config/api_config.dart';

class UserStokMaterialService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // Get material stock with pagination and filters
  static Future<MaterialStockResponse> getMaterialStock({
    String search = '',
    String category = '',
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Build query parameters
      Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (category.isNotEmpty && category != 'semua kategory') {
        queryParams['category'] = category;
      }

      // Build URL with query parameters
      String queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final url = Uri.parse('$_baseUrl/get_material_stock.php?$queryString');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          return MaterialStockResponse.fromJson(jsonData);
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load material stock');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load material stock: $e');
    }
  }

  // Get categories for filter dropdown
  static Future<List<String>> getCategories() async {
    try {
      final url = Uri.parse('$_baseUrl/get_categories1.php');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          final categoriesResponse = CategoriesResponse.fromJson(jsonData);
          return ['semua kategory', ...categoriesResponse.data];
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load categories');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading categories: $e');
      return ['semua kategory']; // Return default if error
    }
  }

  // Search materials by name or code
  static Future<MaterialStockResponse> searchMaterials({
    required String searchTerm,
    String category = '',
    int page = 1,
    int limit = 10,
  }) async {
    return getMaterialStock(
      search: searchTerm,
      category: category,
      page: page,
      limit: limit,
    );
  }

  // Filter materials by category
  static Future<MaterialStockResponse> filterByCategory({
    required String category,
    String search = '',
    int page = 1,
    int limit = 10,
  }) async {
    return getMaterialStock(
      search: search,
      category: category,
      page: page,
      limit: limit,
    );
  }
}