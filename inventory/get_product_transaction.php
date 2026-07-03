<?php
require_once 'conn.php';

try {
    // Catatan: Jika nama kolom 'material_id' seharusnya 'product_id', sebaiknya disesuaikan di database
    $query = "SELECT pt.id_pm, pt.transaction_code, pt.material_id as product_id, 
                     p.name_p, p.code_p, pt.transaction_type, pt.jumlah,
                     pt.stok_sebelum, pt.stok_sesudah, pt.transaction_date, pt.notes,
                     pt.created_by, u.full_name as created_by_name, pt.created_at
              FROM product_transactions pt
              LEFT JOIN products p ON pt.material_id = p.id_p
              LEFT JOIN users u ON pt.created_by = u.id_u
              ORDER BY pt.created_at DESC";
    
    $result = $connect->query($query);
    
    if ($result) {
        $transactions = [];
        while ($row = $result->fetch_assoc()) {
            $transactions[] = [
                'id_pm' => (int)$row['id_pm'],
                'transaction_code' => $row['transaction_code'],
                'product_id' => (int)$row['product_id'],
                'name_p' => $row['name_p'],
                'code_p' => $row['code_p'],
                'transaction_type' => $row['transaction_type'],
                'jumlah' => (int)$row['jumlah'],
                'stok_sebelum' => (int)$row['stok_sebelum'],
                'stok_sesudah' => (int)$row['stok_sesudah'],
                'transaction_date' => $row['transaction_date'],
                'notes' => $row['notes'],
                'created_by' => (int)$row['created_by'],
                'created_by_name' => $row['created_by_name'],
                'created_at' => $row['created_at'],
            ];
        }

        echo json_encode([
            'success' => true,
            'data' => $transactions
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Query failed'
        ]);
    }
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}
?>

