# FFXII NVIDIA Fatal Error Fix

One-click installer that fixes the **"Fatal Error"** crash in **Final Fantasy XII: The Zodiac Age** on recent NVIDIA drivers (591.xx and newer).

---

## Problem

Recent NVIDIA drivers may cause FFXII to crash during startup while shaders are being initialized.

### Typical symptoms

* "Fatal Error" on launch
* Crash during shader initialization
* Game closes before reaching the main menu

---

## Solution

This installer automatically:

* Checks for an NVIDIA GPU
* Validates the bundled `.nip` profile before touching any driver setting
* Downloads NVIDIA Profile Inspector from the official source if missing
* Checks whether FFXII is installed
* Backs up your current NVIDIA driver profile store
* Imports a game-specific NVIDIA profile
* Disables Shader Cache only for FFXII
* Creates a desktop launcher
* Offers to launch the game

---

## Before You Start

> **The bundled `.nip` was exported on driver 591.86.** It works as-is on that
> driver. A `.nip` is tied to the driver version it came from, so if the import
> fails or the crash persists on a different driver, export a replacement
> yourself using the steps below.

1. Run the installer once so it downloads `nvidiaProfileInspector.exe` into
   `%LOCALAPPDATA%\FFXII_NVIDIA_Fix`, or download it yourself from the
   [official releases page](https://github.com/Orbmu2k/nvidiaProfileInspector/releases).
2. Open `nvidiaProfileInspector.exe`.
3. Select the **Final Fantasy XII: The Zodiac Age** profile.
4. Set **Shader Cache** to `Off` and apply.
5. Export the profile as `FFXII_ShaderCacheOff.nip`.
6. Overwrite the file next to `Install_FFXII_NVIDIA_Fix.bat`.

If the `.nip` is missing, empty, or not valid profile XML, the installer stops with
a clear error and changes nothing.

---

## Installation

1. Download the latest release.
2. Extract the ZIP archive.
3. Run:

```text
Install_FFXII_NVIDIA_Fix.bat
```

4. Approve the UAC prompt — importing driver profiles requires administrator rights.
5. Follow the on-screen instructions.

> **Important:** Do not run the BAT file directly from inside the ZIP archive. Extract the archive first.

---

## Uninstall

```text
powershell -ExecutionPolicy Bypass -File Install_FFXII_NVIDIA_Fix.ps1 -Uninstall
```

This offers to restore the driver profile backup taken during installation, then
removes the desktop shortcut and `%LOCALAPPDATA%\FFXII_NVIDIA_Fix`.

---

## Files Included

| File | Purpose |
| --- | --- |
| `Install_FFXII_NVIDIA_Fix.bat` | Launcher that starts the PowerShell installer and reports its exit code |
| `Install_FFXII_NVIDIA_Fix.ps1` | Main installer: validation, download, backup, profile import, shortcut creation |
| `FFXII_ShaderCacheOff.nip` | NVIDIA Profile Inspector profile for FFXII, exported on driver 591.86 |

---

## What the Installer Does

### 1. Elevates itself

Importing a driver profile requires administrator rights, so the installer
re-launches itself elevated once and prompts for UAC a single time.

### 2. Checks for an NVIDIA GPU

Verifies that an NVIDIA graphics card is installed.

### 3. Validates the `.nip` profile

Confirms the file is real profile XML and not a placeholder stub. Importing
an invalid `.nip` makes NVIDIA Profile Inspector hang on an error dialog, so the
installer aborts first and leaves driver settings untouched.

### 4. Downloads NVIDIA Profile Inspector

If not found, the installer offers to download the latest version from the
official GitHub repository.

### 5. Checks Steam and FFXII installation

Detects Steam from the registry, parses `libraryfolders.vdf`, and looks for
`appmanifest_595520.acf` across every Steam library.

### 6. Backs up your driver profiles

Copies `nvdrsdb0.bin`, `nvdrsdb1.bin`, and `nvdrssel.bin` from
`%ProgramData%\NVIDIA Corporation\Drs` into
`%LOCALAPPDATA%\FFXII_NVIDIA_Fix\Backup` so `-Uninstall` can roll back.

### 7. Imports the profile

Runs `nvidiaProfileInspector.exe -silentImport`, waits for the process to
actually exit, and fails loudly on a non-zero exit code or a 60-second timeout.

### 8. Creates a desktop shortcut

Creates **Start FFXII with NVIDIA Fix** on the desktop. The launcher only
re-imports the profile when the driver profile store has changed since install
(driver update, GeForce Experience reset), so normal launches do not trigger UAC.

### 9. Launches the game

Optionally launches FFXII through Steam after installation.

---

## Why Use a Profile Instead of Global Settings?

The fix is applied only to **Final Fantasy XII: The Zodiac Age**.

### Benefits

* Does not affect other games
* No driver rollback required
* Easy to remove or reapply
* Safe after NVIDIA driver updates
* No need to modify global NVIDIA settings

---

## Why Is the .NIP File Needed?

The `.nip` file is an exported NVIDIA Profile Inspector profile. It stores the
FFXII-specific driver setting where **Shader Cache** is disabled.

This approach is safer than changing global NVIDIA settings because it only
affects Final Fantasy XII and leaves all other games untouched.

---

## Requirements

* Windows 10 or Windows 11
* Windows PowerShell 5.1 or later
* Administrator rights
* NVIDIA GPU with drivers 591.xx or newer

---

## Disclaimer

This project is not affiliated with Square Enix or NVIDIA.

NVIDIA Profile Inspector is downloaded from its official GitHub repository:

https://github.com/Orbmu2k/nvidiaProfileInspector

Use this tool at your own risk. The installer only imports a game-specific NVIDIA
profile and does not modify global NVIDIA settings.
