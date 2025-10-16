<?php
// proxy.php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');              // jednoduché CORS
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
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
  http_response_code(400);
  echo json_encode(['error' => 'Missing url or pwd']);
  exit;
}

// (volitelně) Whitelist: povol jen privátní sítě
// Pokud chceš striktně jen privátní IP, odkomentuj:
/*
if (!preg_match('~^https?://(10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.)~', $url)) {
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
  http_response_code(502);
  echo json_encode([
    'error'   => 'Upstream request failed',
    'details' => $err,
    'status'  => $status,
  ]);
  exit;
}

// Vrátíme přímo raw JSON od střídače
echo $response;
