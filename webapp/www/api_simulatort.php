<?php
// solax.php — simple Solax API simulator
// Returns the next line from data.json (NDJSON). Cykluje po konci.
// Ignores auth/optType, just responds with the next JSON line.

declare(strict_types=1);

$baseDir = __DIR__;
$dataFile = $baseDir . '/api_simulator_data.json';
$stateDir = $baseDir . '/state';
$indexFile = $stateDir . '/index';

// CORS (optional, helpful for browser testing)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if (!is_dir($stateDir)) {
    @mkdir($stateDir, 0775, true);
    @chown($stateDir, posix_getuid());
}

// Read all non-empty lines from data.json
if (!file_exists($dataFile)) {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo "data.json not found";
    exit;
}

$lines = file($dataFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$lines = array_values(array_filter(array_map('trim', $lines), 'strlen'));
$count = count($lines);
if ($count === 0) {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo "data.json empty";
    exit;
}

// Ensure index file exists
if (!file_exists($indexFile)) {
    file_put_contents($indexFile, "0");
    @chmod($indexFile, 0664);
}

// Locking/read-update the index to be race-safe
$fp = fopen($indexFile, 'c+');
if (!$fp) {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo "Cannot open index file";
    exit;
}

flock($fp, LOCK_EX);

$raw = stream_get_contents($fp);
$pos = intval(trim($raw !== '' ? $raw : '0'));
if ($pos < 0) $pos = 0;
if ($pos >= $count) $pos = 0;

// Get the line to return
$line = $lines[$pos];

// advance and write new index (wrap)
$next = ($pos + 1) % $count;
rewind($fp);
ftruncate($fp, 0);
fwrite($fp, (string)$next);
fflush($fp);
flock($fp, LOCK_UN);
fclose($fp);

// Return the JSON line as response
header('Content-Type: application/json; charset=utf-8');
echo $line;
