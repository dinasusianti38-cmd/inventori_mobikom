<?php
include 'conn.php';

try {
    // Get parameters
    $search = isset($_GET['search']) ? $_GET['search'] : '';
    $category = isset($_GET['category']) ? $_GET['category'] : '';
    $page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;
    $offset = ($page - 1) * $limit;

    // Base query dengan JOIN untuk mendapatkan data lengkap
    $query = "
        SELECT 
            m.id_m,
            m.code_m,
            m.nama_m,
            m.satuan,
            c.nama_c as kategory,
            ms.stok_tersedia as jumlah,
            CASE 
                WHEN ms.stok_tersedia <= ms.stok_minimal THEN 'stok habis'
                WHEN ms.stok_tersedia <= (ms.stok_minimal * 1.5) THEN 'stok menipis'
                ELSE 'stok normal'
            END as status,
            ms.last_updated
        FROM materials m
        LEFT JOIN categories c ON m.category_id = c.id_c
        LEFT JOIN material_stocks ms ON m.id_m = ms.material_id
        WHERE 1=1
    ";

    $params = [];
    $types = "";

    // Add search filter
    if (!empty($search)) {
        $query .= " AND (m.nama_m LIKE ? OR m.code_m LIKE ?)";
        $searchTerm = "%$search%";
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $types .= "ss";
    }

    // Add category filter
    if (!empty($category) && $category !== 'semua kategory') {
        $query .= " AND c.nama_c = ?";
        $params[] = $category;
        $types .= "s";
    }

    // Get total count for pagination
    $countQuery = "SELECT COUNT(*) as total FROM (" . $query . ") as subquery";
    
    if (!empty($params)) {
        $countStmt = $connect->prepare($countQuery);
        $countStmt->bind_param($types, ...$params);
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $totalRecords = $countResult->fetch_assoc()['total'];
        $countStmt->close();
    } else {
        $countResult = $connect->query($countQuery);
        $totalRecords = $countResult->fetch_assoc()['total'];
    }

    // Add pagination
    $query .= " ORDER BY m.nama_m ASC LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";

    // Execute main query
    if (!empty($params)) {
        $stmt = $connect->prepare($query);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
    } else {
        $result = $connect->query($query);
    }

    $materials = [];
    if ($result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $materials[] = [
                'id' => $row['id_m'],
                'nama_material' => $row['nama_m'],
                'kode_material' => $row['code_m'],
                'jumlah' => $row['jumlah'] ? $row['jumlah'] . ' ' . $row['satuan'] : '0 ' . $row['satuan'],
                'kategory' => $row['kategory'] ?? 'Tidak ada kategori',
                'status' => $row['status'] ?? 'stok normal',
                'last_update' => $row['last_updated'] ? date('d/m/Y', strtotime($row['last_updated'])) : date('d/m/Y')
            ];
        }
    }

    // Calculate pagination info
    $totalPages = ceil($totalRecords / $limit);

    echo json_encode([
        'status' => 'success',
        'data' => $materials,
        'pagination' => [
            'current_page' => $page,
            'total_pages' => $totalPages,
            'total_records' => $totalRecords,
            'per_page' => $limit,
            'showing_from' => $offset + 1,
            'showing_to' => min($offset + $limit, $totalRecords)
        ]
    ]);

    if (isset($stmt)) $stmt->close();

} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$connect->close();
?>
