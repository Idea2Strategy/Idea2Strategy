[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TestEmail,
    [Parameter(Mandatory)][string]$TestPassword
)

$ErrorActionPreference = 'Stop'
$offlineNetwork = 'idea2strategy-offline-proof'
$developmentNetwork = 'idea2strategy-development'
$allApps = @(
    'idea2strategy-backend-api', 'idea2strategy-backend-worker',
    'idea2strategy-backend-batch', 'idea2strategy-admin-mcp',
    'idea2strategy-backtest-api', 'idea2strategy-backtest-worker',
    'idea2strategy-trading-worker', 'idea2strategy-frontend'
)
$offlineMembers = @(
    @{ Name = 'idea2strategy-postgres'; Alias = 'postgres' },
    @{ Name = 'idea2strategy-redis'; Alias = 'redis' },
    @{ Name = 'idea2strategy-minio'; Alias = 'minio' },
    @{ Name = 'idea2strategy-localstack'; Alias = 'localstack' },
    @{ Name = 'idea2strategy-backend-api'; Alias = 'backend-api' },
    @{ Name = 'idea2strategy-backend-worker'; Alias = 'backend-worker' },
    @{ Name = 'idea2strategy-backend-batch'; Alias = 'backend-batch' },
    @{ Name = 'idea2strategy-backtest-api'; Alias = 'backtest-api' },
    @{ Name = 'idea2strategy-backtest-worker'; Alias = 'backtest-worker' },
    @{ Name = 'idea2strategy-trading-worker'; Alias = 'trading-worker' }
)
$login = Invoke-RestMethod -Method Post -Uri 'http://localhost:15173/api/v1/auth/login' `
    -ContentType 'application/json' `
    -Body (@{ email = $TestEmail; password = $TestPassword } | ConvertTo-Json)
$accessToken = $login.accessToken
if (-not $accessToken) { throw 'Could not mint the short-lived offline proof token.' }
$probe = @'
import json, os, time, urllib.error, urllib.request

def call(url, token=None, body=None, *, method=None, extra_headers=None):
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    data = None if body is None else json.dumps(body).encode()
    if data:
        headers['Content-Type'] = 'application/json'
    if extra_headers:
        headers.update(extra_headers)
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = response.read()
        return None if not payload else json.loads(payload)

ready = False
for _ in range(60):
    try:
        with urllib.request.urlopen('http://backend-api:8080/actuator/health', timeout=5) as response:
            ready = response.status == 200
        if ready:
            break
    except Exception:
        time.sleep(2)
if not ready:
    raise RuntimeError('offline services did not become ready')

token = os.environ['I2S_ACCESS_TOKEN']
for _ in range(3):
    try:
        document = call('http://backend-api:8080/api/v1/strategies/9ec38a5c-efce-4146-b9e1-2ac880b35574/document', token)
        break
    except Exception:
        time.sleep(2)
else:
    raise RuntimeError('offline strategy document did not become ready')
instrument = document['presentationDocument']['basicEditor']['snapshot']['sections'][0]['instrumentIds'][0]
one = call(f'http://backend-api:8080/api/v1/market-data/instruments/{instrument}/bars?timeframe=4h&window=1m', token)
three = call(f'http://backend-api:8080/api/v1/market-data/instruments/{instrument}/bars?timeframe=4h&window=3m', token)
benchmarks = call('http://backend-api:8080/api/v1/market-data/benchmarks', token)
run = call('http://backtest-api:8082/api/v1/backtests/bc9a35d1-bec2-399a-88c5-b343ba57c854', token)
performance = call('http://backtest-api:8082/api/v1/backtests/bc9a35d1-bec2-399a-88c5-b343ba57c854/performance', token)

# A stored-result read is insufficient proof: create a fresh mixed-resolution run
# while every application container has only the internal Docker network. The fixed
# demo bot owns the current three-partition strategy (4h, 30m, 1d); Backend still
# performs official manifest selection and the worker must read the pinned Parquet.
proof_key = 'offline-proof-' + os.environ['I2S_PROOF_NONCE']
receipt = call(
    'http://backend-api:8080/api/v1/bots/9333718c-0d10-314d-bda9-9536eff2d705/backtests',
    token,
    {'periodStart': '2024-01-01', 'periodEnd': '2024-12-31'},
    extra_headers={'Idempotency-Key': proof_key},
)
if not receipt or not receipt.get('created'):
    raise RuntimeError('offline backtest request was not created')

fresh = None
deadline = time.monotonic() + 900
while time.monotonic() < deadline:
    listed = call('http://backtest-api:8082/api/v1/backtests?limit=200&offset=0', token)
    fresh = next((item for item in listed['items'] if item.get('idempotencyKey') == proof_key), None)
    if fresh and fresh['status'] in {'COMPLETED', 'FAILED', 'CANCELLED'}:
        break
    time.sleep(3)
if not fresh or fresh['status'] != 'COMPLETED':
    raise RuntimeError('offline backtest did not complete: ' + repr(fresh))

fresh_id = fresh['backtestRunId']
fresh_performance = call(f'http://backtest-api:8082/api/v1/backtests/{fresh_id}/performance', token)
fresh_inputs = call(f'http://backtest-api:8082/api/v1/backtests/{fresh_id}/inputs', token)
input_rows = fresh_inputs.get('datasets', fresh_inputs.get('items', []))
if len(input_rows) < 3:
    raise RuntimeError('offline mixed-resolution backtest did not retain all input pins')
call(f'http://backtest-api:8082/api/v1/backtests/{fresh_id}', token, method='DELETE')

print(json.dumps({
    'egressBlocked': True,
    'oneMonthBars': len(one['bars']),
    'threeMonthBars': len(three['bars']),
    'previewLast': one['availableTo'],
    'benchmarks': ','.join(item['symbol'] for item in benchmarks['instruments']),
    'backtestStatus': run['status'],
    'backtestReturn': performance['metricsDocument']['totalReturnPct'],
    'freshBacktestStatus': fresh['status'],
    'freshBacktestId': fresh_id,
    'freshInputPins': len(input_rows),
    'freshReturn': fresh_performance['metricsDocument']['totalReturnPct'],
    'freshSoftDeleted': True,
}, separators=(',', ':')))
'@

docker stop @allApps | Out-Null
docker network create --internal $offlineNetwork | Out-Null
$proofStartedAt = (Get-Date).ToUniversalTime().ToString('o')
try {
    foreach ($member in $offlineMembers) {
        docker network connect --alias $member.Alias $offlineNetwork $member.Name
    }
    foreach ($app in $allApps) {
        if ($app -eq 'idea2strategy-frontend' -or $app -eq 'idea2strategy-admin-mcp') { continue }
        docker network disconnect $developmentNetwork $app
    }
    docker start idea2strategy-backend-api idea2strategy-backend-worker `
        idea2strategy-backend-batch idea2strategy-backtest-api `
        idea2strategy-backtest-worker idea2strategy-trading-worker | Out-Null

    docker run --rm --network $offlineNetwork postgres:16-alpine sh -c `
        'wget -T 5 -q https://data.alpaca.markets -O /dev/null' *> $null
    if ($LASTEXITCODE -eq 0) { throw 'External provider remained reachable.' }

    $proofOutput = $probe | docker exec -i `
        -e "I2S_ACCESS_TOKEN=$accessToken" `
        -e "I2S_PROOF_NONCE=$([guid]::NewGuid().ToString('N'))" `
        idea2strategy-backtest-api python -
    if ($LASTEXITCODE -ne 0) { throw 'Offline in-network probe failed.' }

    $marketDomainPattern = 'alpaca|query1\.finance\.yahoo|data\.alpaca|api\.polygon|stooq'
    $externalDomainMentions = 0
    foreach ($app in $allApps) {
        if ($app -eq 'idea2strategy-frontend' -or $app -eq 'idea2strategy-admin-mcp') { continue }
        $mentions = docker logs --since $proofStartedAt $app 2>&1 |
            Select-String -Pattern $marketDomainPattern -CaseSensitive:$false
        $externalDomainMentions += @($mentions).Count
    }
    if ($externalDomainMentions -ne 0) {
        throw "Application logs referenced an external market provider $externalDomainMentions time(s)."
    }
    $proofResult = $proofOutput | ConvertFrom-Json
    $proofResult | Add-Member -NotePropertyName externalMarketDomainMentions -NotePropertyValue 0
    $proofResult | ConvertTo-Json -Compress
} finally {
    docker stop idea2strategy-backend-api idea2strategy-backend-worker `
        idea2strategy-backend-batch idea2strategy-backtest-api `
        idea2strategy-backtest-worker idea2strategy-trading-worker 2>$null | Out-Null
    foreach ($member in $offlineMembers) {
        if ($member.Name -in @('idea2strategy-postgres', 'idea2strategy-redis', 'idea2strategy-minio', 'idea2strategy-localstack')) { continue }
        docker network connect --alias $member.Alias $developmentNetwork $member.Name 2>$null | Out-Null
    }
    foreach ($member in $offlineMembers) {
        docker network disconnect $offlineNetwork $member.Name 2>$null | Out-Null
    }
    docker network rm $offlineNetwork 2>$null | Out-Null
    docker start @allApps 2>$null | Out-Null
}
