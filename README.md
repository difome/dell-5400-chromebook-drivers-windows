# Windows drivers for Dell Latitude 5400 Chromebook (Sarien)

Experimental Windows drivers for the Dell Latitude 5400 Chromebook, ChromiumOS
board name **Sarien**.

> **Tested on:** Dell Latitude 5400 Chromebook with Windows 10 LTSC
> 2021 x64 (version 21H2, build 19044).
>
> **Tested hardware:** Dell P98G/P98G005, 13-inch display, Sarien rev17,
> Intel Core i5-8265U, 16 GB DDR4-2400, Intel UHD Graphics 620.
>
> **Development:** researched, written, and documented with assistance from
> **OpenAI Codex**, then compiled and tested on the real target hardware.

## Target Chromebook

| Item | Details |
| --- | --- |
| Retail model | Dell Latitude 5400 Chromebook with 13-inch display |
| Dell regulatory model | `P98G` |
| Dell regulatory type | `P98G005` |
| ChromiumOS board/variant | `sarien` |
| Baseboard family | `sarien` |
| Platform | x86_64, Intel Whiskey Lake-U / Cannon Point-LP PCH |
| Original ChromeOS generation | ChromeOS R75, Linux 4.19 |
| Embedded controller | Google Wilco EC with an emulated i8042/PS/2 keyboard interface |
| Processor in the tested machine | Intel Core i5-8265U — 4 cores / 8 threads, 1.60 GHz base, up to 3.90 GHz turbo, 6 MB cache |
| Integrated graphics in the tested machine | Intel UHD Graphics 620 (`8086:3EA0`) |
| Display in the tested machine | 13-inch |
| Memory in the tested machine | 16 GB DDR4-2400; two SODIMM slots |
| Tested Windows installation | Windows 10 LTSC 2021 x64 (21H2, build 19044) |

The supported target is the **Chromebook** model, not the visually similar
standard Windows Dell Latitude 5400.

See the [full tested-unit hardware profile](docs/sarien-hardware-profile.md)
for firmware, ACPI, EC, keyboard, touchpad, PCI devices, storage, networking,
audio, and captured Windows device status.

Related devices are not automatically compatible:

- Dell Latitude 5300 2-in-1 Chromebook Enterprise uses the related `arcada`
  variant. It shares the `sarien` baseboard family but has not been validated
  with this driver.
- Dell Latitude 7410 Chromebook Enterprise uses the unrelated `drallion`
  platform and is not supported.
- Regular Windows Latitude 5300/5400 models use different firmware and should
  not use these drivers.

To inspect the model reported by firmware from Windows PowerShell:

```powershell
Get-CimInstance Win32_ComputerSystemProduct | Select-Object Vendor, Name, Version
Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product
```

## Drivers

### Internal keyboard

Sarien i8042 to Virtual HID Framework keyboard driver for Windows 10 x64.

- **Version:** v0.1.0
- **Status:** experimental, test-signed
- **Source:** [drivers/keyboard/sarien-i8042-vhf](drivers/keyboard/sarien-i8042-vhf/)
- **Download:** [SarienI8042-Release-x64.zip](https://github.com/difome/dell-5400-chromebook-drivers-windows/releases/download/keyboard-v0.1.0/SarienI8042-Release-x64.zip)
- **Release:** [Keyboard driver v0.1.0](https://github.com/difome/dell-5400-chromebook-drivers-windows/releases/tag/keyboard-v0.1.0)

More drivers will be added to this list when their source code and tested build
packages are ready.

## Information and upstream references

The hardware behavior and implementation were researched using:

- [ChromiumOS device list identifying Latitude 5400 as `sarien` and Latitude
  5300 2-in-1 as `arcada`](https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices/);
- [Dell Latitude 5400 Chromebook specifications](https://dl.dell.com/topicspdf/latitude-14-5400-chrome-laptop_setup-guide2_en-us.pdf);
- Linux observations from the Sarien keyboard exposed as an AT translated
  set-2 keyboard;
- [Linux kernel i8042/serio input drivers](https://github.com/torvalds/linux/tree/master/drivers/input/serio);
- [ChromiumOS EC i8042 keyboard implementation](https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/main/common/keyboard_8042.c);
- [coreboot Sarien EC configuration](https://chromium.googlesource.com/chromiumos/third_party/coreboot/+/refs/heads/main/src/mainboard/google/sarien/variants/sarien/include/variant/ec.h);
- [coreboot Wilco PS/2 ACPI declaration](https://chromium.googlesource.com/chromiumos/third_party/coreboot/+/refs/heads/main/src/ec/google/wilco/acpi/superio.asl);
- [Microsoft Virtual HID Framework documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/virtual-hid-framework--vhf-).

This is an independent Windows implementation informed by the projects above,
not a Linux driver binary conversion.

## Warning

These are prototype kernel drivers for Sarien hardware. Read the instructions
inside each driver directory, keep an external USB keyboard available, and do
not install the packages on unrelated computers.
