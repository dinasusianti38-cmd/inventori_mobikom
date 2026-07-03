<?php
include 'conn.php';

try {
    // Get filter parameters
    $year = isset($_GET['year']) ? $_GET['year'] : date('Y');
    $month = isset($_GET['month']) ? $_GET['month'] : '';
    $jenis = isset($_GET['jenis']) ? $_GET['jenis'] : '';
    $search = isset($_GET['search']) ? $_GET['search'] : '';

    // Base query to get laporan data from multiple tables
    $query = "
        SELECT 
            'material' as tipe,
            m.nama_m as nama_barang,
            m.code_m as kode_barang,
            ms.stok_tersedia as jumlah,
            'Unit' as unit,
            CASE 
                WHEN ms.stok_tersedia > ms.stok_minimal THEN 'masuk'
                ELSE 'keluar'
            END as jenis,
            DATE_FORMAT(ms.last_updated, '%d/%m/%Y') as tanggal,
            COALESCE(u.username, 'system') as dibuat_oleh,
            ms.last_updated as sort_date
        FROM material_stocks ms
        LEFT JOIN materials m ON ms.material_id = m.id_m
        LEFT JOIN users u ON ms.updated_by = u.id_u
        
        UNION ALL
        
        SELECT 
            'product' as tipe,
            p.name_p as nama_barang,
            p.code_p as kode_barang,
            ps.stok_tersedia as jumlah,
            'Unit' as unit,
            CASE 
                WHEN ps.stok_tersedia > ps.stok_minimal THEN 'masuk'
                ELSE 'keluar'
            END as jenis,
            DATE_FORMAT(ps.last_updated, '%d/%m/%Y') as tanggal,
            COALESCE(u.username, 'system') as dibuat_oleh,
            ps.last_updated as sort_date
        FROM product_stocks ps
        LEFT JOIN products p ON ps.product_id = p.id_p
        LEFT JOIN users u ON ps.updated_by = u.id_u
    ";

    // Add WHERE conditions
    $conditions = [];
    $params = [];

    // Year filter
    if (!empty($year)) {
        $conditions[] = "YEAR(sort_date) = ?";
        $params[] = $year;
    }

    // Month filter
    if (!empty($month) && $month !== 'semua bulan') {
        $monthNumbers = [
            'januari' => 1, 'februari' => 2, 'maret' => 3, 'april' => 4,
            'mei' => 5, 'juni' => 6, 'juli' => 7, 'agustus' => 8,
            'september' => 9, 'oktober' => 10, 'november' => 11, 'desember' => 12
        ];
        
        if (isset($monthNumbers[$month])) {
            $conditions[] = "MONTH(sort_date) = ?";
            $params[] = $monthNumbers[$month];
        }
    }

    // Jenis filter
    if (!empty($jenis) && $jenis !== 'semua') {
        $conditions[] = "jenis = ?";
        $params[] = $jenis;
    }

    // Search filter
    if (!empty($search)) {
        $conditions[] = "(nama_barang LIKE ? OR kode_barang LIKE ?)";
        $params[] = '%' . $search . '%';
        $params[] = '%' . $search . '%';
    }

    // Wrap the UNION query and add WHERE conditions
    if (!empty($conditions)) {
        $query = "SELECT * FROM ($query) as laporan_data WHERE " . implode(' AND ', $conditions);
    } else {
        $query = "SELECT * FROM ($query) as laporan_data";
    }

    // Add ORDER BY
    $query .= " ORDER BY sort_date DESC";

    // Prepare and execute the query
    $stmt = $connect->prepare($query);
    if (!empty($params)) {
        $stmt->execute($params);
    } else {
        $stmt->execute();
    }

    $result = $stmt->get_result();
    $data = [];

    while ($row = $result->fetch_assoc()) {
        // Remove sort_date from the final output
        unset($row['sort_date']);
        $data[] = $row;
    }

    echo json_encode([
        'status' => 'success',
        'data' => $data,
        'total' => count($data),
        'filters' => [
            'year' => $year,
            'month' => $month,
            'jenis' => $jenis,
            'search' => $search
        ]
    ]);

} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Error fetching laporan data: ' . $e->getMessage()
    ]);
}

$connect->close();
?>