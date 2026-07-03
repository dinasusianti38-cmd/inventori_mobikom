import 'package:flutter/material.dart';
import '../service/material_service.dart';
import '../models/material_stock_models.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../service/admin_material_export_service.dart';
import '../service/admin_stok_material_service.dart';

class AdminStokMaterial extends StatefulWidget {
  @override
  _AdminStokMaterialState createState() => _AdminStokMaterialState();
}

class _AdminStokMaterialState extends State<AdminStokMaterial> {
  List<MaterialStok> materials = [];
  List<MaterialStok> filteredMaterials = [];
  List<Category> categories = [];
  bool isLoading = true;

  final TextEditingController searchController = TextEditingController();
  String selectedCategory = 'semua kategori';
  String selectedStatus = 'semua status';

  int currentPage = 1;
  int itemsPerPage = 10;
  int totalPages = 1;

  // ScrollController untuk seluruh halaman
  final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadData();
    searchController.addListener(filterMaterials);
  }

  @override
  void dispose() {
    searchController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────
  Future<void> loadData() async {
    setState(() => isLoading = true);
    try {
      final materialsData = await MaterialService.getMaterialStock();
      final categoriesData = await MaterialService.getCategories();
      setState(() {
        materials = materialsData;
        categories = categoriesData;
        filteredMaterials = materials;
        _recalcPages();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _snack('Error: ${e.toString()}', isError: true);
    }
  }

  void filterMaterials() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredMaterials = materials.where((m) {
        final mq = m.namaMaterial.toLowerCase().contains(q) ||
            m.kodeMaterial.toLowerCase().contains(q);
        final mc = selectedCategory == 'semua kategori' ||
            m.kategory.toLowerCase() == selectedCategory.toLowerCase();
        final ms = selectedStatus == 'semua status' ||
            m.status.toLowerCase() == selectedStatus.toLowerCase();
        return mq && mc && ms;
      }).toList();
      currentPage = 1;
      _recalcPages();
    });
  }

  void _recalcPages() {
    totalPages = (filteredMaterials.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
  }

  List<MaterialStok> get _pageItems {
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, filteredMaterials.length);
    return filteredMaterials.sublist(start, end);
  }

  // ── Delete ────────────────────────────────────────────────────
  Future<void> deleteMaterial(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.delete_outline, color: Colors.red[600], size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Konfirmasi Hapus',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin menghapus "$name"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Text(
                'Perhatian: Data stok yang terkait juga akan dihapus.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal',
                style: TextStyle(color: Color(0xFF78B2F5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Row(children: [
          CircularProgressIndicator(color: Color(0xFF78B2F5)),
          SizedBox(width: 20),
          Text('Menghapus Barang...'),
        ]),
      ),
    );

    try {
      final result = await AdminStokService.deleteMaterial(id);
      if (mounted) Navigator.of(context).pop();
      if (result['status'] == 'success') {
        _snack(result['message'] ?? 'Barang berhasil dihapus', isError: false);
        await loadData();
      } else {
        final msg = result['message'] ?? 'Gagal menghapus Barang';
        final isWarn = msg.toLowerCase().contains('sedang digunakan') ||
            msg.toLowerCase().contains('tidak dapat dihapus');
        _snack(msg, isError: true, isWarning: isWarn);
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      _snack('Terjadi kesalahan: ${e.toString()}', isError: true);
    }
  }

  // ── Export PDF ────────────────────────────────────────────────
  Future<void> exportToPDF() async {
    try {
      await initializeDateFormatting('id_ID', null);
      _snack('Mengambil data dan menggenerate PDF...');

      final exportData =
          await AdminMaterialExportService.getMaterialsForExport();
      final List<MaterialExportModel> exportMaterials =
          exportData['materials'];
      final MaterialSummary summary = exportData['summary'];
      final pdf = pw.Document();
      final numFmt = NumberFormat('#,##0', 'id_ID');

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('LAPORAN STOK BARANG',
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text('SISTEM INVENTORY MANAGEMENT',
                          style: pw.TextStyle(fontSize: 16)),
                      pw.Text(
                          'Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now())}',
                          style: pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                          'Waktu: ${DateFormat('HH:mm:ss', 'id_ID').format(DateTime.now())} WIB',
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700)),
                    ]),
              ]),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 20),
          pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1)),
            padding: pw.EdgeInsets.all(12),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RINGKASAN STOK BARANG (Data Real-Time)',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceAround,
                      children: [
                        _pdfStat('Total Barang',
                            summary.totalMaterials.toString(),
                            PdfColors.blue800),
                        _pdfStat('Stok Normal',
                            summary.stokNormal.toString(),
                            PdfColors.green800),
                        _pdfStat('Stok Menipis',
                            summary.stokMenipis.toString(),
                            PdfColors.orange800),
                        _pdfStat('Stok Habis',
                            summary.stokHabis.toString(),
                            PdfColors.red800),
                      ]),
                ]),
          ),
          pw.SizedBox(height: 20),
          pw.Text('DETAIL STOK BARANG',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            cellStyle: pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration:
                pw.BoxDecoration(color: PdfColors.grey300),
            cellPadding: pw.EdgeInsets.all(4),
            headers: [
              'No',
              'Kode',
              'Nama Barang',
              'Kategori',
              'Jumlah',
              'Satuan',
              'Status',
              'Pembaruan'
            ],
            data: exportMaterials.asMap().entries.map((e) {
              final m = e.value;
              final min = m.stokMinimal ?? 10;
              final st = m.jumlah <= 0
                  ? 'stok habis'
                  : m.jumlah <= min
                      ? 'stok menipis'
                      : 'stok normal';
              return [
                (e.key + 1).toString(),
                m.kodeMaterial,
                m.namaMaterial,
                m.kategory,
                numFmt.format(m.jumlah),
                m.satuan,
                st,
                m.lastUpdate,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 30),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Catatan:',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '• Data stok diambil secara real-time dari database',
                          style: pw.TextStyle(fontSize: 8)),
                    ]),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Dicetak pada:',
                          style: pw.TextStyle(fontSize: 9)),
                      pw.Text(
                          DateFormat('dd/MM/yyyy HH:mm:ss', 'id_ID')
                              .format(DateTime.now()),
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 30),
                      pw.Text('Admin Inventory',
                          style: pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 20),
                      pw.Text('(..........................)'),
                    ]),
              ]),
        ],
      ));

      await Printing.layoutPdf(
          onLayout: (fmt) async => pdf.save());
      _snack('Laporan PDF berhasil digenerate', isError: false);
    } catch (e) {
      _snack('Error: ${e.toString()}', isError: true);
    }
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) =>
      pw.Column(children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: pw.FontWeight.bold)),
      ]);

  void _snack(String msg,
      {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    final bg = isError
        ? (isWarning ? Colors.orange[700]! : Colors.red[700]!)
        : const Color(0xFF2E7D32);
    final icon = isError
        ? (isWarning ? Icons.warning_rounded : Icons.error_rounded)
        : Icons.check_circle_rounded;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: bg,
      duration: Duration(seconds: isError ? 5 : 3),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: isError
          ? SnackBarAction(
              label: 'Tutup',
              textColor: Colors.white,
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar())
          : null,
    ));
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF0F5FF),
            Color(0xFFE8F0FB),
            Color(0xFFF5F8FF)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      // ✅ KUNCI: Seluruh halaman bisa di-scroll vertikal
      child: SingleChildScrollView(
        controller: _pageScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            _buildHeader(),
            const SizedBox(height: 16),

            // 2. Filter card
            _buildFilterCard(),
            const SizedBox(height: 16),

            // 4. Tabel (tidak pakai Expanded, tinggi auto)
            _buildTableCard(),
            const SizedBox(height: 16),

            // 5. Pagination di luar card agar ikut scroll
            _buildPagination(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Summary row (chip ringkasan) ──────────────────────────────
  Widget _buildSummaryRow() {
    final total = materials.length;
    final normal =
        materials.where((m) => m.status.toLowerCase() == 'stok normal').length;
    final menipis = materials
        .where((m) => m.status.toLowerCase() == 'stok menipis')
        .length;
    final habis =
        materials.where((m) => m.status.toLowerCase() == 'stok habis').length;

    return Row(
      children: [
        Expanded(child: _summaryChip('Total', total.toString(), const Color(0xFF78B2F5), Icons.inventory_2_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _summaryChip('Normal', normal.toString(), const Color(0xFF16A34A), Icons.check_circle_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _summaryChip('Menipis', menipis.toString(), const Color(0xFFD97706), Icons.warning_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _summaryChip('Habis', habis.toString(), const Color(0xFFDC2626), Icons.cancel_rounded)),
      ],
    );
  }

  Widget _summaryChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF90C8F8), Color(0xFF7ABAFF), Color(0xFF6AABF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF6AADF5).withOpacity(0.35),
              offset: const Offset(0, 6),
              blurRadius: 16),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    offset: const Offset(2, 3),
                    blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.warehouse_rounded,
                color: Color(0xFF78B2F5), size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stok Barang',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 3)
                        ])),
                SizedBox(height: 2),
                Text('Kelola dan pantau stok barang tersedia',
                    style:
                        TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          // Export button
          GestureDetector(
            onTap: exportToPDF,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('Export PDF',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter card ───────────────────────────────────────────────
  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterLabel('Cari Barang'),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari nama atau kode barang...',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.grey[400], size: 18),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 0),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E7EF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E7EF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF78B2F5)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filterLabel('Kategori'),
                    const SizedBox(height: 6),
                    _dropdownBox(
                      value: selectedCategory,
                      items: [
                        const DropdownMenuItem(
                            value: 'semua kategori',
                            child: Text('Semua kategori',
                                style: TextStyle(fontSize: 13))),
                        ...categories.map((c) => DropdownMenuItem(
                            value: c.namaC,
                            child: Text(c.namaC,
                                style:
                                    const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) {
                        setState(() => selectedCategory =
                            v ?? 'semua kategori');
                        filterMaterials();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filterLabel('Status'),
                    const SizedBox(height: 6),
                    _dropdownBox(
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(
                            value: 'semua status',
                            child: Text('Semua status',
                                style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(
                            value: 'stok normal',
                            child: Text('Stok Normal',
                                style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(
                            value: 'stok menipis',
                            child: Text('Stok Menipis',
                                style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(
                            value: 'stok habis',
                            child: Text('Stok Habis',
                                style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (v) {
                        setState(
                            () => selectedStatus = v ?? 'semua status');
                        filterMaterials();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF78B2F5)));

  Widget _dropdownBox({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E7EF)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          iconEnabledColor: const Color(0xFF78B2F5),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF374151)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Table card ────────────────────────────────────────────────
  // ✅ Tidak menggunakan Expanded — tinggi mengikuti konten
  Widget _buildTableCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(children: [
              const Text('Tampilkan ',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: const Color(0xFFE0E7EF)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: itemsPerPage,
                    isDense: true,
                    iconEnabledColor: const Color(0xFF78B2F5),
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)),
                    items: [5, 10, 25, 50]
                        .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.toString())))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          itemsPerPage = v;
                          currentPage = 1;
                          _recalcPages();
                        });
                      }
                    },
                  ),
                ),
              ),
              const Text(' Entries',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280))),
              const Spacer(),
              Text(
                  '${filteredMaterials.length}/${materials.length}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE8EFFE)),

          // ✅ Tabel horizontal scroll tetap, tapi tinggi auto (tidak Expanded)
          isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF78B2F5)),
                  ),
                )
              : filteredMaterials.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text('Tidak ada data',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  : _buildTable(),
        ],
      ),
    );
  }

  Widget _buildTable() {
    // ✅ SingleChildScrollView horizontal untuk tabel lebar
    // Vertikal sudah ditangani oleh page scroll di atas
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 64,
        ),
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(const Color(0xFF78B2F5)),
          headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12),
          dataTextStyle: const TextStyle(
              fontSize: 12, color: Color(0xFF374151)),
          columnSpacing: 14,
          horizontalMargin: 14,
          dividerThickness: 0.5,
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('No')),
            DataColumn(label: Text('Nama Barang')),
            DataColumn(label: Text('Kode')),
            DataColumn(label: Text('Jumlah')),
            DataColumn(label: Text('Kategori')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Diperbarui')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: _pageItems.asMap().entries.map((e) {
            final idx =
                (currentPage - 1) * itemsPerPage + e.key + 1;
            final m = e.value;
            return DataRow(
              color: WidgetStateProperty.resolveWith((states) =>
                  e.key.isEven
                      ? Colors.white
                      : const Color(0xFFF7FAFF)),
              cells: [
                DataCell(Text(idx.toString(),
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF)))),
                DataCell(SizedBox(
                  width: 130,
                  child: Text(m.namaMaterial,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2),
                )),
                DataCell(_codeChip(m.kodeMaterial)),
                DataCell(Text('${m.jumlah} ${m.satuan}')),
                DataCell(SizedBox(
                  width: 90,
                  child: Text(m.kategory,
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(_statusBadge(m.status)),
                DataCell(SizedBox(
                  width: 80,
                  child: Text(m.lastUpdate,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280)),
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(_deleteBtn(m.idM, m.namaMaterial)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _codeChip(String code) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(code,
            style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Color(0xFF4B5563))),
      );

  Widget _statusBadge(String status) {
    Color dot, bg, textColor;
    String label;
    switch (status.toLowerCase()) {
      case 'stok normal':
        dot = const Color(0xFF16A34A);
        bg = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF15803D);
        label = 'Normal';
        break;
      case 'stok menipis':
        dot = const Color(0xFFD97706);
        bg = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFB45309);
        label = 'Menipis';
        break;
      case 'stok habis':
        dot = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFB91C1C);
        label = 'Habis';
        break;
      default:
        dot = Colors.grey;
        bg = const Color(0xFFF3F4F6);
        textColor = Colors.grey;
        label = status;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dot.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor)),
      ]),
    );
  }

  Widget _deleteBtn(int id, String name) => Tooltip(
        message: 'Hapus Barang',
        child: InkWell(
          onTap: () => deleteMaterial(id, name),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFDC2626), size: 16),
          ),
        ),
      );

  // ── Pagination (ikut scroll halaman) ─────────────────────────
  Widget _buildPagination() {
    final start = filteredMaterials.isEmpty
        ? 0
        : (currentPage - 1) * itemsPerPage + 1;
    final end = ((currentPage - 1) * itemsPerPage + _pageItems.length)
        .clamp(0, filteredMaterials.length);

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          // Info teks
          Text(
            'Menampilkan $start–$end dari ${filteredMaterials.length} entri',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 10),
          // Tombol navigasi
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              _pageBtn('‹',
                  enabled: currentPage > 1,
                  onTap: () =>
                      setState(() => currentPage--)),
              ..._pageNumbers(),
              _pageBtn('›',
                  enabled: currentPage < totalPages,
                  onTap: () =>
                      setState(() => currentPage++)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _pageNumbers() {
    final all = <int>[];
    for (var p = 1; p <= totalPages; p++) {
      if (p == 1 ||
          p == totalPages ||
          (p - currentPage).abs() <= 1) all.add(p);
    }
    final widgets = <Widget>[];
    int? prev;
    for (final p in all) {
      if (prev != null && p - prev > 1) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text('…',
              style: TextStyle(color: Color(0xFF9CA3AF))),
        ));
      }
      final active = p == currentPage;
      widgets.add(GestureDetector(
        onTap: () => setState(() => currentPage = p),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [
                        Color(0xFF90C8F8),
                        Color(0xFF6AABF5)
                      ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: active ? null : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active
                    ? const Color(0xFF6AABF5)
                    : const Color(0xFFD1D5DB)),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: const Color(0xFF6AABF5)
                            .withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(p.toString(),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: active
                      ? Colors.white
                      : const Color(0xFF374151))),
        ),
      ));
      prev = p;
    }
    return widgets;
  }

  Widget _pageBtn(String label,
      {required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFFE5E7EB)),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 16,
                color: enabled
                    ? const Color(0xFF374151)
                    : const Color(0xFF9CA3AF))),
      ),
    );
  }
}