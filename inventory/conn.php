<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

// Set timezone
date_default_timezone_set('Asia/Jakarta');

// Database configuration
$host = "localhost";
$username = "invb1937_Inventory";
$password = "Hosting2552.";
$database = "invb1937_inventory"; // // Diperbaiki dari inventory_system ke inventory

// Create connection
$connect = new mysqli($host, $username, $password, $database);

// Check connection
if ($connect->connect_error) {
    die(json_encode([
        'status' => 'error',
        'message' => 'Database connection failed: ' . $connect->connect_error
    ]));
}

// Set charset to UTF-8
$connect->set_charset("utf8");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}
?>