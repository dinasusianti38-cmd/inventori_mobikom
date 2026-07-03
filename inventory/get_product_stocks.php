<?php
require_once 'conn.php';

try {
    $sql = "SELECT 
                ps.id_sp as id,
                p.name_p as product_name,
                p.code_p as product_code,
                ps.stok_tersedia as stock_quantity,
                ps.stok_minimal as min_stock,
                p.description,
                ps.last_updated as last_update,
                CASE 
                    WHEN ps.stok_tersedia <= 0 THEN 'stok habis'
                    WHEN ps.stok_tersedia <= ps.stok_minimal THEN 'stok rendah'
                    ELSE 'stok normal'
                END as status,
                CASE 
                    WHEN p.name_p LIKE '%printer%' OR p.name_p LIKE '%canon%' THEN 'Elektronik'
                    WHEN p.name_p LIKE '%kabel%' OR p.name_p LIKE '%lan%' THEN 'Aksesoris'
                    WHEN p.name_p LIKE '%komputer%' OR p.name_p LIKE '%pc%' THEN 'Komputer'
                    WHEN p.name_p LIKE '%router%' OR p.name_p LIKE '%switch%' THEN 'Jaringan'
                    ELSE 'Aksesoris'
                END as category
            FROM product_stocks ps
            JOIN products p ON ps.product_id = p.id_p
            ORDER BY ps.last_updated DESC";
    
    $result = $connect->query($sql);
    
    if ($result) {
        $stocks = [];
        while ($row = $result->fetch_assoc()) {
            // Format tanggal
            $row['last_update'] = date('d/m/Y', strtotime($row['last_update']));
            $stocks[] = $row;
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $stocks
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to fetch product stocks: ' . $connect->error
        ]);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

$connect->close();
?>
