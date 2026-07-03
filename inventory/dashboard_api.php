<?php
require_once 'conn.php';

try {
    // Get total materials
    $totalMaterialQuery = "SELECT COUNT(*) as total FROM materials";
    $totalMaterialResult = $connect->query($totalMaterialQuery);
    $totalMaterial = $totalMaterialResult->fetch_assoc()['total'];

    // Get total categories
    $totalCategoryQuery = "SELECT COUNT(*) as total FROM categories WHERE is_active = 1";
    $totalCategoryResult = $connect->query($totalCategoryQuery);
    $totalCategory = $totalCategoryResult->fetch_assoc()['total'];

    // Get total product stock (PR)
    $totalStokPRQuery = "SELECT SUM(stok_tersedia) as total FROM product_stocks";
    $totalStokPRResult = $connect->query($totalStokPRQuery);
    $totalStokPR = $totalStokPRResult->fetch_assoc()['total'] ?? 0;

    // Get total material stock (MT)
    $totalStokMTQuery = "SELECT SUM(stok_tersedia) as total FROM material_stocks";
    $totalStokMTResult = $connect->query($totalStokMTQuery);
    $totalStokMT = $totalStokMTResult->fetch_assoc()['total'] ?? 0;

    // Get chart data (monthly transactions)
    // Since we don't have transaction tables yet, we'll create sample data
    // You can modify this query when you have actual transaction tables
    $chartData = [];
    
    // Generate sample data for 12 months
    for ($month = 1; $month <= 12; $month++) {
        // Sample data - replace with actual transaction queries
        $pemasukan = rand(200, 300);
        $pengeluaran = rand(180, 280);
        
        $chartData[] = [
            'month' => $month,
            'pemasukan' => $pemasukan,
            'pengeluaran' => $pengeluaran
        ];
    }

    // If you have actual transaction tables, use queries like this:
    /*
    $chartDataQuery = "
        SELECT 
            MONTH(transaction_date) as month,
            SUM(CASE WHEN transaction_type = 'in' THEN quantity ELSE 0 END) as pemasukan,
            SUM(CASE WHEN transaction_type = 'out' THEN quantity ELSE 0 END) as pengeluaran
        FROM material_transactions 
        WHERE YEAR(transaction_date) = YEAR(NOW())
        GROUP BY MONTH(transaction_date)
        ORDER BY month
    ";
    $chartDataResult = $connect->query($chartDataQuery);
    $chartData = [];
    while ($row = $chartDataResult->fetch_assoc()) {
        $chartData[] = [
            'month' => (int)$row['month'],
            'pemasukan' => (int)$row['pemasukan'],
            'pengeluaran' => (int)$row['pengeluaran']
        ];
    }
    */

    $response = [
        'status' => 'success',
        'data' => [
            'totalMaterial' => (int)$totalMaterial,
            'totalCategory' => (int)$totalCategory,
            'totalStokPR' => (int)$totalStokPR,
            'totalStokMT' => (int)$totalStokMT,
            'chartData' => $chartData
        ]
    ];

    echo json_encode($response);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Terjadi kesalahan: ' . $e->getMessage()
    ]);
}

$connect->close();
?>
