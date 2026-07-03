<?php
// Disable error display to prevent HTML errors in JSON response
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

// Set content type header at the beginning
header('Content-Type: application/json; charset=UTF-8');

require_once 'conn.php';

try {
    // Query untuk mendapatkan semua data stok produk dengan perhitungan real-time
    $query = "SELECT 
                ps.id_sp,
                ps.product_id,
                COALESCE(p.code_p, '') as code_p,
                COALESCE(p.name_p, 'Unknown Product') as name_p,
                COALESCE(ps.stok_minimal, 0) as stok_minimal,
                COALESCE(ps.stok_tersedia, 0) as stok_tersedia,
                ps.last_updated,
                COALESCE(u.full_name, 'Unknown User') as updated_by_name,
                -- Tentukan kategori berdasarkan nama produk
                CASE 
                    WHEN LOWER(p.name_p) LIKE '%battery%' OR 
                         LOWER(p.name_p) LIKE '%batery%' OR 
                         LOWER(p.name_p) LIKE '%lora%' THEN 'battery'
                    ELSE 'antena'
                END as kategori,
                -- Tentukan satuan berdasarkan nama produk
                CASE 
                    WHEN LOWER(p.name_p) LIKE '%meter%' THEN 'meter'
                    ELSE 'pcs'
                END as satuan,
                -- Hitung status real-time berdasarkan stok tersedia
                CASE 
                    WHEN COALESCE(ps.stok_tersedia, 0) = 0 THEN 'stok habis'
                    WHEN COALESCE(ps.stok_tersedia, 0) <= COALESCE(ps.stok_minimal, 0) THEN 'stok menipis'
                    ELSE 'stok normal'
                END as status
              FROM product_stocks ps
              INNER JOIN products p ON ps.product_id = p.id_p
              LEFT JOIN users u ON ps.updated_by = u.id_u
              WHERE ps.product_id IS NOT NULL 
              AND ps.stok_minimal IS NOT NULL 
              AND ps.stok_tersedia IS NOT NULL
              ORDER BY p.name_p ASC";
    
    $result = $connect->query($query);
    
    if (!$result) {
        throw new Exception('Query failed: ' . $connect->error);
    }
    
    $products = [];
    $summary = [
        'total_products' => 0,
        'stok_normal' => 0,
        'stok_menipis' => 0,
        'stok_habis' => 0
    ];
    
    while ($row = $result->fetch_assoc()) {
        // Hitung ulang status untuk memastikan konsistensi
        $stokTersedia = (int)$row['stok_tersedia'];
        $stokMinimal = (int)$row['stok_minimal'];
        
        $actualStatus = 'stok normal';
        if ($stokTersedia == 0) {
            $actualStatus = 'stok habis';
            $summary['stok_habis']++;
        } elseif ($stokTersedia <= $stokMinimal) {
            $actualStatus = 'stok menipis';
            $summary['stok_menipis']++;
        } else {
            $summary['stok_normal']++;
        }
        
        $summary['total_products']++;
        
        // Format data untuk export
        $products[] = [
            'id_sp' => (int)$row['id_sp'],
            'product_id' => (int)$row['product_id'],
            'code_p' => $row['code_p'],
            'name_p' => $row['name_p'],
            'kategori' => $row['kategori'],
            'satuan' => $row['satuan'],
            'stok_minimal' => $stokMinimal,
            'stok_tersedia' => $stokTersedia,
            'status' => $actualStatus, // Status yang sudah divalidasi ulang
            'last_updated' => $row['last_updated'],
            'updated_by_name' => $row['updated_by_name']
        ];
    }
    
    // Response sukses dengan data real-time
    echo json_encode([
        'status' => 'success',
        'data' => $products,
        'summary' => $summary,
        'total' => $summary['total_products'],
        'timestamp' => date('Y-m-d H:i:s') // Tracking kapan data diambil
    ]);
    
} catch (Exception $e) {
    // Response error
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to fetch export data: ' . $e->getMessage(),
        'data' => [],
        'summary' => [
            'total_products' => 0,
            'stok_normal' => 0,
            'stok_menipis' => 0,
            'stok_habis' => 0
        ],
        'total' => 0
    ]);
}

$connect->close();
?>
