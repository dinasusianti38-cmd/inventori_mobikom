<?php
require_once 'conn.php';

header('Content-Type: application/json');

// Function to get current stock with real-time calculation from transactions
function getCurrentStock($materialId) {
    global $connect;
    
    // Get total stock from transactions - REAL TIME
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

// Function to determine stock status based on current stock and minimal threshold
function getStockStatus($currentStock, $stokMinimal = 10) {
    if ($currentStock <= 0) {
        return 'stok habis';
    } elseif ($currentStock <= $stokMinimal) {
        return 'stok menipis';
    } else {
        return 'stok normal';
    }
}

// Function to format date for display
function formatDate($date) {
    if (empty($date)) {
        return date('d/m/Y');
    }
    return date('d/m/Y', strtotime($date));
}

try {
    // Query untuk mendapatkan semua material dengan data terbaru
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
    
    $result = $connect->query($query);
    
    if (!$result) {
        throw new Exception('Query failed: ' . $connect->error);
    }
    
    $materials = [];
    
    while ($row = $result->fetch_assoc()) {
        // Hitung stok real-time dari transaksi
        $currentStock = getCurrentStock($row['id_m']);
        
        // Tentukan status berdasarkan stok real-time dan stok minimal
        $stokMinimal = intval($row['stok_minimal'] ?? 10);
        $status = getStockStatus($currentStock, $stokMinimal);
        
        // Format data untuk export
        $materials[] = [
            'id_m' => intval($row['id_m']),
            'code_m' => $row['code_m'],
            'nama_m' => $row['nama_m'],
            'satuan' => $row['satuan'],
            'description' => $row['description'],
            'category_id' => intval($row['category_id']),
            'kategory' => $row['kategory'],
            'jumlah' => $currentStock, // Stok real-time
            'stok_minimal' => $stokMinimal,
            'status' => $status, // Status real-time
            'last_update' => formatDate($row['updated_at']),
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at']
        ];
    }
    
    // Response sukses dengan data real-time
    echo json_encode([
        'status' => 'success',
        'data' => $materials,
        'total' => count($materials),
        'timestamp' => date('Y-m-d H:i:s') // Untuk tracking kapan data diambil
    ]);
    
} catch (Exception $e) {
    // Response error
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to fetch export data: ' . $e->getMessage(),
        'data' => [],
        'total' => 0
    ]);
}

$connect->close();
?>