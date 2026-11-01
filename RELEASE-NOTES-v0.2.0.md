# Keyboard driver v0.2.0

## Changes

- `install-test.ps1`: enables test signing automatically and asks for a reboot instead of requiring it beforehand.
- Added `manager.ps1` + `start-manager.cmd` — interactive menu with self-elevation and live state.

## Install

1. Unpack into a normal folder.
2. Run `start-manager.cmd` → option **1**.
3. Reboot → option **1** again.
4. Reboot → check the keyboard in Notepad.

If the keyboard does not type, run `collect-diagnostics.ps1`. `BytesRead = 0` means the firmware does not deliver keyboard bytes to the i8042 ports — a firmware limitation.

## Tested

Dell Latitude 5400 Chromebook (Sarien), Windows 10 IoT Enterprise LTSC 2021 x64, TianoCore / RW_LEGACY, no Secure Boot.

## Files

| File | Purpose |
|---|---|
| `SarienI8042.inf` / `.sys` | driver |
| `SarienI8042-Test.cer` | test certificate |
| `sarieni8042.cat` | signature |
| `install-test.ps1` | installer |
| `uninstall-test.ps1` | uninstaller |
| `collect-diagnostics.ps1` | diagnostics |
| `manager.ps1` | interactive menu |
| `start-manager.cmd` | menu launcher (elevates) |
| `devcon.exe` | root device creation |
