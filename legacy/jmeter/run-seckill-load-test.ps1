param(
    [string]$JMeterHome = $env:JMETER_HOME,
    [string]$MySqlHome = $env:MYSQL_HOME,
    [string]$RedisContainer = 'hmdp-redis7',
    [string]$RedisPassword = '123456',
    [string]$MySqlPassword = '123456',
    [string]$BaseUrl = 'http://127.0.0.1:8081',
    [ValidateRange(1, 2000)][int]$OneUserThreads = 100,
    [ValidateRange(1, 2000)][int]$MultiUserThreads = 100,
    [ValidateRange(1, 2000)][int]$MultiUserStock = 30,
    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$jmeter = Join-Path $JMeterHome 'bin\jmeter.bat'
$mysql = Join-Path $MySqlHome 'bin\mysql.exe'
$oneTokenPlan = Join-Path $scriptRoot 'seckill-one-token.jmx'
$multiTokenPlan = Join-Path $scriptRoot 'seckill-multi-token.jmx'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$resultRoot = Join-Path $scriptRoot "results\$runId"
$baseUri = [Uri]$BaseUrl
$hostName = $baseUri.Host
$httpPort = $baseUri.Port
$createdPhones = New-Object System.Collections.Generic.List[string]
$createdTokens = New-Object System.Collections.Generic.List[string]
$createdVoucherIds = New-Object System.Collections.Generic.List[long]

function Assert-File([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label not found: $Path"
    }
}

function Invoke-MySqlScalar([string]$Sql) {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $mysql '--host=127.0.0.1' '--user=root' "--password=$MySqlPassword" '--database=heima' '--batch' '--skip-column-names' "--execute=$Sql" 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($exitCode -ne 0) {
        throw "MySQL command failed: $Sql"
    }
    $value = @($output | Where-Object { $_.ToString() -notmatch '^mysql: \[Warning\]' })
    return ($value | Select-Object -Last 1).ToString().Trim()
}

function Invoke-Redis([string[]]$Arguments) {
    $value = & docker exec $RedisContainer redis-cli -a $RedisPassword --no-auth-warning @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Redis command failed: $($Arguments -join ' ')"
    }
    return $value
}

function Wait-Until([scriptblock]$Condition, [int]$TimeoutSeconds, [string]$FailureMessage) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw $FailureMessage
}

function New-TestLogin {
    do {
        $phone = '13' + (Get-Random -Minimum 100000000 -Maximum 999999999).ToString()
        $exists = [int](Invoke-MySqlScalar "SELECT COUNT(*) FROM tb_user WHERE phone='$phone'")
    } while ($exists -ne 0)

    $null = Invoke-RestMethod -Method Post -Uri "$BaseUrl/user/code?phone=$phone" -TimeoutSec 5
    $code = (Invoke-Redis @('GET', "login:code:$phone") | Select-Object -Last 1).ToString().Trim()
    if (-not $code) {
        throw "Could not read login code for $phone"
    }
    $body = @{ phone = $phone; code = $code } | ConvertTo-Json -Compress
    $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/user/login" -ContentType 'application/json' -Body $body -TimeoutSec 5
    if (-not $login.success -or -not $login.data) {
        throw "Login failed for $phone"
    }
    $createdPhones.Add($phone)
    $createdTokens.Add([string]$login.data)
    return [PSCustomObject]@{
        Phone = $phone
        Token = [string]$login.data
        UserId = [long](Invoke-MySqlScalar "SELECT id FROM tb_user WHERE phone='$phone'")
    }
}

function New-TestVoucher([int]$Stock, [string]$Title) {
    $body = @{
        shopId = 1
        title = $Title
        subTitle = 'JMeter automated test'
        rules = 'Test data only'
        payValue = 1000
        actualValue = 2000
        type = 1
        status = 1
        stock = $Stock
        beginTime = (Get-Date).AddMinutes(-5).ToString('yyyy-MM-ddTHH:mm:ss')
        endTime = (Get-Date).AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss')
    } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri "$BaseUrl/voucher/seckill" -ContentType 'application/json' -Body $body -TimeoutSec 10
    if (-not $response.success -or -not $response.data) {
        throw "Creating test voucher failed: $Title"
    }
    $voucherId = [long]$response.data
    $createdVoucherIds.Add($voucherId)
    return $voucherId
}

function Invoke-JMeterPlan(
    [string]$Plan,
    [string]$Name,
    [long]$VoucherId,
    [int]$Threads,
    [string]$Token,
    [string]$TokenCsv
) {
    $scenarioRoot = Join-Path $resultRoot $Name
    $reportRoot = Join-Path $scenarioRoot 'html'
    $jtl = Join-Path $scenarioRoot 'results.jtl'
    $log = Join-Path $scenarioRoot 'jmeter.log'
    New-Item -ItemType Directory -Path $scenarioRoot -Force | Out-Null

    $arguments = @(
        '-n', '-t', $Plan,
        "-Jhost=$hostName", "-Jport=$httpPort", "-JvoucherId=$VoucherId",
        "-Jthreads=$Threads", '-JrampUp=1',
        '-l', $jtl, '-j', $log,
        '-e', '-o', $reportRoot
    )
    if ($Token) {
        $arguments += "-Jtoken=$Token"
    }
    if ($TokenCsv) {
        $arguments += "-JtokenCsv=$TokenCsv"
    }

    Push-Location (Join-Path $JMeterHome 'bin')
    try {
        # Keep JMeter console text visible without returning it as part of this
        # function's PowerShell output object.
        & $jmeter @arguments | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "JMeter scenario failed: $Name. See $log"
        }
    } finally {
        Pop-Location
    }

    $samples = @(Import-Csv -LiteralPath $jtl)
    if ($samples.Count -eq 0) {
        throw "No JMeter samples were produced for $Name"
    }
    $successCount = @($samples | Where-Object responseMessage -eq 'BUSINESS_SUCCESS').Count
    $duplicateCount = @($samples | Where-Object responseMessage -eq 'DUPLICATE_ORDER').Count
    $outOfStockCount = @($samples | Where-Object responseMessage -eq 'OUT_OF_STOCK').Count
    $businessErrorCount = @($samples | Where-Object responseMessage -eq 'BUSINESS_ERROR').Count
    $elapsedValues = @($samples | ForEach-Object { [int]$_.elapsed } | Sort-Object)
    $p95Index = [Math]::Max(0, [Math]::Ceiling($elapsedValues.Count * 0.95) - 1)
    $startMillis = ($samples | Measure-Object -Property timeStamp -Minimum).Minimum -as [double]
    $endMillis = ($samples | ForEach-Object { ([double]$_.timeStamp) + ([double]$_.elapsed) } | Measure-Object -Maximum).Maximum
    $durationSeconds = [Math]::Max(0.001, ($endMillis - $startMillis) / 1000.0)

    return [PSCustomObject]@{
        scenario = $Name
        voucherId = $VoucherId
        samples = $samples.Count
        businessSuccess = $successCount
        duplicateOrder = $duplicateCount
        outOfStock = $outOfStockCount
        businessError = $businessErrorCount
        averageMs = [Math]::Round((($elapsedValues | Measure-Object -Average).Average), 2)
        p95Ms = $elapsedValues[$p95Index]
        throughputPerSecond = [Math]::Round($samples.Count / $durationSeconds, 2)
        jtl = $jtl
        htmlReport = (Join-Path $reportRoot 'index.html')
    }
}

function Get-PendingCount([string]$Stream, [string]$Group) {
    $result = @(Invoke-Redis @('XPENDING', $Stream, $Group))
    if ($result.Count -eq 0 -or -not $result[0]) {
        return 0
    }
    return [int]$result[0]
}

function Remove-TestData {
    foreach ($token in $createdTokens) {
        $null = Invoke-Redis @('DEL', "login:token:$token")
    }
    foreach ($phone in $createdPhones) {
        $null = Invoke-Redis @('DEL', "login:code:$phone")
    }
    foreach ($voucherId in $createdVoucherIds) {
        $null = Invoke-MySqlScalar "DELETE FROM tb_voucher_order WHERE voucher_id=$voucherId; DELETE FROM tb_seckill_voucher WHERE voucher_id=$voucherId; DELETE FROM tb_voucher WHERE id=$voucherId; SELECT 1;"
        $null = Invoke-Redis @('DEL', "seckill:stock:$voucherId", "seckill:order:$voucherId")
    }
    if ($createdPhones.Count -gt 0) {
        $phoneList = ($createdPhones | ForEach-Object { "'$_'" }) -join ','
        $null = Invoke-MySqlScalar "DELETE FROM tb_user WHERE phone IN ($phoneList); SELECT 1;"
    }
}

Assert-File $jmeter 'JMeter launcher'
Assert-File $mysql 'MySQL client'
Assert-File $oneTokenPlan 'One-token JMeter plan'
Assert-File $multiTokenPlan 'Multi-token JMeter plan'
New-Item -ItemType Directory -Path $resultRoot -Force | Out-Null

$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/shop-type/list" -TimeoutSec 5
if (-not $health.success) {
    throw "Backend health check failed: $BaseUrl"
}

try {
    Write-Host '[1/3] Same-token concurrency test'
    $oneUser = New-TestLogin
    $oneVoucherId = New-TestVoucher -Stock 10 -Title "JMeter one-token $runId"
    $oneResult = Invoke-JMeterPlan -Plan $oneTokenPlan -Name 'one-token' -VoucherId $oneVoucherId -Threads $OneUserThreads -Token $oneUser.Token -TokenCsv ''
    Wait-Until -TimeoutSeconds 30 -FailureMessage 'One-token order was not consumed in time' -Condition {
        ([int](Invoke-MySqlScalar "SELECT COUNT(*) FROM tb_voucher_order WHERE voucher_id=$oneVoucherId")) -eq 1 -and
        (Get-PendingCount 'stream.orders' 'order-group') -eq 0
    }
    $oneDbOrders = [int](Invoke-MySqlScalar "SELECT COUNT(*) FROM tb_voucher_order WHERE voucher_id=$oneVoucherId")
    $oneDbStock = [int](Invoke-MySqlScalar "SELECT stock FROM tb_seckill_voucher WHERE voucher_id=$oneVoucherId")
    $oneRedisStock = [int]((Invoke-Redis @('GET', "seckill:stock:$oneVoucherId") | Select-Object -Last 1).ToString())
    $onePassed = $oneResult.businessSuccess -eq 1 -and $oneDbOrders -eq 1 -and $oneDbStock -eq 9 -and $oneRedisStock -eq 9

    Write-Host '[2/3] Multi-token no-oversell test'
    $multiUsers = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $MultiUserThreads; $i++) {
        $multiUsers.Add((New-TestLogin))
    }
    $tokenCsv = Join-Path $resultRoot 'multi-user-tokens.csv'
    $multiUsers | Select-Object @{Name='token';Expression={$_.Token}} | Export-Csv -LiteralPath $tokenCsv -NoTypeInformation -Encoding UTF8
    $multiVoucherId = New-TestVoucher -Stock $MultiUserStock -Title "JMeter multi-token $runId"
    $multiResult = Invoke-JMeterPlan -Plan $multiTokenPlan -Name 'multi-token' -VoucherId $multiVoucherId -Threads $MultiUserThreads -Token '' -TokenCsv $tokenCsv
    Wait-Until -TimeoutSeconds 40 -FailureMessage 'Multi-token orders were not consumed in time' -Condition {
        ([int](Invoke-MySqlScalar "SELECT COUNT(*) FROM tb_voucher_order WHERE voucher_id=$multiVoucherId")) -eq $MultiUserStock -and
        (Get-PendingCount 'stream.orders' 'order-group') -eq 0
    }
    $multiDbOrders = [int](Invoke-MySqlScalar "SELECT COUNT(*) FROM tb_voucher_order WHERE voucher_id=$multiVoucherId")
    $multiDbStock = [int](Invoke-MySqlScalar "SELECT stock FROM tb_seckill_voucher WHERE voucher_id=$multiVoucherId")
    $multiRedisStock = [int]((Invoke-Redis @('GET', "seckill:stock:$multiVoucherId") | Select-Object -Last 1).ToString())
    $duplicateGroups = [int](Invoke-MySqlScalar "SELECT COUNT(*) FROM (SELECT user_id FROM tb_voucher_order WHERE voucher_id=$multiVoucherId GROUP BY user_id HAVING COUNT(*) > 1) duplicated")
    $multiPassed = $multiResult.businessSuccess -eq $MultiUserStock -and $multiDbOrders -eq $MultiUserStock -and $multiDbStock -eq 0 -and $multiRedisStock -eq 0 -and $duplicateGroups -eq 0

    Write-Host '[3/3] Failure recovery and compensation test'
    $failureUser = New-TestLogin
    $failureVoucherId = New-TestVoucher -Stock 1 -Title "JMeter recovery $runId"
    $null = Invoke-MySqlScalar "UPDATE tb_seckill_voucher SET stock=0 WHERE voucher_id=$failureVoucherId; SELECT 1;"
    $compensatedBefore = [int]((Invoke-Redis @('XLEN', 'stream.orders.compensated') | Select-Object -Last 1).ToString())
    $failureResult = Invoke-JMeterPlan -Plan $oneTokenPlan -Name 'failure-recovery' -VoucherId $failureVoucherId -Threads 1 -Token $failureUser.Token -TokenCsv ''
    # XAUTOCLAIM recovery runs every 30 seconds. Three attempts can legitimately
    # take a little over one minute before the message reaches the DLQ consumer.
    Wait-Until -TimeoutSeconds 120 -FailureMessage 'Dead-letter compensation did not finish in time' -Condition {
        $stockValue = (Invoke-Redis @('GET', "seckill:stock:$failureVoucherId") | Select-Object -Last 1).ToString()
        $orderCount = [int](Invoke-MySqlScalar "SELECT COUNT(*) FROM tb_voucher_order WHERE voucher_id=$failureVoucherId")
        $compensatedNow = [int]((Invoke-Redis @('XLEN', 'stream.orders.compensated') | Select-Object -Last 1).ToString())
        $stockValue -eq '1' -and $orderCount -eq 0 -and $compensatedNow -gt $compensatedBefore -and
        (Get-PendingCount 'stream.orders' 'order-group') -eq 0 -and
        (Get-PendingCount 'stream.orders.dlq' 'order-dlq-group') -eq 0
    }
    $failureRedisStock = [int]((Invoke-Redis @('GET', "seckill:stock:$failureVoucherId") | Select-Object -Last 1).ToString())
    $failureDbOrders = [int](Invoke-MySqlScalar "SELECT COUNT(*) FROM tb_voucher_order WHERE voucher_id=$failureVoucherId")
    $failureUserMarker = [int]((Invoke-Redis @('SISMEMBER', "seckill:order:$failureVoucherId", $failureUser.UserId.ToString()) | Select-Object -Last 1).ToString())
    $failurePassed = $failureResult.businessSuccess -eq 1 -and $failureRedisStock -eq 1 -and $failureDbOrders -eq 0 -and $failureUserMarker -eq 0

    $summary = [PSCustomObject]@{
        runId = $runId
        generatedAt = (Get-Date).ToString('s')
        java = '1.8.0_492'
        jmeter = '5.6.3'
        overallPassed = $onePassed -and $multiPassed -and $failurePassed
        oneToken = [PSCustomObject]@{
            passed = $onePassed
            load = $oneResult
            dbOrders = $oneDbOrders
            dbStock = $oneDbStock
            redisStock = $oneRedisStock
        }
        multiToken = [PSCustomObject]@{
            passed = $multiPassed
            initialStock = $MultiUserStock
            load = $multiResult
            dbOrders = $multiDbOrders
            dbStock = $multiDbStock
            redisStock = $multiRedisStock
            duplicateUserGroups = $duplicateGroups
        }
        failureRecovery = [PSCustomObject]@{
            passed = $failurePassed
            load = $failureResult
            dbOrders = $failureDbOrders
            redisStockAfterCompensation = $failureRedisStock
            userMarkerAfterCompensation = $failureUserMarker
        }
    }
    $summaryPath = Join-Path $resultRoot 'summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    $summary | ConvertTo-Json -Depth 8
    Write-Host "Summary: $summaryPath"

    if (-not $summary.overallPassed) {
        throw 'One or more seckill verification scenarios failed'
    }
} finally {
    if ($Cleanup) {
        Write-Host 'Cleaning generated users, vouchers, orders and login keys...'
        Remove-TestData
    }
}
