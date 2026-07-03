import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_transaction_models.dart';
import '../config/api_config.dart';

class AdminTransaksiProductService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Get all products for dropdown
  static Future<List<ProductModel>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transaksi_product.php?action=get_products'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<ProductModel> products = [];
          for (var item in data['data']) {
            products.add(ProductModel.fromJson(item));
          }
          return products;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch products');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get product transactions history
  static Future<List<ProductTransactionModel>> getProductTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transaksi_product.php?action=get_transactions'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<ProductTransactionModel> transactions = [];
          for (var item in data['data']) {
            transactions.add(ProductTransactionModel.fromJson(item));
          }
          return transactions;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch transactions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Add new product transaction
  static Future<Map<String, dynamic>> addProductTransaction(
    ProductTransactionModel transaction,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transaksi_product.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'add_transaction',
          'data': transaction.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update product transaction
  static Future<Map<String, dynamic>> updateProductTransaction(
    ProductTransactionModel transaction,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/transaksi_product.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'update_transaction',
          'data': transaction.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Delete product transaction
  static Future<Map<String, dynamic>> deleteProductTransaction(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/transaksi_product.php?action=delete_transaction&id=$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}