<?php
include 'conn.php';

$material_id = $_GET['material_id'] ?? null;

if (!$material_id) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Material ID is required'
    ]);
    exit;
}

try {
    $sql = "SELECT 
                ms.id_sm,
                m.nama_m,
                m.code_m,
                ms.stok_tersedia,
                ms.stok_minimal,
                ms.last_updated,
                u.username as updated_by_name
            FROM material_stocks ms
            JOIN materials m ON ms.material_id = m.id_m
            LEFT JOIN users u ON ms.updated_by = u.id_u
            WHERE ms.material_id = ?
            ORDER BY ms.last_updated DESC
            LIMIT 50";
    
    $stmt = $connect->prepare($sql);
    $stmt->bind_param("i", $material_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $data = array();
        while($row = $result->fetch_assoc()) {
            $row['last_updated'] = date('d/m/Y H:i:s', strtotime($row['last_updated']));
            $data[] = $row;
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $data,
            'total' => count($data)
        ]);
    } else {
        echo json_encode([
            'status' => 'success',
            'data' => [],
            'total' => 0,
            'message' => 'No history found'
        ]);
    }
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}

$connect->close();
?>
