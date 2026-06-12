# FFXII NVIDIA Fatal Error Fix

One-click installer that fixes the "Fatal Error" crash in **Final Fantasy XII: The Zodiac Age** on recent NVIDIA drivers (591.xx and newer).

## Problem

Recent NVIDIA drivers may cause FFXII to crash during startup while shaders are being initialized.

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
