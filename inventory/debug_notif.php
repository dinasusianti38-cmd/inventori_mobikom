<?php
require_once 'conn.php';
header('Content-Type: application/json');

$out = [];

// 1. Cek struktur tabel material_stocks
$r = $connect->query("DESCRIBE material_stocks");
$cols = [];
while($row = $r->fetch_assoc()) $cols[] = $row;
$out['material_stocks_columns'] = $cols;

// 2. Cek struktur tabel product_materials
$r2 = $connect->query("DESCRIBE product_materials");
$cols2 = [];
while($row = $r2->fetch_assoc()) $cols2[] = $row;
$out['product_materials_columns'] = $cols2;

// 3. Sample data material_stocks (5 baris)
$r3 = $connect->query("SELECT * FROM material_stocks LIMIT 5");
$sample = [];
while($row = $r3->fetch_assoc()) $sample[] = $row;
$out['material_stocks_sample'] = $sample;

// 4. Sample data product_materials untuk product_id=38
$r4 = $connect->query("SELECT * FROM product_materials WHERE product_id=38 LIMIT 5");
$pm = [];
while($row = $r4->fetch_assoc()) $pm[] = $row;
$out['product_materials_38'] = $pm;

echo json_encode($out, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
$connect->close();
?>
