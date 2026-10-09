# Sarien i8042 → Virtual HID keyboard prototype

> **Experimental branch:** `experimental/top-row-modes`. The source and builds
> below are intentionally preserved outside the official GitHub Releases.

## Experimental top-row builds

- [ActionKeys — Windows 10 x64](experimental-builds/SarienI8042-ActionKeys-Release-x64.zip):
  ChromeOS-style browser, brightness, media and volume actions. The snapshot
  position is emitted as a real keyboard Print Screen usage.
- [FunctionKeys — Windows 10 x64](experimental-builds/SarienI8042-FunctionKeys-Release-x64.zip):
  the action positions are emitted as F1-F9 and F12. F10/F11 already arrive as
  ordinary function keys.

Fn is handled inside the EC and is not visible to this Windows driver, so the
FunctionKeys package changes those positions unconditionally. To switch modes,
install the other ZIP and reboot. Keep an external USB keyboard connected.

The source can build either package with:

```powershell
.\scripts\build-driver.ps1 -Configuration Release -TopRowMode ActionKeys
.\scripts\build-driver.ps1 -Configuration Release -TopRowMode FunctionKeys
```

> **Windows 10 x64 build:**
> [Download Sarien keyboard driver v0.1.0](https://github.com/difome/dell-5400-chromebook-drivers-windows/releases/download/keyboard-v0.1.0/SarienI8042-Release-x64.zip)
>
> **Tested platform:** Dell Latitude 5400 Chromebook running Windows
> 10 LTSC 2021 x64 (version 21H2, build 19044).
>
> **Development disclosure:** researched, implemented, and documented with
> assistance from **OpenAI Codex**, then compiled and tested on the real Sarien
> hardware.

Source repository:
[difome/dell-5400-chromebook-drivers-windows](https://github.com/difome/dell-5400-chromebook-drivers-windows)

## Hardware compatibility

This driver is intended for and has been tested on:

- **Dell Latitude 5400 Chromebook**;
- Dell regulatory model/type: **`P98G` / `P98G005`**;
- 13-inch display;
- ChromiumOS board and variant: **`sarien`**;
- Intel Core i5-8265U (4 cores / 8 threads, 1.60–3.90 GHz, 6 MB cache);
- 16 GB DDR4-2400 and Intel UHD Graphics 620;
- x86_64 Whiskey Lake platform with the Google Wilco EC;
- Windows 10 LTSC 2021 x64 (21H2, build 19044).

Do not confuse it with the regular Windows Latitude 5400. The related Dell
Latitude 5300 2-in-1 Chromebook Enterprise uses the `arcada` variant and has
not been validated. Dell Latitude 7410 Chromebook Enterprise uses the unrelated
`drallion` platform and is not supported.

See the repository's [target Chromebook table](../../../README.md#target-chromebook)
for processor options, platform details, related models, and identification
commands.

The [full tested-unit hardware profile](../../../docs/sarien-hardware-profile.md)
documents the exact rev17 machine, firmware, ACPI IDs, EC, input devices, PCI
inventory, and captured Windows status used during development.

This is the first hardware-validation driver for the Dell Latitude 5400
Chromebook (Google Sarien) running Windows 10 x64. It polls the firmware/EC
emulated i8042 keyboard ports (`0x60`/`0x64`), decodes the translated PS/2
scan-code set 1 bytes delivered to the host,
and publishes a normal keyboard through Microsoft's Virtual HID Framework.
The HID device also has a Consumer Control collection for Chromebook action
keys.

## Development and upstream research

The implementation used user-provided hardware observations together with
public Windows, Linux, ChromiumOS, and coreboot documentation and source code.
It is an independent Windows KMDF/VHF implementation, not a Linux binary or a
direct port of the Linux kernel driver.

The most relevant upstream projects are:

- [Linux kernel i8042/serio input drivers](https://github.com/torvalds/linux/tree/master/drivers/input/serio)
- [ChromiumOS EC i8042 keyboard implementation](https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/main/common/keyboard_8042.c)
- [coreboot Sarien EC configuration](https://chromium.googlesource.com/chromiumos/third_party/coreboot/+/refs/heads/main/src/mainboard/google/sarien/variants/sarien/include/variant/ec.h)
- [coreboot Wilco PS/2 ACPI declaration](https://chromium.googlesource.com/chromiumos/third_party/coreboot/+/refs/heads/main/src/ec/google/wilco/acpi/superio.asl)

See [architecture findings](docs/architecture-findings.md) for the reasoning,
hardware IDs, scan-code path, and remaining validation work.

## What this prototype proves

The critical unknown is whether the RW_LEGACY/edk2 boot path leaves the
emulated i8042 interface alive for Windows. If the `BytesRead` counter stays
at zero while keys are pressed, the next step is firmware/ACPI work—not more
keyboard-class code. If bytes arrive, this driver is a viable base for a
production keyboard driver.

This prototype does not bind to `ACPI\PNP0303`; it uses the root test ID
`Root\SarienI8042Vhf`. The supplied Windows report is not a complete device
inventory. The install script therefore inspects `PNP0303`, `PNP030B`, and
`GOOG000A`, but only refuses to start when a function-driver service is already
attached to one of those nodes or `i8042prt` is running. A firmware node with
no driver owner is reported as a warning and is safe enough for this diagnostic
prototype.

## Build

Requirements:

- Visual Studio 2022 or newer with the Desktop C++ workload
- Visual Studio NuGet support (the project pins the official WDK/SDK NuGet
  packages at `10.0.28000.2526`)
- x64 Debug configuration for initial testing

Open `SarienI8042.sln`, restore NuGet packages, and build `Debug | x64`. The package output must contain
`SarienI8042.sys`, `SarienI8042.inf`, and a generated/test-signed catalog.
Alternatively, run `scripts/build-driver.ps1` after Visual Studio and WDK are
installed. The script creates ready-to-copy ZIP files in `artifacts`; the Debug
ZIP is intended for the first hardware capture.

The driver uses `VhfKm.lib` and requires Windows 10 or newer. Test signing must
be enabled and the produced package must actually be test-signed; merely
enabling test mode does not make an unsigned INF acceptable (the supplied
SetupAPI log shows error `0xE000022F` for exactly that reason).

The INF targets Windows 10 build 16299 or newer. Windows 10 IoT Enterprise
LTSC 2019 (17763) and LTSC 2021 (19044) satisfy that requirement. VHF is an
in-box Windows 10 component, and the driver requests KMDF 1.15, which shipped
with the original Windows 10 release.

## First hardware test

1. Back up important data and attach an external USB keyboard.
2. Use a kernel debugger if possible. A faulty port driver can crash Windows.
3. Run `bcdedit /set testsigning on` as administrator and reboot. On the Sarien
   coreboot/RW_LEGACY setup Secure Boot is normally unavailable, so there is no
   firmware-menu setting to change. The installer only stops if Windows
   explicitly reports Secure Boot as enabled, and imports the matching public
   test certificate automatically.
4. In an elevated PowerShell prompt run `./collect-diagnostics.ps1` and keep
   the generated ZIP.
5. From the unpacked release package run:

   `./install-test.ps1`

6. Press keys and inspect messages beginning with `SarienI8042` in WinDbg or
   DbgView with kernel capture enabled.
7. Remove the prototype with `./uninstall-test.ps1`. Add
   `-RemoveTestCertificate` to remove the imported certificate too.

Before installing the prototype, run `collect-diagnostics.ps1` from an
elevated PowerShell prompt. It checks both firmware identities (`GOOG000A` and
`PNP0303`), i8042/VHF services, the FADT 8042 boot flag, allocated resources,
power state, relevant events, and SetupAPI history, then creates a ZIP in the
`diagnostics` directory.

## Current limitations

- Prototype polling is used instead of IRQ 1 because a root-enumerated node has
  no translated ACPI resources. A production driver should bind to corrected
  ACPI resources or use a firmware fix and interrupt-driven input.
- Boot-keyboard 6-key rollover only; Pause is ignored and Print Screen is
  simplified.
- Chromium's translated set-1 PS/2 codes are mapped for Back, Forward, Refresh,
  Fullscreen, Overview, Screenshot, brightness, playback and volume. Debug builds
  print every make/break code with the `SarienI8042: scan` prefix.
- Direct port access is x64-specific and must not be enabled on arbitrary PCs.
- LED output reports (Caps/Num/Scroll Lock back to the EC) are not implemented.

## Safety boundary

Install only on the specified Sarien test machine. Do not install while
`i8042prt` is already consuming the same hardware. The test is recoverable by
booting Safe Mode and removing `Root\SarienI8042Vhf`/the service if necessary.

