<?php
require_once 'conn.php';

try {
    $query = "SELECT m.id_m, m.code_m, m.nama_m, m.description, m.category_id, 
                     c.nama_c as category_name, m.created_at, m.updated_at
              FROM materials m
              LEFT JOIN categories c ON m.category_id = c.id_c
              ORDER BY m.nama_m ASC";
    
    $result = $connect->query($query);
    
    if ($result) {
        $materials = [];
        while ($row = $result->fetch_assoc()) {
            $materials[] = [
                'id_m' => (int)$row['id_m'],
                'code_m' => $row['code_m'],
                'nama_m' => $row['nama_m'],
                'description' => $row['description'],
                'category_id' => $row['category_id'] ? (int)$row['category_id'] : null,
                'category_name' => $row['category_name'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Materials retrieved successfully',
            'data' => $materials
        ]);
    } else {
        throw new Exception('Failed to execute query: ' . $connect->error);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
} finally {
    if (isset($connect)) {
        $connect->close();
    }
}
?>
