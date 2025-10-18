<?php
declare(strict_types=1);

/**
 * fve_config.php
 * Jednoduché SQLite API pro uložení/načtení konfigurací FVE podle SN.
 * Umísti do stejné složky jako proxy.php (nebo uprav $DB_PATH).
 */

header('Content-Type: application/json; charset=utf-8');

try {
    // === Nastavení cesty k DB ===
    // Pokud máš už nějaký sjednocený path (např. jako v proxy.php), uprav zde:
    //$DB_PATH = __DIR__ . 'data/sqlite/solax_logs.sqlite';
    // --- SQLite logging bootstrap ---
    $DB_PATH = getenv('SLX_DB_PATH') ?: (__DIR__ . '/solax_logs.sqlite');

    $pdo = new PDO('sqlite:' . $DB_PATH, null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    initSchema($pdo);

    // Router
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST') {
        $raw = file_get_contents('php://input') ?: '';
        $data = json_decode($raw, true);
        if (!is_array($data)) {
            // fallback: form-urlencoded
            $data = $_POST;
        }
        $action = $data['action'] ?? '';
        if ($action === 'save') {
            $payload = $data['data'] ?? [];
            echo json_encode(saveConfig($pdo, $payload));
            exit;
        }
        throw new RuntimeException('Unsupported POST action.');
    } else {
        $action = $_GET['action'] ?? 'list';
        if ($action === 'list') {
            echo json_encode(listConfigs($pdo));
            exit;
        } elseif ($action === 'get') {
            $sn = trim((string)($_GET['sn'] ?? ''));
            echo json_encode(getConfig($pdo, $sn));
            exit;
        }
        throw new RuntimeException('Unsupported GET action.');
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['status'=>'err','error'=>$e->getMessage()]);
    exit;
}

// === Helpers ===

function initSchema(PDO $pdo): void {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS fve_config (
            sn TEXT PRIMARY KEY,
            apiUrl TEXT,
            delay INTEGER,
            debuglevel INTEGER,
            peak1 INTEGER,
            peak2 INTEGER,
            maxPower INTEGER,
            maxLoad INTEGER,
            BatteryMaxCapacity INTEGER,
            sendPwd INTEGER,
            passwd TEXT,
            proxy TEXT,
            updated_at TEXT
        )
    ");
}

/**
 * Uloží/aktualizuje konfiguraci (REPLACE INTO).
 * Očekává alespoň 'sn'.
 */
function saveConfig(PDO $pdo, array $cfg): array {
    $sn = trim((string)($cfg['sn'] ?? ''));
    if ($sn === '') {
        throw new InvalidArgumentException('Missing SN.');
    }

    // Připrav hodnoty (cast + defaulty)
    $apiUrl  = (string)($cfg['apiUrl'] ?? '');
    $delay   = (int)($cfg['delay'] ?? 4);
    $debug   = (int)($cfg['debuglevel'] ?? 0);
    $peak1   = (int)($cfg['peak1'] ?? 0);
    $peak2   = (int)($cfg['peak2'] ?? 0);
    $maxPow  = (int)($cfg['maxPower'] ?? 0);
    $maxLoad = (int)($cfg['maxLoad'] ?? 0);
    $bCap    = (int)($cfg['BatteryMaxCapacity'] ?? 0);
    $sendPwd = !empty($cfg['sendPwd']) ? 1 : 0;
    $passwd  = (string)($cfg['passwd'] ?? '');
    $proxy   = (string)($cfg['proxy'] ?? '');
    $ts      = (new DateTimeImmutable('now'))->format('Y-m-d H:i:s');

    $sql = "
        INSERT INTO fve_config (sn, apiUrl, delay, debuglevel, peak1, peak2, maxPower, maxLoad, BatteryMaxCapacity, sendPwd, passwd, proxy, updated_at)
        VALUES (:sn,:apiUrl,:delay,:debug,:peak1,:peak2,:maxPower,:maxLoad,:bcap,:sendPwd,:passwd,:proxy,:updated)
        ON CONFLICT(sn) DO UPDATE SET
            apiUrl=excluded.apiUrl,
            delay=excluded.delay,
            debuglevel=excluded.debuglevel,
            peak1=excluded.peak1,
            peak2=excluded.peak2,
            maxPower=excluded.maxPower,
            maxLoad=excluded.maxLoad,
            BatteryMaxCapacity=excluded.BatteryMaxCapacity,
            sendPwd=excluded.sendPwd,
            passwd=excluded.passwd,
            proxy=excluded.proxy,
            updated_at=excluded.updated_at
    ";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':sn'=>$sn, ':apiUrl'=>$apiUrl, ':delay'=>$delay, ':debug'=>$debug,
        ':peak1'=>$peak1, ':peak2'=>$peak2, ':maxPower'=>$maxPow, ':maxLoad'=>$maxLoad,
        ':bcap'=>$bCap, ':sendPwd'=>$sendPwd, ':passwd'=>$passwd, ':proxy'=>$proxy, ':updated'=>$ts
    ]);

    return ['status'=>'ok','sn'=>$sn];
}

/** Vrací seznam uložených SN (a timestamp). */
function listConfigs(PDO $pdo): array {
    $res = $pdo->query("SELECT sn, updated_at FROM fve_config ORDER BY updated_at DESC NULLS LAST, sn ASC")->fetchAll();
    return ['status'=>'ok','items'=>$res];
}

/** Vrátí konkrétní konfiguraci dle SN. */
function getConfig(PDO $pdo, string $sn): array {
    $sn = trim($sn);
    if ($sn === '') throw new InvalidArgumentException('Missing sn.');
    $stmt = $pdo->prepare("SELECT * FROM fve_config WHERE sn = :sn LIMIT 1");
    $stmt->execute([':sn'=>$sn]);
    $row = $stmt->fetch();
    if (!$row) return ['status'=>'ok','data'=>null];

    // Přetypovat pár věcí na čísla/bool pro frontend
    $row['delay'] = (int)$row['delay'];
    $row['debuglevel'] = (int)$row['debuglevel'];
    foreach (['peak1','peak2','maxPower','maxLoad','BatteryMaxCapacity'] as $k) {
        $row[$k] = (int)$row[$k];
    }
    $row['sendPwd'] = (int)$row['sendPwd'] === 1;

    return ['status'=>'ok','data'=>$row];
}
