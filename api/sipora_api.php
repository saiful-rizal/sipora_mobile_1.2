<?php
require_once __DIR__ . '/db_connect.php';

$action = $_GET['action'] ?? '';

function read_json_input(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function fail_response(string $message, int $statusCode = 400): void
{
    json_response([
        'success' => false,
        'message' => $message
    ], $statusCode);
}

function success_response(array $data = []): void
{
    json_response(array_merge(['success' => true], $data));
}

function scalar_query(mysqli $conn, string $sql)
{
    $result = $conn->query($sql);
    if (!$result) {
        fail_response('Query gagal: ' . $conn->error, 500);
    }
    $row = $result->fetch_row();
    return $row ? $row[0] : 0;
}

function find_or_create_id(mysqli $conn, string $table, string $idCol, string $nameCol, string $value): int
{
    $trimmed = trim($value);
    if ($trimmed === '') {
        return 0;
    }

    $select = $conn->prepare("SELECT $idCol FROM $table WHERE $nameCol = ? LIMIT 1");
    if (!$select) {
        fail_response('Prepare gagal: ' . $conn->error, 500);
    }
    $select->bind_param('s', $trimmed);
    $select->execute();
    $res = $select->get_result();
    if ($row = $res->fetch_assoc()) {
        return (int)$row[$idCol];
    }

    $insert = $conn->prepare("INSERT INTO $table ($nameCol) VALUES (?)");
    if (!$insert) {
        fail_response('Prepare gagal: ' . $conn->error, 500);
    }
    $insert->bind_param('s', $trimmed);
    if (!$insert->execute()) {
        fail_response('Gagal simpan data referensi: ' . $insert->error, 500);
    }

    return (int)$conn->insert_id;
}

function find_id_by_name(mysqli $conn, string $table, string $idCol, string $nameCol, string $value): ?int
{
    $trimmed = trim($value);
    if ($trimmed === '') {
        return null;
    }

    $select = $conn->prepare("SELECT $idCol FROM $table WHERE $nameCol = ? LIMIT 1");
    if (!$select) {
        fail_response('Prepare gagal: ' . $conn->error, 500);
    }
    $select->bind_param('s', $trimmed);
    $select->execute();
    $res = $select->get_result();
    $row = $res->fetch_assoc();

    return $row ? (int)$row[$idCol] : null;
}

function sanitize_file_stem(string $value): string
{
    $stem = strtolower(trim($value));
    $stem = preg_replace('/[^a-z0-9_-]+/', '-', $stem) ?? '';
    $stem = trim($stem, '-_');
    return $stem;
}

function store_document_file(string $base64Content, string $originalFileName): string
{
    $binary = base64_decode($base64Content, true);
    if ($binary === false) {
        fail_response('Isi file dokumen tidak valid');
    }

    $extension = strtolower(pathinfo($originalFileName, PATHINFO_EXTENSION));
    if (!in_array($extension, ['docx', 'pdf'], true)) {
        fail_response('Format file utama harus DOCX atau PDF');
    }

    $stem = sanitize_file_stem(pathinfo($originalFileName, PATHINFO_FILENAME));
    if ($stem === '') {
        $stem = 'dokumen';
    }

    try {
        $suffix = bin2hex(random_bytes(4));
    } catch (Exception $e) {
        $suffix = (string)mt_rand(1000, 9999);
    }

    $fileName = $stem . '-' . date('YmdHis') . '-' . $suffix . '.' . $extension;
    $relativePath = 'uploads/doc/' . $fileName;
    $targetPath = __DIR__ . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    $targetDir = dirname($targetPath);

    if (!is_dir($targetDir) && !mkdir($targetDir, 0777, true) && !is_dir($targetDir)) {
        fail_response('Gagal membuat folder penyimpanan dokumen', 500);
    }

    if (file_put_contents($targetPath, $binary) === false) {
        fail_response('Gagal menyimpan file dokumen', 500);
    }

    return $relativePath;
}

function create_temp_screening_file(string $base64Content, string $originalFileName): string
{
    $binary = base64_decode($base64Content, true);
    if ($binary === false) {
        fail_response('Isi file screening tidak valid');
    }

    $extension = strtolower(pathinfo($originalFileName, PATHINFO_EXTENSION));
    if (!in_array($extension, ['docx', 'pdf'], true)) {
        fail_response('Screening hanya mendukung DOCX dan PDF');
    }

    $tmpDir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'sipora_screening';
    if (!is_dir($tmpDir) && !mkdir($tmpDir, 0777, true) && !is_dir($tmpDir)) {
        fail_response('Gagal membuat direktori sementara screening', 500);
    }

    $fileName = 'screen-' . date('YmdHis') . '-' . mt_rand(1000, 9999) . '.' . $extension;
    $tmpPath = $tmpDir . DIRECTORY_SEPARATOR . $fileName;

    if (file_put_contents($tmpPath, $binary) === false) {
        fail_response('Gagal menulis file sementara screening', 500);
    }

    return $tmpPath;
}

function run_document_screening(string $inputPath, string $tipeDokumen): array
{
    $scriptPath = __DIR__ . DIRECTORY_SEPARATOR . 'screening' . DIRECTORY_SEPARATOR . 'document_screening.py';
    if (!is_file($scriptPath)) {
        fail_response('Script screening Python tidak ditemukan', 500);
    }

    $pythonExecutable = trim((string)getenv('PYTHON_EXECUTABLE'));
    if ($pythonExecutable === '') {
        $pythonExecutable = 'python';
    }

    $command =
        escapeshellarg($pythonExecutable) .
        ' ' . escapeshellarg($scriptPath) .
        ' --input ' . escapeshellarg($inputPath) .
        ' --type ' . escapeshellarg($tipeDokumen);

    $output = [];
    $exitCode = 1;
    exec($command . ' 2>&1', $output, $exitCode);

    if ($exitCode !== 0) {
        $errorLog = implode("\n", array_slice($output, -12));
        fail_response('Screening OCR/YOLOv8 gagal dijalankan: ' . $errorLog, 500);
    }

    $rawJson = trim(implode("\n", $output));
    $decoded = json_decode($rawJson, true);
    if (!is_array($decoded)) {
        fail_response('Output screening Python tidak valid: ' . $rawJson, 500);
    }

    return $decoded;
}

function publication_status_where(string $statusExpr = 'msd.nama_status'): string
{
    // Keep only documents that are explicitly marked as published.
    $lowerExpr = 'LOWER(TRIM(' . $statusExpr . '))';
    return "($lowerExpr = 'publikasi' OR $lowerExpr = 'published' OR $lowerExpr LIKE '%publikasi%' OR $lowerExpr LIKE '%publish%')";
}

function ensure_push_tables(mysqli $conn): void
{
    $tokenTable = "
        CREATE TABLE IF NOT EXISTS user_fcm_tokens (
            id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            user_id INT UNSIGNED NULL,
            email VARCHAR(190) NULL,
            token TEXT NOT NULL,
            platform VARCHAR(32) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY unique_token (token(191)),
            KEY idx_user_email (user_id, email(191))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ";

    $notificationTable = "
        CREATE TABLE IF NOT EXISTS user_notifications (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            user_id INT UNSIGNED NULL,
            email VARCHAR(190) NULL,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            data_json LONGTEXT NULL,
            is_read TINYINT(1) NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            KEY idx_user_email (user_id, email(191)),
            KEY idx_read_created (is_read, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ";

    if (!$conn->query($tokenTable)) {
        fail_response('Gagal menyiapkan tabel token push: ' . $conn->error, 500);
    }

    if (!$conn->query($notificationTable)) {
        fail_response('Gagal menyiapkan tabel notifikasi: ' . $conn->error, 500);
    }
}

function store_notification(mysqli $conn, ?int $userId, ?string $email, string $title, string $message, array $data = []): int
{
    ensure_push_tables($conn);

    $json = !empty($data) ? json_encode($data, JSON_UNESCAPED_UNICODE) : null;
    $insert = $conn->prepare('INSERT INTO user_notifications (user_id, email, title, message, data_json) VALUES (?, ?, ?, ?, ?)');
    if (!$insert) {
        fail_response('Gagal menyiapkan notifikasi: ' . $conn->error, 500);
    }

    $normalizedEmail = $email !== null ? trim($email) : null;
    $insert->bind_param('issss', $userId, $normalizedEmail, $title, $message, $json);
    if (!$insert->execute()) {
        fail_response('Gagal menyimpan notifikasi: ' . $insert->error, 500);
    }

    return (int)$conn->insert_id;
}

function get_user_tokens(mysqli $conn, ?int $userId, ?string $email): array
{
    ensure_push_tables($conn);

    $tokens = [];
    $normalizedEmail = $email !== null ? trim($email) : '';

    if ($userId === null && $normalizedEmail === '') {
        return $tokens;
    }

    if ($userId !== null && $normalizedEmail !== '') {
        $stmt = $conn->prepare('SELECT token FROM user_fcm_tokens WHERE user_id = ? OR email = ? ORDER BY updated_at DESC');
        if (!$stmt) {
            fail_response('Gagal mengambil token push: ' . $conn->error, 500);
        }
        $stmt->bind_param('is', $userId, $normalizedEmail);
    } elseif ($userId !== null) {
        $stmt = $conn->prepare('SELECT token FROM user_fcm_tokens WHERE user_id = ? ORDER BY updated_at DESC');
        if (!$stmt) {
            fail_response('Gagal mengambil token push: ' . $conn->error, 500);
        }
        $stmt->bind_param('i', $userId);
    } else {
        $stmt = $conn->prepare('SELECT token FROM user_fcm_tokens WHERE email = ? ORDER BY updated_at DESC');
        if (!$stmt) {
            fail_response('Gagal mengambil token push: ' . $conn->error, 500);
        }
        $stmt->bind_param('s', $normalizedEmail);
    }

    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $token = trim((string)($row['token'] ?? ''));
        if ($token !== '') {
            $tokens[] = $token;
        }
    }

    return array_values(array_unique($tokens));
}

function send_fcm_push(array $tokens, string $title, string $message, array $data = []): bool
{
    $serverKey = trim((string)getenv('FCM_SERVER_KEY'));
    if ($serverKey === '' || count($tokens) === 0 || !function_exists('curl_init')) {
        return false;
    }

    $payload = json_encode([
        'registration_ids' => array_values($tokens),
        'priority' => 'high',
        'notification' => [
            'title' => $title,
            'body' => $message,
        ],
        'data' => $data,
    ], JSON_UNESCAPED_UNICODE);

    if ($payload === false) {
        return false;
    }

    $curl = curl_init('https://fcm.googleapis.com/fcm/send');
    curl_setopt_array($curl, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'Authorization: key=' . $serverKey,
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_TIMEOUT => 15,
    ]);

    $response = curl_exec($curl);
    $curlError = curl_error($curl);
    $statusCode = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
    curl_close($curl);

    if ($response === false || $curlError !== '' || $statusCode < 200 || $statusCode >= 300) {
        return false;
    }

    return true;
}

function upsert_fcm_token(mysqli $conn, ?int $userId, ?string $email, string $token, ?string $platform = null): void
{
    ensure_push_tables($conn);

    $lookup = $conn->prepare('SELECT id FROM user_fcm_tokens WHERE token = ? LIMIT 1');
    if (!$lookup) {
        fail_response('Gagal menyiapkan lookup token: ' . $conn->error, 500);
    }
    $lookup->bind_param('s', $token);
    $lookup->execute();
    $existing = $lookup->get_result()->fetch_assoc();

    $normalizedEmail = $email !== null ? trim($email) : null;
    $normalizedPlatform = $platform !== null ? trim($platform) : null;

    if ($existing) {
        $update = $conn->prepare('UPDATE user_fcm_tokens SET user_id = ?, email = ?, platform = ?, updated_at = CURRENT_TIMESTAMP WHERE token = ?');
        if (!$update) {
            fail_response('Gagal menyiapkan update token: ' . $conn->error, 500);
        }
        $update->bind_param('isss', $userId, $normalizedEmail, $normalizedPlatform, $token);
        if (!$update->execute()) {
            fail_response('Gagal memperbarui token push: ' . $update->error, 500);
        }
        return;
    }

    $insert = $conn->prepare('INSERT INTO user_fcm_tokens (user_id, email, token, platform) VALUES (?, ?, ?, ?)');
    if (!$insert) {
        fail_response('Gagal menyiapkan simpan token: ' . $conn->error, 500);
    }
    $insert->bind_param('isss', $userId, $normalizedEmail, $token, $normalizedPlatform);
    if (!$insert->execute()) {
        fail_response('Gagal menyimpan token push: ' . $insert->error, 500);
    }
}

function fetch_user_notifications(mysqli $conn, ?int $userId, ?string $email): array
{
    ensure_push_tables($conn);

    $notifications = [];
    $normalizedEmail = $email !== null ? trim($email) : '';

    if ($userId === null && $normalizedEmail === '') {
        return $notifications;
    }

    if ($userId !== null && $normalizedEmail !== '') {
        $stmt = $conn->prepare(
            'SELECT id, title, message, data_json, is_read, created_at FROM user_notifications WHERE user_id = ? OR email = ? ORDER BY created_at DESC LIMIT 50'
        );
        if (!$stmt) {
            fail_response('Gagal menyiapkan daftar notifikasi: ' . $conn->error, 500);
        }
        $stmt->bind_param('is', $userId, $normalizedEmail);
    } elseif ($userId !== null) {
        $stmt = $conn->prepare(
            'SELECT id, title, message, data_json, is_read, created_at FROM user_notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50'
        );
        if (!$stmt) {
            fail_response('Gagal menyiapkan daftar notifikasi: ' . $conn->error, 500);
        }
        $stmt->bind_param('i', $userId);
    } else {
        $stmt = $conn->prepare(
            'SELECT id, title, message, data_json, is_read, created_at FROM user_notifications WHERE email = ? ORDER BY created_at DESC LIMIT 50'
        );
        if (!$stmt) {
            fail_response('Gagal menyiapkan daftar notifikasi: ' . $conn->error, 500);
        }
        $stmt->bind_param('s', $normalizedEmail);
    }

    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $data = [];
        if (!empty($row['data_json'])) {
            $decoded = json_decode((string)$row['data_json'], true);
            if (is_array($decoded)) {
                $data = $decoded;
            }
        }

        $notifications[] = [
            'id' => (string)$row['id'],
            'title' => $row['title'],
            'message' => $row['message'],
            'time' => $row['created_at'],
            'isRead' => (int)$row['is_read'] === 1,
            'data' => $data,
        ];
    }

    return $notifications;
}

switch ($action) {
    case 'dashboard':
        $statusFilter = publication_status_where('msd.nama_status');
        $totalDokumen = (int)scalar_query($conn, "
            SELECT COUNT(*)
            FROM dokumen d
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
            WHERE $statusFilter
        ");
        $penggunaAktif = (int)scalar_query($conn, "SELECT COUNT(*) FROM users WHERE status = 'approved'");
        $uploadBaru = (int)scalar_query($conn, "
            SELECT COUNT(*)
            FROM dokumen d
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
            WHERE DATE(d.tgl_unggah) = CURDATE() AND $statusFilter
        ");
        $totalPenulis = (int)scalar_query($conn, 'SELECT COUNT(*) FROM master_author');

        $recentSql = "
            SELECT
                d.dokumen_id,
                d.judul,
                d.file_path,
                DATE_FORMAT(d.tgl_unggah, '%d %b %Y') AS tanggal,
                COALESCE(msd.nama_status, 'Dokumen') AS kategori,
                COALESCE(u.nama_lengkap, 'Unknown') AS uploader,
                COUNT(da.author_id) AS author_count
            FROM dokumen d
            LEFT JOIN users u ON u.id_user = d.uploader_id
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
            LEFT JOIN dokumen_author da ON da.dokumen_id = d.dokumen_id
            WHERE $statusFilter
            GROUP BY d.dokumen_id, d.judul, tanggal, kategori, uploader
            ORDER BY d.tgl_unggah DESC
            LIMIT 5
        ";
        $recentResult = $conn->query($recentSql);
        if (!$recentResult) {
            fail_response('Gagal mengambil dokumen terbaru: ' . $conn->error, 500);
        }

        $recent = [];
        while ($row = $recentResult->fetch_assoc()) {
            $recent[] = [
                'id' => (int)$row['dokumen_id'],
                'title' => $row['judul'],
                'author' => $row['uploader'],
                'downloads' => (int)$row['author_count'],
                'date' => $row['tanggal'] ?? '-',
                'category' => $row['kategori'],
                'file_path' => $row['file_path'] ?? ''
            ];
        }

        $topTopics = [];
        $topicSql = "
            SELECT keyword, COUNT(*) AS total
            FROM search_history
            WHERE keyword IS NOT NULL AND TRIM(keyword) <> ''
            GROUP BY keyword
            ORDER BY total DESC, keyword ASC
            LIMIT 10
        ";
        $topicResult = $conn->query($topicSql);
        if ($topicResult) {
            while ($topic = $topicResult->fetch_assoc()) {
                $topTopics[] = [
                    'topic' => $topic['keyword'],
                    'count' => (int)$topic['total']
                ];
            }
        }

        if (count($topTopics) === 0) {
            $fallbackSql = "
                SELECT keyword, search_count AS total
                FROM trending_keywords
                WHERE keyword IS NOT NULL AND TRIM(keyword) <> ''
                ORDER BY search_count DESC, keyword ASC
                LIMIT 10
            ";
            $fallbackResult = $conn->query($fallbackSql);
            if ($fallbackResult) {
                while ($topic = $fallbackResult->fetch_assoc()) {
                    $topTopics[] = [
                        'topic' => $topic['keyword'],
                        'count' => (int)$topic['total']
                    ];
                }
            }
        }

        success_response([
            'stats' => [
                'total_dokumen' => $totalDokumen,
                'pengguna_aktif' => $penggunaAktif,
                'upload_baru' => $uploadBaru,
                'total_penulis' => $totalPenulis
            ],
            'recent_documents' => $recent,
            'top_topics' => $topTopics
        ]);
        break;

    case 'browse_documents':
        $year = trim($_GET['year'] ?? '');
        $jurusan = trim($_GET['jurusan'] ?? '');
        $prodi = trim($_GET['prodi'] ?? '');
        $statusFilter = publication_status_where('msd.nama_status');

        $sql = "
            SELECT
                d.dokumen_id,
                d.judul,
                d.file_path,
                DATE_FORMAT(d.tgl_unggah, '%d %M %Y') AS tanggal,
                COALESCE(msd.nama_status, 'Dokumen') AS tipe,
                COALESCE(mj.nama_jurusan, '-') AS jurusan,
                COALESCE(mp.nama_prodi, '-') AS prodi,
                COALESCE(u.nama_lengkap, 'Unknown') AS uploader,
                COUNT(da.author_id) AS downloads
            FROM dokumen d
            LEFT JOIN users u ON u.id_user = d.uploader_id
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
            LEFT JOIN master_jurusan mj ON mj.id_jurusan = d.id_jurusan
            LEFT JOIN master_prodi mp ON mp.id_prodi = d.id_prodi
            LEFT JOIN master_tahun mt ON mt.year_id = d.year_id
            LEFT JOIN dokumen_author da ON da.dokumen_id = d.dokumen_id
            WHERE $statusFilter
        ";

        if ($year !== '') {
            $safeYear = $conn->real_escape_string($year);
            $sql .= " AND mt.tahun = '$safeYear'";
        }
        if ($jurusan !== '') {
            $safeJurusan = $conn->real_escape_string($jurusan);
            $sql .= " AND mj.nama_jurusan = '$safeJurusan'";
        }
        if ($prodi !== '') {
            $safeProdi = $conn->real_escape_string($prodi);
            $sql .= " AND mp.nama_prodi = '$safeProdi'";
        }

        $sql .= "
            GROUP BY d.dokumen_id, d.judul, tanggal, tipe, jurusan, prodi, uploader
            ORDER BY d.tgl_unggah DESC
            LIMIT 40
        ";

        $result = $conn->query($sql);
        if (!$result) {
            fail_response('Gagal mengambil data jelajahi: ' . $conn->error, 500);
        }

        $rows = [];
        while ($row = $result->fetch_assoc()) {
            $rows[] = [
                'id' => (int)$row['dokumen_id'],
                'title' => $row['judul'],
                'author' => $row['uploader'],
                'date' => $row['tanggal'] ?? '-',
                'downloads' => (int)$row['downloads'],
                'type' => $row['tipe'],
                'status' => $row['jurusan'],
                'prodi' => $row['prodi'],
                'file_path' => $row['file_path'] ?? ''
            ];
        }

        success_response(['documents' => $rows]);
        break;

    case 'search_overview':
        $recent = [];
        $recentRes = $conn->query("SELECT keyword FROM search_history ORDER BY created_at DESC LIMIT 8");
        if ($recentRes) {
            while ($r = $recentRes->fetch_assoc()) {
                $recent[] = $r['keyword'];
            }
        }

        $trending = [];
        $trendingRes = $conn->query("SELECT keyword FROM trending_keywords ORDER BY search_count DESC, last_searched DESC LIMIT 8");
        if ($trendingRes) {
            while ($t = $trendingRes->fetch_assoc()) {
                $trending[] = $t['keyword'];
            }
        }

        $shortcuts = [];
        $shortcutSql = "
            SELECT COALESCE(mj.nama_jurusan, 'Lainnya') AS label, COUNT(*) AS total
            FROM dokumen d
            LEFT JOIN master_jurusan mj ON mj.id_jurusan = d.id_jurusan
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
            WHERE " . publication_status_where('msd.nama_status') . "
            GROUP BY label
            ORDER BY total DESC
            LIMIT 6
        ";
        $shortcutRes = $conn->query($shortcutSql);
        if ($shortcutRes) {
            while ($s = $shortcutRes->fetch_assoc()) {
                $shortcuts[] = [
                    'label' => $s['label'],
                    'count' => (int)$s['total']
                ];
            }
        }

        success_response([
            'recent_searches' => $recent,
            'trending_topics' => $trending,
            'shortcuts' => $shortcuts
        ]);
        break;

    case 'search_documents':
        $input = read_json_input();
        $keyword = trim(($input['keyword'] ?? '') . '');
        if ($keyword === '') {
            fail_response('Keyword pencarian wajib diisi');
        }

        $store = $conn->prepare('INSERT INTO search_history (user_id, keyword) VALUES (?, ?)');
        if ($store) {
            $uid = 0;
            $store->bind_param('is', $uid, $keyword);
            $store->execute();
        }

        $searchLike = '%' . $keyword . '%';
        $stmt = $conn->prepare(
            "
            SELECT
                d.dokumen_id,
                d.judul,
                d.file_path,
                COALESCE(u.nama_lengkap, '-') AS author,
                DATE_FORMAT(d.tgl_unggah, '%d %M %Y') AS tanggal,
                COALESCE(msd.nama_status, 'Dokumen') AS kategori
            FROM dokumen d
            LEFT JOIN users u ON u.id_user = d.uploader_id
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
                        WHERE (d.judul LIKE ? OR d.abstrak LIKE ?)
                            AND " . publication_status_where('msd.nama_status') . "
            ORDER BY d.tgl_unggah DESC
            LIMIT 30
            "
        );
        if (!$stmt) {
            fail_response('Gagal menyiapkan pencarian: ' . $conn->error, 500);
        }

        $stmt->bind_param('ss', $searchLike, $searchLike);
        $stmt->execute();
        $result = $stmt->get_result();

        $documents = [];
        while ($row = $result->fetch_assoc()) {
            $documents[] = [
                'id' => (int)$row['dokumen_id'],
                'title' => $row['judul'],
                'author' => $row['author'],
                'date' => $row['tanggal'],
                'category' => $row['kategori'],
                'file_path' => $row['file_path'] ?? ''
            ];
        }

        success_response(['documents' => $documents]);
        break;

    case 'lookup_options':
        $tahun = [];
        $resTahun = $conn->query('SELECT year_id, tahun FROM master_tahun ORDER BY tahun DESC');
        if ($resTahun) {
            while ($r = $resTahun->fetch_assoc()) {
                $tahun[] = $r['tahun'];
            }
        }

        $jurusan = [];
        $resJurusan = $conn->query('SELECT id_jurusan, nama_jurusan FROM master_jurusan ORDER BY nama_jurusan ASC');
        if ($resJurusan) {
            while ($r = $resJurusan->fetch_assoc()) {
                $jurusan[] = $r['nama_jurusan'];
            }
        }

        $prodi = [];
        $resProdi = $conn->query('SELECT id_prodi, nama_prodi FROM master_prodi ORDER BY nama_prodi ASC');
        if ($resProdi) {
            while ($r = $resProdi->fetch_assoc()) {
                $prodi[] = $r['nama_prodi'];
            }
        }

        $divisi = [];
        $resDivisi = $conn->query('SELECT id_divisi, nama_divisi FROM master_divisi ORDER BY nama_divisi ASC');
        if ($resDivisi) {
            while ($r = $resDivisi->fetch_assoc()) {
                $divisi[] = $r['nama_divisi'];
            }
        }

        $tema = [];
        $resTema = $conn->query('SELECT id_tema, nama_tema FROM master_tema ORDER BY nama_tema ASC');
        if ($resTema) {
            while ($r = $resTema->fetch_assoc()) {
                $tema[] = $r['nama_tema'];
            }
        }

        $statusDokumen = [];
        $resStatus = $conn->query('SELECT status_id, nama_status FROM master_status_dokumen ORDER BY nama_status ASC');
        if ($resStatus) {
            while ($r = $resStatus->fetch_assoc()) {
                $statusDokumen[] = $r['nama_status'];
            }
        }

        success_response([
            'tahun' => $tahun,
            'jurusan' => $jurusan,
            'prodi' => $prodi,
            'divisi' => $divisi,
            'tema' => $tema,
            'tipe_dokumen' => $statusDokumen
        ]);
        break;

    case 'login':
        $input = read_json_input();
        $emailOrUsername = trim(($input['email'] ?? '') . '');
        $password = trim(($input['password'] ?? '') . '');

        if ($emailOrUsername === '' || $password === '') {
            fail_response('Email/username dan password wajib diisi');
        }

        $stmt = $conn->prepare('SELECT id_user, nama_lengkap, email, username, role, status, password_hash FROM users WHERE email = ? OR username = ? LIMIT 1');
        if (!$stmt) {
            fail_response('Gagal menyiapkan login: ' . $conn->error, 500);
        }
        $stmt->bind_param('ss', $emailOrUsername, $emailOrUsername);
        $stmt->execute();
        $res = $stmt->get_result();
        $user = $res->fetch_assoc();

        if (!$user) {
            fail_response('Akun tidak ditemukan', 401);
        }

        $passwordValid = password_verify($password, $user['password_hash']) || $password === $user['password_hash'];
        if (!$passwordValid) {
            fail_response('Password salah', 401);
        }

        success_response([
            'user' => [
                'id_user' => (int)$user['id_user'],
                'nama_lengkap' => $user['nama_lengkap'],
                'email' => $user['email'],
                'username' => $user['username'],
                'role' => $user['role'],
                'status' => $user['status']
            ]
        ]);
        break;

    case 'register':
        $input = read_json_input();
        $nama = trim(($input['nama_lengkap'] ?? '') . '');
        $nim = trim(($input['nim'] ?? '') . '');
        $email = trim(($input['email'] ?? '') . '');
        $username = trim(($input['username'] ?? '') . '');
        $password = trim(($input['password'] ?? '') . '');

        if ($nama === '' || $nim === '' || $email === '' || $username === '' || $password === '') {
            fail_response('Semua field registrasi wajib diisi');
        }

        $check = $conn->prepare('SELECT id_user FROM users WHERE email = ? OR username = ? OR nim = ? LIMIT 1');
        if (!$check) {
            fail_response('Gagal menyiapkan validasi registrasi: ' . $conn->error, 500);
        }
        $check->bind_param('sss', $email, $username, $nim);
        $check->execute();
        $exists = $check->get_result()->fetch_assoc();
        if ($exists) {
            fail_response('Email/username/NIM sudah terdaftar');
        }

        $hash = password_hash($password, PASSWORD_BCRYPT);
        $role = 'pengguna';
        $status = 'pending';

        $insert = $conn->prepare('INSERT INTO users (nama_lengkap, nim, email, username, password_hash, role, status) VALUES (?, ?, ?, ?, ?, ?, ?)');
        if (!$insert) {
            fail_response('Gagal menyiapkan registrasi: ' . $conn->error, 500);
        }
        $insert->bind_param('sssssss', $nama, $nim, $email, $username, $hash, $role, $status);

        if (!$insert->execute()) {
            fail_response('Registrasi gagal: ' . $insert->error, 500);
        }

        success_response([
            'message' => 'Registrasi berhasil',
            'user_id' => (int)$conn->insert_id
        ]);
        break;

    case 'upload_document':
        $input = read_json_input();
        $judul = trim(($input['judul'] ?? '') . '');
        $abstrak = trim(($input['abstrak'] ?? '') . '');
        $filePathInput = trim(($input['file_path'] ?? '') . '');
        $originalFileName = trim(($input['original_file_name'] ?? $filePathInput) . '');
        $fileBytesBase64 = trim(($input['file_bytes_base64'] ?? '') . '');
        $uploaderId = (int)($input['uploader_id'] ?? 1);
        $tahun = trim(($input['tahun'] ?? '') . '');
        $jurusan = trim(($input['jurusan'] ?? '') . '');
        $prodi = trim(($input['prodi'] ?? '') . '');
        $divisi = trim(($input['divisi'] ?? '') . '');
        $tema = trim(($input['tema'] ?? '') . '');
        $statusDokumen = trim(($input['tipe_dokumen'] ?? '') . '');
        $kataKunci = is_array($input['kata_kunci'] ?? null) ? $input['kata_kunci'] : [];
        $penulis = is_array($input['penulis'] ?? null) ? $input['penulis'] : [];
        $turnitin = (int)($input['turnitin'] ?? 0);
        $uploaderEmail = trim(($input['uploader_email'] ?? '') . '');

        if ($judul === '' || $originalFileName === '') {
            fail_response('Judul dan file dokumen wajib diisi');
        }

        $filePath = $filePathInput;
        if ($fileBytesBase64 !== '') {
            $filePath = store_document_file($fileBytesBase64, $originalFileName);
        }

        $yearId = 0;
        if ($tahun !== '') {
            $stmtYear = $conn->prepare('SELECT year_id FROM master_tahun WHERE tahun = ? LIMIT 1');
            if ($stmtYear) {
                $stmtYear->bind_param('s', $tahun);
                $stmtYear->execute();
                $resYear = $stmtYear->get_result()->fetch_assoc();
                $yearId = $resYear ? (int)$resYear['year_id'] : 0;
            }
        }

        $jurusanId = find_id_by_name($conn, 'master_jurusan', 'id_jurusan', 'nama_jurusan', $jurusan);
        $prodiId = find_id_by_name($conn, 'master_prodi', 'id_prodi', 'nama_prodi', $prodi);
        $divisiId = find_id_by_name($conn, 'master_divisi', 'id_divisi', 'nama_divisi', $divisi);
        $temaId = find_id_by_name($conn, 'master_tema', 'id_tema', 'nama_tema', $tema);
        $statusId = find_id_by_name($conn, 'master_status_dokumen', 'status_id', 'nama_status', $statusDokumen);

        $turnitinFile = trim(($input['turnitin_file'] ?? '') . '');

        $insertDoc = $conn->prepare(
            'INSERT INTO dokumen (judul, abstrak, turnitin, turnitin_file, kata_kunci, file_path, uploader_id, id_tema, id_jurusan, id_prodi, id_divisi, year_id, status_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );

        if (!$insertDoc) {
            fail_response('Gagal menyiapkan upload dokumen: ' . $conn->error, 500);
        }

        $keywordsJoined = implode(', ', array_map('trim', $kataKunci));
        $temaBind = $temaId ?: null;
        $jurBind = $jurusanId ?: null;
        $prodiBind = $prodiId ?: null;
        $divBind = $divisiId ?: null;
        $yearBind = $yearId ?: null;
        $statusBind = $statusId ?: null;

        $insertDoc->bind_param(
            'ssisssiiiiiii',
            $judul,
            $abstrak,
            $turnitin,
            $turnitinFile,
            $keywordsJoined,
            $filePath,
            $uploaderId,
            $temaBind,
            $jurBind,
            $prodiBind,
            $divBind,
            $yearBind,
            $statusBind
        );

        if (!$insertDoc->execute()) {
            fail_response('Gagal menyimpan dokumen: ' . $insertDoc->error, 500);
        }

        $dokumenId = (int)$conn->insert_id;

        foreach ($penulis as $namaPenulisRaw) {
            $namaPenulis = trim((string)$namaPenulisRaw);
            if ($namaPenulis === '') {
                continue;
            }
            $authorId = find_or_create_id($conn, 'master_author', 'author_id', 'nama_author', $namaPenulis);
            $linkAuthor = $conn->prepare('INSERT INTO dokumen_author (dokumen_id, author_id) VALUES (?, ?)');
            if ($linkAuthor) {
                $linkAuthor->bind_param('ii', $dokumenId, $authorId);
                $linkAuthor->execute();
            }
        }

        foreach ($kataKunci as $keywordRaw) {
            $keyword = trim((string)$keywordRaw);
            if ($keyword === '') {
                continue;
            }
            $keywordId = find_or_create_id($conn, 'master_keyword', 'keyword_id', 'nama_keyword', $keyword);
            $linkKeyword = $conn->prepare('INSERT INTO dokumen_keyword (dokumen_id, keyword_id) VALUES (?, ?)');
            if ($linkKeyword) {
                $linkKeyword->bind_param('ii', $dokumenId, $keywordId);
                $linkKeyword->execute();
            }
        }

        if ($uploaderEmail !== '') {
            $notificationId = store_notification(
                $conn,
                $uploaderId > 0 ? $uploaderId : null,
                $uploaderEmail,
                'Dokumen berhasil diunggah',
                'Dokumen "' . $judul . '" berhasil disimpan dan menunggu proses berikutnya.',
                [
                    'type' => 'document_uploaded',
                    'dokumen_id' => $dokumenId,
                    'judul' => $judul,
                ]
            );

            $tokens = get_user_tokens($conn, $uploaderId > 0 ? $uploaderId : null, $uploaderEmail);
            send_fcm_push(
                $tokens,
                'Dokumen berhasil diunggah',
                'Dokumen "' . $judul . '" berhasil disimpan.',
                [
                    'notification_id' => (string)$notificationId,
                    'type' => 'document_uploaded',
                    'dokumen_id' => (string)$dokumenId,
                    'judul' => $judul,
                ]
            );
        }

        success_response([
            'message' => 'Dokumen berhasil disimpan',
            'dokumen_id' => $dokumenId
        ]);
        break;

    case 'register_push_token':
        $input = read_json_input();
        $token = trim(($input['token'] ?? '') . '');
        $email = trim(($input['email'] ?? '') . '');
        $platform = trim(($input['platform'] ?? '') . '');
        $userId = (int)($input['user_id'] ?? 0);

        if ($token === '') {
            fail_response('Token push wajib diisi');
        }

        upsert_fcm_token(
            $conn,
            $userId > 0 ? $userId : null,
            $email !== '' ? $email : null,
            $token,
            $platform !== '' ? $platform : null
        );

        success_response([
            'message' => 'Token push berhasil disimpan'
        ]);
        break;

    case 'notifications':
        $email = trim(($_GET['email'] ?? '') . '');
        $userId = (int)($_GET['user_id'] ?? 0);

        $notifications = fetch_user_notifications(
            $conn,
            $userId > 0 ? $userId : null,
            $email !== '' ? $email : null
        );

        success_response([
            'notifications' => $notifications
        ]);
        break;

    case 'screen_document':
        $input = read_json_input();
        $originalFileName = trim(($input['original_file_name'] ?? '') . '');
        $fileBytesBase64 = trim(($input['file_bytes_base64'] ?? '') . '');
        $tipeDokumen = trim(($input['tipe_dokumen'] ?? '') . '');

        if ($originalFileName === '' || $fileBytesBase64 === '') {
            fail_response('Nama file dan isi file wajib diisi');
        }

        if ($tipeDokumen === '') {
            $tipeDokumen = 'umum';
        }

        $tmpPath = create_temp_screening_file($fileBytesBase64, $originalFileName);
        try {
            $screening = run_document_screening($tmpPath, $tipeDokumen);
            success_response([
                'screening' => $screening
            ]);
        } finally {
            if (is_file($tmpPath)) {
                @unlink($tmpPath);
            }
        }
        break;

    default:
        fail_response('Action API tidak dikenali', 404);
}
