# FFXII NVIDIA Fatal Error Fix

One-click installer that fixes the "Fatal Error" crash in **Final Fantasy XII: The Zodiac Age** on recent NVIDIA drivers (591.xx and newer).

## Problem

Recent NVIDIA drivers may cause FFXII to crash during startup while shaders are being initialized.
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
* Downloads NVIDIA Profile Inspector from the official source if missing
* Checks whether FFXII is installed
* Imports a game-specific NVIDIA profile
* Disables Shader Cache only for FFXII
* Creates a desktop launcher
* Offers to launch the game

---

## Installation

1. Download the latest release.
2. Extract the ZIP archive.
3. Run:

```text
Install_FFXII_NVIDIA_Fix.bat
```

4. Follow the on-screen instructions.

> **Important:** Do not run the BAT file directly from inside the ZIP archive. Extract the archive first.

---

## Files Included

### Install_FFXII_NVIDIA_Fix.bat

Simple launcher that starts the PowerShell installer.

### Install_FFXII_NVIDIA_Fix.ps1

Main installer responsible for downloading dependencies, importing the profile, and creating shortcuts.

### FFXII_ShaderCacheOff.nip

NVIDIA Profile Inspector profile for FFXII.

---

## What the Installer Does

### 1. Checks for NVIDIA GPU

Verifies that an NVIDIA graphics card is installed.

### 2. Downloads NVIDIA Profile Inspector

If NVIDIA Profile Inspector is not found, the installer offers to download the latest version from the official GitHub repository.

### 3. Checks Steam and FFXII Installation

Detects Steam and verifies whether Final Fantasy XII: The Zodiac Age is installed.

### 4. Copies the NVIDIA Profile

Copies:

```text
FFXII_ShaderCacheOff.nip
```

to:

```text
%LOCALAPPDATA%\FFXII_NVIDIA_Fix
```

### 5. Imports the Profile

Automatically imports the profile using:

```text
nvidiaProfileInspector.exe -silentImport
```

### 6. Creates a Desktop Shortcut

Creates:

```text
Start FFXII with NVIDIA Fix
```

on the user's desktop.

### 7. Launches the Game

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

The `.nip` file is an exported NVIDIA Profile Inspector profile.

It stores the FFXII-specific driver setting where **Shader Cache** is disabled.

This approach is safer than changing global NVIDIA settings because it only affects Final Fantasy XII and leaves all other games untouched.

---

## Tested

* Windows 10
* Windows 11
* NVIDIA Drivers 591.xx and newer

---

## Disclaimer

This project is not affiliated with Square Enix or NVIDIA.

NVIDIA Profile Inspector is downloaded from its official GitHub repository:

https://github.com/Orbmu2k/nvidiaProfileInspector

Use this tool at your own risk. The installer only imports a game-specific NVIDIA profile and does not modify global NVIDIA settings.

Typical symptoms:

* "Fatal Error" on launch
* Crash during shader initialization
* Game closes before reaching the main menu

## Solution

This installer automatically:

* Checks for an NVIDIA GPU
* Downloads NVIDIA Profile Inspector (official source) if missing
* Checks whether FFXII is installed
* Imports a game-specific NVIDIA profile
* Disables Shader Cache only for FFXII
* Creates a desktop launcher
* Launches the game

## Installation

1. Download the latest release.
2. Extract the archive.
3. Run:

Install_FFXII_NVIDIA_Fix.bat

4. Follow the on-screen instructions.

## Why use a profile instead of global settings?

The fix is applied only to Final Fantasy XII.

Benefits:

* Does not affect other games
* No driver rollback required
* Easy to remove or reapply
* Safe after driver updates

## Tested

* Windows 10
* Windows 11
* NVIDIA Drivers 591.xx+

## Disclaimer

This project is not affiliated with Square Enix or NVIDIA.
NVIDIA Profile Inspector is downloaded from its official GitHub repository.
