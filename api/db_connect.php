<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$host = '127.0.0.1';
$username = 'root';
$password = '';
$database = 'sipora_app';

$conn = new mysqli($host, $username, $password, $database);

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Koneksi database gagal: ' . $conn->connect_error
    ]);
    exit;
}

$conn->set_charset('utf8mb4');

function json_response($data, int $statusCode = 200): void
{
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

if (realpath($_SERVER['SCRIPT_FILENAME']) === __FILE__) {
    // Endpoint test sederhana:
    // http://localhost/sipora_api/db_connect.php
    json_response([
        'success' => true,
        'message' => 'Koneksi API ke database berhasil',
        'server_time' => date('Y-m-d H:i:s')
    ]);
}
