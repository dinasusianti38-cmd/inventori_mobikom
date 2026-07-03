import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class AdminAssemblyService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Get all products
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assembly_get_products.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get materials for a specific product with stock information
  Future<List<Map<String, dynamic>>> getProductMaterials(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assembly_get_materials.php?product_id=$productId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load product materials: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Check if product can be assembled (all materials available)
  Future<Map<String, dynamic>> checkAssemblyStatus(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assembly_check_status.php?product_id=$productId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to check assembly status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Process assembly
  // PENTING: method ini TIDAK melempar exception untuk status 'error' dengan
  // result_type 'blocked' — dikembalikan sebagai Map biasa agar UI bisa
  // menampilkan dialog blokir yang sesuai.
  Future<Map<String, dynamic>> processAssembly(int productId, int quantity,
      {int? userId}) async {
    try {
      final uri = Uri.parse('$baseUrl/assembly_process.php');

      final requestBody = json.encode({
        'product_id': productId,
        'quantity': quantity,
        'user_id': userId ?? 1,
      });

      print('processAssembly → POST $uri');
      print('Body: $requestBody');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      print('processAssembly ← status: ${response.statusCode}');
      print('processAssembly ← body: ${response.body}');

      // Coba parse JSON terlebih dahulu
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Server mengembalikan response tidak valid: ${response.body}');
      }

      // ── Kasus BLOCKED: status error tapi result_type blocked ──
      // Jangan throw Exception, kembalikan data agar UI tampilkan dialog blokir
      if (data['status'] == 'error' && data['result_type'] == 'blocked') {
        return data; // UI akan cek result_type == 'blocked'
      }

      // ── Kasus SUCCESS atau WARNING ──
      if (data['status'] == 'success') {
        return data;
      }

      // ── Kasus error lain (bukan blocked) → throw ──
      throw Exception(data['message'] ?? 'Proses assembly gagal');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get assembly history/transactions
  Future<List<Map<String, dynamic>>> getAssemblyHistory(
      {int limit = 100}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assembly_get_history.php?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception(
            'Failed to load assembly history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Export assembly report PDF
  Future<Map<String, dynamic>> exportAssemblyReport() async {
    try {
      print('Starting PDF export...');

      final response = await http.get(
        Uri.parse('$baseUrl/assembly_export_pdf.php'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 60));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          if (data['data'] != null) {
            final fileUrl = data['data']['file_url']?.toString() ?? '';

            if (fileUrl.isNotEmpty) {
              await _downloadPDF(fileUrl);
            }

            return {
              'file_url': fileUrl,
              'filename': data['data']['filename']?.toString() ?? '',
              'file_path': data['data']['file_path']?.toString() ?? '',
              'file_size': data['data']['file_size'] ?? 0,
              'records_count': data['data']['records_count'] ?? 0,
              'file_type': data['data']['file_type']?.toString() ?? 'PDF',
              'summary': data['data']['summary'] ?? {},
            };
          } else {
            throw Exception('Response data is null');
          }
        } else {
          throw Exception(data['message']?.toString() ?? 'Export failed');
        }
      } else {
        throw Exception(
            'Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Export error: $e');
      throw Exception('Export error: $e');
    }
  }

  Future<void> _downloadPDF(String url) async {
    try {
      final Uri pdfUri = Uri.parse(url);
      if (await canLaunchUrl(pdfUri)) {
        await launchUrl(pdfUri, mode: LaunchMode.externalApplication);
        print('PDF download started: $url');
      } else {
        throw Exception('Could not launch URL: $url');
      }
    } catch (e) {
      print('Download PDF error: $e');
      throw Exception('Failed to download PDF: $e');
    }
  }

  // Check notifications for new products ready to assemble
  // Response: { summary: {...}, products: [...] }
  Future<Map<String, dynamic>> checkNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assembly_check_notifications.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Kembalikan isi 'data' langsung: { summary, products }
          return Map<String, dynamic>.from(data['data']);
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to check notifications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}