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
    @{ Name = 'idea2strategy-backtest-api'; Alias = 'backtest-api' }
)
$login = Invoke-RestMethod -Method Post -Uri 'http://localhost:15173/api/v1/auth/login' `
    -ContentType 'application/json' `
    -Body (@{ email = $TestEmail; password = $TestPassword } | ConvertTo-Json)
$accessToken = $login.accessToken
if (-not $accessToken) { throw 'Could not mint the short-lived offline proof token.' }
$probe = @'
import json, os, time, urllib.request

def call(url, token=None, body=None):
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    data = None if body is None else json.dumps(body).encode()
    if data:
        headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)

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
print(json.dumps({
    'egressBlocked': True,
    'oneMonthBars': len(one['bars']),
    'threeMonthBars': len(three['bars']),
    'previewLast': one['availableTo'],
    'benchmarks': ','.join(item['symbol'] for item in benchmarks['instruments']),
    'backtestStatus': run['status'],
    'backtestReturn': performance['metricsDocument']['totalReturnPct'],
}, separators=(',', ':')))
'@

docker stop @allApps | Out-Null
docker network create --internal $offlineNetwork | Out-Null
try {
    foreach ($member in $offlineMembers) {
        docker network connect --alias $member.Alias $offlineNetwork $member.Name
    }
    docker network disconnect $developmentNetwork idea2strategy-backend-api
    docker network disconnect $developmentNetwork idea2strategy-backtest-api
    docker start idea2strategy-backend-api idea2strategy-backtest-api | Out-Null

    docker run --rm --network $offlineNetwork postgres:16-alpine sh -c `
        'wget -T 5 -q https://data.alpaca.markets -O /dev/null' *> $null
    if ($LASTEXITCODE -eq 0) { throw 'External provider remained reachable.' }

    $probe | docker exec -i `
        -e "I2S_ACCESS_TOKEN=$accessToken" `
        idea2strategy-backtest-api python -
    if ($LASTEXITCODE -ne 0) { throw 'Offline in-network probe failed.' }
} finally {
    docker stop idea2strategy-backend-api idea2strategy-backtest-api 2>$null | Out-Null
    docker network connect --alias backend-api $developmentNetwork idea2strategy-backend-api 2>$null | Out-Null
    docker network connect --alias backtest-api $developmentNetwork idea2strategy-backtest-api 2>$null | Out-Null
    foreach ($member in $offlineMembers) {
        docker network disconnect $offlineNetwork $member.Name 2>$null | Out-Null
    }
    docker network rm $offlineNetwork 2>$null | Out-Null
    docker start @allApps 2>$null | Out-Null
}
