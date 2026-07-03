<?php
require_once 'conn.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");

try {
    if (!isset($connect) || !$connect) {
        throw new Exception("Database connection failed");
    }

    // Ambil semua produk yang punya material (sesuai tampilan halaman Assembly)
    $sql_projects = "SELECT DISTINCT
                        p.id_p,
                        p.code_p,
                        p.name_p,
                        p.created_at
                    FROM products p
                    INNER JOIN product_materials pm ON p.id_p = pm.product_id
                    GROUP BY p.id_p, p.code_p, p.name_p, p.created_at
                    ORDER BY p.created_at DESC
                    LIMIT 50";

    $result_projects = $connect->query($sql_projects);
    if ($result_projects === false) {
        throw new Exception("Query projects failed: " . $connect->error);
    }

    $projects = [];
    while ($row = $result_projects->fetch_assoc()) {
        $projects[] = $row;
    }

    $report_data = [];

    foreach ($projects as $project) {
        $product_id = (int)$project['id_p'];

        // Jumlah assembly & total unit diproduksi dari product_transactions
        $sql_asm = "SELECT 
                        COUNT(*) as assembly_count,
                        COALESCE(SUM(jumlah), 0) as total_qty,
                        MAX(transaction_date) as last_assembly
                    FROM product_transactions
                    WHERE product_id = ?
                    AND transaction_type = 'in'
                    AND notes LIKE '%Assembly%'";
        $stmt = $connect->prepare($sql_asm);
        if (!$stmt) throw new Exception("Prepare asm query failed: " . $connect->error);
        $stmt->bind_param("i", $product_id);
        $stmt->execute();
        $asm_row = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        // Stok produk saat ini
        $sql_pstok = "SELECT COALESCE(stok_tersedia, 0) as stok_produk 
                      FROM product_stocks WHERE product_id = ? LIMIT 1";
        $stmt = $connect->prepare($sql_pstok);
        $stok_produk = 0;
        if ($stmt) {
            $stmt->bind_param("i", $product_id);
            $stmt->execute();
            $pstok_row = $stmt->get_result()->fetch_assoc();
            $stok_produk = (int)($pstok_row['stok_produk'] ?? 0);
            $stmt->close();
        }

        // Material projek + stok + kategori + sisa setelah assembly
        $sql_materials = "SELECT 
                            m.code_m,
                            m.nama_m,
                            COALESCE(c.nama_c, '-') as category,
                            pm.quantity as qty_needed,
                            COALESCE(ms.stok_tersedia, 0) as stock_available
                        FROM product_materials pm
                        INNER JOIN materials m ON pm.material_id = m.id_m
                        LEFT JOIN material_stocks ms ON m.id_m = ms.material_id
                        LEFT JOIN categories c ON m.category_id = c.id_c
                        WHERE pm.product_id = ?
                        ORDER BY m.nama_m";

        $stmt = $connect->prepare($sql_materials);
        if (!$stmt) throw new Exception("Prepare materials query failed: " . $connect->error);
        $stmt->bind_param("i", $product_id);
        $stmt->execute();
        $result_materials = $stmt->get_result();

        $materials = [];
        while ($mat = $result_materials->fetch_assoc()) {
            $needed    = (int)$mat['qty_needed'];
            $available = (int)$mat['stock_available'];
            $materials[] = [
                'code_m'                => (string)($mat['code_m']   ?? '-'),
                'nama_m'                => (string)($mat['nama_m']   ?? '-'),
                'category'              => (string)($mat['category'] ?? '-'),
                'qty_needed'            => $needed,
                'stock_available'       => $available,
                'sisa_setelah_assembly' => $available - $needed,
            ];
        }
        $stmt->close();

        $report_data[] = [
            'project' => [
                'id_p'           => $product_id,
                'code_p'         => (string)($project['code_p'] ?? '-'),
                'name_p'         => (string)($project['name_p'] ?? '-'),
                'assembly_count' => (int)($asm_row['assembly_count'] ?? 0),
                'total_qty'      => (int)($asm_row['total_qty']      ?? 0),
                'stok_produk'    => $stok_produk,
                'last_assembly'  => $asm_row['last_assembly'] ?? '-',
            ],
            'materials' => $materials,
        ];
    }

    $total_projects = count($projects);
    $total_assembly = 0;
    $total_units    = 0;
    foreach ($report_data as $rd) {
        $total_assembly += $rd['project']['assembly_count'];
        $total_units    += $rd['project']['total_qty'];
    }

    echo json_encode([
        'status'  => 'success',
        'message' => 'Data loaded successfully',
        'data'    => [
            'generated_date' => date('d/m/Y H:i'),
            'total_projects' => $total_projects,
            'total_assembly' => $total_assembly,
            'total_units'    => $total_units,
            'report_data'    => $report_data,
        ],
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status'  => 'error',
        'message' => $e->getMessage(),
    ]);
}

if (isset($connect) && $connect) {
    $connect->close();
}
?>