<?php
require_once 'conn.php';

header('Content-Type: application/json');

try {
    $sql = "SELECT 
                p.id_p, 
                p.code_p, 
                p.name_p, 
                p.description,
                p.created_at,
                p.updated_at,
                COUNT(pm.id_pm) as total_materials
            FROM products p 
            LEFT JOIN product_materials pm ON p.id_p = pm.product_id
            GROUP BY p.id_p, p.code_p, p.name_p, p.description, p.created_at, p.updated_at
            ORDER BY p.name_p ASC";
    
    $result = $connect->query($sql);
    
    if ($result === false) {
        throw new Exception("Database query failed: " . $connect->error);
    }
    
    $products = [];
    while ($row = $result->fetch_assoc()) {
        $products[] = [
            'id_p' => (int)$row['id_p'],
            'code_p' => $row['code_p'],
            'name_p' => $row['name_p'],
            'description' => $row['description'],
            'total_materials' => (int)$row['total_materials'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at']
        ];
    }
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Products loaded successfully',
        'data' => $products,
        'count' => count($products)
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