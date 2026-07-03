import 'package:flutter/material.dart';
import '../service/admin_assembly_service.dart';
import '../service/admin_assembly_pdf_service.dart';
import 'package:printing/printing.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────
// RESPONSIVE BREAKPOINTS
// ─────────────────────────────────────────────────────────────

const double _kMobileBreakpoint = 700;

bool _isMobile(BuildContext context) =>
    MediaQuery.of(context).size.width < _kMobileBreakpoint;

// ─────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────

const Color _primaryBlue = Color(0xFF3B6FBE);
const Color _primaryBlueDark = Color(0xFF2B52A0);
const Color _surfaceGrey = Color(0xFFF5F7FA);
const Color _borderGrey = Color(0xFFE2E8F0);
const Color _textPrimary = Color(0xFF1A202C);
const Color _textSecondary = Color(0xFF718096);

class AdminAssembly extends StatefulWidget {
  const AdminAssembly({Key? key}) : super(key: key);

  @override
  _AdminAssemblyState createState() => _AdminAssemblyState();
}

class _AdminAssemblyState extends State<AdminAssembly>
    with SingleTickerProviderStateMixin {
  final AdminAssemblyService _assemblyService = AdminAssemblyService();
  final AssemblyPdfService _pdfService = AssemblyPdfService();

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> selectedProductMaterials = [];
  Map<String, dynamic>? selectedProduct;
  Map<String, dynamic>? assemblyStatus;
  bool isLoading = false;
  String searchQuery = '';
  int notificationCount = 0;
  List<Map<String, dynamic>> notificationItems = [];
  Timer? _notificationTimer;

  bool _showMaterialPanel = false;

  late AnimationController _bellController;
  late Animation<double> _bellAnim;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bellAnim = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.elasticIn),
    );
    _loadProducts();
    _checkNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkNotifications();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _bellController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // COMPUTED GETTERS
  // ─────────────────────────────────────────────────────────────

  bool get _hasBlockedItems =>
      notificationItems.any((i) =>
          i['assembly_status'] == 'blocked' ||
          i['assembly_status'] == 'done');

  bool get _isSelectedProductDone {
    if (selectedProduct == null) return false;
    return (selectedProduct!['assembly_status'] ?? '').toString() == 'done';
  }

  bool get _hasZeroStock {
    if (selectedProductMaterials.isEmpty) return false;
    return selectedProductMaterials
        .any((m) => (m['stok_tersedia'] as num? ?? 0).toInt() <= 0);
  }

  bool get _allStockSufficient {
    if (selectedProductMaterials.isEmpty) return false;
    return selectedProductMaterials.every((m) {
      final avail = (m['stok_tersedia'] as num? ?? 0).toInt();
      final req = (m['quantity'] as num? ?? 0).toInt();
      return avail >= req;
    });
  }

  bool get _hasLimitedStock =>
      !_hasZeroStock && !_allStockSufficient && selectedProductMaterials.isNotEmpty;

  /// Menentukan state tombol assembly:
  /// - 'none'    → produk belum dipilih
  /// - 'loading' → masih memuat material
  /// - 'done'    → sudah selesai
  /// - 'blocked' → ada material stok = 0
  /// - 'limited' → stok ada tapi kurang
  /// - 'ok'      → semua stok cukup, siap proses
  String get _assemblyButtonState {
    if (selectedProduct == null) return 'none';
    // Status 'done' bisa diketahui dari selectedProduct tanpa perlu assemblyStatus
    if (_isSelectedProductDone) return 'done';
    // Kalau materialnya belum selesai dimuat, tapi produk sudah dipilih
    // dan assemblyStatus masih null → tampilkan tombol loading
    if (assemblyStatus == null && selectedProductMaterials.isEmpty) return 'loading';
    if (_hasZeroStock) return 'blocked';
    if (_hasLimitedStock) return 'limited';
    return 'ok';
  }

  // ─────────────────────────────────────────────────────────────
  // DATA LOADERS
  // ─────────────────────────────────────────────────────────────

  Future<void> _checkNotifications() async {
    try {
      final result = await _assemblyService.checkNotifications();
      final summary = result['summary'] as Map<String, dynamic>? ?? {};
      final newCount = ((summary['total_pending'] ?? 0) as int) +
          ((summary['total_blocked'] ?? 0) as int);
      List<Map<String, dynamic>> items = [];
      if (result['products'] != null) {
        items = List<Map<String, dynamic>>.from(result['products']);
      }
      if (mounted) {
        setState(() {
          notificationCount = newCount;
          notificationItems = items;
          for (final item in items) {
            final idx = products.indexWhere((p) => p['id_p'] == item['id_p']);
            if (idx >= 0) {
              products[idx] = {
                ...products[idx],
                'assembly_status': item['assembly_status'],
              };
            }
          }
          if (selectedProduct != null) {
            final updated = items.firstWhere(
              (i) => i['id_p'] == selectedProduct!['id_p'],
              orElse: () => {},
            );
            if (updated.isNotEmpty && updated['assembly_status'] != null) {
              selectedProduct = {
                ...selectedProduct!,
                'assembly_status': updated['assembly_status'],
              };
            }
          }
        });
        if (newCount > 0) {
          _bellController.forward().then((_) => _bellController.reverse());
        }
      }
    } catch (e) {
      debugPrint('Notification check failed: $e');
    }
  }

  Future<void> _loadProducts() async {
    setState(() => isLoading = true);
    try {
      final result = await _assemblyService.getProducts();
      setState(() {
        products = _removeDuplicateProducts(result);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackbar('Gagal memuat data produk: $e');
    }
  }

  List<Map<String, dynamic>> _removeDuplicateProducts(
      List<Map<String, dynamic>> list) {
    final Map<int, Map<String, dynamic>> seen = {};
    for (final p in list) {
      seen.putIfAbsent(p['id_p'] as int, () => p);
    }
    return seen.values.toList();
  }

  List<Map<String, dynamic>> _removeDuplicateMaterials(
      List<Map<String, dynamic>> list) {
    final Map<int, Map<String, dynamic>> seen = {};
    for (final m in list) {
      seen.putIfAbsent(m['material_id'] as int, () => m);
    }
    return seen.values.toList();
  }

  Future<void> _loadProductMaterials(int productId) async {
    setState(() => isLoading = true);
    try {
      final materialsResult =
          await _assemblyService.getProductMaterials(productId);
      final statusResult =
          await _assemblyService.checkAssemblyStatus(productId);
      setState(() {
        selectedProductMaterials = _removeDuplicateMaterials(materialsResult);
        assemblyStatus = statusResult;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackbar('Gagal memuat material produk: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // EXPORT PDF
  // ─────────────────────────────────────────────────────────────

  Future<void> _exportReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Membuat PDF laporan...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    try {
      final pdfBytes = await _pdfService.buildReportPdf();
      if (!mounted) return;
      Navigator.of(context).pop();
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Laporan_Assembly_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showErrorSnackbar('Gagal membuat PDF: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SNACKBARS
  // ─────────────────────────────────────────────────────────────

  void _showErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  void _showSuccessSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: Colors.green[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICATION PANEL
  // ─────────────────────────────────────────────────────────────

  void _showNotificationPanel() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 20,
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 520),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _notifHeader(),
              Flexible(
                child: notificationItems.isEmpty
                    ? _buildEmptyNotification()
                    : _buildNotificationContent(),
              ),
              _notifFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notifHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B6FBE), Color(0xFF2B52A0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifikasi Assembly',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  notificationItems.isEmpty
                      ? 'Tidak ada projek'
                      : _buildNotifSubtitle(),
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ]),
      );

  Widget _notifFooter() => Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            'Diperbarui: ${_formatTime(DateTime.now())}',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _checkNotifications();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: _primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Tutup',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ]),
      );

  Widget _buildEmptyNotification() => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline,
                  size: 44, color: Colors.green[400]),
            ),
            const SizedBox(height: 16),
            const Text('Semua beres!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Tidak ada projek yang menunggu untuk di-assembly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );

  Widget _buildNotificationContent() {
    final inProgressItems = notificationItems
        .where((i) => i['assembly_status'] == 'in_progress')
        .toList();
    final doneItems =
        notificationItems.where((i) => i['assembly_status'] == 'done').toList();
    final blockedItems = notificationItems
        .where((i) => i['assembly_status'] == 'blocked')
        .toList();
    final limitedItems = notificationItems
        .where((i) => i['assembly_status'] == 'limited')
        .toList();
    final readyItems = notificationItems
        .where((i) =>
            i['assembly_status'] == 'ready' ||
            (i['assembly_status'] != 'in_progress' &&
                i['assembly_status'] != 'done' &&
                i['assembly_status'] != 'blocked' &&
                i['assembly_status'] != 'limited'))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (readyItems.isNotEmpty)
                _summaryChip(
                    icon: Icons.play_circle_outline,
                    label: '${readyItems.length} Siap',
                    color: Colors.blue[700]!,
                    bg: Colors.blue[50]!),
              if (limitedItems.isNotEmpty)
                _summaryChip(
                    icon: Icons.warning_amber_rounded,
                    label: '${limitedItems.length} Terbatas',
                    color: Colors.orange[700]!,
                    bg: Colors.orange[50]!),
              if (inProgressItems.isNotEmpty)
                _summaryChip(
                    icon: Icons.autorenew,
                    label: '${inProgressItems.length} Berlangsung',
                    color: Colors.blue[700]!,
                    bg: Colors.blue[50]!),
              if (doneItems.isNotEmpty)
                _summaryChip(
                    icon: Icons.check_circle,
                    label: '${doneItems.length} Selesai',
                    color: Colors.green[700]!,
                    bg: Colors.green[50]!),
              if (blockedItems.isNotEmpty)
                _summaryChip(
                    icon: Icons.block,
                    label: '${blockedItems.length} Diblokir',
                    color: Colors.red[700]!,
                    bg: Colors.red[50]!),
            ],
          ),
          const SizedBox(height: 16),
          if (inProgressItems.isNotEmpty) ...[
            _sectionHeader('Sedang Berlangsung', Colors.blue[700]!, Icons.autorenew),
            const SizedBox(height: 8),
            ...inProgressItems.map((i) => _buildNotifItemFromData(i, 'in_progress')),
            const SizedBox(height: 14),
          ],
          if (readyItems.isNotEmpty) ...[
            _sectionHeader(
                'Siap Diproses', Colors.blue[600]!, Icons.play_circle_outline),
            const SizedBox(height: 8),
            ...readyItems.map((i) => _buildNotifItemFromData(i, 'ready')),
            const SizedBox(height: 14),
          ],
          if (limitedItems.isNotEmpty) ...[
            _sectionHeader(
                'Stok Terbatas', Colors.orange[700]!, Icons.warning_amber_rounded),
            const SizedBox(height: 8),
            ...limitedItems.map((i) => _buildNotifItemFromData(i, 'limited')),
            const SizedBox(height: 14),
          ],
          if (doneItems.isNotEmpty) ...[
            _sectionHeader('Sudah Selesai', Colors.green[700]!, Icons.check_circle),
            const SizedBox(height: 8),
            ...doneItems.map((i) => _buildNotifItemFromData(i, 'done')),
            const SizedBox(height: 14),
          ],
          if (blockedItems.isNotEmpty) ...[
            _sectionHeader('Stok Habis', Colors.red[700]!, Icons.block),
            const SizedBox(height: 8),
            ...blockedItems.map((i) => _buildNotifItemFromData(i, 'blocked')),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );

  Widget _sectionHeader(String title, Color color, IconData icon) =>
      Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.3)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withOpacity(0.3), height: 1)),
      ]);

  Widget _buildNotifItemFromData(Map<String, dynamic> item, String status) {
    final name = item['name_p'] ?? item['nama'] ?? '-';
    final code = item['code_p'] ?? item['kode'] ?? '';

    Color borderColor, iconBg, iconColor, badgeBg, badgeText, cardBg;
    String badgeLabel;
    IconData itemIcon;
    Widget? statusIndicator;

    switch (status) {
      case 'in_progress':
        borderColor = Colors.blue[300]!;
        iconBg = Colors.blue[50]!;
        iconColor = Colors.blue[600]!;
        badgeBg = Colors.blue[100]!;
        badgeText = Colors.blue[800]!;
        cardBg = Colors.blue[50]!;
        badgeLabel = 'Berlangsung';
        itemIcon = Icons.autorenew;
        statusIndicator = SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.blue[600]),
        );
        break;
      case 'done':
        borderColor = Colors.green[300]!;
        iconBg = Colors.green[50]!;
        iconColor = Colors.green[600]!;
        badgeBg = Colors.green[100]!;
        badgeText = Colors.green[800]!;
        cardBg = Colors.green[50]!;
        badgeLabel = 'Selesai';
        itemIcon = Icons.check_circle;
        statusIndicator = null;
        break;
      case 'blocked':
        borderColor = Colors.red[200]!;
        iconBg = Colors.red[50]!;
        iconColor = Colors.red[600]!;
        badgeBg = Colors.red[100]!;
        badgeText = Colors.red[800]!;
        cardBg = Colors.red[50]!;
        badgeLabel = 'Stok Habis';
        itemIcon = Icons.block;
        statusIndicator = null;
        break;
      case 'limited':
        borderColor = Colors.orange[200]!;
        iconBg = Colors.orange[50]!;
        iconColor = Colors.orange[600]!;
        badgeBg = Colors.orange[100]!;
        badgeText = Colors.orange[800]!;
        cardBg = Colors.orange[50]!;
        badgeLabel = 'Stok Terbatas';
        itemIcon = Icons.warning_amber_rounded;
        statusIndicator = null;
        break;
      default:
        borderColor = Colors.blue[200]!;
        iconBg = Colors.blue[50]!;
        iconColor = Colors.blue[600]!;
        badgeBg = Colors.blue[100]!;
        badgeText = Colors.blue[800]!;
        cardBg = Colors.white;
        badgeLabel = 'Siap Diproses';
        itemIcon = Icons.play_circle_outline;
        statusIndicator = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(itemIcon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                if (code.isNotEmpty)
                  Text(code,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (statusIndicator != null) ...[
              statusIndicator,
              const SizedBox(width: 5),
            ],
            Text(badgeLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeText)),
          ]),
        ),
      ]),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _buildNotifSubtitle() {
    final inProgress =
        notificationItems.where((i) => i['assembly_status'] == 'in_progress').length;
    final done =
        notificationItems.where((i) => i['assembly_status'] == 'done').length;
    final blocked =
        notificationItems.where((i) => i['assembly_status'] == 'blocked').length;
    final limited =
        notificationItems.where((i) => i['assembly_status'] == 'limited').length;
    final waiting =
        notificationItems.where((i) => i['assembly_status'] == 'ready').length;
    final parts = <String>[];
    if (inProgress > 0) parts.add('$inProgress berlangsung');
    if (waiting > 0) parts.add('$waiting siap diproses');
    if (limited > 0) parts.add('$limited terbatas');
    if (blocked > 0) parts.add('$blocked stok habis');
    if (done > 0) parts.add('$done selesai');
    return parts.isNotEmpty
        ? parts.join(' · ')
        : '${notificationItems.length} projek';
  }

  // ─────────────────────────────────────────────────────────────
  // ASSEMBLY DIALOG & PROCESS
  // ─────────────────────────────────────────────────────────────

  void _showAssemblyDialog() {
    if (selectedProduct == null) return;
    if (_isSelectedProductDone) {
      _showDoneBlockedDialog();
      return;
    }
    if (_hasZeroStock) {
      _showBlockedDialog();
      return;
    }

    final quantityController = TextEditingController(text: '1');
    final hasLimitedStock = _hasLimitedStock;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasLimitedStock
                        ? [Colors.orange[700]!, Colors.orange[500]!]
                        : [_primaryBlue, _primaryBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: Icon(
                        hasLimitedStock
                            ? Icons.warning_amber_rounded
                            : Icons.build_circle,
                        color: Colors.white,
                        size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLimitedStock
                              ? 'Proses Assembly (Stok Terbatas)'
                              : 'Proses Assembly',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(selectedProduct!['name_p'] ?? '',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child:
                          const Icon(Icons.close, color: Colors.white, size: 15),
                    ),
                  ),
                ]),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: _primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.inventory_2,
                                color: _primaryBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selectedProduct!['name_p'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(
                                    'Kode: ${selectedProduct!['code_p'] ?? '-'}',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      Row(children: [
                        Icon(Icons.list_alt,
                            size: 16,
                            color: hasLimitedStock
                                ? Colors.orange[700]
                                : _primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          'Material yang dibutuhkan'
                          ' (${selectedProductMaterials.length} item):',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: hasLimitedStock
                                  ? Colors.orange[800]
                                  : _textPrimary),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      ...selectedProductMaterials.map((mat) {
                        final avail =
                            (mat['stok_tersedia'] as num? ?? 0).toInt();
                        final req = (mat['quantity'] as num? ?? 0).toInt();
                        final isOk = avail >= req;
                        final isLimited = avail > 0 && avail < req;

                        Color rowColor = isOk
                            ? Colors.green[50]!
                            : isLimited
                                ? Colors.orange[50]!
                                : Colors.red[50]!;
                        Color borderC = isOk
                            ? Colors.green[200]!
                            : isLimited
                                ? Colors.orange[200]!
                                : Colors.red[200]!;
                        Color textC = isOk
                            ? Colors.green[800]!
                            : isLimited
                                ? Colors.orange[800]!
                                : Colors.red[800]!;
                        IconData statusIc = isOk
                            ? Icons.check_circle
                            : isLimited
                                ? Icons.warning_amber_rounded
                                : Icons.block;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: rowColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderC),
                          ),
                          child: Row(children: [
                            Icon(statusIc, size: 18, color: textC),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mat['nama_m'] ?? '-',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary)),
                                  Text('Kode: ${mat['code_m'] ?? '-'}',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Butuh: $req',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700])),
                                Text('Stok: $avail',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textC)),
                              ],
                            ),
                          ]),
                        );
                      }),

                      if (hasLimitedStock) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 18, color: Colors.orange[800]),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Beberapa material stok tidak mencukupi. '
                                    'Assembly tetap akan diproses menggunakan stok yang tersedia.',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.orange[800]),
                                  ),
                                ),
                              ]),
                        ),
                      ],
                      const SizedBox(height: 16),

                      const Text('Jumlah Unit',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Masukkan jumlah unit',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: _primaryBlue, width: 2)),
                          prefixIcon: const Icon(Icons.format_list_numbered,
                              color: _primaryBlue),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Setelah assembly selesai, projek ini tidak dapat diproses ulang.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.blue[700]),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border:
                      Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final quantity =
                            int.tryParse(quantityController.text);
                        if (quantity == null || quantity <= 0) {
                          Navigator.of(context).pop();
                          _showErrorSnackbar(
                              'Jumlah tidak valid. Masukkan angka lebih dari 0.');
                          return;
                        }
                        Navigator.of(context).pop();
                        await _processAssembly(quantity);
                      },
                      icon: Icon(
                          hasLimitedStock
                              ? Icons.warning_amber_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20),
                      label: Text(
                          hasLimitedStock
                              ? 'Proses (Stok Terbatas)'
                              : 'Mulai Proses',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasLimitedStock
                            ? Colors.orange[700]
                            : _primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDoneBlockedDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 420,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), color: Colors.white),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF276749), Color(0xFF38A169)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child:
                      const Icon(Icons.check_circle, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Projek Sudah Selesai',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(selectedProduct?['name_p'] ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 15),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.green[700], size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Projek "${selectedProduct?['name_p'] ?? ''}" sudah pernah di-assembly dan telah selesai.\n\n'
                          'Assembly tidak dapat diproses ulang untuk projek yang sama.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.green[800]),
                        ),
                      ),
                    ]),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Mengerti',
                      style:
                          TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showBlockedDialog() {
    final zeroMaterials = selectedProductMaterials
        .where((m) => (m['stok_tersedia'] ?? 0) <= 0)
        .toList();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), color: Colors.white),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFE53E3E), Color(0xFFC53030)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child:
                      const Icon(Icons.block, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assembly Diblokir',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text('Stok material telah habis (0)',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[700], size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Proses assembly tidak dapat dilanjutkan karena '
                                'satu atau lebih material memiliki stok 0 (habis). '
                                'Tambahkan stok material terlebih dahulu.',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.red[800]),
                              ),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(Icons.inventory_2,
                          size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Material dengan stok habis (${zeroMaterials.length}):',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    ...zeroMaterials.map((mat) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red[100]!),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.red.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  shape: BoxShape.circle),
                              child: Icon(Icons.remove_circle,
                                  color: Colors.red[500], size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(mat['nama_m'] ?? '-',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary)),
                                  Text('Kode: ${mat['code_m'] ?? '-'}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.red[600],
                                  borderRadius:
                                      BorderRadius.circular(20)),
                              child: const Text('Stok: 0',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        )),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(children: [
                Icon(Icons.tips_and_updates,
                    size: 16, color: Colors.blue[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Tip: Tambah stok material via menu Inventory.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[600])),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Mengerti',
                      style:
                          TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _processAssembly(int quantity) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1), blurRadius: 20)
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: _primaryBlue),
              ),
              const SizedBox(height: 20),
              const Text('Memproses Assembly...',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary)),
              const SizedBox(height: 6),
              Text('Harap tunggu sebentar',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
          ),
        ),
      ),
    );

    try {
      _updateNotifItemStatus(selectedProduct!['id_p'], 'in_progress');
      final result = await _assemblyService.processAssembly(
          selectedProduct!['id_p'], quantity);
      if (!mounted) return;
      Navigator.of(context).pop();

      if (result['result_type'] == 'blocked') {
        await _checkNotifications();
        _showBlockedDialog();
        return;
      }

      if (result['data'] != null &&
          result['data']['assembly_now_done'] == true) {
        _updateNotifItemStatus(selectedProduct!['id_p'], 'done');
        setState(() {
          selectedProduct = {
            ...selectedProduct!,
            'assembly_status': 'done',
          };
        });
      }

      await _checkNotifications();

      final isWarning = result['result_type'] == 'warning';
      final warningMaterials = isWarning
          ? List<Map<String, dynamic>>.from(
              result['data']['warning_materials'] ?? [])
          : <Map<String, dynamic>>[];
      final consumedMaterials = List<Map<String, dynamic>>.from(
          result['data']['consumed_materials'] ?? []);

      _showResultDialog(
        isWarning: isWarning,
        quantity: quantity,
        warningMaterials: warningMaterials,
        consumedMaterials: consumedMaterials,
        message: result['message'] ?? '',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await _checkNotifications();
      _showErrorSnackbar('Gagal memproses assembly: $e');
    }
  }

  void _updateNotifItemStatus(int productId, String status) {
    if (!mounted) return;
    setState(() {
      final idx = notificationItems.indexWhere((item) =>
          item['id_p'] == productId || item['product_id'] == productId);
      if (idx >= 0) {
        notificationItems[idx] = {
          ...notificationItems[idx],
          'assembly_status': status,
        };
      }
      final pidx = products.indexWhere((p) => p['id_p'] == productId);
      if (pidx >= 0) {
        products[pidx] = {
          ...products[pidx],
          'assembly_status': status,
        };
      }
    });
  }

  void _showResultDialog({
    required bool isWarning,
    required int quantity,
    required List<Map<String, dynamic>> warningMaterials,
    required List<Map<String, dynamic>> consumedMaterials,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), color: Colors.white),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWarning
                      ? [Colors.orange[700]!, Colors.orange[500]!]
                      : [Colors.green[600]!, Colors.green[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(
                      isWarning
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          isWarning
                              ? 'Assembly Selesai (Stok Terbatas)'
                              : 'Assembly Berhasil!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(selectedProduct!['name_p'] ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isWarning
                            ? Colors.orange[50]
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isWarning
                                ? Colors.orange[200]!
                                : Colors.green[200]!),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: _resultStat(
                              'Produk',
                              selectedProduct!['name_p'] ?? '',
                              Icons.inventory_2,
                              isWarning
                                  ? Colors.orange[700]!
                                  : Colors.green[700]!),
                        ),
                        Container(
                            width: 1,
                            height: 40,
                            color: isWarning
                                ? Colors.orange[200]
                                : Colors.green[200]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _resultStat(
                              'Jumlah',
                              '$quantity unit',
                              Icons.production_quantity_limits,
                              isWarning
                                  ? Colors.orange[700]!
                                  : Colors.green[700]!),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (consumedMaterials.isNotEmpty) ...[
                      Row(children: [
                        Icon(Icons.checklist,
                            size: 16,
                            color: isWarning
                                ? Colors.orange[700]
                                : Colors.green[700]),
                        const SizedBox(width: 8),
                        Text('Material yang digunakan:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isWarning
                                    ? Colors.orange[800]
                                    : Colors.green[800])),
                      ]),
                      const SizedBox(height: 10),
                      ...consumedMaterials.map((mat) {
                        final dikurangi = mat['dikurangi'] ?? 0;
                        final sesudah = mat['sesudah'] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(children: [
                            Icon(Icons.remove_circle_outline,
                                size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(mat['nama'] ?? '-',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                            ),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text('-$dikurangi unit',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[600])),
                                Text('Sisa: $sesudah',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500])),
                              ],
                            ),
                          ]),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                    if (isWarning && warningMaterials.isNotEmpty) ...[
                      Row(children: [
                        Icon(Icons.error_outline,
                            size: 16, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text('Material dengan stok tidak mencukupi:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[800])),
                      ]),
                      const SizedBox(height: 10),
                      ...warningMaterials.map((mat) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(children: [
                              Icon(Icons.remove_circle,
                                  color: Colors.red[400], size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(mat['nama'] ?? '-',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      'Butuh: ${mat['dibutuhkan']}  •  '
                                      'Tersedia: ${mat['tersedia']}  •  '
                                      'Kurang: ${mat['kurang']}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red[700]),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                          )),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.lock, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Projek ini telah ditandai selesai dan tidak dapat diproses ulang.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue[700]),
                          ),
                        ),
                      ]),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(message,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _loadProductMaterials(selectedProduct!['id_p']);
                        _checkNotifications();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isWarning ? Colors.orange[700] : _primaryBlue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Selesai',
                          style: TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _resultStat(String label, String value, IconData icon, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ]),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]);

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get filteredProducts {
    if (searchQuery.isEmpty) return products;
    final q = searchQuery.toLowerCase();
    return products.where((p) {
      final name = (p['name_p'] ?? '').toString().toLowerCase();
      final code = (p['code_p'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  Color _getStockColor(int available, int required) {
    if (available <= 0) return Colors.red[700]!;
    if (available < required) return Colors.orange[700]!;
    return Colors.green[600]!;
  }

  IconData _getStockIcon(int available, int required) {
    if (available <= 0) return Icons.block;
    if (available < required) return Icons.warning_amber_rounded;
    return Icons.check_circle;
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD ENTRY POINT
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceGrey,
      body:
          _isMobile(context) ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDesktopHeader(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: _buildProductListPanel(),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildMaterialsPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child:
              const Icon(Icons.build_circle, color: _primaryBlue, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Assembly Barang',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
                letterSpacing: -0.3),
          ),
          Text('Manajemen proses perakitan produk',
              style: TextStyle(fontSize: 12, color: _textSecondary)),
        ]),
        const Spacer(),
        _buildBellButton(),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _exportReport,
          icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
          label: const Text('Export Laporan',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMobileLayout() {
    return Column(children: [
      _buildMobileAppBar(),
      Expanded(
        child: _showMaterialPanel && selectedProduct != null
            ? _buildMobileMaterialView()
            : _buildMobileProductView(),
      ),
    ]);
  }

  Widget _buildMobileAppBar() {
    final showBack = _showMaterialPanel && selectedProduct != null;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 4,
        right: 12,
        bottom: 8,
      ),
      child: Row(children: [
        if (showBack)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 20, color: _primaryBlue),
            onPressed: () => setState(() => _showMaterialPanel = false),
          )
        else
          const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showBack
                      ? (selectedProduct!['name_p'] ?? 'Detail Material')
                      : 'Assembly Barang',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue),
                ),
                if (!showBack)
                  Text('Pilih projek untuk memulai',
                      style:
                          TextStyle(fontSize: 11, color: _textSecondary)),
              ]),
        ),
        _buildBellButton(),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _exportReport,
          icon: const Icon(Icons.picture_as_pdf,
              color: _primaryBlue, size: 22),
          tooltip: 'Export Laporan',
        ),
      ]),
    );
  }

  Widget _buildMobileProductView() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: _buildSearchBar(),
      ),
      Expanded(child: _buildMobileProductList()),
    ]);
  }

  Widget _buildMobileProductList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              searchQuery.isEmpty ? 'Belum ada projek' : 'Tidak ditemukan',
              style: TextStyle(color: _textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: filteredProducts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final product = filteredProducts[i];
        final isSelected = selectedProduct != null &&
            selectedProduct!['id_p'] == product['id_p'];
        final isDone =
            (product['assembly_status'] ?? '').toString() == 'done';

        return GestureDetector(
          onTap: () async {
            setState(() {
              selectedProduct = product;
              selectedProductMaterials.clear();
              assemblyStatus = null;
              _showMaterialPanel = true;
            });
            await _loadProductMaterials(product['id_p']);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.green[50]
                  : isSelected
                      ? _primaryBlue.withOpacity(0.06)
                      : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDone
                    ? Colors.green[300]!
                    : isSelected
                        ? _primaryBlue
                        : _borderGrey,
                width: isSelected || isDone ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              _buildProductStatusDot(product),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['name_p'] ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDone ? Colors.green[800] : _textPrimary)),
                    const SizedBox(height: 2),
                    Text('Kode: ${product['code_p'] ?? '-'}',
                        style:
                            TextStyle(fontSize: 12, color: _textSecondary)),
                    if (product['total_materials'] != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: isDone
                                ? Colors.green[100]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          '${product['total_materials']} material',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDone
                                  ? Colors.green[700]
                                  : Colors.blue[700],
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('SELESAI',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                )
              else
                const Icon(Icons.chevron_right,
                    color: _textSecondary, size: 20),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMobileMaterialView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      child: Column(children: [
        // ── Tombol assembly selalu tampil jika produk sudah dipilih ──
        _buildAssemblyActionButton(),
        const SizedBox(height: 12),
        if (assemblyStatus != null) _buildStatusCard(),
        const SizedBox(height: 12),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: CircularProgressIndicator(),
          )
        else if (selectedProductMaterials.isEmpty)
          _emptyMaterialsView()
        else
          ..._buildMaterialCards(),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOMBOL ASSEMBLY — BARU: selalu tampil, warna berubah sesuai state
  //
  // State  │ Warna   │ Teks
  // ────────┼─────────┼──────────────────────────────────────────
  // ok      │ Biru    │ "Proses Assembly"
  // limited │ Orange  │ "Proses (Stok Terbatas)"
  // done    │ Biru*   │ "Sudah Selesai" (*disabled, abu muda)
  // blocked │ Merah   │ "Tidak Dapat Diproses (Stok Habis)"
  // loading │ Abu-abu │ skeleton / shimmer
  // ─────────────────────────────────────────────────────────────
  Widget _buildAssemblyActionButton() {
    final state = _assemblyButtonState;

    // Belum ada produk dipilih → tidak tampil
    if (state == 'none') return const SizedBox.shrink();

    // Sedang loading material
    if (state == 'loading') {
      return Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.grey[500]),
            ),
            const SizedBox(width: 10),
            Text('Memuat status...',
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
      );
    }

    Color btnColor;
    Color btnShadowColor;
    IconData btnIcon;
    String btnLabel;
    bool isDisabled;

    switch (state) {
      case 'done':
        // Biru muda / disabled — sudah selesai
        btnColor = _primaryBlue.withOpacity(0.55);
        btnShadowColor = _primaryBlue.withOpacity(0.2);
        btnIcon = Icons.check_circle_outline;
        btnLabel = 'Sudah Selesai';
        isDisabled = true;
        break;
      case 'blocked':
        // Merah — stok habis
        btnColor = const Color(0xFFE53E3E);
        btnShadowColor = const Color(0xFFE53E3E).withOpacity(0.3);
        btnIcon = Icons.block_rounded;
        btnLabel = 'Tidak Dapat Diproses (Stok Habis)';
        isDisabled = false; // masih bisa tap untuk lihat detail
        break;
      case 'limited':
        // Orange — stok terbatas
        btnColor = Colors.orange[700]!;
        btnShadowColor = Colors.orange.withOpacity(0.3);
        btnIcon = Icons.warning_amber_rounded;
        btnLabel = 'Proses (Stok Terbatas)';
        isDisabled = false;
        break;
      default: // 'ok'
        // Biru penuh — siap diproses
        btnColor = _primaryBlue;
        btnShadowColor = _primaryBlue.withOpacity(0.35);
        btnIcon = Icons.play_arrow_rounded;
        btnLabel = 'Proses Assembly';
        isDisabled = false;
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : _showAssemblyDialog,
        icon: Icon(btnIcon, color: Colors.white, size: 20),
        label: Text(
          btnLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey[350] : btnColor,
          disabledBackgroundColor: btnColor, // tetap warna biru muda
          disabledForegroundColor: Colors.white,
          elevation: isDisabled ? 0 : 2,
          shadowColor: btnShadowColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMaterialCards() {
    return selectedProductMaterials.asMap().entries.map((entry) {
      final idx = entry.key;
      final material = entry.value;
      final available =
          (material['stok_tersedia'] as num? ?? 0).toInt();
      final required = (material['quantity'] as num? ?? 0).toInt();
      final stockColor = _getStockColor(available, required);
      final stockIcon = _getStockIcon(available, required);
      final isZero = available <= 0;

      return Container(
        key: ValueKey('mmat_${material['material_id']}_$idx'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isZero ? Colors.red[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: stockColor.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(stockIcon, color: stockColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(material['nama_m'] ?? '-',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _textPrimary)),
                ),
                if (isZero)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('HABIS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text('Kode: ${material['code_m'] ?? '-'}',
                  style: TextStyle(fontSize: 11, color: _textSecondary)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _stockInfoBox(
                      label: 'Dibutuhkan',
                      value: '$required',
                      color: _textPrimary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _stockInfoBox(
                      label: 'Tersedia',
                      value: '$available',
                      color: stockColor),
                ),
              ]),
              if (material['notes'] != null &&
                  material['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!)),
                  child: Row(children: [
                    Icon(Icons.note, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(material['notes'].toString(),
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue[700])),
                    ),
                  ]),
                ),
              ],
            ]),
      );
    }).toList();
  }

  Widget _stockInfoBox({
    required String label,
    required String value,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: _surfaceGrey, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ]),
      );

  Widget _emptyMaterialsView() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada material untuk projek ini',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildBellButton() {
    return Tooltip(
      message: _hasBlockedItems
          ? 'Ada stok habis!'
          : notificationCount > 0
              ? '$notificationCount projek menunggu'
              : 'Semua beres',
      child: GestureDetector(
        onTap: _showNotificationPanel,
        child: AnimatedBuilder(
          animation: _bellAnim,
          builder: (_, child) =>
              Transform.rotate(angle: _bellAnim.value, child: child),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _hasBlockedItems
                      ? Colors.red[50]
                      : notificationCount > 0
                          ? Colors.orange[50]
                          : Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hasBlockedItems
                        ? Colors.red[300]!
                        : notificationCount > 0
                            ? Colors.orange[300]!
                            : Colors.grey[300]!,
                  ),
                ),
                child: Icon(
                  notificationItems.isNotEmpty
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  size: 21,
                  color: _hasBlockedItems
                      ? Colors.red[700]
                      : notificationCount > 0
                          ? Colors.orange[700]
                          : Colors.grey[600],
                ),
              ),
              if (notificationItems.isNotEmpty)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: _hasBlockedItems
                          ? Colors.red[600]
                          : Colors.orange[600],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_hasBlockedItems
                                  ? Colors.red[600]!
                                  : Colors.orange[600]!)
                              .withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      _hasBlockedItems ? '!' : '$notificationCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderGrey),
      ),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Cari projek...',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
          border: InputBorder.none,
          prefixIcon:
              const Icon(Icons.search, color: _textSecondary, size: 20),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: _textSecondary, size: 18),
                  onPressed: () => setState(() => searchQuery = ''),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DESKTOP: PRODUCT LIST PANEL
  // ─────────────────────────────────────────────────────────────

  Widget _buildProductListPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            const Text('Daftar Projek',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${filteredProducts.length}',
                style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: _borderGrey),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredProducts.isEmpty
                  ? _emptyProductsView()
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final product = filteredProducts[i];
                        final isSelected = selectedProduct != null &&
                            selectedProduct!['id_p'] == product['id_p'];
                        final isDone =
                            (product['assembly_status'] ?? '').toString() ==
                                'done';

                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              selectedProduct = product;
                              selectedProductMaterials.clear();
                              assemblyStatus = null;
                            });
                            _loadProductMaterials(product['id_p']);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? Colors.green[50]
                                  : isSelected
                                      ? _primaryBlue.withOpacity(0.07)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDone
                                    ? Colors.green[300]!
                                    : isSelected
                                        ? _primaryBlue
                                        : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(children: [
                              _buildProductStatusDot(product),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(product['name_p'] ?? '',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: isDone
                                                ? Colors.green[800]
                                                : isSelected
                                                    ? _primaryBlue
                                                    : _textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(product['code_p'] ?? '-',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: _textSecondary)),
                                  ],
                                ),
                              ),
                              if (isDone)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.green[600],
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  child: const Text('SELESAI',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                )
                              else if (isSelected)
                                const Icon(Icons.chevron_right,
                                    color: _primaryBlue, size: 18),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _emptyProductsView() => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 52, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                searchQuery.isEmpty
                    ? 'Belum ada projek'
                    : 'Tidak ditemukan',
                style: TextStyle(color: _textSecondary, fontSize: 14),
              ),
            ]),
      );

  // ─────────────────────────────────────────────────────────────
  // DESKTOP: MATERIALS PANEL
  // ─────────────────────────────────────────────────────────────

  Widget _buildMaterialsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // ── Header panel: nama produk + tombol assembly ──────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(children: [
            const Icon(Icons.inventory_2, color: _primaryBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedProduct != null
                    ? selectedProduct!['name_p'] ?? 'Material'
                    : 'Pilih projek terlebih dahulu',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ── FIX UTAMA: tombol SELALU tampil jika ada produk dipilih ──
            // Tidak lagi bergantung pada assemblyStatus != null
            if (selectedProduct != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildDesktopAssemblyButton(),
              ),
          ]),
        ),
        const Divider(height: 1, color: _borderGrey),
        Expanded(
          child: selectedProduct == null
              ? _buildNoSelectionView()
              : isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : selectedProductMaterials.isEmpty
                      ? _emptyMaterialsView()
                      : _buildMaterialsList(),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOMBOL ASSEMBLY VERSI DESKTOP (lebih kompak, di header panel)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDesktopAssemblyButton() {
    final state = _assemblyButtonState;

    // Sedang loading
    if (state == 'loading' || state == 'none') {
      return SizedBox(
        height: 38,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.grey[400]),
          ),
          label: const Text('Memuat...'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            disabledBackgroundColor: Colors.grey[200],
            disabledForegroundColor: Colors.grey[500],
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9)),
            elevation: 0,
          ),
        ),
      );
    }

    Color btnColor;
    IconData btnIcon;
    String btnLabel;
    bool isDisabled;

    switch (state) {
      case 'done':
        btnColor = _primaryBlue.withOpacity(0.55);
        btnIcon = Icons.check_circle_outline;
        btnLabel = 'Sudah Selesai';
        isDisabled = true;
        break;
      case 'blocked':
        btnColor = const Color(0xFFE53E3E);
        btnIcon = Icons.block_rounded;
        btnLabel = 'Stok Habis';
        isDisabled = false;
        break;
      case 'limited':
        btnColor = Colors.orange[700]!;
        btnIcon = Icons.warning_amber_rounded;
        btnLabel = 'Proses (Terbatas)';
        isDisabled = false;
        break;
      default: // ok
        btnColor = _primaryBlue;
        btnIcon = Icons.play_arrow_rounded;
        btnLabel = 'Proses Assembly';
        isDisabled = false;
    }

    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : _showAssemblyDialog,
        icon: Icon(btnIcon, color: Colors.white, size: 17),
        label: Text(btnLabel,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey[350] : btnColor,
          disabledBackgroundColor: btnColor,
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9)),
          elevation: isDisabled ? 0 : 1,
        ),
      ),
    );
  }

  Widget _buildNoSelectionView() => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Pilih projek dari daftar\nuntuk melihat material yang dibutuhkan',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 14),
              ),
            ]),
      );

  Widget _buildMaterialsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        if (assemblyStatus != null) _buildStatusCard(),
        const SizedBox(height: 16),
        ...selectedProductMaterials.asMap().entries.map((entry) {
          final idx = entry.key;
          final material = entry.value;
          final available =
              (material['stok_tersedia'] as num? ?? 0).toInt();
          final required = (material['quantity'] as num? ?? 0).toInt();
          final stockColor = _getStockColor(available, required);
          final stockIcon = _getStockIcon(available, required);
          final isZero = available <= 0;

          return Container(
            key: ValueKey('dmat_${material['material_id']}_$idx'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isZero ? Colors.red[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: stockColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(stockIcon, color: stockColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(material['nama_m'] ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _textPrimary)),
                    ),
                    if (isZero)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.red[600],
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('HABIS',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: stockColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(material['code_m'] ?? '-',
                          style: TextStyle(
                              color: stockColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  if (material['category_name'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Kategori: ${material['category_name']}',
                        style:
                            TextStyle(fontSize: 11, color: _textSecondary)),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Dibutuhkan',
                                style: TextStyle(
                                    color: _textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('$required',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: _textPrimary)),
                          ])),
                      Container(width: 1, height: 40, color: _borderGrey),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Tersedia',
                                style: TextStyle(
                                    color: _textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('$available',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: stockColor)),
                          ])),
                    ]),
                  ),
                  if (material['notes'] != null &&
                      material['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue[200]!)),
                      child: Row(children: [
                        Icon(Icons.note, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(material['notes'].toString(),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue[700])),
                        ),
                      ]),
                    ),
                  ],
                ]),
          );
        }),
      ]),
    );
  }

  Widget _buildStatusCard() {
    final state = _assemblyButtonState;
    Color cardColor, borderColor, iconColor, textColor;
    IconData cardIcon;
    String statusMsg;

    switch (state) {
      case 'done':
        cardColor = Colors.green[50]!;
        borderColor = Colors.green[400]!;
        iconColor = Colors.green[700]!;
        textColor = Colors.green[800]!;
        cardIcon = Icons.check_circle;
        statusMsg =
            'Projek telah selesai di-assembly — tidak dapat diproses ulang';
        break;
      case 'blocked':
        cardColor = Colors.red[50]!;
        borderColor = Colors.red[300]!;
        iconColor = Colors.red[700]!;
        textColor = Colors.red[800]!;
        cardIcon = Icons.block;
        statusMsg = 'Assembly diblokir — ada material yang stoknya habis';
        break;
      case 'limited':
        cardColor = Colors.orange[50]!;
        borderColor = Colors.orange[300]!;
        iconColor = Colors.orange[700]!;
        textColor = Colors.orange[800]!;
        cardIcon = Icons.warning_amber_rounded;
        statusMsg = 'Stok terbatas — assembly tetap dapat diproses';
        break;
      default:
        cardColor = Colors.green[50]!;
        borderColor = Colors.green[300]!;
        iconColor = Colors.green[700]!;
        textColor = Colors.green[800]!;
        cardIcon = Icons.check_circle;
        statusMsg = assemblyStatus != null
            ? (assemblyStatus!['status_message'] ?? 'Semua stok tersedia')
            : 'Semua stok tersedia';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(cardIcon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(statusMsg,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textColor)),
              ),
            ]),
            if (state != 'done' && assemblyStatus != null) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 14, children: [
                _legendItem(
                    Icons.check_circle, 'Tersedia', Colors.green[700]!),
                _legendItem(Icons.warning_amber_rounded, 'Terbatas',
                    Colors.orange[700]!),
                _legendItem(Icons.block, 'Habis', Colors.red[700]!),
              ]),
              const SizedBox(height: 6),
              Text(
                'Total: ${assemblyStatus!['total_materials']} material  ·  '
                'Tersedia: ${assemblyStatus!['available_materials']}  ·  '
                'Kurang: ${assemblyStatus!['insufficient_materials']}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ]),
    );
  }

  Widget _legendItem(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _buildProductStatusDot(Map<String, dynamic> product) {
    final status = (product['assembly_status'] ?? 'ready').toString();
    Color dotColor;
    String tooltip;
    switch (status) {
      case 'done':
        dotColor = Colors.green[600]!;
        tooltip = 'Selesai';
        break;
      case 'blocked':
        dotColor = Colors.red[600]!;
        tooltip = 'Stok habis';
        break;
      case 'in_progress':
        dotColor = Colors.amber[500]!;
        tooltip = 'Berlangsung';
        break;
      case 'limited':
        dotColor = Colors.orange[500]!;
        tooltip = 'Stok terbatas';
        break;
      default:
        dotColor = Colors.blue[400]!;
        tooltip = 'Siap diproses';
    }
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: dotColor.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1)
          ],
        ),
      ),
    );
  }
}