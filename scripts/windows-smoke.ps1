param([Parameter(Mandatory=$true)][string]$Archive, [switch]$RequireWindows11)
$ErrorActionPreference = 'Stop'
$os = Get-CimInstance Win32_OperatingSystem
if ($RequireWindows11 -and ($os.Caption -notmatch 'Windows 11' -or [int]$os.BuildNumber -lt 22000)) { throw 'Runner is not Windows 11' }
$target = Join-Path $env:RUNNER_TEMP ('Daylex QA ' + [guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $Archive -DestinationPath $target
$exe = Join-Path $target 'paper_agent.exe'
$runtimeNames = @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')
foreach ($name in $runtimeNames) {
  if (!(Test-Path -LiteralPath (Join-Path $target $name))) { throw "Package missing required runtime: $name" }
}
$process = Start-Process -FilePath $exe -PassThru -WindowStyle Hidden
try {
  Start-Sleep -Seconds 12
  $process.Refresh()
  if ($process.HasExited -or $process.MainWindowHandle -eq 0) { throw 'Installed app did not open its window' }
  $runtimeModules = @($process.Modules | Where-Object {$_.ModuleName.ToLowerInvariant() -in $runtimeNames})
  if ($runtimeModules.Count -ne $runtimeNames.Count) { throw 'Not all C++ runtimes loaded' }
  foreach ($module in $runtimeModules) {
    if ([IO.Path]::GetDirectoryName($module.FileName) -ne $target) { throw "Runtime loaded outside the package: $($module.ModuleName)" }
  }
  & (Join-Path $target 'whatsapp_bridge/node.exe') --version
  if ($LASTEXITCODE -ne 0) { throw 'Bundled Node failed' }
  [ordered]@{os=$os.Caption;build=$os.BuildNumber;architecture=$env:PROCESSOR_ARCHITECTURE;package='x64';version=(Get-Item $exe).VersionInfo.ProductVersion;startup=$true;appLocalRuntime=$true;sha256=(Get-FileHash $Archive -Algorithm SHA256).Hash} | ConvertTo-Json | Set-Content app/dist/windows-startup.json
} finally {
  if (!$process.HasExited) { $null=$process.CloseMainWindow(); if (!$process.WaitForExit(10000)) { $process.Kill(); throw 'App did not close cleanly' } }
}

