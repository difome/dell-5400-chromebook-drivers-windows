# Dell Latitude 5400 Chromebook hardware profile

This document describes the physical machine used to research and test the
drivers in this repository. The data was captured from Linux, ACPI tables,
coreboot/DMI, PCI and USB enumeration, flashrom, and Windows diagnostics on
2026-10-08.

## Machine identity

| Field | Tested machine |
| --- | --- |
| Manufacturer | Dell Inc. |
| Retail model | Dell Latitude 5400 Chromebook |
| Dell regulatory model | `P98G` |
| Dell regulatory type | `P98G005` |
| DMI product | `Sarien` |
| Board/variant | `sarien` |
| Board revision | `rev17` |
| Chassis type | 9 (laptop) |
| Architecture | x86_64 |
| Platform generation | Intel Whiskey Lake-U with Cannon Point-LP PCH |
| Tested CPU | Intel Core i5-8265U — 4 cores / 8 threads, 1.60 GHz base, up to 3.90 GHz turbo, 6 MB cache |
| Integrated GPU | Intel UHD Graphics 620 (`8086:3EA0`) |
| Display in tested machine | 13-inch, owner-confirmed |
| Memory in tested machine | 16 GB DDR4-2400, two SODIMM slots |
| Tested Windows | Windows 10 LTSC 2021 x64, 21H2, build 19044 |
| Linux reference system | Linux 6.12.111, Debian 13 userspace |

Dell also sold the Latitude 5400 Chromebook with Celeron 4305U, Core
i3-8145U, Core i5-8365U, and Core i7-8665U processors. Dell's family-level
manual lists configurations with two DDR4-2400 SODIMM slots and support up to
32 GB, while the physical `rev17` test machine has 16 GB. Only that Core
i5-8265U/16 GB unit was used for this driver work.

## Model-family warning

ChromiumOS identifies two related devices in the same baseboard family:

| Retail model | ChromiumOS variant | Driver status |
| --- | --- | --- |
| Dell Latitude 5400 Chromebook | `sarien` | Tested target |
| Dell Latitude 5300 2-in-1 Chromebook Enterprise | `arcada` | Related but not tested |

The regular Windows Latitude 5300/5400 models are different machines from the
Chromebook variants despite their similar cases and names. Dell
Latitude 7410 Chromebook Enterprise uses the unrelated `drallion` platform.
None of those systems should be assumed compatible with a `sarien` driver.

## Firmware

| Field | Value |
| --- | --- |
| BIOS vendor | coreboot |
| BIOS version | `Google_Sarien.12200.222.0` |
| BIOS date | 2020-07-29 |
| ROM size | 32 MiB |
| Boot path used for Windows | RW_LEGACY with TianoCore/edk2 |
| Full replacement UEFI ROM | Not available in the captured configuration |
| SPI flash | Winbond `W25Q256JV_M`, 32 MiB |

The flash descriptor and Intel ME regions are locked. The BIOS region is
generally writable, but a protected range was reported at
`0x01BD0000-0x01BEFFFF`. This repository does not provide firmware flashing
instructions or images.

The firmware exposes the following ACPI tables: APIC, BGRT, DBG2, DMAR, DSDT,
FACP/FADT, FACS, HPET, MCFG, SSDT, and TPM2.

## Internal keyboard path

The keyboard is not exposed as a USB device. The Wilco EC/coreboot firmware
emulates an i8042 PS/2 controller:

| Property | Value |
| --- | --- |
| ACPI device | `PS2K` |
| Hardware ID | `PNP0303` |
| Compatible ID | `PNP030B` |
| ACPI status | `0x0F` (present and enabled) |
| Data/command ports | `0x60` / `0x64` |
| Interrupt | IRQ 1 |
| Linux controller | `i8042` |
| Linux keyboard driver | `atkbd` |
| Linux input name | `AT Translated Set 2 keyboard` |
| Linux input ID | bus `0011`, vendor/product `0001:0001`, version `ab83` |

Linux reports translated set-1 bytes to the host even though the device name
says “Set 2”. It also reports `Keylock active` and says the PS/2 AUX port is
disabled. The ACPI `PS2M` device (`PNP0F13`) is disabled by firmware.

The Windows prototype in this repository reads the emulated i8042 ports and
publishes keyboard and consumer-control reports through Microsoft's Virtual
HID Framework. It exists because the normal Windows `i8042prt` path did not
attach successfully in the tested RW_LEGACY Windows boot environment.

## Touchpad

| Property | Value |
| --- | --- |
| ACPI device | `D02C` |
| Hardware ID | `ELAN0000` |
| ACPI description | ELAN Touchpad |
| I2C controller | Intel Cannon Point-LP Serial IO I2C #1 (`8086:9DE9`) |
| Linux bus path | `i2c_designware.1`, bus `i2c-2` |
| I2C address | `0x2C` |
| Bus speed from ACPI | 400 kHz |
| Linux input vendor/product | `04F3:00D6` |
| Linux behavior | Absolute multitouch/precision-touchpad style device |
| Captured Windows device | `ACPI\ELAN0000\0`, shown as Chromebook Elan Touchpad |

The touchpad is a separate I2C device; it is not the disabled PS/2 AUX device.
The keyboard VHF driver does not control it.

## Embedded controller and ACPI devices

| ACPI ID | Name/function | Captured behavior |
| --- | --- | --- |
| `PNP0C09` | ACPI Embedded Controller (`EC0`) | Active; GPE `0x6E`; data `0x930`, command/status `0x934` |
| `GOOG000C` | Wilco EC Command Device | Bound to `wilco_ec` in Linux; no working Windows driver in the capture |
| `GOOG000D` | Wilco EC Event Interface | `wilco_ec_events` in Linux; unowned/error in Windows capture |
| `GOOG000E` | Wilco EC UCSI | Linux `ucsi_acpi` initialization timed out; error in Windows capture |
| `GOOG000F` | Vital Product Data | Exposed by firmware; unowned/error in Windows capture |
| `GOOG9999` | Firmware placeholder | No functional driver expected in the capture |
| `BOOT0000` | Coreboot Table | Working in Windows with the captured Coreboot Table driver |
| `GOOG0005` | Cr50 TPM 2.0 | I2C address `0x50`, IRQ 114, ID `0x28`; working in both captures |
| `INT33D6` | Intel Virtual Buttons | Input device exposed by ACPI |
| `INT34BB` | Intel LPSS-related ACPI device | Part of the platform I2C path |

Linux loaded `wilco_ec`, `wilco_ec_events`, `wilco_ec_telem`,
`wilco_charger`, `rtc_wilco_ec`, and `wilco_ec_debugfs`. The separate
`cros_ec_lpcs` probe failed with `-16` because its memory region was already in
use; this machine primarily follows the Wilco EC path.

## Main PCI devices from the tested unit

| Function | Device |
| --- | --- |
| Host/DRAM controller | Intel Coffee Lake Host and DRAM Controller (`8086:3E34`) |
| Graphics | Intel Whiskey Lake-U GT2 / UHD Graphics 620 (`8086:3EA0`) |
| USB | Intel Cannon Point-LP USB 3.1 xHCI (`8086:9DED`) |
| Wi-Fi | Intel Cannon Point-LP CNVi Wireless-AC (`8086:9DF0`) |
| Bluetooth | Intel 9460/9560 (`8087:0AAA`) |
| Ethernet | Intel Ethernet Connection (6) I219-V (`8086:15BE`) |
| Audio controller | Intel Cannon Point-LP HDA (`8086:9DC8`) |
| Audio codec | Realtek ALC236 |
| SATA | Intel Cannon Point-LP AHCI (`8086:9DD3`) |
| NVMe in captured unit | SK hynix Gold P31/BC711/PC711 family (`1C5C:174A`) |
| Card reader | Realtek RTS525A (`10EC:525A`) |
| SMBus | Intel Cannon Point-LP SMBus (`8086:9DA3`) |
| SPI | Intel Cannon Point-LP SPI (`8086:9DA4`) |
| Integrated webcam | Realtek `0BDA:5539` |

The NVMe drive is the part installed in the captured machine, not a guarantee
for every Latitude 5400 Chromebook configuration.

## Windows status captured during development

- Intel UHD Graphics 620 was working with the Intel display driver.
- Chromebook Elan Touchpad (`ACPI\ELAN0000\0`) was working with the installed
  touchpad driver.
- Cr50 TPM 2.0 (`GOOG0005`) and Coreboot Table (`BOOT0000`) were working.
- `GOOG000C`, `GOOG000D`, `GOOG000E`, and `GOOG000F` did not have working
  Windows drivers in the captured diagnostic.
- The Realtek RTS525A card reader, Intel SMBus/SPI-related devices, and several
  platform devices still appeared with errors in that diagnostic.

This is a historical development snapshot, not a promise that every device is
currently supported by this repository.

## Sources

- Local Sarien Linux/coreboot/ACPI and Windows diagnostic captures supplied for
  this project
- [ChromiumOS device list](https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices/)
- [Dell Latitude 5400 Chromebook specifications](https://dl.dell.com/topicspdf/latitude-14-5400-chrome-laptop_setup-guide2_en-us.pdf)
- [ChromiumOS EC i8042 implementation](https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/main/common/keyboard_8042.c)
- [coreboot Sarien sources](https://chromium.googlesource.com/chromiumos/third_party/coreboot/+/refs/heads/main/src/mainboard/google/sarien/)

Development of the driver and this documentation was assisted by **OpenAI
Codex**. Hardware captures and validation came from the physical Sarien test
machine.
