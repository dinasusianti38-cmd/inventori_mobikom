<?php
require_once 'conn.php';

header('Content-Type: application/json');

try {
    // Validasi input
    if (!isset($_GET['assembly_id']) || !is_numeric($_GET['assembly_id'])) {
        throw new Exception("Invalid assembly ID");
    }
    
    $assembly_id = (int)$_GET['assembly_id'];
    
    // Query untuk mengambil items dengan informasi stok
    $sql = "SELECT 
                ai.id as item_id,
                ai.assembly_id,
                ai.product_id,
                ai.quantity as required_quantity,
                ai.cost,
                p.id,
                p.code,
                p.name,
                p.unit,
                p.price,
                c.name as category_name,
                COALESCE(sb.quantity, 0) as stock_available,
                COALESCE(sb.min_stock, 0) as min_stock,
                COALESCE(sb.max_stock, 0) as max_stock,
                COALESCE(sb.location, 'Gudang Utama') as location,
                CASE 
                    WHEN COALESCE(sb.quantity, 0) < ai.quantity THEN 'insufficient'
                    WHEN COALESCE(sb.quantity, 0) <= ai.quantity * 1.2 THEN 'limited'
                    ELSE 'sufficient'
                END as stock_status
            FROM assembly_items ai
            INNER JOIN products p ON ai.product_id = p.id
            LEFT JOIN categories c ON p.category_id = c.id
            LEFT JOIN stock_barang sb ON p.id = sb.product_id
            WHERE ai.assembly_id = ?
            ORDER BY p.name ASC";
    
    $stmt = $connect->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare statement failed: " . $connect->error);
    }
    
    $stmt->bind_param("i", $assembly_id);
    
    if (!$stmt->execute()) {
        throw new Exception("Execute statement failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    $items = [];
    while ($row = $result->fetch_assoc()) {
        $items[] = [
            'item_id' => (int)$row['item_id'],
            'assembly_id' => (int)$row['assembly_id'],
            'product_id' => (int)$row['product_id'],
            'required_quantity' => (int)$row['required_quantity'],
            'cost' => (float)$row['cost'],
            'product_code' => $row['code'],
            'product_name' => $row['name'],
            'unit' => $row['unit'],
            'price' => (float)$row['price'],
            'category_name' => $row['category_name'],
            'stock_available' => (int)$row['stock_available'],
            'min_stock' => (int)$row['min_stock'],
            'max_stock' => (int)$row['max_stock'],
            'location' => $row['location'],
            'stock_status' => $row['stock_status']
        ];
    }
    
    $stmt->close();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Assembly items loaded successfully',
        'data' => $items,
        'count' => count($items)
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'data' => []
    ]);
}

$connect->close();
?>
