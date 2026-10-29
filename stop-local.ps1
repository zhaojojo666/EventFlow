param([switch]$WithDependencies)
$ErrorActionPreference = 'Stop'
$rootPath = $PSScriptRoot
$pidFile = Join-Path $rootPath 'output\preview-process.txt'
if (Test-Path -LiteralPath $pidFile) {
    $appProcessId = [int](Get-Content -LiteralPath $pidFile | Select-Object -First 1)
    $appProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$appProcessId" -ErrorAction SilentlyContinue
    if ($appProcess -and $appProcess.Name -match '^java(w)?\.exe$' -and $appProcess.CommandLine -like '*eventflow-ticketing-0.0.1-SNAPSHOT.jar*') {
        Stop-Process -Id $appProcessId
        Write-Host 'EventFlow stopped.'
    }
    Remove-Item -LiteralPath $pidFile -Force
}
if ($WithDependencies) {
    & docker compose -p eventflow-desktop-qa -f (Join-Path $rootPath 'compose.local.yaml') stop
    if ($LASTEXITCODE -ne 0) { throw 'Failed to stop the local dependencies.' }
}
