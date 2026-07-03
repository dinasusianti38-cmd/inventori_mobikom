<?php
require_once 'conn.php';

try {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        // Get parameters from query string
        $startDate = isset($_GET['start_date']) ? $_GET['start_date'] : null;
        $endDate = isset($_GET['end_date']) ? $_GET['end_date'] : null;
        $materialId = isset($_GET['material_id']) ? $_GET['material_id'] : null;
        $transactionType = isset($_GET['transaction_type']) ? $_GET['transaction_type'] : null;
        
        // Base query
        $query = "SELECT 
                    mt.id_tm,
                    mt.transaction_code,
                    mt.transaction_type,
                    mt.jumlah,
                    mt.stok_sebelum,
                    mt.stok_sesudah,
                    mt.transaction_date,
                    mt.notes,
                    m.nama_m as material_name,
                    m.satuan,
                    u.full_name as created_by_name,
                    mt.created_at
                  FROM material_transactions mt
                  LEFT JOIN materials m ON mt.material_id = m.id_m
                  LEFT JOIN users u ON mt.created_by = u.id_u
                  WHERE 1=1";
        
        $params = [];
        $types = "";
        
        // Add date filters
        if ($startDate) {
            $query .= " AND mt.transaction_date >= ?";
            $params[] = $startDate;
            $types .= "s";
        }
        
        if ($endDate) {
            $query .= " AND mt.transaction_date <= ?";
            $params[] = $endDate;
            $types .= "s";
        }
        
        // Add material filter
        if ($materialId) {
            $query .= " AND mt.material_id = ?";
            $params[] = $materialId;
            $types .= "i";
        }
        
        // Add transaction type filter
        if ($transactionType && $transactionType !== 'all') {
            $query .= " AND mt.transaction_type = ?";
            $params[] = $transactionType;
            $types .= "s";
        }
        
        $query .= " ORDER BY mt.transaction_date DESC, mt.created_at DESC";
        
        $stmt = $connect->prepare($query);
        
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        
        $stmt->execute();
        $result = $stmt->get_result();
        
        $transactions = [];
        while ($row = $result->fetch_assoc()) {
            $transactions[] = $row;
        }
        
        // Get summary data
        $summaryQuery = "SELECT 
                           transaction_type,
                           COUNT(*) as count,
                           SUM(jumlah) as total_quantity
                         FROM material_transactions mt
                         WHERE 1=1";
        
        $summaryParams = [];
        $summaryTypes = "";
        
        if ($startDate) {
            $summaryQuery .= " AND mt.transaction_date >= ?";
            $summaryParams[] = $startDate;
            $summaryTypes .= "s";
        }
        
        if ($endDate) {
            $summaryQuery .= " AND mt.transaction_date <= ?";
            $summaryParams[] = $endDate;
            $summaryTypes .= "s";
        }
        
        if ($materialId) {
            $summaryQuery .= " AND mt.material_id = ?";
            $summaryParams[] = $materialId;
            $summaryTypes .= "i";
        }
        
        if ($transactionType && $transactionType !== 'all') {
            $summaryQuery .= " AND mt.transaction_type = ?";
            $summaryParams[] = $transactionType;
            $summaryTypes .= "s";
        }
        
        $summaryQuery .= " GROUP BY transaction_type";
        
        $summaryStmt = $connect->prepare($summaryQuery);
        
        if (!empty($summaryParams)) {
            $summaryStmt->bind_param($summaryTypes, ...$summaryParams);
        }
        
        $summaryStmt->execute();
        $summaryResult = $summaryStmt->get_result();
        
        $summary = [
            'in' => ['count' => 0, 'total_quantity' => 0],
            'out' => ['count' => 0, 'total_quantity' => 0],
            'adjustment' => ['count' => 0, 'total_quantity' => 0]
        ];
        
        while ($summaryRow = $summaryResult->fetch_assoc()) {
            $summary[$summaryRow['transaction_type']] = [
                'count' => (int)$summaryRow['count'],
                'total_quantity' => (int)$summaryRow['total_quantity']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => [
                'transactions' => $transactions,
                'summary' => $summary,
                'filters' => [
                    'start_date' => $startDate,
                    'end_date' => $endDate,
                    'material_id' => $materialId,
                    'transaction_type' => $transactionType
                ]
            ]
        ]);
        
    } else {
        http_response_code(405);
        echo json_encode([
            'status' => 'error',
            'message' => 'Method not allowed'
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

$connect->close();
?>
