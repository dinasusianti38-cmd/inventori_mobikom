<?php
require_once 'conn.php';

header('Content-Type: application/json');

try {
    // Check if assembly_history table exists
    $check_table = $connect->query("SHOW TABLES LIKE 'assembly_history'");
    
    if ($check_table->num_rows == 0) {
        // Table doesn't exist yet, return empty report
        // Create CSV with header only
        $csv_content = "\xEF\xBB\xBF";
        $csv_content .= "ID,Tanggal Assembly,Kode Produk,Nama Produk,Jumlah,Status,Dibuat Oleh,Catatan\n";
        $csv_content .= "# Belum ada data assembly history\n";
        
        $filename = 'assembly_report_empty_' . date('Y-m-d_His') . '.csv';
        $filepath = 'exports/' . $filename;
        
        if (!file_exists('exports')) {
            mkdir('exports', 0777, true);
        }
        
        file_put_contents($filepath, $csv_content);
        
        $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http";
        $host = $_SERVER['HTTP_HOST'];
        $script_path = dirname($_SERVER['SCRIPT_NAME']);
        $base_url = $protocol . "://" . $host . $script_path;
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Report exported (no data yet)',
            'data' => [
                'file_url' => $base_url . '/' . $filepath,
                'filename' => $filename,
                'file_path' => $filepath,
                'file_size' => filesize($filepath),
                'records_count' => 0
            ]
        ]);
        exit;
    }
    
    // Table exists, proceed with normal export
    $sql = "SELECT 
                ah.id_ah,
                ah.assembly_date,
                p.code_p,
                p.name_p,
                ah.quantity,
                ah.status,
                ah.notes,
                u.nama_u as created_by_name
            FROM assembly_history ah
            INNER JOIN products p ON ah.product_id = p.id_p
            LEFT JOIN users u ON ah.created_by = u.id_u
            ORDER BY ah.assembly_date DESC";
    
    $result = $connect->query($sql);
    
    if ($result === false) {
        throw new Exception("Database query failed: " . $connect->error);
    }
    
    // Create CSV content with UTF-8 BOM
    $csv_content = "\xEF\xBB\xBF";
    $csv_content .= "ID,Tanggal Assembly,Kode Produk,Nama Produk,Jumlah,Status,Dibuat Oleh,Catatan\n";
    
    $record_count = 0;
    while ($row = $result->fetch_assoc()) {
        $csv_content .= sprintf(
            "%d,%s,%s,\"%s\",%d,%s,\"%s\",\"%s\"\n",
            $row['id_ah'],
            date('Y-m-d H:i:s', strtotime($row['assembly_date'])),
            $row['code_p'],
            str_replace('"', '""', $row['name_p']),
            $row['quantity'],
            $row['status'],
            str_replace('"', '""', $row['created_by_name'] ?? 'System'),
            str_replace('"', '""', $row['notes'] ?? '')
        );
        $record_count++;
    }
    
    // Generate filename
    $filename = 'assembly_report_' . date('Y-m-d_His') . '.csv';
    $filepath = 'exports/' . $filename;
    
    // Create exports directory if not exists
    if (!file_exists('exports')) {
        mkdir('exports', 0777, true);
    }
    
    // Save file
    file_put_contents($filepath, $csv_content);
    
    // Get base URL
    $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http";
    $host = $_SERVER['HTTP_HOST'];
    $script_path = dirname($_SERVER['SCRIPT_NAME']);
    $base_url = $protocol . "://" . $host . $script_path;
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Report exported successfully',
        'data' => [
            'file_url' => $base_url . '/' . $filepath,
            'filename' => $filename,
            'file_path' => $filepath,
            'file_size' => filesize($filepath),
            'records_count' => $record_count
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

if (isset($connect)) {
    $connect->close();
}
?>