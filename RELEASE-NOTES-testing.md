# Keyboard driver v0.3.1-testing (pre-release)

Test build from the `testing` branch. Driver binary is identical to v0.3.0; only the tooling changed.

## Added

- `cleanup.ps1` — removes the root device, stale (ghost) keyboard entries and optionally the driver package.
- Manager menu entries **8) Clean up devices (keep driver)** and **9) Remove everything**.

## Install

1. Unpack into a normal folder.
2. Run `start-manager.cmd` → option **1**.
3. Reboot → option **1** again.
4. If Device Manager shows several keyboards: option **9**, then reinstall with option **1**.

## Files

| File | Purpose |
|---|---|
| `SarienI8042.inf` / `.sys` | driver |
| `SarienI8042-Test.cer` | test certificate |
| `sarieni8042.cat` | signature |
| `install-test.ps1` | installer |
| `uninstall-test.ps1` | uninstaller |
| `cleanup.ps1` | removes devices / driver package |
| `collect-diagnostics.ps1` | diagnostics |
| `manager.ps1` | interactive menu |
| `start-manager.cmd` | menu launcher (elevates) |
| `devcon.exe` | root device creation |
