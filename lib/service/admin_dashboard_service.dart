import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminDashboardService {
  static const String _baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard_data.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          var chartData = data['data']['chartData'] ?? [];

          if (chartData.isEmpty) {
            chartData = _getDefaultChartData();
          } else {
            chartData = (chartData as List).map((item) {
              return {
                'month'    : _parseToInt(item['month']),
                'mt_masuk' : _parseToInt(item['mt_masuk']),
                'mt_keluar': _parseToInt(item['mt_keluar']),
                'pr_masuk' : _parseToInt(item['pr_masuk']),
                'pr_keluar': _parseToInt(item['pr_keluar']),
              };
            }).toList();
          }

          return {
            'totalMaterial': _parseToInt(data['data']['totalMaterial']),
            'totalCategory': _parseToInt(data['data']['totalCategory']),
            'totalStokPR'  : _parseToInt(data['data']['totalStokPR']),
            'totalStokMT'  : _parseToInt(data['data']['totalStokMT']),
            'chartData'    : chartData,
          };
        } else {
          throw Exception(data['message'] ?? 'Unknown error');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getDashboardData: $e');
      return {
        'totalMaterial': 0,
        'totalCategory': 0,
        'totalStokPR'  : 0,
        'totalStokMT'  : 0,
        'chartData'    : _getDefaultChartData(),
      };
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ─── default data (fallback / testing) ──────────────────────────────────────

  List<Map<String, dynamic>> _getDefaultChartData() {
    return [
      {'month': 1,  'mt_masuk': 45, 'mt_keluar': 30, 'pr_masuk': 20, 'pr_keluar': 15},
      {'month': 2,  'mt_masuk': 55, 'mt_keluar': 25, 'pr_masuk': 30, 'pr_keluar': 20},
      {'month': 3,  'mt_masuk': 40, 'mt_keluar': 35, 'pr_masuk': 25, 'pr_keluar': 18},
      {'month': 4,  'mt_masuk': 60, 'mt_keluar': 40, 'pr_masuk': 35, 'pr_keluar': 28},
      {'month': 5,  'mt_masuk': 50, 'mt_keluar': 45, 'pr_masuk': 28, 'pr_keluar': 22},
      {'month': 6,  'mt_masuk': 65, 'mt_keluar': 35, 'pr_masuk': 40, 'pr_keluar': 30},
      {'month': 7,  'mt_masuk': 70, 'mt_keluar': 50, 'pr_masuk': 45, 'pr_keluar': 35},
      {'month': 8,  'mt_masuk': 55, 'mt_keluar': 30, 'pr_masuk': 32, 'pr_keluar': 25},
      {'month': 9,  'mt_masuk': 48, 'mt_keluar': 42, 'pr_masuk': 27, 'pr_keluar': 20},
      {'month': 10, 'mt_masuk': 52, 'mt_keluar': 38, 'pr_masuk': 30, 'pr_keluar': 24},
      {'month': 11, 'mt_masuk': 58, 'mt_keluar': 45, 'pr_masuk': 38, 'pr_keluar': 29},
      {'month': 12, 'mt_masuk': 62, 'mt_keluar': 40, 'pr_masuk': 42, 'pr_keluar': 32},
    ];
  }

  // ─── trend analysis (opsional) ───────────────────────────────────────────────

  Map<String, dynamic> calculateTrends(List<Map<String, dynamic>> chartData) {
    if (chartData.length < 2) {
      return {
        'mtMasukTrend' : 0.0,
        'mtKeluarTrend': 0.0,
        'prMasukTrend' : 0.0,
        'prKeluarTrend': 0.0,
      };
    }

    final len = chartData.length;
    int n = (len >= 6) ? 3 : len ~/ 2;

    double rMtM = 0, rMtK = 0, rPrM = 0, rPrK = 0;
    double pMtM = 0, pMtK = 0, pPrM = 0, pPrK = 0;

    for (int i = len - n; i < len; i++) {
      rMtM += _parseToDouble(chartData[i]['mt_masuk']);
      rMtK += _parseToDouble(chartData[i]['mt_keluar']);
      rPrM += _parseToDouble(chartData[i]['pr_masuk']);
      rPrK += _parseToDouble(chartData[i]['pr_keluar']);
    }
    for (int i = len - n * 2; i < len - n; i++) {
      if (i >= 0) {
        pMtM += _parseToDouble(chartData[i]['mt_masuk']);
        pMtK += _parseToDouble(chartData[i]['mt_keluar']);
        pPrM += _parseToDouble(chartData[i]['pr_masuk']);
        pPrK += _parseToDouble(chartData[i]['pr_keluar']);
      }
    }

    double _trendPct(double r, double p) =>
        p > 0 ? ((r - p) / p) * 100 : 0;

    return {
      'mtMasukTrend' : _trendPct(rMtM / n, pMtM / n),
      'mtKeluarTrend': _trendPct(rMtK / n, pMtK / n),
      'prMasukTrend' : _trendPct(rPrM / n, pPrM / n),
      'prKeluarTrend': _trendPct(rPrK / n, pPrK / n),
    };
  }
}