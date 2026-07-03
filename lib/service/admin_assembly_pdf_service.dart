import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/api_config.dart';

class AssemblyPdfService {
  static const String baseUrl = ApiConfig.baseUrl;

  static const _blue       = PdfColor.fromInt(0xFF4682B4);
  static const _darkText   = PdfColor.fromInt(0xFF111111);
  static const _grayText   = PdfColor.fromInt(0xFF555555);
  static const _lightGray  = PdfColor.fromInt(0xFFF2F2F2);
  static const _borderGray = PdfColor.fromInt(0xFFCCCCCC);
  static const _green      = PdfColor.fromInt(0xFF28a745);
  static const _orange     = PdfColor.fromInt(0xFFe67e00);
  static const _red        = PdfColor.fromInt(0xFFcc2200);
  static const _white      = PdfColors.white;

  // ─── NULL-SAFE HELPERS ───────────────────────────────────

  String _s(dynamic v, [String fb = '-']) =>
      (v == null || v.toString().isEmpty) ? fb : v.toString();

  int _i(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  Map<String, dynamic> _m(dynamic v) =>
      (v is Map) ? Map<String, dynamic>.from(v) : {};

  // ─── NETWORK ─────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchReportData() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/assembly_export_pdf.php'),
              headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

          print('STATUS CODE: ${response.statusCode}');
          print('BODY: ${response.body}'); // ← tambah ini

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
         print('DECODED: $decoded'); // ← 
        if (decoded is! Map<String, dynamic>) {
          throw Exception('Format response tidak valid');
        }
        if (decoded['status'] == 'success') {
          final data = decoded['data'];
          if (data == null) throw Exception('Data server null/kosong');
          return data as Map<String, dynamic>;
        }
        throw Exception(decoded['message']?.toString() ?? 'Gagal mengambil data');
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('$e');
    }
  }

  // ─── PDF GENERATION ──────────────────────────────────────
  Future<Uint8List> generatePdf(Map<String, dynamic> reportData) async {
  print('generatePdf called');
  
  final pdf = pw.Document();

  final genDate    = _s(reportData['generated_date'], '-');
  final totalProj  = _i(reportData['total_projects']);
  final totalAssem = _i(reportData['total_assembly']);
  final totalUnits = _i(reportData['total_units']);
  final List items = (reportData['report_data'] is List)
      ? reportData['report_data'] as List
      : [];

  print('Membangun halaman PDF...');

  try {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        // ← HAPUS header dan footer dulu untuk isolasi error
        build: (ctx) {
          print('build() dipanggil');
          final List<pw.Widget> widgets = [];

          widgets.add(_summaryBox(totalProj, totalAssem, totalUnits));
          widgets.add(pw.SizedBox(height: 18));
          widgets.add(_sectionLabel('DETAIL ASSEMBLY PROJEK'));
          widgets.add(pw.SizedBox(height: 10));

          if (items.isEmpty) {
            widgets.add(_noDataWidget());
          } else {
            for (int i = 0; i < items.length; i++) {
              print('Memproses item ke-$i');
              try {
                final block = _projectBlock(items[i]);
                print('Block item ke-$i berhasil dibuat');
                widgets.add(block);
                widgets.add(pw.SizedBox(height: 14));
              } catch (e, st) {
                print('ERROR di item ke-$i: $e');
                print('STACKTRACE: $st');
              }
            }
          }

          return widgets;
        },
      ),
    );
    
    print('addPage selesai, menyimpan PDF...');
    final bytes = await pdf.save();
    print('PDF berhasil disimpan, ukuran: ${bytes.length} bytes');
    return bytes;
    
  } catch (e, st) {
    print('ERROR saat addPage/save: $e');
    print('STACKTRACE: $st');
    rethrow;
  }
}

  // ─── PAGE HEADER ─────────────────────────────────────────

  pw.Widget _pageHeader(String genDate, int pageNum) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('LAPORAN ASSEMBLY PROJEK',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _darkText)),
        pw.SizedBox(height: 3),
        pw.Text('SISTEM INVENTORY MANAGEMENT',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _darkText)),
        pw.SizedBox(height: 3),
        pw.Text('Tanggal: $genDate WIB',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: _grayText)),
        pw.SizedBox(height: 10),
        pw.Container(height: 2.0, color: _darkText),
        pw.SizedBox(height: 2),
        pw.Container(height: 0.5, color: _darkText),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // ─── SUMMARY BOX ─────────────────────────────────────────

  pw.Widget _summaryBox(int totalProj, int totalAssem, int totalUnits) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderGray, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: _lightGray,
            padding:
                const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            child: pw.Text('RINGKASAN ASSEMBLY PROJEK (Data Real-Time)',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText)),
          ),
          pw.Row(
            children: [
              _summaryCell('Total Projek', '$totalProj', _blue, bold: true),
              _vDivider(),
              _summaryCell('Total Assembly', '$totalAssem', _grayText),
              _vDivider(),
              _summaryCell('Total Unit\nDiproduksi', '$totalUnits', _blue),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryCell(String label, String value, PdfColor color,
      {bool bold = false}) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(label,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8, color: _grayText)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _vDivider() =>
      pw.Container(width: 0.5, height: 58, color: _borderGray);

  pw.Widget _sectionLabel(String text) {
    return pw.Container(
      width: double.infinity,
      color: _lightGray,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _darkText)),
    );
  }

  // ─── PROJECT BLOCK ───────────────────────────────────────

    pw.Widget _projectBlock(dynamic item) {
    print('_projectBlock item type: ${item.runtimeType}');
    print('_projectBlock item: $item');
    
    final Map<String, dynamic> proj = _m(_m(item)['project']);
    print('proj: $proj');
    
    final List materials = (_m(item)['materials'] is List)
        ? _m(item)['materials'] as List
        : [];
    print('materials count: ${materials.length}');

    final name       = _s(proj['name_p'], '-');
    final code       = _s(proj['code_p'], '-');
    final asmCount   = _i(proj['assembly_count']);
    final totalQty   = _i(proj['total_qty']);
    final stokProduk = _i(proj['stok_produk']);
    final lastAsm    = _s(proj['last_assembly'], '-');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header biru dengan nama + kode
        pw.Container(
          width: double.infinity,
          color: _blue,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(name,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _white)),
              pw.Text('Kode: $code',
                  style: pw.TextStyle(fontSize: 8, color: _white)),
            ],
          ),
        ),

        // Info bar: assembly count, total produksi, stok produk saat ini
        pw.Container(
          width: double.infinity,
          color: const PdfColor.fromInt(0xFFEBF2FA),
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Assembly: ${asmCount}x   |   Total Diproduksi: $totalQty unit   |   Stok Produk Saat Ini: $stokProduk unit',
                style: pw.TextStyle(fontSize: 7.5, color: _grayText),
              ),
              pw.Text('Terakhir: $lastAsm',
                  style: pw.TextStyle(fontSize: 7.5, color: _grayText)),
            ],
          ),
        ),

        // Tabel material
        pw.Table(
          border: pw.TableBorder.all(color: _borderGray, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(20),
            1: pw.FixedColumnWidth(54),
            2: pw.FlexColumnWidth(2.2),
            3: pw.FixedColumnWidth(50),
            4: pw.FixedColumnWidth(46),
            5: pw.FixedColumnWidth(46),
            6: pw.FixedColumnWidth(50),
            7: pw.FixedColumnWidth(36),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _lightGray),
              children: [
                _th('No'),
                _th('Kode'),
                _th('Nama Material'),
                _th('Kategori'),
                _th('Dibutuhkan', center: true),
                _th('Stok\nSaat Ini', center: true),
                _th('Sisa Setelah\nAssembly', center: true),
                _th('Status', center: true),
              ],
            ),

            if (materials.isEmpty)
              pw.TableRow(children: [
                pw.SizedBox(),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 8, horizontal: 6),
                  child: pw.Text('Tidak ada material',
                      style: pw.TextStyle(fontSize: 8, color: _grayText)),
                ),
                pw.SizedBox(), pw.SizedBox(), pw.SizedBox(),
                pw.SizedBox(), pw.SizedBox(), pw.SizedBox(),
              ])
            else
              ...materials.asMap().entries.map((e) {
                final idx = e.key;
                final Map<String, dynamic> mat = _m(e.value);

                final int needed    = _i(mat['qty_needed']);
                final int available = _i(mat['stock_available']);
                final int sisa      = _i(
                  mat['sisa_setelah_assembly'],
                  available - needed,
                );

                String   statusText;
                PdfColor statusColor;
                if (available >= needed) {
                  statusText  = 'Cukup';
                  statusColor = _green;
                } else if (available > 0) {
                  statusText  = 'Kurang';
                  statusColor = _orange;
                } else {
                  statusText  = 'Habis';
                  statusColor = _red;
                }

                final sisaColor =
                    sisa < 0 ? _red : (sisa == 0 ? _orange : _green);
                final rowBg = idx % 2 == 0
                    ? _white
                    : const PdfColor.fromInt(0xFFFAFAFA);

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: rowBg),
                  children: [
                    _td('${idx + 1}', center: true),
                    _td(_s(mat['code_m'], '-')),
                    _td(_s(mat['nama_m'], '-')),
                    _td(_s(mat['category'], '-')),
                    _td('$needed', center: true),
                    _td('$available', center: true, color: statusColor),
                    _td('$sisa', center: true, color: sisaColor),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 3),
                      child: pw.Center(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                                color: statusColor, width: 0.8),
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                          child: pw.Text(statusText,
                              style: pw.TextStyle(
                                  fontSize: 7,
                                  color: statusColor,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                );
              }),
          ],
        ),
      ],
    );
  }

  // ─── NOTES + SIGNATURE ───────────────────────────────────

  pw.Widget _notesSection(String genDate) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Catatan:',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkText)),
              pw.SizedBox(height: 3),
              pw.Text(
                '- Data diambil secara real-time dari database\n'
                '- "Sisa Setelah Assembly" = Stok Saat Ini dikurangi Dibutuhkan\n'
                '- Status: Cukup = stok memadai | Kurang = stok sebagian | Habis = stok nol\n'
                '- Laporan digenerate otomatis oleh sistem',
                style: pw.TextStyle(fontSize: 7, color: _grayText),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Dicetak pada: $genDate',
                style: pw.TextStyle(fontSize: 7, color: _grayText)),
            pw.SizedBox(height: 40),
            pw.Text('Admin Inventory',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText)),
            pw.SizedBox(height: 4),
            pw.Container(width: 110, height: 0.8, color: _darkText),
            pw.SizedBox(height: 3),
            pw.Text('(..............................)',
                style: pw.TextStyle(fontSize: 8, color: _grayText)),
          ],
        ),
      ],
    );
  }

  // ─── PAGE FOOTER ─────────────────────────────────────────

  pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Container(height: 0.5, color: _borderGray),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                'Sistem Inventory Management — Laporan Assembly Projek',
                style: pw.TextStyle(fontSize: 7, color: _grayText)),
            pw.Text(
                'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7, color: _grayText)),
          ],
        ),
      ],
    );
  }

  // ─── NO DATA ─────────────────────────────────────────────

  pw.Widget _noDataWidget() {
    return pw.Center(
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          children: [
            pw.Text('Belum Ada Data Projek',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _grayText)),
            pw.SizedBox(height: 6),
            pw.Text(
                'Tambahkan produk dengan material terlebih dahulu.',
                style: pw.TextStyle(fontSize: 9, color: _grayText)),
          ],
        ),
      ),
    );
  }

  // ─── TABLE HELPERS ───────────────────────────────────────

  pw.Widget _th(String text, {bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(text,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _darkText)),
    );
  }

  pw.Widget _td(String text, {bool center = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(text,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: 7.5, color: color ?? _darkText)),
    );
  }

  // ─── PUBLIC ENTRY ─────────────────────────────────────────

 Future<Uint8List> buildReportPdf() async {
  final response = await fetchReportData(); // ini return decoded['data']
  print('buildReportPdf response keys: ${response.keys}');
  // harus print: generated_date, total_projects, total_assembly, total_units, report_data
  return generatePdf(response);
}
}