param([switch]$Build,[switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$rootPath = $PSScriptRoot
Set-Location -LiteralPath $rootPath
New-Item -ItemType Directory -Force (Join-Path $rootPath 'output') | Out-Null
$jarPath = Join-Path $rootPath 'target\eventflow-ticketing-0.0.1-SNAPSHOT.jar'
$url = 'http://127.0.0.1:8082/'
$pidFile = Join-Path $rootPath 'output\preview-process.txt'
$existing = $null
if (Test-Path -LiteralPath $pidFile) {
    $savedId = [int](Get-Content -LiteralPath $pidFile | Select-Object -First 1)
    $existing = Get-CimInstance Win32_Process -Filter "ProcessId=$savedId" -ErrorAction SilentlyContinue
    if ($existing -and ($existing.Name -notmatch '^java(w)?\.exe$' -or $existing.CommandLine -notlike '*eventflow-ticketing-0.0.1-SNAPSHOT.jar*')) { $existing = $null }
}
if ($existing -and !$Build) {
    try {
        $health = Invoke-RestMethod -Uri ($url + 'events/config') -TimeoutSec 3
        if ($health.success) {
            Write-Host "EventFlow is already running: $url"
            if (!$NoBrowser) { Start-Process $url }
            exit 0
        }
    } catch { }
}

if (!(Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Install Docker Desktop and open it before starting EventFlow.' }
try {
    & docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Docker engine unavailable.' }
} catch { throw 'Docker Desktop is not ready. Open Docker Desktop, wait until its engine is running, then retry.' }
& docker compose -p eventflow-desktop-qa -f compose.local.yaml up -d
if ($LASTEXITCODE -ne 0) { throw 'Failed to start local MySQL and Redis.' }
Write-Host 'Waiting for MySQL...'
$dbReady = $false
for ($attempt=0; $attempt -lt 60; $attempt++) {
    try {
        & docker compose -p eventflow-desktop-qa -f compose.local.yaml exec -T -e MYSQL_PWD=eventflow-qa-local mysql mysql -uroot eventflow_desktop -N -e 'SELECT COUNT(*) FROM tb_event;' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $dbReady=$true; break }
    } catch { }
    Start-Sleep -Seconds 1
}
if (!$dbReady) { throw 'MySQL initialization did not finish. Check: docker compose -p eventflow-desktop-qa -f compose.local.yaml logs mysql' }

$javaExe = $null
if ($env:JAVA_HOME -and (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\java.exe'))) { $javaExe=Join-Path $env:JAVA_HOME 'bin\java.exe' }
if (!$javaExe) { $javaCommand=Get-Command java -ErrorAction SilentlyContinue; if ($javaCommand) { $javaExe=$javaCommand.Source } }
if (!$javaExe) { throw 'Java 8 is required. Set JAVA_HOME to a JDK 8 installation.' }

if ($Build -or !(Test-Path -LiteralPath $jarPath)) {
    if ($existing) { & (Join-Path $rootPath 'stop-local.ps1') }
    $mavenCandidates=@(
        (Join-Path $rootPath '.tools\apache-maven-3.9.11\bin\mvn.cmd'),
        (Join-Path $env:TEMP 'eventflow-maven\apache-maven-3.9.11\bin\mvn.cmd')
    )
    $globalMaven=Get-Command mvn -ErrorAction SilentlyContinue
    if ($globalMaven) { $mavenCandidates += $globalMaven.Source }
    $mavenExe=$null
    foreach ($candidate in $mavenCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            $bootPath=Join-Path (Split-Path (Split-Path $candidate -Parent) -Parent) 'boot'
            if (Get-ChildItem -LiteralPath $bootPath -Filter 'plexus-classworlds-*.jar' -ErrorAction SilentlyContinue) { $mavenExe=$candidate; break }
        }
    }
    if (!$mavenExe) { throw 'A complete Maven installation is required to build. You can also run Maven package from IntelliJ IDEA.' }
    & $mavenExe -q -DskipTests package
    if ($LASTEXITCODE -ne 0) { throw 'Maven build failed.' }
}
if ($existing) { & (Join-Path $rootPath 'stop-local.ps1') }
if (Get-NetTCPConnection -State Listen -LocalPort 8082 -ErrorAction SilentlyContinue) { throw 'Port 8082 is occupied by another application. Stop that application first.' }
$env:DB_URL='jdbc:mysql://127.0.0.1:23306/eventflow_desktop?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true'
$env:DB_USER='root'
$env:DB_PASSWORD='eventflow-qa-local'
$env:REDIS_HOST='127.0.0.1'
$env:REDIS_PORT='26379'
$env:REDIS_PASSWORD='eventflow-qa-local'
$env:EVENTFLOW_DEMO_MODE='true'
$staticUri=([System.Uri](Join-Path $rootPath 'src\main\resources\static\')).AbsoluteUri
$newApp = Start-Process -FilePath $javaExe -ArgumentList @('-Xms128m','-Xmx384m','-jar',('"'+$jarPath+'"'),('--spring.resources.static-locations='+$staticUri)) -WorkingDirectory $rootPath -WindowStyle Hidden -RedirectStandardOutput (Join-Path $rootPath 'output\preview-app.log') -RedirectStandardError (Join-Path $rootPath 'output\preview-app-error.log') -PassThru
$newApp.Id | Set-Content -LiteralPath $pidFile
for ($attempt=0; $attempt -lt 60; $attempt++) {
    Start-Sleep -Seconds 1
    if ($newApp.HasExited) { throw 'EventFlow exited. Read output/preview-app.log and output/preview-app-error.log.' }
    try {
        $health = Invoke-RestMethod -Uri ($url + 'events/config') -TimeoutSec 2
        if ($health.success) {
            Write-Host "EventFlow started: $url"
            Write-Host 'Logs: output/preview-app.log'
            if (!$NoBrowser) { Start-Process $url }
            exit 0
        }
    } catch { }
}
throw 'EventFlow did not become ready within 60 seconds. Read output/preview-app.log.'
