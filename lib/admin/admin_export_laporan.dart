// ignore: avoid_web_libraries_in_flutter

import 'dart:typed_data';
import 'package:flutter/material.dart' hide Material;
import '../models/export_laporan_models.dart';
import '../service/admin_export_laporan_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../service/admin_export_transaksi_service.dart';

// ── Breakpoints ──────────────────────────────────────────
// mobile  : width < 600
// tablet  : 600 <= width < 960
// desktop : width >= 960

const _primary = Color(0xFFB42B2B);

// ── Warna PDF ──────────────────────────────────────────────────────────────
const _pdfHeaderBg   = PdfColor.fromInt(0xFF2E6DA4);
const _pdfHeaderBgIn = PdfColor.fromInt(0xFF1A7A4A);
const _pdfHeaderText = PdfColors.white;
const _pdfTitleText  = PdfColor.fromInt(0xFF1A1A1A);
const _pdfBorderGray = PdfColor.fromInt(0xFFCCCCCC);
const _pdfRowEven    = PdfColors.white;
const _pdfRowOdd     = PdfColor.fromInt(0xFFF5F8FC);
const _pdfGrayText   = PdfColor.fromInt(0xFF555555);
const _pdfGroupBg    = PdfColor.fromInt(0xFFEAF2FB);
const _pdfSummaryBg  = PdfColor.fromInt(0xFFF0F0F0);
const _pdfGreen      = PdfColor.fromInt(0xFF27AE60);
const _pdfRed        = PdfColor.fromInt(0xFFC0392B);
const _pdfOrange     = PdfColor.fromInt(0xFFE67E22);

// ══════════════════════════════════════════════════════════════════════════════
// HELPER
// ══════════════════════════════════════════════════════════════════════════════
String _fmtNum(num value) {
  final str = value.toInt().abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return value < 0 ? '-${buf.toString()}' : buf.toString();
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';

String _fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

String _parseFmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  try {
    return _fmtDate(DateTime.parse(raw));
  } catch (_) {
    return raw;
  }
}

String _monthLabel(String key) {
  const bulan = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  final parts = key.split('-');
  if (parts.length < 2) return key;
  final month = int.tryParse(parts[1]) ?? 0;
  if (month < 1 || month > 12) return key;
  return '${bulan[month]} ${parts[0]}';
}

// ══════════════════════════════════════════════════════════════════════════════
class AdminExportLaporan extends StatefulWidget {
  @override
  _AdminExportLaporanState createState() => _AdminExportLaporanState();
}

class _AdminExportLaporanState extends State<AdminExportLaporan> {
  final AdminExportLaporanService  _service  = AdminExportLaporanService();
  final AdminExportTransaksiService _service1 = AdminExportTransaksiService();

  List<MaterialTransaction> _transactions         = [];
  List<MaterialTransaction> _filteredTransactions = [];
  List<Material>            _materials            = [];

  bool   _isLoading      = false;
  bool   _isExporting    = false;
  double _exportProgress = 0.0;
  String _exportStatus   = '';

  DateTime? _startDate;
  DateTime? _endDate;
  String?   _selectedMaterialId;
  String?   _selectedTransactionType;

  final List<String> _transactionTypes      = ['all', 'in', 'out', 'adjustment'];
  final List<String> _transactionTypeLabels = ['Semua', 'Masuk', 'Keluar', 'Penyesuaian'];

  int _currentPage  = 1;
  int _itemsPerPage = 5;

  final TextEditingController _searchController = TextEditingController();

  // ── responsive helpers ────────────────────────────────────────────────────
  bool _isMobile(BuildContext ctx)  => MediaQuery.of(ctx).size.width < 600;
  bool _isTablet(BuildContext ctx)  =>
      MediaQuery.of(ctx).size.width >= 600 &&
      MediaQuery.of(ctx).size.width < 960;
  bool _isDesktop(BuildContext ctx) => MediaQuery.of(ctx).size.width >= 960;

  int get _totalPages =>
      (_filteredTransactions.length / _itemsPerPage).ceil().clamp(1, 99999);

  List<MaterialTransaction> get _pagedTransactions {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredTransactions.length);
    if (start >= _filteredTransactions.length) return [];
    return _filteredTransactions.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_applySearch);
  }

  void _applySearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _currentPage = 1;
      _filteredTransactions = q.isEmpty
          ? List.from(_transactions)
          : _transactions.where((t) =>
              t.materialName.toLowerCase().contains(q) ||
              t.transactionCode.toLowerCase().contains(q) ||
              (t.notes ?? '').toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadInitialData() async {
    await _loadMaterials();
    await _loadTransactions();
  }

  Future<void> _loadMaterials() async {
    try {
      final m = await _service.getMaterials();
      setState(() => _materials = m);
    } catch (e) {
      _showSnackBar('Gagal memuat data Barang: $e', isError: true);
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final tx = await _service.getTransactions(
        startDate: _startDate,
        endDate: _endDate,
        materialId: _selectedMaterialId,
        transactionType:
            _selectedTransactionType == 'all' ? null : _selectedTransactionType,
      );
      setState(() {
        _transactions           = tx;
        _filteredTransactions   = List.from(tx);
        _currentPage            = 1;
        _isLoading              = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Gagal memuat data transaksi: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? _primary : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
      _loadTransactions();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
      _loadTransactions();
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _startDate                = null;
      _endDate                  = null;
      _selectedMaterialId       = null;
      _selectedTransactionType  = null;
      _currentPage              = 1;
    });
    _loadTransactions();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPORT
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() {
      _isExporting    = true;
      _exportProgress = 0.0;
      _exportStatus   = 'Mengambil data transaksi...';
    });
    try {
      final exportData = await _service1.getExportData(
        startDate: _startDate,
        endDate:   _endDate,
        materialId:      _selectedMaterialId,
        transactionType: (_selectedTransactionType == 'all')
            ? null
            : _selectedTransactionType,
      );
      _setProgress(0.3, 'Menyiapkan dokumen PDF...');
      final pdfBytes = await _buildPdfBytes(exportData);
      _setProgress(0.85, 'Mengunduh file...');

      final now = DateTime.now();
      final filename = 'Rekap_Transaksi_'
          '${now.year}${now.month.toString().padLeft(2,'0')}'
          '${now.day.toString().padLeft(2,'0')}'
          '_${now.hour.toString().padLeft(2,'0')}'
          '${now.minute.toString().padLeft(2,'0')}.pdf';

      await Printing.sharePdf(
  bytes: pdfBytes,
  filename: filename,
);

      _setProgress(1.0, 'Selesai!');
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() {
        _isExporting    = false;
        _exportProgress = 0.0;
        _exportStatus   = '';
      });
      _showSnackBar('Rekap PDF berhasil diunduh: $filename');
    } catch (e) {
      setState(() {
        _isExporting    = false;
        _exportProgress = 0.0;
        _exportStatus   = '';
      });
      _showSnackBar('Gagal mengekspor laporan: $e', isError: true);
    }
  }

  void _setProgress(double val, String status) {
    if (mounted) setState(() {
      _exportProgress = val;
      _exportStatus   = status;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PDF BUILDER  (tidak berubah dari versi asli)
  // ══════════════════════════════════════════════════════════════════════════
  Future<Uint8List> _buildPdfBytes(Map<String, dynamic> exportData) async {
    final pdf  = pw.Document();
    final now  = DateTime.now();
    final allTx    = exportData['transactions'] as List;
    final filters  = exportData['filters'] as Map<String, dynamic>;

    final txIn  = allTx.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'in').toList();
    final txOut = allTx.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'out').toList();
    final txAdj = allTx.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'adjustment').toList();

    final String? activeType   = filters['transaction_type'] as String?;
    final String? typeLabel    = filters['type_label']       as String?;
    final String? materialName = filters['material_name']    as String?;

    String periodeLabel = 'Semua Periode';
    if (filters['start_date'] != null || filters['end_date'] != null) {
      periodeLabel =
          'Periode: ${filters['start_date'] ?? '-'}  s/d  ${filters['end_date'] ?? '-'}';
    }

    final List<String> filterInfo = [];
    if (typeLabel    != null) filterInfo.add('Jenis: $typeLabel');
    if (materialName != null) filterInfo.add('Barang: $materialName');
    final String filterSubtitle =
        filterInfo.isNotEmpty ? filterInfo.join('  |  ') : 'Semua Jenis Transaksi';

    final printDate = _fmtDate(now);
    final printTime = _fmtTime(now);

    Map<String, List<dynamic>> groupByMaterial(List src) {
      final map = <String, List<dynamic>>{};
      for (final t in src) {
        final name = (t['material_name'] ?? 'Tidak Diketahui').toString();
        map.putIfAbsent(name, () => []).add(t);
      }
      map.forEach((_, list) {
        list.sort((a, b) {
          final da = DateTime.tryParse(a['transaction_date'] ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(b['transaction_date'] ?? '') ?? DateTime(2000);
          return da.compareTo(db);
        });
      });
      return map;
    }

    final byMaterialAll = groupByMaterial(allTx);
    final byMaterialIn  = groupByMaterial(txIn);
    final byMaterialOut = groupByMaterial(txOut);
    final byMaterialAdj = groupByMaterial(txAdj);

    // Cover page
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _buildKop(periodeLabel: periodeLabel, filterSubtitle: filterSubtitle,
              printDate: printDate, printTime: printTime, totalTx: allTx.length),
          pw.SizedBox(height: 24),
          _buildRingkasanGabungan(txIn: txIn, txOut: txOut, txAdj: txAdj, activeType: activeType),
          pw.SizedBox(height: 24),
          _buildDaftarBarang(byMaterialAll),
          pw.Spacer(),
          _buildFooterSign(),
        ],
      ),
    ));

    final bool renderIn  = txIn.isNotEmpty  && (activeType == null || activeType == 'in');
    final bool renderOut = txOut.isNotEmpty && (activeType == null || activeType == 'out');
    final bool renderAdj = txAdj.isNotEmpty && (activeType == null || activeType == 'adjustment');

    if (renderIn) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        header: (ctx) => _buildSectionPageHeader('REKAP TRANSAKSI MASUK', periodeLabel, printDate, _pdfHeaderBgIn, filterSubtitle: filterSubtitle),
        footer: (ctx) => _buildPageFooter(ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          widgets.add(_buildSectionTitle('REKAP TRANSAKSI MASUK', txIn.length, _pdfGreen));
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(_buildRingkasanPerBarangSection(byMaterialIn, _pdfGreen));
          widgets.add(pw.SizedBox(height: 20));
          for (final entry in byMaterialIn.entries) {
            final byMonth = _groupByMonth(entry.value);
            widgets.add(_buildMaterialInfoBar(entry.key, entry.value, sectionColor: _pdfHeaderBgIn));
            widgets.add(pw.SizedBox(height: 10));
            for (final me in byMonth.entries) {
              widgets.add(_buildMonthLabel(_monthLabel(me.key), _pdfHeaderBgIn));
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(_buildTransactionTable(me.value, txType: 'in'));
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(_buildMonthSubTotal(me.value, singleType: 'in'));
              widgets.add(pw.SizedBox(height: 14));
            }
            widgets.add(_buildGrandTotalRow(entry.value, singleType: 'in', color: _pdfHeaderBgIn));
            widgets.add(pw.SizedBox(height: 20));
          }
          return widgets;
        },
      ));
    }

    if (renderOut) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        header: (ctx) => _buildSectionPageHeader('REKAP TRANSAKSI KELUAR', periodeLabel, printDate, _pdfRed, filterSubtitle: filterSubtitle),
        footer: (ctx) => _buildPageFooter(ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          widgets.add(_buildSectionTitle('REKAP TRANSAKSI KELUAR', txOut.length, _pdfRed));
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(_buildRingkasanPerBarangSection(byMaterialOut, _pdfRed));
          widgets.add(pw.SizedBox(height: 20));
          for (final entry in byMaterialOut.entries) {
            final byMonth = _groupByMonth(entry.value);
            widgets.add(_buildMaterialInfoBar(entry.key, entry.value, sectionColor: _pdfRed));
            widgets.add(pw.SizedBox(height: 10));
            for (final me in byMonth.entries) {
              widgets.add(_buildMonthLabel(_monthLabel(me.key), _pdfRed));
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(_buildTransactionTable(me.value, txType: 'out'));
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(_buildMonthSubTotal(me.value, singleType: 'out'));
              widgets.add(pw.SizedBox(height: 14));
            }
            widgets.add(_buildGrandTotalRow(entry.value, singleType: 'out', color: _pdfRed));
            widgets.add(pw.SizedBox(height: 20));
          }
          return widgets;
        },
      ));
    }

    if (renderAdj) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        header: (ctx) => _buildSectionPageHeader('REKAP PENYESUAIAN', periodeLabel, printDate, _pdfOrange, filterSubtitle: filterSubtitle),
        footer: (ctx) => _buildPageFooter(ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          widgets.add(_buildSectionTitle('REKAP PENYESUAIAN', txAdj.length, _pdfOrange));
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(_buildRingkasanPerBarangSection(byMaterialAdj, _pdfOrange));
          widgets.add(pw.SizedBox(height: 20));
          for (final entry in byMaterialAdj.entries) {
            final byMonth = _groupByMonth(entry.value);
            widgets.add(_buildMaterialInfoBar(entry.key, entry.value, sectionColor: _pdfOrange));
            widgets.add(pw.SizedBox(height: 10));
            for (final me in byMonth.entries) {
              widgets.add(_buildMonthLabel(_monthLabel(me.key), _pdfOrange));
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(_buildTransactionTable(me.value, txType: 'adjustment'));
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(_buildMonthSubTotal(me.value, singleType: 'adjustment'));
              widgets.add(pw.SizedBox(height: 14));
            }
            widgets.add(_buildGrandTotalRow(entry.value, singleType: 'adjustment', color: _pdfOrange));
            widgets.add(pw.SizedBox(height: 20));
          }
          return widgets;
        },
      ));
    }

    return pdf.save();
  }

  Map<String, List<dynamic>> _groupByMonth(List<dynamic> src) {
    final map = <String, List<dynamic>>{};
    for (final t in src) {
      final dt  = DateTime.tryParse(t['transaction_date'] ?? '');
      final key = dt != null
          ? '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}'
          : '0000-00';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PDF WIDGET BUILDERS  (tidak berubah)
  // ══════════════════════════════════════════════════════════════════════════
  pw.Widget _buildKop({required String periodeLabel, required String filterSubtitle,
      required String printDate, required String printTime, required int totalTx}) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Text('REKAP TRANSAKSI BARANG',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _pdfTitleText)),
      pw.SizedBox(height: 3),
      pw.Text('Sistem Inventory Management',
          style: pw.TextStyle(fontSize: 10, color: _pdfGrayText)),
      pw.SizedBox(height: 3),
      pw.Text(periodeLabel, style: pw.TextStyle(fontSize: 9, color: _pdfGrayText)),
      pw.SizedBox(height: 2),
      pw.Text(filterSubtitle,
          style: pw.TextStyle(fontSize: 9, color: _pdfHeaderBg, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Container(height: 2.5, color: _pdfHeaderBg),
      pw.SizedBox(height: 2),
      pw.Container(height: 0.8, color: _pdfBorderGray),
      pw.SizedBox(height: 10),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        _infoBox('Tanggal Cetak', '$printDate  $printTime', _pdfHeaderBg),
        pw.SizedBox(width: 12),
        _infoBox('Total Transaksi', '$totalTx', _pdfGrayText),
      ]),
    ]);
  }

  pw.Widget _infoBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _pdfBorderGray),
          borderRadius: pw.BorderRadius.circular(4),
          color: _pdfSummaryBg),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _pdfGrayText)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
      ]),
    );
  }

  pw.Widget _buildRingkasanGabungan(
      {required List txIn, required List txOut, required List txAdj, String? activeType}) {
    int sumQty(List l) => l.fold(0, (s, t) => s + ((t['jumlah'] ?? 0) as num).toInt());
    final bool showIn  = activeType == null || activeType == 'in';
    final bool showOut = activeType == null || activeType == 'out';
    final bool showAdj = activeType == null || activeType == 'adjustment';
    final List allShown = [if (showIn) ...txIn, if (showOut) ...txOut, if (showAdj) ...txAdj];
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Container(
        color: _pdfHeaderBg,
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        child: pw.Text('RINGKASAN TRANSAKSI',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdfHeaderText)),
      ),
      pw.Table(
        border: pw.TableBorder.all(color: _pdfBorderGray, width: 0.5),
        columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FixedColumnWidth(70), 2: pw.FixedColumnWidth(70)},
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _pdfSummaryBg), children: [
            _thCell('Jenis Transaksi'),
            _thCell('Jumlah Transaksi', center: true),
            _thCell('Total Qty', center: true),
          ]),
          if (showIn)  _summaryRowPdf('Transaksi Masuk', txIn.length,  sumQty(txIn),  _pdfGreen),
          if (showOut) _summaryRowPdf('Transaksi Keluar', txOut.length, sumQty(txOut), _pdfRed),
          if (showAdj) _summaryRowPdf('Penyesuaian',     txAdj.length, sumQty(txAdj), _pdfOrange),
          pw.TableRow(decoration: const pw.BoxDecoration(color: _pdfSummaryBg), children: [
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfTitleText))),
            _tdCell('${allShown.length}', center: true, bold: true),
            _tdCell(_fmtNum(sumQty(allShown)), center: true, bold: true),
          ]),
        ],
      ),
    ]);
  }

  pw.TableRow _summaryRowPdf(String label, int count, int qty, PdfColor dot) {
    return pw.TableRow(decoration: const pw.BoxDecoration(color: _pdfRowEven), children: [
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(children: [
            pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(color: dot, shape: pw.BoxShape.circle)),
            pw.SizedBox(width: 6),
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _pdfTitleText)),
          ])),
      _tdCell('$count', center: true),
      _tdCell(_fmtNum(qty), center: true),
    ]);
  }

  pw.Widget _buildDaftarBarang(Map<String, List<dynamic>> byMaterial) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Container(
        color: _pdfHeaderBg,
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        child: pw.Text('DAFTAR BARANG',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdfHeaderText)),
      ),
      pw.Table(
        border: pw.TableBorder.all(color: _pdfBorderGray, width: 0.5),
        columnWidths: const {0: pw.FixedColumnWidth(22), 1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(55), 3: pw.FixedColumnWidth(55), 4: pw.FixedColumnWidth(55)},
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _pdfSummaryBg), children: [
            _thCell('No', center: true), _thCell('Nama Barang'),
            _thCell('Masuk', center: true), _thCell('Keluar', center: true), _thCell('Penyesuaian', center: true),
          ]),
          ...byMaterial.entries.toList().asMap().entries.map((e) {
            final idx  = e.key;
            final name = e.value.key;
            final list = e.value.value;
            final cIn  = list.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'in').length;
            final cOut = list.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'out').length;
            final cAdj = list.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'adjustment').length;
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: idx % 2 == 0 ? _pdfRowEven : _pdfRowOdd),
              children: [
                _tdCell('${idx+1}', center: true),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: pw.Text(name, style: pw.TextStyle(fontSize: 9, color: _pdfTitleText))),
                _tdCell('$cIn',  center: true, color: cIn  > 0 ? _pdfGreen  : _pdfGrayText),
                _tdCell('$cOut', center: true, color: cOut > 0 ? _pdfRed    : _pdfGrayText),
                _tdCell('$cAdj', center: true, color: cAdj > 0 ? _pdfOrange : _pdfGrayText),
              ],
            );
          }),
        ],
      ),
    ]);
  }

  pw.Widget _buildSectionPageHeader(String title, String periode, String printDate,
      PdfColor color, {String filterSubtitle = ''}) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text('Sistem Inventory Management  |  $periode',
              style: pw.TextStyle(fontSize: 7.5, color: _pdfGrayText)),
          if (filterSubtitle.isNotEmpty)
            pw.Text(filterSubtitle,
                style: pw.TextStyle(fontSize: 7.5, color: color, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Dicetak: $printDate', style: pw.TextStyle(fontSize: 7.5, color: _pdfGrayText)),
      ]),
      pw.SizedBox(height: 5),
      pw.Container(height: 2, color: color),
      pw.SizedBox(height: 1),
      pw.Container(height: 0.5, color: _pdfBorderGray),
      pw.SizedBox(height: 8),
    ]);
  }

  pw.Widget _buildSectionTitle(String title, int count, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text('$count transaksi',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
        ),
      ]),
    );
  }

  pw.Widget _buildRingkasanPerBarangSection(Map<String, List<dynamic>> byMaterial, PdfColor color) {
    int sumQty(List l) => l.fold(0, (s, t) => s + ((t['jumlah'] ?? 0) as num).toInt());
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Container(
        color: color,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: pw.Text('RINGKASAN PER BARANG',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ),
      pw.Table(
        border: pw.TableBorder.all(color: _pdfBorderGray, width: 0.5),
        columnWidths: const {0: pw.FixedColumnWidth(22), 1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(80), 3: pw.FixedColumnWidth(80)},
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _pdfSummaryBg), children: [
            _thCell('No', center: true), _thCell('Nama Barang'),
            _thCell('Jml Transaksi', center: true), _thCell('Total Qty', center: true),
          ]),
          ...byMaterial.entries.toList().asMap().entries.map((e) {
            final idx  = e.key;
            final name = e.value.key;
            final list = e.value.value;
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: idx % 2 == 0 ? _pdfRowEven : _pdfRowOdd),
              children: [
                _tdCell('${idx+1}', center: true),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: pw.Text(name, style: pw.TextStyle(fontSize: 9, color: _pdfTitleText))),
                _tdCell('${list.length}', center: true, color: color),
                _tdCell(_fmtNum(sumQty(list)), center: true, color: color),
              ],
            );
          }),
        ],
      ),
    ]);
  }

  pw.Widget _buildMaterialInfoBar(String name, List txList, {PdfColor sectionColor = _pdfHeaderBg}) {
    final cIn  = txList.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'in').length;
    final cOut = txList.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'out').length;
    final cAdj = txList.where((t) => (t['transaction_type'] ?? '').toLowerCase() == 'adjustment').length;
    return pw.Row(children: [
      pw.Container(width: 4, height: 52, color: sectionColor),
      pw.Expanded(child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const pw.BoxDecoration(color: _pdfGroupBg),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Expanded(child: pw.Text(name,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _pdfTitleText))),
          pw.Row(children: [
            if (cIn  > 0) ...[_statBadge('Masuk',      cIn,  _pdfGreen),  pw.SizedBox(width: 6)],
            if (cOut > 0) ...[_statBadge('Keluar',      cOut, _pdfRed),    pw.SizedBox(width: 6)],
            if (cAdj > 0) _statBadge('Penyesuaian', cAdj, _pdfOrange),
          ]),
        ]),
      )),
    ]);
  }

  pw.Widget _statBadge(String label, int count, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text('$count', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: PdfColors.white)),
      ]),
    );
  }

  pw.Widget _buildMonthLabel(String monthLabel, [PdfColor color = _pdfHeaderBg]) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: color, width: 3)),
          color: _pdfSummaryBg),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: pw.Text(monthLabel.toUpperCase(),
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
    );
  }

  pw.Widget _buildTransactionTable(List txList, {String txType = ''}) {
    const headers   = ['No','Tanggal','Kode Transaksi','Jenis','Jumlah','Stok\nSebelum','Stok\nSesudah','Dibuat Oleh','Catatan'];
    const colWidths = {0: pw.FixedColumnWidth(18), 1: pw.FixedColumnWidth(52), 2: pw.FixedColumnWidth(72),
        3: pw.FixedColumnWidth(48), 4: pw.FixedColumnWidth(42), 5: pw.FixedColumnWidth(42),
        6: pw.FixedColumnWidth(42), 7: pw.FixedColumnWidth(55), 8: pw.FlexColumnWidth()};
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfBorderGray, width: 0.5),
      columnWidths: colWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _pdfHeaderBg),
          children: headers.map((h) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            alignment: pw.Alignment.center,
            child: pw.Text(h,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _pdfHeaderText),
                textAlign: pw.TextAlign.center),
          )).toList(),
        ),
        ...List.generate(txList.length, (idx) {
          final t    = txList[idx];
          final type = (t['transaction_type'] ?? '').toString().toLowerCase();
          PdfColor typeColor; String typeLabel;
          switch (type) {
            case 'in':  typeColor = _pdfGreen;  typeLabel = 'Masuk'; break;
            case 'out': typeColor = _pdfRed;    typeLabel = 'Keluar'; break;
            default:    typeColor = _pdfOrange; typeLabel = 'Penyesuaian';
          }
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: idx % 2 == 0 ? _pdfRowEven : _pdfRowOdd),
            children: [
              _tdCell('${idx+1}', center: true),
              _tdCell(_parseFmtDate(t['transaction_date']), center: true),
              _tdCell(t['transaction_code'] ?? '-'),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  child: pw.Center(child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: pw.BoxDecoration(color: typeColor, borderRadius: pw.BorderRadius.circular(3)),
                    child: pw.Text(typeLabel, style: pw.TextStyle(fontSize: 7, color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  ))),
              _tdCell('${_fmtNum((t['jumlah'] ?? 0) as num)} ${t['satuan'] ?? ''}', center: true),
              _tdCell(_fmtNum((t['stok_sebelum'] ?? 0) as num), center: true),
              _tdCell(_fmtNum((t['stok_sesudah'] ?? 0) as num), center: true),
              _tdCell(_truncate(t['created_by_name'] ?? '-', 14)),
              _tdCell(_truncate(t['notes'] ?? '-', 25), fontSize: 7),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildMonthSubTotal(List txList, {String singleType = ''}) {
    int sumQtyOf(String type) => txList
        .where((t) => (t['transaction_type'] ?? '').toLowerCase() == type)
        .fold(0, (s, t) => s + ((t['jumlah'] ?? 0) as num).toInt());
    final isIn  = singleType == 'in';
    final isOut = singleType == 'out';
    final qty   = singleType.isNotEmpty ? sumQtyOf(singleType) : 0;
    final color = isIn ? _pdfGreen : isOut ? _pdfRed : _pdfOrange;
    final label = isIn ? 'Masuk' : isOut ? 'Keluar' : 'Penyesuaian';
    return pw.Container(
      decoration: const pw.BoxDecoration(color: _pdfSummaryBg),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('Sub-total bulan ini: ', style: pw.TextStyle(fontSize: 8, color: _pdfGrayText)),
        pw.SizedBox(width: 8),
        _subTotalChip('$label: ${txList.length} tx  (${_fmtNum(qty)} unit)', color),
      ]),
    );
  }

  pw.Widget _subTotalChip(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 0.7), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, color: color, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildGrandTotalRow(List txList, {String singleType = '', PdfColor color = _pdfHeaderBg}) {
    int sumQtyOf(String type) => txList
        .where((t) => (t['transaction_type'] ?? '').toLowerCase() == type)
        .fold(0, (s, t) => s + ((t['jumlah'] ?? 0) as num).toInt());
    final isIn  = singleType == 'in';
    final isOut = singleType == 'out';
    final label = isIn ? 'Masuk' : isOut ? 'Keluar' : 'Penyesuaian';
    final qty   = singleType.isNotEmpty ? sumQtyOf(singleType) : 0;
    return pw.Container(
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(4)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('TOTAL KESELURUHAN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        _grandChip('$label: ${txList.length} tx  (${_fmtNum(qty)} unit)', color),
      ]),
    );
  }

  pw.Widget _grandChip(String text, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: bgColor)),
    );
  }

  pw.Widget _buildFooterSign() {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _pdfBorderGray), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text('Mengetahui,', style: pw.TextStyle(fontSize: 9, color: _pdfGrayText)),
          pw.SizedBox(height: 38),
          pw.Container(width: 140,
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _pdfTitleText))),
              child: pw.SizedBox(height: 1)),
          pw.SizedBox(height: 4),
          pw.Text('Admin', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfTitleText)),
        ]),
      ),
    ]);
  }

  pw.Widget _buildPageFooter(pw.Context ctx) {
    return pw.Column(children: [
      pw.Container(height: 0.5, color: _pdfBorderGray),
      pw.SizedBox(height: 4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Sistem Inventory Management — Rekap Transaksi Barang',
            style: pw.TextStyle(fontSize: 7, color: _pdfGrayText)),
        pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: _pdfGrayText)),
      ]),
    ]);
  }

  pw.Widget _thCell(String text, {bool center = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfTitleText)),
  );

  pw.Widget _tdCell(String text, {bool center = false, bool bold = false,
      PdfColor? color, double fontSize = 8}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    child: pw.Text(text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? _pdfTitleText)),
  );

  String _truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}...';

  // ══════════════════════════════════════════════════════════════════════════
  // FLUTTER UI  —  FULLY RESPONSIVE
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        // ── Mobile: gunakan AppBar standar Android ──────────────────────────
        appBar: _isMobile(context)
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 1,
                shadowColor: Colors.black12,
                title: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.assessment, color: _primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Laporan Transaksi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))),
                    Text('Export & kelola laporan',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500],
                            fontWeight: FontWeight.normal)),
                  ]),
                ]),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        minimumSize: const Size(0, 36),
                      ),
                      icon: _isExporting
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf, size: 14),
                      label: Text(_isExporting ? 'Proses...' : 'Export PDF',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: Column(children: [
            // ── Desktop/Tablet: header custom ────────────────────────────────
            if (!_isMobile(context)) _buildDesktopHeader(context),
            if (_isExporting) _buildExportProgressBanner(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(_isMobile(context) ? 12 : 20),
                child: Column(children: [
                  _buildFilterCard(context),
                  SizedBox(height: _isMobile(context) ? 12 : 16),
                  _buildSummaryCards(context),
                  SizedBox(height: _isMobile(context) ? 12 : 16),
                  _buildTableCard(context),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]),
        ),
      );
    });
  }

  // ── Desktop header ─────────────────────────────────────────────────────────
  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.assessment, color: _primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Laporan Transaksi Barang',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey[850])),
          Text('Export dan kelola laporan transaksi',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ])),
        ElevatedButton.icon(
          onPressed: _isExporting ? null : _exportData,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: _isExporting
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf, size: 16),
          label: Text(_isExporting ? 'Memproses...' : 'Export Rekap PDF',
              style: const TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }

  // ── Export progress banner ─────────────────────────────────────────────────
  Widget _buildExportProgressBanner(BuildContext context) {
    final isMobile = _isMobile(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
          const SizedBox(width: 10),
          Expanded(child: Text(_exportStatus,
              style: TextStyle(fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.w500, color: _primary))),
          Text('${(_exportProgress * 100).toInt()}%',
              style: TextStyle(fontSize: isMobile ? 11 : 12,
                  color: _primary, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _exportProgress,
            backgroundColor: Colors.grey.shade200,
            color: _primary,
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  // ── Filter card ────────────────────────────────────────────────────────────
  Widget _buildFilterCard(BuildContext context) {
    final isMobile = _isMobile(context);
    final isTablet = _isTablet(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.filter_list, color: _primary, size: 16),
          ),
          const SizedBox(width: 8),
          Text('Filter Laporan',
              style: TextStyle(fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const Spacer(),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Reset', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: _primary),
          ),
        ]),
        const SizedBox(height: 14),

        // ─ Mobile: filter dalam 2 kolom × 2 baris ──────────────────────────
        if (isMobile) ...[
          Row(children: [
            Expanded(child: _filterField('Tgl Mulai', InkWell(
                onTap: _selectStartDate,
                child: _datePickerBox(_startDate != null ? _fmtDate(_startDate!) : 'Pilih', isMobile: true)))),
            const SizedBox(width: 10),
            Expanded(child: _filterField('Tgl Selesai', InkWell(
                onTap: _selectEndDate,
                child: _datePickerBox(_endDate != null ? _fmtDate(_endDate!) : 'Pilih', isMobile: true)))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _filterField('Barang', _dropdownBox(
              value: _selectedMaterialId, hint: 'Semua Barang', isMobile: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua', style: TextStyle(fontSize: 13))),
                ..._materials.map((m) => DropdownMenuItem(value: m.idM.toString(),
                    child: Text(m.namaM, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) { setState(() { _selectedMaterialId = v; _currentPage = 1; }); _loadTransactions(); },
            ))),
            const SizedBox(width: 10),
            Expanded(child: _filterField('Jenis', _dropdownBox(
              value: _selectedTransactionType, hint: 'Semua', isMobile: true,
              items: List.generate(_transactionTypes.length, (i) => DropdownMenuItem(
                  value: _transactionTypes[i],
                  child: Text(_transactionTypeLabels[i], style: const TextStyle(fontSize: 13)))),
              onChanged: (v) { setState(() { _selectedTransactionType = v; _currentPage = 1; }); _loadTransactions(); },
            ))),
          ]),
        ]

        // ─ Tablet: 2+2 dalam baris yang sama, font/tinggi lebih compact ─────
        else if (isTablet) ...[
          Row(children: [
            Expanded(child: _filterField('Tanggal Mulai', InkWell(
                onTap: _selectStartDate,
                child: _datePickerBox(_startDate != null ? _fmtDate(_startDate!) : 'Pilih tanggal')))),
            const SizedBox(width: 10),
            Expanded(child: _filterField('Tanggal Selesai', InkWell(
                onTap: _selectEndDate,
                child: _datePickerBox(_endDate != null ? _fmtDate(_endDate!) : 'Pilih tanggal')))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _filterField('Barang', _dropdownBox(
              value: _selectedMaterialId, hint: 'Semua Barang',
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Barang', style: TextStyle(fontSize: 13))),
                ..._materials.map((m) => DropdownMenuItem(value: m.idM.toString(),
                    child: Text(m.namaM, style: const TextStyle(fontSize: 13)))),
              ],
              onChanged: (v) { setState(() { _selectedMaterialId = v; _currentPage = 1; }); _loadTransactions(); },
            ))),
            const SizedBox(width: 10),
            Expanded(child: _filterField('Jenis Transaksi', _dropdownBox(
              value: _selectedTransactionType, hint: 'Semua Jenis',
              items: List.generate(_transactionTypes.length, (i) => DropdownMenuItem(
                  value: _transactionTypes[i],
                  child: Text(_transactionTypeLabels[i], style: const TextStyle(fontSize: 13)))),
              onChanged: (v) { setState(() { _selectedTransactionType = v; _currentPage = 1; }); _loadTransactions(); },
            ))),
          ]),
        ]

        // ─ Desktop: 4 kolom sejajar ─────────────────────────────────────────
        else
          Row(children: [
            Expanded(child: _filterField('Tanggal Mulai', InkWell(
                onTap: _selectStartDate,
                child: _datePickerBox(_startDate != null ? _fmtDate(_startDate!) : 'Pilih tanggal')))),
            const SizedBox(width: 12),
            Expanded(child: _filterField('Tanggal Selesai', InkWell(
                onTap: _selectEndDate,
                child: _datePickerBox(_endDate != null ? _fmtDate(_endDate!) : 'Pilih tanggal')))),
            const SizedBox(width: 12),
            Expanded(child: _filterField('Barang', _dropdownBox(
              value: _selectedMaterialId, hint: 'Semua Barang',
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Barang', style: TextStyle(fontSize: 13))),
                ..._materials.map((m) => DropdownMenuItem(value: m.idM.toString(),
                    child: Text(m.namaM, style: const TextStyle(fontSize: 13)))),
              ],
              onChanged: (v) { setState(() { _selectedMaterialId = v; _currentPage = 1; }); _loadTransactions(); },
            ))),
            const SizedBox(width: 12),
            Expanded(child: _filterField('Jenis Transaksi', _dropdownBox(
              value: _selectedTransactionType, hint: 'Semua Jenis',
              items: List.generate(_transactionTypes.length, (i) => DropdownMenuItem(
                  value: _transactionTypes[i],
                  child: Text(_transactionTypeLabels[i], style: const TextStyle(fontSize: 13)))),
              onChanged: (v) { setState(() { _selectedTransactionType = v; _currentPage = 1; }); _loadTransactions(); },
            ))),
          ]),
      ]),
    );
  }

  Widget _filterField(String label, Widget child) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700])),
        const SizedBox(height: 5),
        child,
      ]);

  Widget _datePickerBox(String text, {bool isMobile = false}) => Container(
    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 9 : 10),
    decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50]),
    child: Row(children: [
      Icon(Icons.calendar_today, size: 13, color: Colors.grey[500]),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey[700]),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _dropdownBox<T>({
    required T? value, required String hint,
    required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged,
    bool isMobile = false,
  }) => Container(
    padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
    decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50]),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint, style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey[400])),
        isExpanded: true, isDense: true,
        icon: const Icon(Icons.arrow_drop_down, size: 20),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  // ── Summary cards ──────────────────────────────────────────────────────────
  Widget _buildSummaryCards(BuildContext context) {
    final isMobile = _isMobile(context);
    final countIn  = _transactions.where((t) => t.transactionType == 'in').length;
    final countOut = _transactions.where((t) => t.transactionType == 'out').length;
    final countAdj = _transactions.where((t) => t.transactionType == 'adjustment').length;

    // Mobile: 2×2 grid
    if (isMobile) {
      return Column(children: [
        Row(children: [
          _summaryCard('Masuk',   countIn,              Icons.trending_up_rounded,   Colors.green, isMobile: true),
          const SizedBox(width: 10),
          _summaryCard('Keluar',  countOut,             Icons.trending_down_rounded, _primary,     isMobile: true),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _summaryCard('Penyesuaian', countAdj,         Icons.tune,                 Colors.orange, isMobile: true),
          const SizedBox(width: 10),
          _summaryCard('Total',       _transactions.length, Icons.list_alt,         Colors.blue,   isMobile: true),
        ]),
      ]);
    }

    // Tablet / Desktop: 4 kolom
    return Row(children: [
      _summaryCard('Transaksi Masuk',  countIn,              Icons.trending_up_rounded,   Colors.green),
      const SizedBox(width: 12),
      _summaryCard('Transaksi Keluar', countOut,             Icons.trending_down_rounded, _primary),
      const SizedBox(width: 12),
      _summaryCard('Penyesuaian',      countAdj,             Icons.tune,                 Colors.orange),
      const SizedBox(width: 12),
      _summaryCard('Total Transaksi',  _transactions.length, Icons.list_alt,             Colors.blue),
    ]);
  }

  Widget _summaryCard(String label, int count, IconData icon, Color color,
      {bool isMobile = false}) =>
      Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16, vertical: isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: isMobile ? 16 : 18),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$count',
                  style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: TextStyle(fontSize: isMobile ? 10 : 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
      );

  // ── Table card ─────────────────────────────────────────────────────────────
  Widget _buildTableCard(BuildContext context) {
    final isMobile = _isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.04),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: Row(children: [
            const Icon(Icons.format_list_bulleted, color: _primary, size: 18),
            const SizedBox(width: 8),
            Text('Data Transaksi Barang',
                style: TextStyle(fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.bold, color: _primary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(20)),
              child: Text('${_transactions.length} transaksi',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // Toolbar: show entries + search
        Padding(
          padding: EdgeInsets.fromLTRB(isMobile ? 14 : 20, 12, isMobile ? 14 : 20, 8),
          child: isMobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Search full width on mobile
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari transaksi...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _primary, width: 1.5)),
                      filled: true, fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Show entries row
                  Row(children: [
                    Text('Tampil', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    _entriesDropdown(),
                    const SizedBox(width: 6),
                    Text('data', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
                ])
              : Row(children: [
                  Text('Show', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  _entriesDropdown(),
                  const SizedBox(width: 8),
                  Text('Entries', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const Spacer(),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search :',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _primary, width: 1.5)),
                        filled: true, fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                ]),
        ),

        // Content
        if (_isLoading)
          const Padding(padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: _primary)))
        else if (_filteredTransactions.isEmpty)
          Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Column(children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Tidak ada data transaksi', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ])))
        else if (isMobile)
          _buildMobileTransactionList()
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
                scrollDirection: Axis.vertical, child: _buildFullWidthTable()),
          ),

        if (!_isLoading && _filteredTransactions.isNotEmpty)
          _buildPagination(context),
      ]),
    );
  }

  Widget _entriesDropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _itemsPerPage, isDense: true,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        items: [5, 10, 25, 50].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
        onChanged: (v) { if (v != null) setState(() { _itemsPerPage = v; _currentPage = 1; }); },
      ),
    ),
  );

  // ── Mobile: card list (menggantikan tabel horizontal) ──────────────────────
  Widget _buildMobileTransactionList() {
    final rows       = _pagedTransactions;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    return Column(
      children: rows.asMap().entries.map((entry) {
        final li = entry.key;
        final gi = startIndex + li;
        final t  = entry.value;
        final tc = _getTransactionTypeColor(t.transactionType);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0,1))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Card header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tc.withOpacity(0.06),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              ),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                  child: Text('${gi+1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(t.transactionCode,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: tc.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(_getTransactionTypeLabel(t.transactionType),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tc)),
                ),
              ]),
            ),
            // Card body
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _mobileRow(Icons.inventory_2_outlined, 'Barang', t.materialName),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _mobileRowInline(Icons.numbers, 'Jumlah', '${t.jumlah} ${t.satuan}')),
                  Expanded(child: _mobileRowInline(Icons.calendar_today_outlined, 'Tanggal', _formatDateStr(t.transactionDate))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _mobileRowInline(Icons.trending_up, 'Stok Sebelum', '${t.stokSebelum}')),
                  Expanded(child: _mobileRowInline(Icons.trending_flat, 'Stok Sesudah', '${t.stokSesudah}')),
                ]),
                if (t.notes != null && t.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _mobileRow(Icons.notes_outlined, 'Catatan', t.notes!),
                ],
                const SizedBox(height: 8),
                _mobileRow(Icons.person_outline, 'Dibuat oleh', t.createdByName),
              ]),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _mobileRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: Colors.grey[400]),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
    ]);
  }

  Widget _mobileRowInline(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 13, color: Colors.grey[400]),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ]);
  }

  // ── Desktop table ──────────────────────────────────────────────────────────
  Widget _buildFullWidthTable() {
    final rows       = _pagedTransactions;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    const colFlex = [1, 3, 3, 2, 2, 2, 2, 2, 2, 3];
    const headers = ['No','Kode','Barang','Jenis','Jumlah','Stok\nSebelum','Stok\nSesudah','Tanggal','Dibuat Oleh','Catatan'];

    return Column(children: [
      Container(
        color: _primary.withOpacity(0.07),
        child: Row(children: List.generate(headers.length, (i) => Expanded(
          flex: colFlex[i],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(border: Border(left: i == 0 ? BorderSide.none
                : BorderSide(color: Colors.grey.shade200))),
            child: Text(headers[i],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
                textAlign: TextAlign.center),
          ),
        ))),
      ),
      Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
      ...rows.asMap().entries.map((entry) {
        final li = entry.key;
        final gi = startIndex + li;
        final t  = entry.value;
        final tc = _getTransactionTypeColor(t.transactionType);
        return Column(children: [
          Container(
            color: li % 2 == 0 ? Colors.white : const Color(0xFFF9FAFB),
            child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _tCell(flex: colFlex[0], leftBorder: false,
                  child: Text('${gi+1}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
              _tCell(flex: colFlex[1], child: Text(t.transactionCode, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
              _tCell(flex: colFlex[2], child: Text(t.materialName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              _tCell(flex: colFlex[3], child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: tc.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(_getTransactionTypeLabel(t.transactionType),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tc), textAlign: TextAlign.center),
              )),
              _tCell(flex: colFlex[4], child: Text('${t.jumlah} ${t.satuan}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
              _tCell(flex: colFlex[5], child: Text('${t.stokSebelum}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
              _tCell(flex: colFlex[6], child: Text('${t.stokSesudah}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
              _tCell(flex: colFlex[7], child: Text(_formatDateStr(t.transactionDate), style: TextStyle(fontSize: 11, color: Colors.grey[700]))),
              _tCell(flex: colFlex[8], child: Text(t.createdByName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
              _tCell(flex: colFlex[9], child: Text(t.notes ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis, maxLines: 2)),
            ])),
          ),
          Divider(height: 1, thickness: 0.8, color: Colors.grey.shade200),
        ]);
      }).toList(),
    ]);
  }

  Widget _tCell({required int flex, required Widget child, bool leftBorder = true}) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(border: Border(left: leftBorder ? BorderSide(color: Colors.grey.shade200) : BorderSide.none)),
      alignment: Alignment.centerLeft,
      child: child,
    ),
  );

  // ── Pagination ─────────────────────────────────────────────────────────────
  Widget _buildPagination(BuildContext context) {
    final isMobile   = _isMobile(context);
    final start = (_currentPage - 1) * _itemsPerPage + 1;
    final end   = (start + _itemsPerPage - 1).clamp(0, _filteredTransactions.length);

    // Mobile: sederhana (prev/next + info)
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(children: [
          Text('Data $start–$end dari ${_filteredTransactions.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _pageBtn('‹ Prev', _currentPage > 1, () => setState(() => _currentPage--)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(6)),
              child: Text('$_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            _pageBtn('Next ›', _currentPage < _totalPages, () => setState(() => _currentPage++)),
          ]),
        ]),
      );
    }

    // Desktop/Tablet: full pagination
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Text('Showing $start to $end of ${_filteredTransactions.length} entries',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const Spacer(),
        Row(children: [
          _pageBtn('Previous', _currentPage > 1, () => setState(() => _currentPage--)),
          const SizedBox(width: 4),
          ...List.generate(_totalPages, (i) => i + 1).map(_pageNumBtn),
          const SizedBox(width: 4),
          _pageBtn('Next', _currentPage < _totalPages, () => setState(() => _currentPage++)),
        ]),
      ]),
    );
  }

  Widget _pageBtn(String label, bool enabled, VoidCallback onTap) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: enabled ? Colors.grey[800] : Colors.grey[400])),
    ),
  );

  Widget _pageNumBtn(int page) {
    final isActive = page == _currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => setState(() => _currentPage = page),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? _primary : Colors.white,
            border: Border.all(color: isActive ? _primary : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$page', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey[700])),
        ),
      ),
    );
  }

  String _formatDateStr(String dateStr) {
    try { return _fmtDate(DateTime.parse(dateStr)); } catch (_) { return dateStr; }
  }

  String _getTransactionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'in':          return 'Masuk';
      case 'out':         return 'Keluar';
      case 'adjustment':  return 'Penyesuaian';
      default:            return type;
    }
  }

  Color _getTransactionTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'in':          return Colors.green;
      case 'out':         return _primary;
      case 'adjustment':  return Colors.orange;
      default:            return Colors.grey;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}