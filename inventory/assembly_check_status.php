<?php
require_once 'conn.php';

header('Content-Type: application/json');

try {
    if (!isset($_GET['product_id']) || !is_numeric($_GET['product_id'])) {
        throw new Exception("Invalid product ID");
    }
    
    $product_id = (int)$_GET['product_id'];
    
    $sql = "SELECT 
                p.id_p,
                p.code_p,
                p.name_p,
                COUNT(pm.id_pm) as total_materials,
                SUM(CASE WHEN COALESCE(ms.stok_tersedia, 0) >= pm.quantity THEN 1 ELSE 0 END) as available_materials,
                SUM(CASE WHEN COALESCE(ms.stok_tersedia, 0) < pm.quantity THEN 1 ELSE 0 END) as insufficient_materials,
                GROUP_CONCAT(
                    CASE 
                        WHEN COALESCE(ms.stok_tersedia, 0) < pm.quantity 
                        THEN CONCAT(m.nama_m, ' (butuh: ', pm.quantity, ', tersedia: ', COALESCE(ms.stok_tersedia, 0), ')')
                        ELSE NULL
                    END
                    SEPARATOR '; '
                ) as missing_materials
            FROM products p
            LEFT JOIN product_materials pm ON p.id_p = pm.product_id
            LEFT JOIN materials m ON pm.material_id = m.id_m
            LEFT JOIN material_stocks ms ON m.id_m = ms.material_id
            WHERE p.id_p = ?
            GROUP BY p.id_p, p.code_p, p.name_p";
    
    $stmt = $connect->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $connect->error);
    }
    
    $stmt->bind_param("i", $product_id);
    
    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    if (!$row) {
        throw new Exception("Product not found");
    }
    
    $stmt->close();
    
    $can_assemble = (int)$row['insufficient_materials'] === 0 && (int)$row['total_materials'] > 0;
    
    $status_data = [
        'product_id' => (int)$row['id_p'],
        'product_code' => $row['code_p'],
        'product_name' => $row['name_p'],
        'total_materials' => (int)$row['total_materials'],
        'available_materials' => (int)$row['available_materials'],
        'insufficient_materials' => (int)$row['insufficient_materials'],
        'can_assemble' => $can_assemble,
        'missing_materials' => $row['missing_materials'],
        'status' => $can_assemble ? 'ready' : 'not_ready',
        'status_message' => $can_assemble 
            ? 'Produk siap untuk dirakit' 
            : 'Material tidak mencukupi untuk merakit produk'
    ];
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Assembly status checked successfully',
        'data' => $status_data
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'data' => null
    ]);
}

if (isset($connect)) {
    $connect->close();
}
?>