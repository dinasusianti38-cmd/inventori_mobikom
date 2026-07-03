// FIXED: Material Model untuk dropdown
class MaterialModel {
  int? idM;
  String? namaM;
  String? codeM;
  String? satuan;
  int? stokTersedia;

  MaterialModel({
    this.idM,
    this.namaM,
    this.codeM,
    this.satuan,
    this.stokTersedia,
  });

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      idM: json['id_m'] != null ? int.tryParse(json['id_m'].toString()) : null,
      namaM: json['nama_m'],
      codeM: json['code_m'],
      satuan: json['satuan'],
      stokTersedia: json['stok_tersedia'] != null 
          ? int.tryParse(json['stok_tersedia'].toString()) ?? 0 
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_m': idM,
      'nama_m': namaM,
      'code_m': codeM,
      'satuan': satuan,
      'stok_tersedia': stokTersedia,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaterialModel && other.idM == idM;
  }

  @override
  int get hashCode => idM.hashCode;
}

// FIXED: Material Transaction Model
class MaterialTransaksiModel {
  int? idTm;
  String? transactionCode;
  int? materialId;
  String? transactionType;
  int? jumlah;
  int? stokSebelum;
  int? stokSesudah;
  String? transactionDate;
  String? notes;
  String? createdAt;
  String? updatedAt;
  
  // Fields dari join dengan tabel materials
  String? namaMaterial;
  String? codeMaterial;
  String? satuan;

  MaterialTransaksiModel({
    this.idTm,
    this.transactionCode,
    this.materialId,
    this.transactionType,
    this.jumlah,
    this.stokSebelum,
    this.stokSesudah,
    this.transactionDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.namaMaterial,
    this.codeMaterial,
    this.satuan,
  });

  factory MaterialTransaksiModel.fromJson(Map<String, dynamic> json) {
    return MaterialTransaksiModel(
      idTm: json['id_tm'] != null ? int.tryParse(json['id_tm'].toString()) : null,
      transactionCode: json['transaction_code'],
      materialId: json['material_id'] != null ? int.tryParse(json['material_id'].toString()) : null,
      transactionType: json['transaction_type'],
      jumlah: json['jumlah'] != null ? int.tryParse(json['jumlah'].toString()) : null,
      stokSebelum: json['stok_sebelum'] != null ? int.tryParse(json['stok_sebelum'].toString()) : null,
      stokSesudah: json['stok_sesudah'] != null ? int.tryParse(json['stok_sesudah'].toString()) : null,
      transactionDate: json['transaction_date'],
      notes: json['notes'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      namaMaterial: json['nama_m'],
      codeMaterial: json['code_m'],
      satuan: json['satuan'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_tm': idTm,
      'transaction_code': transactionCode,
      'material_id': materialId,
      'transaction_type': transactionType,
      'jumlah': jumlah,
      'stok_sebelum': stokSebelum,
      'stok_sesudah': stokSesudah,
      'transaction_date': transactionDate,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'nama_m': namaMaterial,
      'code_m': codeMaterial,
      'satuan': satuan,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaterialTransaksiModel && other.idTm == idTm;
  }

  @override
  int get hashCode => idTm.hashCode;
}