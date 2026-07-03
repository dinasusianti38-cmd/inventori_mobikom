import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminExportTransaksiService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Get export data for PDF generation
  Future<Map<String, dynamic>> getExportData({
    DateTime? startDate,
    DateTime? endDate,
    String? materialId,
    String? transactionType,
  }) async {
    try {
      // Build query parameters
      Map<String, String> queryParams = {};
      
      if (startDate != null) {
        queryParams['start_date'] = _formatDate(startDate);
      }
      
      if (endDate != null) {
        queryParams['end_date'] = _formatDate(endDate);
      }
      
      if (materialId != null && materialId.isNotEmpty) {
        queryParams['material_id'] = materialId;
      }
      
      if (transactionType != null && transactionType.isNotEmpty && transactionType != 'all') {
        queryParams['transaction_type'] = transactionType;
      }
      
      // Build URL with query parameters
      String url = '$baseUrl/transaksi_export.php';
      if (queryParams.isNotEmpty) {
        String queryString = queryParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url += '?$queryString';
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          return jsonResponse['data'];
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to get export data');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get export data: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}