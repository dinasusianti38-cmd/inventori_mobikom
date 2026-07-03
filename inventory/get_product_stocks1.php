<?php
require_once 'conn.php';

try {
    $query = "SELECT 
                ps.id_sp,
                ps.product_id,
                ps.stok_minimal,
                ps.stok_tersedia,
                ps.last_updated,
                ps.updated_by,
                p.code_p,
                p.name_p,
                p.description,
                u.full_name as updated_by_name
              FROM product_stocks ps
              LEFT JOIN products p ON ps.product_id = p.id_p
              LEFT JOIN users u ON ps.updated_by = u.id_u
              ORDER BY ps.last_updated DESC";
    
    $result = $connect->query($query);
    
    if ($result) {
        $stocks = [];
        while ($row = $result->fetch_assoc()) {
            // Convert to integers
            $row['id_sp'] = intval($row['id_sp']);
            $row['product_id'] = intval($row['product_id']);
            $row['stok_minimal'] = intval($row['stok_minimal']);
            $row['stok_tersedia'] = intval($row['stok_tersedia']);
            $row['updated_by'] = intval($row['updated_by']);
            
            // TAMBAHKAN: Hitung status berdasarkan stok
            if ($row['stok_tersedia'] <= 0) {
                $row['status'] = 'stok habis';
            } else if ($row['stok_tersedia'] <= $row['stok_minimal']) {
                $row['status'] = 'stok menipis';
            } else {
                $row['status'] = 'stok normal';
            }
            
            // TAMBAHKAN: Tentukan kategori berdasarkan nama produk
            $productName = strtolower($row['name_p']);
            if (strpos($productName, 'printer') !== false || 
                strpos($productName, 'laptop') !== false ||
                strpos($productName, 'komputer') !== false) {
                $row['kategori'] = 'Elektronik';
            } else if (strpos($productName, 'kabel') !== false || 
                       strpos($productName, 'mouse') !== false ||
                       strpos($productName, 'keyboard') !== false) {
                $row['kategori'] = 'Aksesoris';
            } else {
                $row['kategori'] = 'Lainnya';
            }
            
            $stocks[] = $row;
        }
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Product stocks retrieved successfully',
            'data' => $stocks
        ]);
    } else {
        throw new Exception('Query failed: ' . $connect->error);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'data' => []
    ]);
}

$connect->close();
?>