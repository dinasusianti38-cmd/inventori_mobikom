<?php
require_once 'conn.php';

try {
    $search = isset($_GET['search']) ? $_GET['search'] : '';
    $status = isset($_GET['status']) ? $_GET['status'] : '';
    
    // Build the query
    $query = "SELECT 
                ps.id_sp,
                p.name_p,
                p.code_p,
                ps.stok_minimal,
                ps.stok_tersedia,
                ps.last_updated,
                u.full_name as updated_by_name,
                CASE 
                    WHEN ps.stok_tersedia = 0 THEN 'stok habis'
                    WHEN ps.stok_tersedia <= ps.stok_minimal THEN 'stok menipis'
                    ELSE 'stok normal'
                END as status
              FROM product_stocks ps
              JOIN products p ON ps.product_id = p.id_p
              LEFT JOIN users u ON ps.updated_by = u.id_u
              WHERE 1=1";
    
    $params = [];
    $types = "";
    
    // Add search condition
    if (!empty($search)) {
        $query .= " AND (p.name_p LIKE ? OR p.code_p LIKE ?)";
        $searchParam = "%$search%";
        $params[] = $searchParam;
        $params[] = $searchParam;
        $types .= "ss";
    }
    
    // Add status filter
    if (!empty($status)) {
        $query .= " HAVING status = ?";
        $params[] = $status;
        $types .= "s";
    }
    
    $query .= " ORDER BY p.name_p ASC";
    
    $stmt = $connect->prepare($query);
    
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = [
            'id_sp' => $row['id_sp'],
            'name_p' => $row['name_p'],
            'code_p' => $row['code_p'],
            'stok_minimal' => (int)$row['stok_minimal'],
            'stok_tersedia' => (int)$row['stok_tersedia'],
            'status' => $row['status'],
            'last_updated' => $row['last_updated'],
            'updated_by_name' => $row['updated_by_name']
        ];
    }
    
    // Calculate summary
    $totalProducts = count($data);
    $stokHabis = count(array_filter($data, function($item) {
        return $item['status'] === 'stok habis';
    }));
    $stokMenipis = count(array_filter($data, function($item) {
        return $item['status'] === 'stok menipis';
    }));
    $stokNormal = count(array_filter($data, function($item) {
        return $item['status'] === 'stok normal';
    }));
    
    $response = [
        'status' => 'success',
        'data' => $data,
        'summary' => [
            'total_products' => $totalProducts,
            'stok_habis' => $stokHabis,
            'stok_menipis' => $stokMenipis,
            'stok_normal' => $stokNormal
        ]
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$connect->close();
?>
