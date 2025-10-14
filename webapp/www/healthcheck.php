<?php
// health.php — jednoduchý healthcheck endpoint

header('Content-Type: text/plain');

// 1️⃣ Ověření, že PHP běží
if (php_sapi_name() === false) {
    http_response_code(500);
    echo "PHP not responding\n";
    exit(1);
}

// 2️⃣ Ověření dostupnosti klíčových služeb (např. DB, Redis, apod.)
// (odkomentuj dle potřeby)
// try {
//     $db = new PDO('mysql:host=localhost;dbname=test', 'user', 'pass', [
//         PDO::ATTR_TIMEOUT => 1,
//     ]);
// } catch (Exception $e) {
//     http_response_code(500);
//     echo "DB connection failed\n";
//     exit(1);
// }

// 3️⃣ OK výsledek
http_response_code(200);
echo "OK\n";
