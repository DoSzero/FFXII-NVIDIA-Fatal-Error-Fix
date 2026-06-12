# FFXII The Zodiac Age - NVIDIA Fatal Error Fix Installer
# Version: 1.1

$ErrorActionPreference = "Stop"

$AppName = "FFXII_NVIDIA_Fix"
$GameName = "Final Fantasy XII: The Zodiac Age"
$SteamAppId = "595520"
$ProfileFileName = "FFXII_ShaderCacheOff.nip"

$InstallDir = Join-Path $env:LOCALAPPDATA $AppName
$NpiExe = Join-Path $InstallDir "nvidiaProfileInspector.exe"
$InstalledProfile = Join-Path $InstallDir $ProfileFileName
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BundledProfile = Join-Path $ScriptDir $ProfileFileName
$LauncherPath = Join-Path $InstallDir "Start_FFXII_With_NVIDIA_Fix.ps1"
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Start FFXII with NVIDIA Fix.lnk"

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
    $libraries = New-Object System.Collections.Generic.List[string]

    if ($SteamPath -and (Test-Path $SteamPath)) {
        $libraries.Add($SteamPath)
    }

    $vdfPath = Join-Path $SteamPath "steamapps\libraryfolders.vdf"
    if (Test-Path $vdfPath) {
        $content = Get-Content $vdfPath -Raw
        $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
        foreach ($match in $matches) {
            $libraryPath = $match.Groups[1].Value.Replace("\\", "\")
            if ($libraryPath -and (Test-Path $libraryPath) -and !$libraries.Contains($libraryPath)) {
                $libraries.Add($libraryPath)
            }
        }
    }

    return $libraries
}

function Test-SteamGameInstalled($SteamPath, $AppId) {
    if (!$SteamPath) { return $false }

    $libraries = Get-SteamLibraryFolders -SteamPath $SteamPath
    foreach ($library in $libraries) {
        $manifest = Join-Path $library "steamapps\appmanifest_$AppId.acf"
        if (Test-Path $manifest) { return $true }
    }

    return $false
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

    $apiUrl = "https://api.github.com/repos/Orbmu2k/nvidiaProfileInspector/releases/latest"
    Write-Info "Reading latest release information..."
    $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "FFXII-NVIDIA-Fix-Installer" }

    $asset = $release.assets | Where-Object {
        $_.name -match "nvidiaProfileInspector.*\.zip$" -or $_.name -match "NvidiaProfileInspector.*\.zip$"
    } | Select-Object -First 1

    if (!$asset) {
        throw "Could not find NVIDIA Profile Inspector ZIP asset in the latest GitHub release."
    }

    $zipPath = Join-Path $TargetDir $asset.name
    Write-Info "Downloading: $($asset.browser_download_url)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers @{ "User-Agent" = "FFXII-NVIDIA-Fix-Installer" }

    Write-Info "Extracting NVIDIA Profile Inspector..."
    Expand-Archive -Path $zipPath -DestinationPath $TargetDir -Force

    $foundExe = Get-ChildItem -Path $TargetDir -Recurse -Filter "nvidiaProfileInspector.exe" | Select-Object -First 1
    if (!$foundExe) { throw "nvidiaProfileInspector.exe was not found after extraction." }

    if ($foundExe.FullName -ne $TargetExe) {
        Copy-Item -Path $foundExe.FullName -Destination $TargetExe -Force
    }

    Write-Ok "NVIDIA Profile Inspector installed: $TargetExe"
}

try {
    Write-Step "FFXII NVIDIA Fatal Error Fix Installer"

    if (!(Test-IsAdmin)) {
        Write-Warn "Administrator rights are recommended."
        Write-Warn "If profile import fails, restart this installer as Administrator."
    }

    Write-Step "1. Checking NVIDIA GPU"
    $gpuList = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
    $nvidiaGpu = $gpuList | Where-Object { $_ -match "NVIDIA" }

    if ($nvidiaGpu) {
        Write-Ok "NVIDIA GPU detected:"
        $nvidiaGpu | ForEach-Object { Write-Host " - $_" }
    } else {
        Write-Warn "No NVIDIA GPU detected. This fix is only useful for NVIDIA driver profiles."
    }

    Write-Step "2. Installing NVIDIA Profile Inspector if missing"
    Install-NvidiaProfileInspector -TargetDir $InstallDir -TargetExe $NpiExe

    Write-Step "3. Checking Steam and FFXII installation"
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

    Write-Step "4. Copying .nip profile"
    Write-Info "Why .nip is needed:"
    Write-Info ".nip is an exported NVIDIA Profile Inspector profile."
    Write-Info "It contains the FFXII-specific driver setting where Shader Cache is disabled."
    Write-Info "This affects only FFXII and does not change global settings for all games."

    if (!(Test-Path $BundledProfile)) {
        Write-Err "Required profile file is missing:"
        Write-Host $BundledProfile
        throw "Place $ProfileFileName next to Install_FFXII_NVIDIA_Fix.ps1."
    }

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -Path $BundledProfile -Destination $InstalledProfile -Force
    Write-Ok "Profile copied to: $InstalledProfile"

    Write-Step "5. Importing NVIDIA profile"
    & $NpiExe -silentImport $InstalledProfile

    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Profile import returned exit code: $LASTEXITCODE"
        Write-Warn "Try running this installer as Administrator."
    } else {
        Write-Ok "Profile imported successfully."
    }

    Write-Step "6. Creating desktop launcher"

    $launcherContent = @"
`$ErrorActionPreference = "Stop"

`$NpiExe = "$NpiExe"
`$Profile = "$InstalledProfile"
`$SteamGame = "steam://rungameid/$SteamAppId"

Write-Host "Applying FFXII NVIDIA profile..."
& `$NpiExe -silentImport `$Profile

Write-Host "Launching $GameName..."
Start-Process `$SteamGame
"@

    Set-Content -Path $LauncherPath -Value $launcherContent -Encoding UTF8

    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($DesktopShortcut)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$LauncherPath`""
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.IconLocation = "powershell.exe,0"
    $shortcut.Save()

    Write-Ok "Desktop shortcut created:"
    Write-Host $DesktopShortcut

    Write-Step "7. Launching game"

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
} catch {
    Write-Host ""
    Write-Err $_.Exception.Message
    Write-Host ""
    Write-Host "Installer stopped."
}

Read-Host "Press Enter to close"
