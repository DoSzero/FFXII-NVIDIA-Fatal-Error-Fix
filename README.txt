FFXII The Zodiac Age — NVIDIA Fatal Error Fix Installer

HOW TO USE
----------
1. Extract the ZIP archive first.
2. Run:
   Install_FFXII_NVIDIA_Fix.bat

Do not run the BAT directly from inside the ZIP archive.

FILES
-----
1. Install_FFXII_NVIDIA_Fix.bat
   Simple launcher for the PowerShell installer.

2. Install_FFXII_NVIDIA_Fix.ps1
   Main installer.

3. FFXII_ShaderCacheOff.nip
   NVIDIA Profile Inspector profile for FFXII.

WHAT THE INSTALLER DOES
-----------------------
1. Checks for NVIDIA GPU.
2. Downloads NVIDIA Profile Inspector from the official GitHub releases if missing.
3. Checks Steam and FFXII installation.
4. Copies FFXII_ShaderCacheOff.nip to:
   %LOCALAPPDATA%\FFXII_NVIDIA_Fix

5. Imports the profile using:
   nvidiaProfileInspector.exe -silentImport

6. Creates a desktop shortcut:
   Start FFXII with NVIDIA Fix

7. Offers to launch the game.

WHY .NIP IS NEEDED
------------------
The .nip file is an exported NVIDIA Profile Inspector profile.
It stores the FFXII-specific driver setting where Shader Cache is disabled.

This is better than changing global NVIDIA settings because:
- it affects only Final Fantasy XII;
- it does not affect other games;
- it is easy to re-apply after driver updates.
