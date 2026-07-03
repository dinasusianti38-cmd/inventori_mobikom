<?php
require_once 'conn.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

// Hitung stok real-time dari tabel transaksi
function getCurrentStock($materialId) {
    global $connect;

    $query = "SELECT 
                COALESCE(SUM(CASE WHEN transaction_type = 'in' THEN jumlah ELSE 0 END), 0) -
                COALESCE(SUM(CASE WHEN transaction_type = 'out' THEN jumlah ELSE 0 END), 0) +
                COALESCE(SUM(CASE WHEN transaction_type = 'adjustment' THEN jumlah ELSE 0 END), 0) as current_stock
              FROM material_transactions 
              WHERE material_id = ?";

    $stmt = $connect->prepare($query);
    $stmt->bind_param("i", $materialId);
    $stmt->execute();
    $result = $stmt->get_result();
    $stock = $result->fetch_assoc();

    return intval($stock['current_stock'] ?? 0);
}

// Tentukan status stok
function getStockStatus($currentStock, $stokMinimal = 10) {
    if ($currentStock <= 0) {
        return 'stok habis';
    } elseif ($currentStock <= $stokMinimal) {
        return 'stok menipis';
    } else {
        return 'stok normal';
    }
}

// Format tanggal
function formatDate($date) {
    if (empty($date)) {
        return date('d/m/Y');
    }
    return date('d/m/Y', strtotime($date));
}

try {
    // Cek apakah kolom stok_minimal ada di tabel materials
    $checkColumn = $connect->query("SHOW COLUMNS FROM materials LIKE 'stok_minimal'");
    $hasStokMinimal = ($checkColumn && $checkColumn->num_rows > 0);

    // Query sesuai kondisi kolom
    if ($hasStokMinimal) {
        $query = "SELECT 
                    m.id_m,
                    m.code_m,
                    m.nama_m,
                    m.satuan,
                    m.description,
                    m.stok_minimal,
                    m.category_id,
                    m.created_at,
                    m.updated_at,
                    COALESCE(c.nama_c, 'Tidak Berkategori') as kategory
                  FROM materials m 
                  LEFT JOIN categories c ON m.category_id = c.id_c 
                  ORDER BY m.nama_m ASC";
    } else {
        // Fallback jika kolom stok_minimal belum ada
        $query = "SELECT 
                    m.id_m,
                    m.code_m,
                    m.nama_m,
                    m.satuan,
                    m.description,
                    10 as stok_minimal,
                    m.category_id,
                    m.created_at,
                    m.updated_at,
                    COALESCE(c.nama_c, 'Tidak Berkategori') as kategory
                  FROM materials m 
                  LEFT JOIN categories c ON m.category_id = c.id_c 
                  ORDER BY m.nama_m ASC";
    }

    $result = $connect->query($query);

    if (!$result) {
        throw new Exception('Query failed: ' . $connect->error);
    }

    $materials = [];

    while ($row = $result->fetch_assoc()) {
        $currentStock = getCurrentStock($row['id_m']);
        $stokMinimal  = intval($row['stok_minimal'] ?? 10);
        $status       = getStockStatus($currentStock, $stokMinimal);

        $materials[] = [
            'id_m'        => intval($row['id_m']),
            'code_m'      => $row['code_m'],
            'nama_m'      => $row['nama_m'],
            'satuan'      => $row['satuan'],
            'description' => $row['description'] ?? '',
            'category_id' => intval($row['category_id']),
            'kategory'    => $row['kategory'],
            'jumlah'      => $currentStock,
            'stok_minimal'=> $stokMinimal,
            'status'      => $status,
            'last_update' => formatDate($row['updated_at']),
            'created_at'  => $row['created_at'],
            'updated_at'  => $row['updated_at'],
        ];
    }

    echo json_encode([
        'status'    => 'success',
        'data'      => $materials,
        'total'     => count($materials),
        'timestamp' => date('Y-m-d H:i:s'),
    ]);

} catch (Exception $e) {
    echo json_encode([
        'status'  => 'error',
        'message' => 'Failed to fetch export data: ' . $e->getMessage(),
        'data'    => [],
        'total'   => 0,
    ]);
}

$connect->close();
?>
