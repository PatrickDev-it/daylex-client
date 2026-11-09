$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sandbox = Join-Path $env:RUNNER_TEMP ('installer-smoke-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox | Out-Null
$source = Join-Path $sandbox 'Smoke.cs'
Set-Content -LiteralPath $source -Value 'using System;using System.IO;class Smoke{static void Main(){File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"booted.txt"),"ok");}}'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:winexe ("/out:" + (Join-Path $sandbox 'smoke.exe')) $source
if ($LASTEXITCODE -ne 0) { throw 'Fixture compile failed' }
$results = @()
foreach ($mode in @('valid','tampered','rollback','cancelled')) {
  Write-Output "Testing updater scenario: $mode"
  $root = Join-Path $sandbox $mode
  $app = Join-Path $root 'app'
  $new = Join-Path $root 'package'
  New-Item -ItemType Directory -Path $app,$new | Out-Null
  Copy-Item -LiteralPath (Join-Path $sandbox 'smoke.exe') -Destination $app
  Copy-Item -LiteralPath (Join-Path $sandbox 'smoke.exe') -Destination $new
  Set-Content -LiteralPath (Join-Path $app 'version.txt') -Value 'old'
  Set-Content -LiteralPath (Join-Path $app 'stale.dll') -Value 'retired'
  Set-Content -LiteralPath (Join-Path $app 'unins000.dat') -Value 'installer-owned'
  Set-Content -LiteralPath (Join-Path $new 'version.txt') -Value 'new'
  $archive = Join-Path $root 'update.zip'
  Compress-Archive -Path (Join-Path $new '*') -DestinationPath $archive
  $expected = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($mode -eq 'tampered') { $expected = '0' * 64 }
  $held = $null
  if ($mode -eq 'rollback') {
    # Force a changed executable timestamp, then deny replacement while allowing its backup to be read.
    (Get-Item -LiteralPath (Join-Path $app 'smoke.exe')).LastWriteTime = (Get-Date).AddDays(-1)
    $held = [IO.File]::Open((Join-Path $app 'smoke.exe'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  }
  Push-Location (Join-Path $workspace 'app')
  try {
    & dart run tool/run_installer_smoke.dart $root $expected $mode
    if ($LASTEXITCODE -ne 0) { throw 'Updater launcher failed' }
  }
  finally { Pop-Location }
  if ($mode -eq 'cancelled') {
    Start-Sleep -Seconds 1
    if ((Test-Path -LiteralPath (Join-Path $app 'booted.txt')) -or (Get-Content -LiteralPath (Join-Path $app 'version.txt') -Raw).Trim() -ne 'old') { throw 'Cancelled updater changed the app' }
    $results += @{mode=$mode;version='old';restarted=$false}
    continue
  }
  # The installer itself may wait up to 60 seconds for its parent to exit;
  # allow that boundary plus file-copy retries and process startup on hosted CI.
  $deadline = (Get-Date).AddSeconds(90)
  while (!(Test-Path -LiteralPath (Join-Path $app 'booted.txt')) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
  if ($held) { $held.Dispose() }
  if (!(Test-Path -LiteralPath (Join-Path $app 'booted.txt'))) {
    $logFile = Join-Path $root 'install.log'
    if (Test-Path -LiteralPath $logFile) { Get-Content -LiteralPath $logFile }
    Get-ChildItem -LiteralPath $app | Select-Object Name,Length | Format-Table
    throw "Installer did not restart fixture in scenario $mode"
  }
  $actual = (Get-Content -LiteralPath (Join-Path $app 'version.txt') -Raw).Trim()
  if ($actual -ne $(if ($mode -eq 'valid') {'new'} else {'old'})) { throw "Wrong installed content: $mode" }
  if (!(Test-Path -LiteralPath (Join-Path $app 'unins000.dat')) -or (Get-Content -LiteralPath (Join-Path $app 'unins000.dat') -Raw).Trim() -ne 'installer-owned') { throw 'Updater removed installer metadata' }
  if ($mode -eq 'valid' -and (Test-Path -LiteralPath (Join-Path $app 'stale.dll'))) { throw 'Stale binary remained' }
  if ($mode -eq 'rollback' -and !(Get-Content -LiteralPath (Join-Path $root 'install.log') -Raw).Contains('the previous one is back')) { throw 'Rollback was not exercised' }
  $results += @{mode=$mode;version=$actual;restarted=$true;log=(Get-Content -LiteralPath (Join-Path $root 'install.log') -Raw)}
}
$results | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $workspace 'app/dist/desktop-installer-smoke.json')
Write-Output 'PASS: actual Windows updater replaced files, restarted, rejected tampering, restored after failure and honoured cancellation.'

