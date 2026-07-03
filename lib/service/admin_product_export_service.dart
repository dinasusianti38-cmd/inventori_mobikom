import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/api_config.dart';

class ProductExportModel {
  final int idSp;
  final int productId;
  final String codeP;
  final String nameP;
  final String kategori;
  final String satuan;
  final int stokMinimal;
  final int stokTersedia;
  final String status;
  final String lastUpdated;
  final String updatedByName;

  ProductExportModel({
    required this.idSp,
    required this.productId,
    required this.codeP,
    required this.nameP,
    required this.kategori,
    required this.satuan,
    required this.stokMinimal,
    required this.stokTersedia,
    required this.status,
    required this.lastUpdated,
    required this.updatedByName,
  });

  factory ProductExportModel.fromJson(Map<String, dynamic> json) {
    return ProductExportModel(
      idSp: json['id_sp'] ?? 0,
      productId: json['product_id'] ?? 0,
      codeP: json['code_p'] ?? '',
      nameP: json['name_p'] ?? '',
      kategori: json['kategori'] ?? 'antena',
      satuan: json['satuan'] ?? 'pcs',
      stokMinimal: json['stok_minimal'] ?? 0,
      stokTersedia: json['stok_tersedia'] ?? 0,
      status: json['status'] ?? 'stok normal',
      lastUpdated: json['last_updated'] ?? '',
      updatedByName: json['updated_by_name'] ?? '',
    );
  }
}

class ProductSummary {
  final int totalProducts;
  final int stokNormal;
  final int stokMenipis;
  final int stokHabis;

  ProductSummary({
    required this.totalProducts,
    required this.stokNormal,
    required this.stokMenipis,
    required this.stokHabis,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    return ProductSummary(
      totalProducts: json['total_products'] ?? 0,
      stokNormal: json['stok_normal'] ?? 0,
      stokMenipis: json['stok_menipis'] ?? 0,
      stokHabis: json['stok_habis'] ?? 0,
    );
  }
}

class AdminProductExportService {
  static const String _baseUrl = ApiConfig.baseUrl;

  /// Mengambil data produk untuk export dengan data real-time
  static Future<Map<String, dynamic>> getProductsForExport() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/get_stok_produk_export.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['status'] == 'success') {
          List<ProductExportModel> products = [];
          
          // Parse products
          for (var item in responseData['data']) {
            products.add(ProductExportModel.fromJson(item));
          }

          // Parse summary
          ProductSummary summary = ProductSummary.fromJson(responseData['summary']);

          return {
            'products': products,
            'summary': summary,
            'timestamp': responseData['timestamp'],
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

  /// Export ke PDF dengan data real-time
  static Future<void> exportToPdf({
    String search = '',
    String status = '',
    required BuildContext context,
  }) async {
    try {
      await initializeDateFormatting('id_ID', null);
      
      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Mengambil data terbaru dan menggenerate laporan PDF...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Ambil data terbaru dari service
      final exportData = await getProductsForExport();
      final List<ProductExportModel> products = exportData['products'];
      final ProductSummary summary = exportData['summary'];

      final pdf = pw.Document();
      final numberFormat = NumberFormat('#,##0', 'id_ID');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (context) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'LAPORAN STOK PRODUK',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'SISTEM INVENTORY MANAGEMENT',
                      style: pw.TextStyle(fontSize: 16),
                    ),
                    pw.Text(
                      'Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Waktu: ${DateFormat('HH:mm:ss', 'id_ID').format(DateTime.now())} WIB',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // Summary Section dengan data real-time
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
              padding: pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RINGKASAN STOK PRODUK (Data Real-Time)',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text(
                            'Total Produk',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            summary.totalProducts.toString(),
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.blue800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            'Stok Normal',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            summary.stokNormal.toString(),
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.green800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            'Stok Menipis',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            summary.stokMenipis.toString(),
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.orange800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            'Stok Habis',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            summary.stokHabis.toString(),
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.red800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Detail Table
            pw.Text(
              'DETAIL STOK PRODUK',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
            ),
            pw.SizedBox(height: 10),

            // Table dengan data real-time
            pw.Table.fromTextArray(
              cellStyle: pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: pw.EdgeInsets.all(4),
              headers: [
                'No',
                'Kode Produk',
                'Nama Produk',
                'Kategori',
                'Jumlah',
                'Satuan',
                'Status',
                'Pembaruan Terakhir',
              ],
              data: products.asMap().entries.map((entry) {
                int index = entry.key + 1;
                ProductExportModel product = entry.value;

                // Validasi ulang status untuk memastikan konsistensi 100%
                String actualStatus;
                
                if (product.stokTersedia == 0) {
                  actualStatus = 'stok habis';
                } else if (product.stokTersedia <= product.stokMinimal) {
                  actualStatus = 'stok menipis';
                } else {
                  actualStatus = 'stok normal';
                }

                // Format tanggal
                String formattedDate = product.lastUpdated;
                if (formattedDate.length > 10) {
                  formattedDate = formattedDate.substring(0, 10);
                }

                return [
                  index.toString(),
                  product.codeP,
                  product.nameP,
                  product.kategori,
                  numberFormat.format(product.stokTersedia),
                  product.satuan,
                  actualStatus,
                  formattedDate,
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 30),

            // Footer dengan timestamp
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Catatan:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '• Data stok diambil secara real-time dari database',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      '• Status stok dihitung berdasarkan jumlah aktual saat ini',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Dicetak pada:',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      DateFormat('dd/MM/yyyy HH:mm:ss', 'id_ID').format(DateTime.now()),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Text(
                      'Admin Inventory',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text('(..........................)'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Laporan PDF berhasil digenerate dengan data terbaru'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Error: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}