<?php

// --- SQLite logging bootstrap ---
$__SLX_DB_PATH = getenv('SLX_DB_PATH') ?: (__DIR__ . '/solax_logs.sqlite');

try {
    $__slx_pdo = new PDO('sqlite:' . $__SLX_DB_PATH);
    $__slx_pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $__slx_pdo->exec("CREATE TABLE IF NOT EXISTS slx_responses (
        idsys TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        response_code INTEGER,
        data TEXT,
        PRIMARY KEY (idsys, timestamp)
    )");
} catch (Throwable $e) {
    $__slx_pdo = null;
}

function __slx_extract_idsys(): string {
    if (isset($_REQUEST['idsys']) && $_REQUEST['idsys'] !== '') {
        return (string)$_REQUEST['idsys'];
    }
    $raw = @file_get_contents('php://input');
    if ($raw) {
        $j = json_decode($raw, true);
        if (is_array($j)) {
            foreach (['idsys','system_id','id','sn','serial','serialNumber'] as $k) {
                if (isset($j[$k]) && $j[$k] !== '') return (string)$j[$k];
            }
        }
    }
    return 'unknown';
}

function __slx_log_response(?PDO $pdo, string $idsys, ?int $code = null, ?string $data = null): void {
    if (!$pdo) return;
    try {
        $ts = gmdate('c');
        $stmt = $pdo->prepare("INSERT OR REPLACE INTO slx_responses (idsys, timestamp, response_code, data) VALUES (:idsys, :ts, :code, :data)");
        $stmt->execute([
            ':idsys' => $idsys,
            ':ts' => $ts,
            ':code' => $code,
            ':data' => $data
        ]);
    } catch (Throwable $e) { /* ignore */ }
}

// --- Register shutdown hook to record result ---
$__slx_idsys = __slx_extract_idsys();
$__slx_http_code = null;
$__slx_body_out = null;

function __slx_set_http_code($code){ global $__slx_http_code; $__slx_http_code = (int)$code; }
function __slx_set_body_out($body){ global $__slx_body_out; $__slx_body_out = (string)$body; }

register_shutdown_function(function() use ($__slx_pdo) {
    global $__slx_idsys, $__slx_http_code, $__slx_body_out;
    if ($__slx_http_code === null) {
        $last = http_response_code();
        if ($last !== false) $__slx_http_code = (int)$last;
    }
    if ($__slx_http_code === null) {
        $__slx_http_code = $__slx_body_out !== null ? 200 : 500;
    }
    __slx_log_response($__slx_pdo, $__slx_idsys, $__slx_http_code, $__slx_body_out);
});

// proxy.php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');              // jednoduché CORS
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
  __slx_set_http_code(200);
http_response_code(200);
  exit;
}

// --- vstupy ---
$input = $_POST;
if (empty($input)) {
  // umožní i JSON POST
  $raw = file_get_contents('php://input');
  if ($raw) { $input = json_decode($raw, true) ?: []; }
}

$url = $input['target'] ?? '';
$pwd = $input['pwd'] ?? '';   // u některých modelů je to “registration no.”, u jiných skutečné heslo
$proxy = $input['proxy'] ?? '';

// --- základní validace ---
if (!$url || !$pwd) {
  __slx_set_http_code(400);
http_response_code(400);
  echo json_encode(['error' => 'Missing url or pwd']);
  exit;
}

// (volitelně) Whitelist: povol jen privátní sítě
// Pokud chceš striktně jen privátní IP, odkomentuj:
/*
if (!preg_match('~^https?://(10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.)~', $url)) {
  __slx_set_http_code(403);
http_response_code(403);
  echo json_encode(['error' => 'URL not allowed']);
  exit;
}
*/

// --- požadavek na střídač ---
$ch = curl_init();
curl_setopt_array($ch, [
  CURLOPT_URL            => $url,
  CURLOPT_RETURNTRANSFER => true,
  CURLOPT_POST           => true,
  CURLOPT_POSTFIELDS     => http_build_query([
    'optType' => 'ReadRealTimeData',
    'pwd'     => $pwd,
  ]),
  CURLOPT_TIMEOUT        => 5,   // můžeš upravit
]);

if ($proxy !== '') {
  curl_setopt($ch, CURLOPT_PROXY, $proxy);
} else {
  // vynutit "bez proxy" i když jsou nastavené HTTP(S)_PROXY v env
  curl_setopt($ch, CURLOPT_PROXY, '');
  if (defined('CURLOPT_NOPROXY')) {
    curl_setopt($ch, CURLOPT_NOPROXY, '*'); // pro jistotu
  }
}

$response = curl_exec($ch);
$errno    = curl_errno($ch);
$err      = curl_error($ch);
$status   = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($errno !== 0 || $status >= 400 || !$response) {
  __slx_set_http_code(502);
http_response_code(502);
  echo json_encode([
    'error'   => 'Upstream request failed',
    'details' => $err,
    'status'  => $status,
  ]);
  exit;
}

// Vrátíme přímo raw JSON od střídače
__slx_set_body_out($response);
echo $response;
