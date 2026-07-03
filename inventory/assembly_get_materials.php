<?php
require_once 'conn.php';

try {
    // Validasi input
    if (!isset($_GET['product_id']) || !is_numeric($_GET['product_id'])) {
        throw new Exception("Invalid product ID");
    }
    
    $product_id = (int)$_GET['product_id'];
    
    // Query yang dioptimasi dengan GROUP BY untuk menghindari duplikasi
    $sql = "SELECT 
                pm.id_pm,
                pm.product_id,
                pm.material_id,
                pm.quantity,
                pm.notes,
                m.id_m,
                m.code_m,
                m.nama_m,
                m.description as material_description,
                c.nama_c as category_name,
                COALESCE(MAX(ms.stok_tersedia), 0) as stok_tersedia,
                COALESCE(MAX(ms.stok_minimal), 0) as stok_minimal,
                MAX(ms.last_updated) as last_updated,
                CASE 
                    WHEN COALESCE(MAX(ms.stok_tersedia), 0) < pm.quantity THEN 'insufficient'
                    WHEN COALESCE(MAX(ms.stok_tersedia), 0) <= pm.quantity * 1.2 THEN 'limited'
                    ELSE 'sufficient'
                END as stock_status
            FROM product_materials pm
            INNER JOIN materials m ON pm.material_id = m.id_m
            LEFT JOIN categories c ON m.category_id = c.id_c
            LEFT JOIN material_stocks ms ON m.id_m = ms.material_id
            WHERE pm.product_id = ?
            GROUP BY pm.id_pm, pm.product_id, pm.material_id, pm.quantity, pm.notes, 
                     m.id_m, m.code_m, m.nama_m, m.description, c.nama_c
            ORDER BY m.nama_m ASC";
    
    $stmt = $connect->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare statement failed: " . $connect->error);
    }
    
    $stmt->bind_param("i", $product_id);
    
    if (!$stmt->execute()) {
        throw new Exception("Execute statement failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    $materials = [];
    while ($row = $result->fetch_assoc()) {
        $materials[] = [
            'id_pm' => (int)$row['id_pm'],
            'product_id' => (int)$row['product_id'],
            'material_id' => (int)$row['material_id'],
            'quantity' => (int)$row['quantity'],
            'notes' => $row['notes'],
            'id_m' => (int)$row['id_m'],
            'code_m' => $row['code_m'],
            'nama_m' => $row['nama_m'],
            'material_description' => $row['material_description'],
            'category_name' => $row['category_name'],
            'stok_tersedia' => (int)$row['stok_tersedia'],
            'stok_minimal' => (int)$row['stok_minimal'],
            'last_updated' => $row['last_updated'],
            'stock_status' => $row['stock_status']
        ];
    }
    
    $stmt->close();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Product materials loaded successfully',
        'data' => $materials,
        'count' => count($materials)
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'data' => []
    ]);
}

$connect->close();
?>