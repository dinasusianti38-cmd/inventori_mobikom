<?php
require_once 'conn.php';

try {
    $query_param = isset($_GET['query']) ? trim($_GET['query']) : '';
    
    if (empty($query_param)) {
        // If no query, return all stocks
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
    } else {
        $search_term = "%$query_param%";
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
                  WHERE p.name_p LIKE ? 
                     OR p.code_p LIKE ?
                     OR p.description LIKE ?
                  ORDER BY ps.last_updated DESC";
    }
    
    if (empty($query_param)) {
        $result = $connect->query($query);
    } else {
        $stmt = $connect->prepare($query);
        $stmt->bind_param('sss', $search_term, $search_term, $search_term);
        $stmt->execute();
        $result = $stmt->get_result();
    }
    
    if ($result) {
        $stocks = [];
        while ($row = $result->fetch_assoc()) {
            $stocks[] = $row;
        }
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Search completed successfully',
            'data' => $stocks,
            'query' => $query_param
        ]);
    } else {
        throw new Exception('Query failed: ' . $connect->error);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'data' => [],
        'query' => $query_param ?? ''
    ]);
}

if (isset($stmt)) {
    $stmt->close();
}
$connect->close();
?>
