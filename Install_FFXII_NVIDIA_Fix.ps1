# FFXII The Zodiac Age - NVIDIA Fatal Error Fix Installer
# Version: 2.0

[CmdletBinding()]
param(
    [switch]$Elevated,
    [switch]$NoPause,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 negotiates TLS 1.0 on some systems, which breaks
# api.github.com. Force TLS 1.2 before any web call.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$AppName = "FFXII_NVIDIA_Fix"
$GameName = "Final Fantasy XII: The Zodiac Age"
$SteamAppId = "595520"
$GameExeName = "FFXII_TZA.exe"
$ProfileFileName = "FFXII_ShaderCacheOff.nip"
$ImportTimeoutSec = 60

$InstallDir = Join-Path $env:LOCALAPPDATA $AppName
$NpiExe = Join-Path $InstallDir "nvidiaProfileInspector.exe"
$InstalledProfile = Join-Path $InstallDir $ProfileFileName
$BackupDir = Join-Path $InstallDir "Backup"
$StateFile = Join-Path $InstallDir "state.json"
# $PSCommandPath is empty when the script is pasted or piped into iex rather than
# run with -File, so fall back to the working directory instead of throwing.
$ScriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
$BundledProfile = Join-Path $ScriptDir $ProfileFileName
$LauncherPath = Join-Path $InstallDir "Start_FFXII_With_NVIDIA_Fix.ps1"
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Start FFXII with NVIDIA Fix.lnk"
$DrsDir = Join-Path $env:ProgramData "NVIDIA Corporation\Drs"

function Write-Step($Text) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Text
    Write-Host "============================================================"
}

function Write-Info($Text) { Write-Host "[INFO] $Text" }
function Write-Ok($Text) { Write-Host "[OK] $Text" -ForegroundColor Green }
function Write-Warn($Text) { Write-Host "[WARNING] $Text" -ForegroundColor Yellow }
function Write-Err($Text) { Write-Host "[ERROR] $Text" -ForegroundColor Red }

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-SelfElevate {
    # nvidiaProfileInspector needs administrator rights to write driver profiles.
    # Elevate once here so the user gets a single UAC prompt instead of one per step.
    if (!$PSCommandPath) {
        throw "Cannot elevate automatically because the script path is unknown. Run Install_FFXII_NVIDIA_Fix.bat, or start PowerShell as Administrator and run the .ps1 with -File."
    }

    $argList = @(
        "-NoProfile"
        "-ExecutionPolicy", "Bypass"
        "-File", "`"$PSCommandPath`""
        "-Elevated"
    )
    if ($Uninstall) { $argList += "-Uninstall" }

    Write-Info "Requesting administrator rights..."
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs | Out-Null
    } catch {
        Write-Err "Elevation was declined or failed: $($_.Exception.Message)"
        return 1
    }
    Write-Info "Continuing in the elevated window."
    return 0
}

function Get-SteamInstallPath {
    $paths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam"
    )

    foreach ($path in $paths) {
        try {
            $props = Get-ItemProperty -Path $path -ErrorAction Stop
            if ($props.SteamPath -and (Test-Path $props.SteamPath)) { return $props.SteamPath }
            if ($props.InstallPath -and (Test-Path $props.InstallPath)) { return $props.InstallPath }
        } catch {}
    }

    return $null
}

function Get-SteamLibraryFolders($SteamPath) {
    # Paths from the registry and from libraryfolders.vdf differ in case and slash
    # direction for the same folder, so normalise before de-duplicating.
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $libraries = New-Object System.Collections.Generic.List[string]

    function Add-Library($Path) {
        if (!$Path) { return }
        try { $full = [IO.Path]::GetFullPath($Path.Replace("/", "\").TrimEnd("\")) } catch { return }
        if ((Test-Path $full) -and $seen.Add($full)) { $libraries.Add($full) }
    }

    Add-Library $SteamPath

    if ($SteamPath) {
        $vdfPath = Join-Path $SteamPath "steamapps\libraryfolders.vdf"
        if (Test-Path $vdfPath) {
            $content = Get-Content $vdfPath -Raw
            foreach ($match in [regex]::Matches($content, '"path"\s+"([^"]+)"')) {
                Add-Library $match.Groups[1].Value.Replace("\\", "\")
            }
        }
    }

    return ,$libraries.ToArray()
}

function Test-SteamGameInstalled($SteamPath, $AppId) {
    if (!$SteamPath) { return $false }

    foreach ($library in (Get-SteamLibraryFolders -SteamPath $SteamPath)) {
        $manifest = Join-Path $library "steamapps\appmanifest_$AppId.acf"
        if (Test-Path $manifest) { return $true }
    }

    return $false
}

function Get-GameExePath($SteamPath, $AppId, $ExeName) {
    # Only used to give the desktop shortcut the game's own icon.
    if (!$SteamPath) { return $null }

    foreach ($library in (Get-SteamLibraryFolders -SteamPath $SteamPath)) {
        $manifest = Join-Path $library "steamapps\appmanifest_$AppId.acf"
        if (!(Test-Path $manifest)) { continue }

        $installDir = [regex]::Match((Get-Content $manifest -Raw), '"installdir"\s+"([^"]+)"').Groups[1].Value
        if (!$installDir) { continue }

        $gameDir = Join-Path $library "steamapps\common\$installDir"
        if (!(Test-Path $gameDir)) { continue }

        $exe = Get-ChildItem -Path $gameDir -Filter $ExeName -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($exe) { return $exe.FullName }
    }

    return $null
}

function Test-NipProfile {
    param([string]$Path)

    # The repo ships a placeholder .nip. Importing it makes nvidiaProfileInspector
    # sit on an error dialog forever, so reject anything that is not real profile XML.
    if (!(Test-Path $Path)) { return "File not found: $Path" }

    $raw = Get-Content -Path $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return "File is empty." }
    if ($raw -match "PLACEHOLDER FILE") {
        return "This is the placeholder shipped with the repository, not a real profile."
    }

    try {
        $xml = [xml]$raw
    } catch {
        return "File is not valid XML: $($_.Exception.Message)"
    }

    if (!$xml.DocumentElement) { return "File has no XML root element." }
    if ($xml.DocumentElement.Name -notmatch "Profile") {
        return "Unexpected XML root <$($xml.DocumentElement.Name)>; expected an exported profile."
    }
    if (!$xml.SelectSingleNode("//Profile")) {
        return "No <Profile> element found in the file."
    }

    return $null
}

function Install-NvidiaProfileInspector {
    param([string]$TargetDir, [string]$TargetExe)

    if (Test-Path $TargetExe) {
        Write-Ok "NVIDIA Profile Inspector already exists: $TargetExe"
        return
    }

    Write-Warn "NVIDIA Profile Inspector was not found."
    Write-Info "It will be downloaded from the official GitHub repository:"
    Write-Info "https://github.com/Orbmu2k/nvidiaProfileInspector/releases"

    $confirm = Read-Host "Download and install NVIDIA Profile Inspector now? Type Y to continue"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        throw "User cancelled NVIDIA Profile Inspector download."
    }

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

    $headers = @{ "User-Agent" = "FFXII-NVIDIA-Fix-Installer" }
    $apiUrl = "https://api.github.com/repos/Orbmu2k/nvidiaProfileInspector/releases/latest"
    Write-Info "Reading latest release information..."
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing

    $asset = $release.assets |
        Where-Object { $_.name -match "nvidiaProfileInspector.*\.zip$" } |
        Select-Object -First 1

    if (!$asset) {
        throw "Could not find NVIDIA Profile Inspector ZIP asset in the latest GitHub release."
    }

    $zipPath = Join-Path $TargetDir $asset.name
    Write-Info "Downloading: $($asset.browser_download_url)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers $headers -UseBasicParsing

    Write-Info "Extracting NVIDIA Profile Inspector..."
    Expand-Archive -Path $zipPath -DestinationPath $TargetDir -Force

    $foundExe = Get-ChildItem -Path $TargetDir -Recurse -Filter "nvidiaProfileInspector.exe" | Select-Object -First 1
    if (!$foundExe) { throw "nvidiaProfileInspector.exe was not found after extraction." }

    if ($foundExe.FullName -ne $TargetExe) {
        Copy-Item -Path $foundExe.FullName -Destination $TargetExe -Force
    }

    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    Write-Ok "NVIDIA Profile Inspector installed: $TargetExe"
}

function Backup-DriverProfileStore {
    param([string]$Destination)

    if (!(Test-Path $DrsDir)) {
        Write-Warn "NVIDIA driver profile store not found at: $DrsDir"
        Write-Warn "Skipping backup."
        return $false
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    $copied = 0
    foreach ($name in @("nvdrsdb0.bin", "nvdrsdb1.bin", "nvdrssel.bin")) {
        $source = Join-Path $DrsDir $name
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination (Join-Path $Destination $name) -Force
            $copied++
        }
    }

    if ($copied -eq 0) {
        Write-Warn "No driver profile files were found to back up."
        return $false
    }

    Write-Ok "Backed up $copied driver profile file(s) to: $Destination"
    return $true
}

function Import-NvidiaProfile {
    param([string]$Exe, [string]$NipPath, [int]$TimeoutSec)

    # nvidiaProfileInspector is a GUI application: the call operator returns before it
    # exits and never populates $LASTEXITCODE, so wait on the process explicitly.
    # It also exits 0 even when the import fails, so the exit code proves nothing --
    # compare the driver profile store timestamp instead. Observed runtime is 3-11s.
    $before = Get-DrsStamp

    # Start-Process joins an array ArgumentList with spaces and does not quote it,
    # so quote the path here for users whose profile folder contains spaces.
    $quotedNip = '"' + $NipPath + '"'
    $proc = Start-Process -FilePath $Exe -ArgumentList @("-silentImport", $quotedNip) -PassThru

    if (!$proc.WaitForExit($TimeoutSec * 1000)) {
        try { $proc.Kill() } catch {}
        throw "NVIDIA Profile Inspector did not finish within $TimeoutSec seconds. It most likely opened an error dialog. The profile was NOT imported."
    }

    if ($proc.ExitCode -ne 0) {
        throw "NVIDIA Profile Inspector exited with code $($proc.ExitCode). The profile was NOT imported."
    }

    return ($before -ne (Get-DrsStamp))
}

function Get-DrsStamp {
    $db = Join-Path $DrsDir "nvdrsdb0.bin"
    if (Test-Path $db) {
        return (Get-Item $db).LastWriteTimeUtc.ToString("o")
    }
    return ""
}

function Invoke-Uninstall {
    Write-Step "Uninstalling $AppName"

    $restored = $false
    if (Test-Path $BackupDir) {
        $answer = Read-Host "Restore the NVIDIA driver profiles backed up before install? Type Y to restore"
        if ($answer -eq "Y" -or $answer -eq "y") {
            Write-Warn "The NVIDIA display driver service must not be writing profiles during restore."
            foreach ($file in Get-ChildItem -Path $BackupDir -Filter "*.bin") {
                Copy-Item -Path $file.FullName -Destination (Join-Path $DrsDir $file.Name) -Force
            }
            $restored = $true
            Write-Ok "Driver profiles restored. Reboot for the change to take full effect."
        } else {
            Write-Info "Driver profiles left unchanged."
        }
    } else {
        Write-Warn "No backup found at: $BackupDir"
    }

    if (Test-Path $DesktopShortcut) {
        Remove-Item -Path $DesktopShortcut -Force
        Write-Ok "Desktop shortcut removed."
    }

    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Ok "Removed: $InstallDir"
    }

    if (!$restored) {
        Write-Info "The FFXII driver profile itself was not reverted."
        Write-Info "To revert it manually, open NVIDIA Control Panel and restore FFXII to defaults."
    }

    Write-Ok "Uninstall complete."
    return 0
}

function Invoke-Install {
    Write-Step "FFXII NVIDIA Fatal Error Fix Installer"

    Write-Step "1. Checking NVIDIA GPU"
    $gpuList = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
    $nvidiaGpu = $gpuList | Where-Object { $_ -match "NVIDIA" }

    if ($nvidiaGpu) {
        Write-Ok "NVIDIA GPU detected:"
        $nvidiaGpu | ForEach-Object { Write-Host " - $_" }
    } else {
        Write-Warn "No NVIDIA GPU detected. This fix is only useful for NVIDIA driver profiles."
    }

    Write-Step "2. Validating the .nip profile"
    Write-Info "Why .nip is needed:"
    Write-Info ".nip is an exported NVIDIA Profile Inspector profile."
    Write-Info "It contains the FFXII-specific driver setting where Shader Cache is disabled."
    Write-Info "This affects only FFXII and does not change global settings for all games."

    if (!(Test-Path $BundledProfile)) {
        Write-Err "Required profile file is missing:"
        Write-Host $BundledProfile
        throw "Place $ProfileFileName next to Install_FFXII_NVIDIA_Fix.ps1."
    }

    $nipProblem = Test-NipProfile -Path $BundledProfile
    if ($nipProblem) {
        Write-Err "The profile file is not usable:"
        Write-Host "  $BundledProfile"
        Write-Host "  $nipProblem"
        Write-Host ""
        Write-Info "To create a real profile:"
        Write-Info "  1. Open nvidiaProfileInspector.exe"
        Write-Info "  2. Select the '$GameName' profile"
        Write-Info "  3. Set 'Shader Cache' to Off and apply"
        Write-Info "  4. Export the profile as $ProfileFileName"
        Write-Info "  5. Overwrite the file next to this installer, then run it again"
        throw "Aborting before touching any driver settings."
    }
    Write-Ok "Profile file looks valid."

    Write-Step "3. Installing NVIDIA Profile Inspector if missing"
    Install-NvidiaProfileInspector -TargetDir $InstallDir -TargetExe $NpiExe

    Write-Step "4. Checking Steam and FFXII installation"
    $steamPath = Get-SteamInstallPath

    if ($steamPath) {
        Write-Ok "Steam found: $steamPath"
    } else {
        Write-Warn "Steam was not found in registry."
    }

    $gameInstalled = Test-SteamGameInstalled -SteamPath $steamPath -AppId $SteamAppId
    if ($gameInstalled) {
        Write-Ok "$GameName appears to be installed in Steam."
    } else {
        Write-Warn "$GameName was not found in Steam libraries."
        Write-Warn "Steam App ID checked: $SteamAppId"
    }

    Write-Step "5. Backing up current NVIDIA driver profiles"
    Backup-DriverProfileStore -Destination $BackupDir | Out-Null
    Write-Info "Run this installer with -Uninstall to restore the backup."

    Write-Step "6. Copying .nip profile"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -Path $BundledProfile -Destination $InstalledProfile -Force
    Write-Ok "Profile copied to: $InstalledProfile"

    Write-Step "7. Importing NVIDIA profile"
    $storeChanged = Import-NvidiaProfile -Exe $NpiExe -NipPath $InstalledProfile -TimeoutSec $ImportTimeoutSec
    if ($storeChanged) {
        Write-Ok "Profile imported successfully."
    } else {
        Write-Warn "The driver profile store did not change."
        Write-Warn "This is expected if the profile was already applied, but it also"
        Write-Warn "happens when the import silently fails. Verify in NVIDIA Profile"
        Write-Warn "Inspector that Shader Cache is Off for $GameName."
    }

    $state = @{ DrsStamp = Get-DrsStamp }
    $state | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8

    Write-Step "8. Creating desktop launcher"

    $launcherContent = @"
# Generated by $AppName. Re-run the installer to regenerate.
`$ErrorActionPreference = "Stop"

`$NpiExe = "$NpiExe"
`$NipPath = "$InstalledProfile"
`$StateFile = "$StateFile"
`$DrsDb = "$(Join-Path $DrsDir 'nvdrsdb0.bin')"
`$SteamGame = "steam://rungameid/$SteamAppId"
`$TimeoutSec = $ImportTimeoutSec

function Test-NipUsable {
    # An invalid .nip makes nvidiaProfileInspector sit on an error dialog instead of
    # exiting, which would stall the launch. Never hand it a file we have not checked.
    param([string]`$Path)
    if (!(Test-Path `$Path)) { return `$false }
    `$raw = Get-Content -Path `$Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace(`$raw)) { return `$false }
    if (`$raw -match "PLACEHOLDER FILE") { return `$false }
    try { `$xml = [xml]`$raw } catch { return `$false }
    if (!`$xml.DocumentElement -or `$xml.DocumentElement.Name -notmatch "Profile") { return `$false }
    return [bool]`$xml.SelectSingleNode("//Profile")
}

function Test-ProfileStillApplied {
    # Re-importing needs administrator rights, which means a UAC prompt on every
    # launch. The driver profile persists, so only re-import when the driver
    # profile store changed (driver update, GeForce Experience reset, etc).
    if (!(Test-Path `$StateFile) -or !(Test-Path `$DrsDb)) { return `$false }
    try {
        `$saved = (Get-Content `$StateFile -Raw | ConvertFrom-Json).DrsStamp
    } catch { return `$false }
    return `$saved -eq (Get-Item `$DrsDb).LastWriteTimeUtc.ToString("o")
}

if (!(Test-NipUsable `$NipPath)) {
    # No profile to import. Whatever was set by hand in NVIDIA Profile Inspector
    # is stored in the driver and stays applied, so just start the game.
    Write-Host "No exported .nip available - using the driver profile as-is."
} elseif (Test-ProfileStillApplied) {
    Write-Host "FFXII NVIDIA profile is still applied. Skipping re-import."
} else {
    Write-Host "Driver profiles changed since install. Re-applying FFXII NVIDIA profile..."
    `$quotedNip = '"' + `$NipPath + '"'
    `$proc = Start-Process -FilePath `$NpiExe -ArgumentList @("-silentImport", `$quotedNip) -PassThru
    if (!`$proc.WaitForExit(`$TimeoutSec * 1000)) {
        try { `$proc.Kill() } catch {}
        Write-Warning "Profile import timed out. Launching the game anyway."
    } elseif (`$proc.ExitCode -ne 0) {
        Write-Warning "Profile import failed with exit code `$(`$proc.ExitCode). Launching the game anyway."
    } else {
        Write-Host "Profile re-applied."
        @{ DrsStamp = (Get-Item `$DrsDb).LastWriteTimeUtc.ToString("o") } |
            ConvertTo-Json | Set-Content -Path `$StateFile -Encoding UTF8
    }
}

Write-Host "Launching $GameName..."
Start-Process `$SteamGame
"@

    Set-Content -Path $LauncherPath -Value $launcherContent -Encoding UTF8

    $gameExe = Get-GameExePath -SteamPath $steamPath -AppId $SteamAppId -ExeName $GameExeName
    $iconLocation = if ($gameExe) { "$gameExe,0" } else { "powershell.exe,0" }

    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($DesktopShortcut)
    $shortcut.TargetPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    # -WindowStyle Hidden keeps a console from flashing up on every launch.
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$LauncherPath`""
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.IconLocation = $iconLocation
    $shortcut.Description = "Applies the FFXII NVIDIA profile if needed, then launches the game"
    $shortcut.Save()

    Write-Ok "Desktop shortcut created:"
    Write-Host $DesktopShortcut

    Write-Step "9. Launching game"

    if ($gameInstalled) {
        $launch = Read-Host "Launch $GameName now? Type Y to launch"
        if ($launch -eq "Y" -or $launch -eq "y") {
            Start-Process "steam://rungameid/$SteamAppId"
            Write-Ok "Game launch requested through Steam."
        } else {
            Write-Info "You can launch later using the desktop shortcut."
        }
    } else {
        Write-Warn "Game was not detected, so automatic launch was skipped."
        Write-Info "After installing FFXII, use the desktop shortcut."
    }

    Write-Host ""
    Write-Ok "Done."
    return 0
}

$exitCode = 1
try {
    if (!(Test-IsAdmin)) {
        if ($Elevated) {
            # Already relaunched once and still not admin - do not loop.
            throw "Administrator rights are required but were not granted."
        }
        $exitCode = Invoke-SelfElevate
        exit $exitCode
    }

    # Pipe to Out-Null so stray function output cannot turn $exitCode into an array;
    # a thrown error is the only failure signal these two need.
    if ($Uninstall) { Invoke-Uninstall | Out-Null } else { Invoke-Install | Out-Null }
    $exitCode = 0
} catch {
    Write-Host ""
    Write-Err $_.Exception.Message
    Write-Host ""
    Write-Host "Installer stopped."
    $exitCode = 1
}

if (!$NoPause) { Read-Host "Press Enter to close" | Out-Null }
exit $exitCode
