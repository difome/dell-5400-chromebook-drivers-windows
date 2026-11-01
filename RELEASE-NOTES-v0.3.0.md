# Keyboard driver v0.3.0

## Fixed

- **Stuck and repeating keys.** The driver polls the i8042 output buffer, so a dropped break code left a phantom key in the HID report and Windows auto-repeated it forever. If no byte arrives for 1.2 s while keys are marked pressed, the report is released.
- Typematic is now enabled on the EC (`F3`), so a real key hold keeps producing bytes and is never mistaken for a lost break code.
- Command acknowledgements (`0xFA` / `0xFE`) and echo (`0xEE`) are filtered out of the scan-code stream. They were decoded as unmapped keys.
- The poll loop drains up to 64 bytes per tick instead of 32.

## Added

- Top row **Fullscreen** → `F11`.
- Top row **Overview** → `Win+Tab`.
- Top row **Snapshot** → `Win+Shift+S`.

## Install

1. Unpack into a normal folder.
2. Run `start-manager.cmd` → option **1**.
3. Reboot → option **1** again.
4. Reboot → check the keyboard in Notepad.

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
