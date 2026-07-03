<?php
require_once 'conn.php';

header('Content-Type: application/json');

try {
    // Query untuk mengambil semua assembly yang aktif
    $sql = "SELECT 
                a.id, 
                a.name, 
                a.code, 
                a.description,
                a.total_cost,
                a.status,
                a.created_at,
                a.updated_at,
                COUNT(ai.id) as total_items
            FROM assembly a 
            LEFT JOIN assembly_items ai ON a.id = ai.assembly_id
            WHERE a.status = 'active'
            GROUP BY a.id, a.name, a.code, a.description, a.total_cost, a.status, a.created_at, a.updated_at
            ORDER BY a.name ASC";
    
    $result = $connect->query($sql);
    
    if ($result === false) {
        throw new Exception("Database query failed: " . $connect->error);
    }
    
    $assemblies = [];
    while ($row = $result->fetch_assoc()) {
        $assemblies[] = [
            'id' => (int)$row['id'],
            'name' => $row['name'],
            'code' => $row['code'],
            'description' => $row['description'],
            'total_cost' => (float)$row['total_cost'],
            'status' => $row['status'],
            'total_items' => (int)$row['total_items'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at']
        ];
    }
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Assemblies loaded successfully',
        'data' => $assemblies,
        'count' => count($assemblies)
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
