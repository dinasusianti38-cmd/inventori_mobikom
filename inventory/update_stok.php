<?php
include 'conn.php';

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (!isset($input['material_id']) || !isset($input['new_stok'])) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Missing required fields'
    ]);
    exit;
}

$material_id = $input['material_id'];
$new_stok = $input['new_stok'];
$reason = $input['reason'] ?? 'Update stok';
$updated_by = 1; // Default user ID, you can modify this based on your authentication

try {
    // Start transaction
    $connect->begin_transaction();
    
    // Update stok
    $sql = "UPDATE material_stocks 
            SET stok_tersedia = ?, 
                last_updated = CURRENT_TIMESTAMP,
                updated_by = ?
            WHERE material_id = ?";
    
    $stmt = $connect->prepare($sql);
    $stmt->bind_param("iii", $new_stok, $updated_by, $material_id);
    
    if ($stmt->execute()) {
        // Log the stock change (optional - you can create a stock_history table)
        $log_sql = "INSERT INTO stock_history (material_id, old_stock, new_stock, reason, updated_by, updated_at) 
                    SELECT material_id, stok_tersedia, ?, ?, ?, CURRENT_TIMESTAMP 
                    FROM material_stocks 
                    WHERE material_id = ?";
        
        // Note: This assumes you have a stock_history table. If not, you can remove this part.
        
        $connect->commit();
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Stok updated successfully'
        ]);
    } else {
        $connect->rollback();
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to update stok'
        ]);
    }
} catch (Exception $e) {
    $connect->rollback();
    echo json_encode([
        'status' => 'error',
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}

$connect->close();
?>
