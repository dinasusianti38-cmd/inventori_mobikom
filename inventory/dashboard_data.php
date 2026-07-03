<?php
require_once 'conn.php';

try {
    // Get total materials
    $materialQuery = "SELECT COUNT(*) as total FROM materials";
    $materialResult = $connect->query($materialQuery);
    $totalMaterial = $materialResult->fetch_assoc()['total'];

    // Get total categories
    $categoryQuery = "SELECT COUNT(*) as total FROM categories WHERE is_active = 1";
    $categoryResult = $connect->query($categoryQuery);
    $totalCategory = $categoryResult->fetch_assoc()['total'];

    // Get total product stock (PR)
    $productStockQuery = "SELECT COALESCE(SUM(stok_tersedia), 0) as total FROM product_stocks";
    $productStockResult = $connect->query($productStockQuery);
    $totalStokPR = $productStockResult->fetch_assoc()['total'];

    // Get total material stock (MT)
    $materialStockQuery = "SELECT COALESCE(SUM(stok_tersedia), 0) as total FROM material_stocks";
    $materialStockResult = $connect->query($materialStockQuery);
    $totalStokMT = $materialStockResult->fetch_assoc()['total'];

    // -------------------------------------------------------
    // Material transactions per bulan (MT)
    // -------------------------------------------------------
    $mtChartQuery = "
        SELECT 
            MONTH(transaction_date) as month,
            SUM(CASE WHEN transaction_type = 'in' THEN jumlah ELSE 0 END) as mt_masuk,
            SUM(CASE WHEN transaction_type = 'out' THEN jumlah ELSE 0 END) as mt_keluar
        FROM material_transactions 
        WHERE YEAR(transaction_date) = YEAR(CURDATE())
        GROUP BY MONTH(transaction_date)
        ORDER BY MONTH(transaction_date)
    ";

    $mtResult = $connect->query($mtChartQuery);
    $mtData = [];
    while ($row = $mtResult->fetch_assoc()) {
        $mtData[(int)$row['month']] = [
            'mt_masuk'  => (int)$row['mt_masuk'],
            'mt_keluar' => (int)$row['mt_keluar'],
        ];
    }

    // -------------------------------------------------------
    // Product transactions per bulan (PR)
    // -------------------------------------------------------
    $prChartQuery = "
        SELECT 
            MONTH(transaction_date) as month,
            SUM(CASE WHEN transaction_type = 'in' THEN jumlah ELSE 0 END) as pr_masuk,
            SUM(CASE WHEN transaction_type = 'out' THEN jumlah ELSE 0 END) as pr_keluar
        FROM product_transactions 
        WHERE YEAR(transaction_date) = YEAR(CURDATE())
        GROUP BY MONTH(transaction_date)
        ORDER BY MONTH(transaction_date)
    ";

    $prResult = $connect->query($prChartQuery);
    $prData = [];
    while ($row = $prResult->fetch_assoc()) {
        $prData[(int)$row['month']] = [
            'pr_masuk'  => (int)$row['pr_masuk'],
            'pr_keluar' => (int)$row['pr_keluar'],
        ];
    }

    // -------------------------------------------------------
    // Gabungkan ke array 12 bulan
    // -------------------------------------------------------
    $chartData = [];
    for ($i = 1; $i <= 12; $i++) {
        $chartData[] = [
            'month'     => $i,
            'mt_masuk'  => isset($mtData[$i]) ? $mtData[$i]['mt_masuk']  : 0,
            'mt_keluar' => isset($mtData[$i]) ? $mtData[$i]['mt_keluar'] : 0,
            'pr_masuk'  => isset($prData[$i]) ? $prData[$i]['pr_masuk']  : 0,
            'pr_keluar' => isset($prData[$i]) ? $prData[$i]['pr_keluar'] : 0,
        ];
    }

    $response = [
        'status' => 'success',
        'data'   => [
            'totalMaterial' => (int)$totalMaterial,
            'totalCategory' => (int)$totalCategory,
            'totalStokPR'   => (int)$totalStokPR,
            'totalStokMT'   => (int)$totalStokMT,
            'chartData'     => $chartData,
        ],
    ];

    header('Content-Type: application/json');
    echo json_encode($response);

} catch (Exception $e) {
    header('Content-Type: application/json');
    echo json_encode([
        'status'  => 'error',
        'message' => $e->getMessage(),
    ]);
} finally {
    $connect->close();
}
?>