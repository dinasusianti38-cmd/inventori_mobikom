<?php
include 'conn.php';

try {
    // Get parameters
    $year = isset($_GET['year']) ? $_GET['year'] : date('Y');
    $month = isset($_GET['month']) ? $_GET['month'] : '';
    
    // Build query
    $query = "SELECT 
                b.nama_barang,
                b.kode_barang,
                t.jumlah,
                t.jenis,
                DATE_FORMAT(t.tanggal, '%d/%m/%Y') as tanggal,
                t.dibuat_oleh,
                b.unit
              FROM transaksi t
              JOIN barang b ON t.id_barang = b.id_barang
              WHERE YEAR(t.tanggal) = ?";
    
    $params = [$year];
    $types = "s";
    
    // Add month filter if specified
    if (!empty($month)) {
        $query .= " AND MONTH(t.tanggal) = ?";
        $params[] = $month;
        $types .= "s";
    }
    
    $query .= " ORDER BY t.tanggal DESC";
    
    // Prepare and execute query
    $stmt = $connect->prepare($query);
    if ($stmt) {
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $data = [];
        while ($row = $result->fetch_assoc()) {
            $data[] = $row;
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $data,
            'total' => count($data)
        ]);
        
        $stmt->close();
    } else {
        throw new Exception("Query preparation failed: " . $connect->error);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
} finally {
    $connect->close();
}
?>
