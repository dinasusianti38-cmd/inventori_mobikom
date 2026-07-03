class MaterialTransaction {
  final int idTm;
  final String transactionCode;
  final int materialId;
  final String transactionType;
  final int jumlah;
  final int stokSebelum;
  final int stokSesudah;
  final String transactionDate;
  final String notes;
  final int createdBy;
  final String createdAt;
  final String materialName;
  final String materialCode;
  final String satuan;
  final String createdByName;

  MaterialTransaction({
    required this.idTm,
    required this.transactionCode,
    required this.materialId,
    required this.transactionType,
    required this.jumlah,
    required this.stokSebelum,
    required this.stokSesudah,
    required this.transactionDate,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.materialName,
    required this.materialCode,
    required this.satuan,
    required this.createdByName,
  });

  factory MaterialTransaction.fromJson(Map<String, dynamic> json) {
    return MaterialTransaction(
      idTm:            _parseInt(json['id_tm']),
      transactionCode: _parseString(json['transaction_code']),
      materialId:      _parseInt(json['material_id']),
      transactionType: _parseString(json['transaction_type']),
      jumlah:          _parseInt(json['jumlah']),
      stokSebelum:     _parseInt(json['stok_sebelum']),
      stokSesudah:     _parseInt(json['stok_sesudah']),
      transactionDate: _parseString(json['transaction_date']),
      notes:           _parseString(json['notes']),
      createdBy:       _parseInt(json['created_by']),
      createdAt:       _parseString(json['created_at']),
      materialName:    _parseString(json['material_name']),
      materialCode:    _parseString(json['material_code']),
      satuan:          _parseString(json['satuan']),
      createdByName:   _parseString(json['created_by_name']),
    );
  }

  // Helper: parse int aman (null, string, int semua dihandle)
  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  // Helper: parse string aman (null → '-')
  static String _parseString(dynamic v, [String fallback = '-']) {
    if (v == null) return fallback;
    return v.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id_tm':            idTm,
      'transaction_code': transactionCode,
      'material_id':      materialId,
      'transaction_type': transactionType,
      'jumlah':           jumlah,
      'stok_sebelum':     stokSebelum,
      'stok_sesudah':     stokSesudah,
      'transaction_date': transactionDate,
      'notes':            notes,
      'created_by':       createdBy,
      'created_at':       createdAt,
      'material_name':    materialName,
      'material_code':    materialCode,
      'satuan':           satuan,
      'created_by_name':  createdByName,
    };
  }
}

class Material {
  final int idM;
  final String namaM;
  final String codeM;
  final String satuan;
  final String categoryName;

  Material({
    required this.idM,
    required this.namaM,
    required this.codeM,
    required this.satuan,
    required this.categoryName,
  });

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      idM:          _parseInt(json['id_m']),
      namaM:        _parseString(json['nama_m']),
      codeM:        _parseString(json['code_m']),
      satuan:       _parseString(json['satuan']),
      categoryName: _parseString(json['category_name']),
    );
  }

  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static String _parseString(dynamic v, [String fallback = '-']) {
    if (v == null) return fallback;
    return v.toString();
  }
}

class TransactionSummary {
  final int totalTransactions;
  final int inTransactions;
  final int outTransactions;
  final int adjustmentTransactions;
  final int totalQuantityIn;
  final int totalQuantityOut;

  TransactionSummary({
    required this.totalTransactions,
    required this.inTransactions,
    required this.outTransactions,
    required this.adjustmentTransactions,
    required this.totalQuantityIn,
    required this.totalQuantityOut,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      totalTransactions:      _parseInt(json['total_transactions']),
      inTransactions:         _parseInt(json['in_transactions']),
      outTransactions:        _parseInt(json['out_transactions']),
      adjustmentTransactions: _parseInt(json['adjustment_transactions']),
      totalQuantityIn:        _parseInt(json['total_quantity_in']),
      totalQuantityOut:       _parseInt(json['total_quantity_out']),
    );
  }

  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }
}