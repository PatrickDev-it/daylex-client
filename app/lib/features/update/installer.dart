import 'dart:convert';
import 'dart:io';

/// What the update window says while the app is closed for the update: from the moment the app quits until the new
/// version's window is on screen, so the lawyer is never left looking at nothing.
class UpdateSplash {
  const UpdateSplash({required this.title, required this.message});

  final String title;
  final String message;
}

/// Why this copy of the app cannot replace itself.
enum InstallProblem {
  /// The folder the app is in is not the lawyer's to change (Program Files, a read-only disk).
  notWritable,

  /// A Mac app opened from the download folder or the disk image: macOS runs it from a temporary copy.
  notInstalled,
}

/// Puts a downloaded release in place of the running app. A small script that outlives the app does it: it
/// waits for the app to quit, swaps the files (putting the old ones back if anything fails) and starts the
/// version it leaves in place. What it did is appended to [log].
abstract class Installer {
  const Installer();

  static Installer? forThisComputer() {
    if (Platform.isWindows) return WindowsInstaller(File(Platform.resolvedExecutable));
    if (Platform.isMacOS) return MacInstaller(File(Platform.resolvedExecutable));
    if (Platform.isLinux) return LinuxInstaller(File(Platform.resolvedExecutable));
    return null;
  }

  /// What is replaced: the app's folder on Windows, the `.app` bundle on macOS.
  String get target;

  /// Why the files cannot be replaced from here, or null.
  InstallProblem? problem();

  /// Starts the script for [archive] (a release zip, already verified) and returns; the app must then quit.
  /// [work] is the script's own folder, emptied as it needs. [splash]: the window shown while the app is closed
  /// (Windows; elsewhere the app is gone for a few seconds without one).
  Future<Process?> launch(
    File archive, {
    required Directory work,
    required File log,
    required String expectedSha256,
    UpdateSplash? splash,
  });

  /// Whether a file can be created in [dir], which is all the swap needs.
  static bool canWrite(Directory dir) {
    final probe = File('${dir.path}${Platform.pathSeparator}.daylex-update-probe');
    try {
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

/// The Windows app is a folder (paper_agent.exe and what it loads), the one the lawyer unpacked it into.
class WindowsInstaller extends Installer {
  const WindowsInstaller(this.executable);

  final File executable;

  @override
  String get target => executable.parent.path;

  @override
  InstallProblem? problem() => Installer.canWrite(executable.parent) ? null : InstallProblem.notWritable;

  /// How long the app waits for the update window to be ready before it quits anyway.
  static const _splashWait = Duration(seconds: 4);

  @override
  Future<Process?> launch(
    File archive, {
    required Directory work,
    required File log,
    required String expectedSha256,
    UpdateSplash? splash,
  }) async {
    work.createSync(recursive: true);
    log.parent.createSync(recursive: true);
    final script = File('${work.path}\\install.ps1')..writeAsStringSync(_windowsScript);
    final ready = File('${work.path}\\ready');
    if (ready.existsSync()) ready.deleteSync();
    final process = await Process.start('powershell.exe', [
      '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', //
      '-File', script.path,
      '-AppPid', '$pid',
      '-Archive', archive.path,
      '-InstallDir', target,
      '-Exe', executable.uri.pathSegments.last,
      '-Work', work.path,
      '-Log', log.path,
      '-ExpectedSha256', expectedSha256,
      '-ReadyFile', ready.path,
    ]);
    void capture(List<int> bytes) {
      try { log.writeAsBytesSync(bytes, mode: FileMode.append); } on FileSystemException { /* Startup handshake fails closed. */ }
    }
    process.stdout.listen(capture);
    process.stderr.listen(capture);
    for (var i = 0; i < 100; i++) {
      if (ready.existsSync()) {
        ready.deleteSync();
        if (splash != null) await _showSplash(splash, work: work, log: log, installer: process.pid);
        return process;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    process.kill();
    throw const ProcessException('powershell.exe', [], 'Updater did not acknowledge startup');
  }

  /// Starts the update window and waits, [_splashWait] at most, until it is loaded: it appears the moment this app
  /// quits and closes when the [installer] ends, which is once the new version's window is up. Best effort: without
  /// it the update still runs. Never on top of this app, so it cannot hide a question the app asks before quitting.
  Future<void> _showSplash(UpdateSplash splash, {required Directory work, required File log, required int installer}) async {
    final loaded = File('${work.path}\\splash-ready');
    try {
      if (loaded.existsSync()) loaded.deleteSync();
      // A copy, so the window never holds a file the installer replaces.
      final logo = File('${executable.parent.path}\\data\\flutter_assets\\assets\\branding\\daylex.png');
      final copy = File('${work.path}\\splash-logo.png');
      final hasLogo = logo.existsSync();
      if (hasLogo) logo.copySync(copy.path);
      final config = File('${work.path}\\splash.json')
        ..writeAsStringSync(
          jsonEncode({
            'title': splash.title,
            'message': splash.message,
            'logo': hasLogo ? copy.path : '',
            'icon': executable.path,
          }),
        );
      final script = File('${work.path}\\splash.ps1')..writeAsStringSync(_windowsSplash);
      // Started as the installer is, which outlives the app: started detached, powershell.exe never ran the script.
      // It writes nothing to its pipes (its failures go to splash.log); they are drained anyway, never left full.
      final window = await Process.start('powershell.exe', [
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', //
        '-File', script.path,
        '-AppPid', '$pid',
        '-Watch', '$installer',
        '-Config', config.path,
        '-ReadyFile', loaded.path,
      ]);
      window.stdout.listen((_) {});
      window.stderr.listen((_) {});
      final until = DateTime.now().add(_splashWait);
      while (!loaded.existsSync() && DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!loaded.existsSync()) _note(log, 'the update window did not load in time: the update runs without it');
    } catch (e) {
      _note(log, 'could not show the update window: $e');
    }
  }

  static void _note(File log, String message) {
    try {
      log.writeAsStringSync('${DateTime.now().toUtc().toIso8601String()} app: $message\n', mode: FileMode.append);
    } on FileSystemException {
      // The log is a courtesy here: the update goes on.
    }
  }
}

/// The Mac app is a `.app` bundle: the executable is `<bundle>/Contents/MacOS/<name>`.
class MacInstaller extends Installer {
  const MacInstaller(this.executable);

  final File executable;

  Directory get _bundle => executable.parent.parent.parent;

  @override
  String get target => _bundle.path;

  @override
  InstallProblem? problem() {
    final path = _bundle.path;
    if (!path.endsWith('.app') || path.contains('/AppTranslocation/') || path.startsWith('/Volumes/')) {
      return InstallProblem.notInstalled;
    }
    return Installer.canWrite(_bundle.parent) ? null : InstallProblem.notWritable;
  }

  @override
  Future<Process?> launch(
    File archive, {
    required Directory work,
    required File log,
    required String expectedSha256,
    UpdateSplash? splash,
  }) async {
    work.createSync(recursive: true);
    log.parent.createSync(recursive: true);
    final script = File('${work.path}/install.sh')..writeAsStringSync(_macScript);
    return Process.start('/bin/sh', [
      script.path, '$pid', archive.path, target, work.path, log.path, expectedSha256, //
    ], mode: ProcessStartMode.detached);
  }
}

/// A Linux bundle installed in a user-owned directory; system packages remain administrator-managed.
class LinuxInstaller extends Installer {
  const LinuxInstaller(this.executable);
  final File executable;
  @override
  String get target => executable.parent.path;
  @override
  InstallProblem? problem() => Installer.canWrite(executable.parent) && Installer.canWrite(executable.parent.parent)
      ? null : InstallProblem.notWritable;
  @override
  Future<Process?> launch(
    File archive, {
    required Directory work,
    required File log,
    required String expectedSha256,
    UpdateSplash? splash,
  }) async {
    work.createSync(recursive: true);
    log.parent.createSync(recursive: true);
    final script = File('${work.path}/install-linux.sh')..writeAsStringSync(linuxInstallerScript);
    return Process.start('/bin/bash', [script.path, '$pid', archive.path, target, log.path, expectedSha256],
        mode: ProcessStartMode.detached);
  }
}

// Public for the native rollback/integrity regression harness.
const linuxInstallerScript = r'''
set -u
app_pid="$1"; archive="$2"; app="$3"; log="$4"; expected="$5"
note() { printf '%s installer: %s\n' "$(date -u +%FT%TZ)" "$*" >> "$log"; }
case "$app" in /*) ;; *) exit 1;; esac
if [ "$app" = / ] || [ ! -x "$app/paper_agent" ] || [ -L "$app" ]; then exit 1; fi
for ((i=0; i<120; i++)); do
  kill -0 "$app_pid" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$app_pid" 2>/dev/null; then note 'app did not quit'; exit 1; fi
if [[ ! "$expected" =~ ^[a-f0-9]{64}$ ]] || [ "$(sha256sum "$archive" | cut -d ' ' -f 1)" != "$expected" ]; then
  note 'archive integrity check failed'; exit 1
fi
parent="$(dirname "$app")"
stage="$(mktemp -d "$parent/.daylex-update.XXXXXX")" || exit 1
cleanup() { rm -rf -- "$stage"; }
trap cleanup EXIT
if ! unzip -q "$archive" -d "$stage/new" || [ ! -x "$stage/new/paper_agent" ] || [ ! -f "$stage/new/lib/libapp.so" ]; then
  note 'invalid Linux bundle'; exit 1
fi
if ! mv -- "$app" "$stage/previous"; then note 'cannot move old bundle'; exit 1; fi
if ! mv -- "$stage/new" "$app"; then
  mv -- "$stage/previous" "$app"
  note 'installation failed; previous bundle restored'
else
  note 'installed verified Linux bundle'
fi
cd "$app"
nohup "$app/paper_agent" >> "$log" 2>&1 < /dev/null &
''';

// The scripts keep the old version until the new one is in place, put it back on any failure, and always start
// whatever is installed at the end: the lawyer never ends up with no app.

const _windowsScript = r'''
param([int]$AppPid, [string]$Archive, [string]$InstallDir, [string]$Exe, [string]$Work, [string]$Log, [string]$ExpectedSha256, [string]$ReadyFile)
$ErrorActionPreference = 'Stop'
# A parent PowerShell 7 can pass incompatible module paths to Windows PowerShell 5.
$env:PSModulePath = Join-Path $PSHOME 'Modules'
function Note([string]$m) { Add-Content -LiteralPath $Log -Value "$(Get-Date -Format o) installer: $m" }
# Inno Setup owns these files; an in-app update must preserve its uninstaller.
$copy = @('/MIR', '/R:5', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XF', 'unins*.exe', 'unins*.dat', 'unins*.msg')
try {
  Note "waiting for the app ($AppPid) to quit"
  $parentProcess = $null
  try { $parentProcess = [Diagnostics.Process]::GetProcessById($AppPid) } catch [ArgumentException] {}
  if ($ReadyFile) { [IO.File]::WriteAllText($ReadyFile, 'ready') }
  if ($parentProcess) {
    try {
      if (-not $parentProcess.WaitForExit(60000)) { Note 'the app did not quit: nothing changed'; exit 1 }
    } finally { $parentProcess.Dispose() }
  }
  if ($ExpectedSha256 -notmatch '^[0-9a-f]{64}$' -or (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ne $ExpectedSha256) { throw 'archive integrity check failed' }
  $Work = [IO.Path]::GetFullPath($Work).TrimEnd('\')
  $InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
  if ($Work.Length -lt 10 -or $InstallDir.Length -lt 10 -or $Work.StartsWith($InstallDir + '\', [StringComparison]::OrdinalIgnoreCase) -or $InstallDir.StartsWith($Work + '\', [StringComparison]::OrdinalIgnoreCase) -or $Work -eq $InstallDir) { throw 'unsafe update paths' }
  $new = Join-Path $Work 'new'
  $backup = Join-Path $Work 'backup'
  foreach ($target in @($new, $backup)) {
    if (-not [IO.Path]::GetFullPath($target).StartsWith($Work + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'unsafe cleanup path' }
  }
  Remove-Item -LiteralPath $new, $backup -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive -LiteralPath $Archive -DestinationPath $new -Force
  if (-not (Test-Path -LiteralPath (Join-Path $new $Exe))) { throw "the archive has no $Exe" }
  robocopy $InstallDir $backup @copy | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "could not back up $InstallDir (robocopy $LASTEXITCODE)" }
  robocopy $new $InstallDir @copy | Out-Null
  if ($LASTEXITCODE -ge 8) {
    $code = $LASTEXITCODE
    robocopy $backup $InstallDir @copy | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "update AND rollback failed; recover from $backup" }
    throw "could not copy the new version (robocopy $code): the previous one is back"
  }
  Remove-Item -LiteralPath $new -Recurse -Force -ErrorAction SilentlyContinue
  Note "installed $Archive into $InstallDir"
} catch {
  Note "failed: $_"
}
$started = Start-Process -FilePath (Join-Path $InstallDir $Exe) -WorkingDirectory $InstallDir -PassThru
# The update window lasts as long as this script: end it once the new version's window is on screen (30 s at most).
try {
  for ($i = 0; $i -lt 150; $i++) {
    $started.Refresh()
    if ($started.HasExited -or $started.MainWindowHandle -ne [IntPtr]::Zero) { break }
    Start-Sleep -Milliseconds 200
  }
} catch {}
''';

// The update window (ASCII: Windows PowerShell reads a script without a byte-order mark in the local code page; the
// words come from splash.json, read as UTF-8). Loaded hidden, it appears as the app quits and closes when the
// installer ends; it also gives up after 10 minutes. A failure here only means no window: the update runs anyway.
const _windowsSplash = r'''
param([int]$AppPid, [int]$Watch, [string]$Config, [string]$ReadyFile)
$ErrorActionPreference = 'Stop'
$env:PSModulePath = Join-Path $PSHOME 'Modules'
$failures = Join-Path (Split-Path -Parent $ReadyFile) 'splash.log'
try {
  $installer = $null
  try { $installer = [Diagnostics.Process]::GetProcessById($Watch) } catch [ArgumentException] { exit 0 }
  $c = [IO.File]::ReadAllText($Config, [Text.Encoding]::UTF8) | ConvertFrom-Json
  Add-Type -AssemblyName System.Windows.Forms, System.Drawing
  try {
    Add-Type -Namespace DaylexUpdate -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][DaylexUpdate.Dpi]::SetProcessDPIAware()
  } catch {}
  [Windows.Forms.Application]::EnableVisualStyles()
  [Windows.Forms.Application]::SetUnhandledExceptionMode([Windows.Forms.UnhandledExceptionMode]::CatchException)
  [Windows.Forms.Application]::add_ThreadException({ [Windows.Forms.Application]::ExitThread() })
  $g = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
  $scale = $g.DpiX / 96
  $g.Dispose()
  function Px([double]$v) { [int][Math]::Round($v * $scale) }
  $form = New-Object Windows.Forms.Form
  $form.FormBorderStyle = 'None'
  $form.StartPosition = 'CenterScreen'
  $form.ClientSize = New-Object Drawing.Size((Px 360), (Px 300))
  $form.BackColor = [Drawing.Color]::FromArgb(12, 12, 12)
  $form.TopMost = $true
  $form.Text = $c.title
  try { $form.Icon = [Drawing.Icon]::ExtractAssociatedIcon($c.icon) } catch {}
  $edge = New-Object Drawing.Pen([Drawing.Color]::FromArgb(38, 38, 38))
  $form.Add_Paint({ param($sender, $e)
    try { $e.Graphics.DrawRectangle($edge, 0, 0, $form.ClientSize.Width - 1, $form.ClientSize.Height - 1) } catch {}
  })
  # Without its logo the window still shows.
  if ($c.logo -and (Test-Path -LiteralPath $c.logo)) {
    try {
      $stream = New-Object IO.MemoryStream(, [IO.File]::ReadAllBytes($c.logo))
      $logo = New-Object Windows.Forms.PictureBox
      $logo.Image = [Drawing.Image]::FromStream($stream)
      $logo.SizeMode = 'Zoom'
      $logo.Size = New-Object Drawing.Size((Px 72), (Px 72))
      $logo.Location = New-Object Drawing.Point((Px 144), (Px 32))
      $form.Controls.Add($logo)
    } catch {
      try { Add-Content -LiteralPath $failures -Value "$(Get-Date -Format o) update window: no logo: $_" } catch {}
    }
  }
  function Add-Text([string]$text, [double]$top, [double]$height, [single]$points, [string]$style, [Drawing.Color]$color) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $text
    $label.AutoSize = $false
    $label.TextAlign = 'TopCenter'
    $label.Location = New-Object Drawing.Point((Px 24), (Px $top))
    $label.Size = New-Object Drawing.Size((Px 312), (Px $height))
    $label.Font = New-Object Drawing.Font('Segoe UI', $points, [Drawing.FontStyle]$style)
    $label.ForeColor = $color
    $form.Controls.Add($label)
  }
  Add-Text $c.title 120 30 13 'Bold' ([Drawing.Color]::White)
  Add-Text $c.message 156 60 9.5 'Regular' ([Drawing.Color]::FromArgb(181, 181, 181))
  $spinner = New-Object Windows.Forms.PictureBox
  $spinner.Size = New-Object Drawing.Size((Px 34), (Px 34))
  $spinner.Location = New-Object Drawing.Point((Px 163), (Px 232))
  $arc = New-Object Drawing.Pen([Drawing.Color]::FromArgb(0, 174, 179), [single](3 * $scale))
  $arc.StartCap = 'Round'
  $arc.EndCap = 'Round'
  $track = New-Object Drawing.Pen([Drawing.Color]::FromArgb(38, 38, 38), [single](3 * $scale))
  $script:angle = 0
  $spinner.Add_Paint({ param($sender, $e)
    try {
      $e.Graphics.SmoothingMode = 'AntiAlias'
      $inset = [single](3 * $scale)
      $ring = New-Object Drawing.RectangleF($inset, $inset, [single]($spinner.Width - 2 * $inset), [single]($spinner.Height - 2 * $inset))
      $e.Graphics.DrawEllipse($track, $ring)
      $e.Graphics.DrawArc($arc, $ring, [single]$script:angle, [single]100)
    } catch {}
  })
  $form.Controls.Add($spinner)
  $clock = [Diagnostics.Stopwatch]::StartNew()
  $app = $null
  try { $app = [Diagnostics.Process]::GetProcessById($AppPid) } catch [ArgumentException] {}
  $timer = New-Object Windows.Forms.Timer
  $timer.Interval = 30
  $timer.Add_Tick({
    try {
      if ($installer.HasExited -or $clock.Elapsed.TotalMinutes -ge 10) {
        $timer.Stop()
        $form.Close()
        [Windows.Forms.Application]::ExitThread()
        return
      }
      if (-not $form.Visible -and ($null -eq $app -or $app.HasExited)) { $form.Show(); $form.Activate() }
      if ($form.Visible) {
        $script:angle = ($script:angle + 9) % 360
        $spinner.Invalidate()
      }
    } catch { [Windows.Forms.Application]::ExitThread() }
  })
  $timer.Start()
  [IO.File]::WriteAllText($ReadyFile, 'ready')
  [Windows.Forms.Application]::Run()
} catch {
  try { Add-Content -LiteralPath $failures -Value "$(Get-Date -Format o) update window: $_" } catch {}
}
''';

const _macScript = r'''
pid="$1"; archive="$2"; app="$3"; work="$4"; log="$5"; expected="$6"
note() { printf '%s installer: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$log"; }
note "waiting for the app ($pid) to quit"
i=0
while kill -0 "$pid" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 120 ]; then note "the app did not quit: nothing changed"; exit 1; fi
  sleep 0.5
done
actual="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
if [ "$actual" != "$expected" ] || [ "${#expected}" -ne 64 ]; then
  note "archive integrity check failed"; open "$app"; exit 1
fi
new="$work/new"
rm -rf "$new"
mkdir -p "$new"
if ! ditto -x -k "$archive" "$new" 2>>"$log"; then
  note "could not unpack $archive"
elif [ ! -d "$new/Daylex.app" ]; then
  note "the archive has no Daylex.app"
elif ! codesign --verify --deep --strict "$new/Daylex.app" 2>>"$log"; then
  note "the new app's code signature is invalid"
elif ! mv "$app" "$app.old" 2>>"$log"; then
  note "could not move $app aside: nothing changed"
elif ! ditto "$new/Daylex.app" "$app" 2>>"$log"; then
  rm -rf "$app"
  mv "$app.old" "$app"
  note "could not copy the new version: the previous one is back"
else
  rm -rf "$app.old"
  note "installed $archive into $app"
fi
rm -rf "$new"
open "$app"
''';
