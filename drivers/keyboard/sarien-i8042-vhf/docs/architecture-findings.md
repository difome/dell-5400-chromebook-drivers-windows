# Architecture findings

## Confirmed hardware path

Sarien uses a Wilco embedded controller. Coreboot's Sarien device tree enables
the Wilco EC under the LPC/eSPI device and decodes EC host-command ranges at
`0x930-0x937`, `0x940-0x947`, and `0x950-0x95f`.

Coreboot's Wilco `superio.asl` declares the keyboard as `PS2K` with:

- hardware ID `GOOG000A` in current sources;
- compatible IDs `PNP0303` and `PNP030B`;
- I/O ports `0x60` and `0x64`;
- edge-triggered, active-high, exclusive IRQ 1.

The exact 2020 coreboot source contemporary with the supplied firmware uses
`PNP0303` as the primary ID, `PNP030B` as the compatible ID, and explicitly
defines `SIO_EC_ENABLE_PS2K` for the Sarien variant. Current coreboot sources
use `GOOG000A` as the primary ID. Windows diagnostics therefore search for all
three identities.

The supplied Windows report only enumerates devices whose status is Error or
Unknown plus a separate CoolStar-oriented selection. It never contains an
unfiltered device inventory. Consequently, the statement in the supplied task
document that Windows does not create `PNP0303` is still a hypothesis, not an
observed fact. The direct-port prototype must not be installed until the full
inventory proves that no working `i8042prt` stack owns the ports.

The exact coreboot revision corresponding to the supplied firmware does not
set bit 1 (`8042`) in `FADT.IAPC_BOOT_ARCH`; the current Sarien/coreboot path
still does not set it. ACPI specifies that operating systems consult this flag
before they can parse the ACPI namespace. This is a credible explanation for
Linux finding the translated keyboard while Windows fails to initialize its
legacy i8042 path, although only the target's dumped FADT can prove the shipped
image has the same value. `collect-diagnostics.ps1` now reads the live FADT
from Windows' ACPI registry cache and reports this bit explicitly.

Linux confirms that the EC-backed interface behaves as an AT translated set-2
keyboard. This name is easy to misread: with the i8042 translation bit set,
the keyboard generates set 2 internally but the host reads translated set-1
bytes. Chromium's EC implementation documents the same behavior. The driver
therefore decodes set 1. Linux does not prove that edk2 leaves the same
interface enabled after Windows takes control, which is why the prototype
begins with passive reads.

## Preferred implementation order

1. Check whether Windows enumerates either ACPI ID and whether `i8042prt` is
   disabled, missing, or resource-conflicted.
2. If an ACPI node exists, prefer the in-box `i8042prt` stack or a narrow filter
   over a second driver reading the same ports.
3. If no ACPI node exists but port bytes are present, use the VHF prototype to
   validate scan codes, then move to an ACPI-rooted/interrupt-driven design.
4. If no bytes are present, fix the firmware/ACPI handoff; a Windows keyboard
   class driver cannot recover data that the EC no longer exposes.

For a firmware-first fix, set `ACPI_FADT_8042` in Sarien's FADT and retest the
in-box `i8042prt` stack before installing the VHF prototype. This is cleaner
than permanent polling because Windows can own the ACPI resources and IRQ 1.
The VHF driver remains useful as a diagnostic fallback and for translating the
Chromebook action row.

## VHF integration requirement

Microsoft requires `vhf.sys` to be registered as a lower filter beneath a VHF
HID source driver. A service dependency alone does not construct that device
stack. The INF now installs a device `LowerFilters` multi-string containing
`vhf`; this was a critical correction found during the documentation audit.

The keyboard and Consumer Control collections use distinct report IDs. The
driver sends a nine-byte keyboard report (`ID + 8`) and a three-byte consumer
report (`ID + 16-bit usage`) instead of combining two top-level collections in
one ambiguous report. It also performs bounded standard i8042 initialization:
read/update the controller command byte, force translation, disable IRQ/AUX for
polling, enable the keyboard interface, and send `F4` to enable scanning. If
initialization times out, it logs the failure and continues passive reads so a
bootloader-initialized controller can still be tested.

## Function row

Chromium's public EC translation table gives the host-side set-1 action codes:
Back (`E0 6A`), Forward (`E0 69`), Refresh (`E0 67`), Fullscreen (`E0 11`),
Overview (`E0 12`), Snapshot (`E0 13`), Brightness Down/Up (`E0 14`/`E0 15`),
Mute (`E0 20`), Volume Down (`E0 2E`), and Volume Up (`E0 30`). These align
with the physical Sarien keycaps and with the Camera/Prog1/SwitchVideoMode
events in the supplied Linux `keyd` configuration. Debug builds still log
every make/break byte so the first hardware run can verify Wilco EC behavior.

## Remaining evidence needed from the target

- output of `scripts/collect-diagnostics.ps1`;
- debug scan log for every physical key;
- the newest `DRIVER_POWER_STATE_FAILURE` dump;
- verification that no CoolStar filter remains attached to the keyboard stack.

## Primary references

- [Microsoft Virtual HID Framework](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/virtual-hid-framework--vhf-)
- [Microsoft KMDF version history](https://learn.microsoft.com/en-us/windows-hardware/drivers/wdf/kmdf-version-history)
- [ACPI 6.4, IA-PC boot architecture flags](https://uefi.org/sites/default/files/resources/ACPI_Spec_6_4_Jan22.pdf)
- [Current Sarien EC configuration](https://chromium.googlesource.com/chromiumos/third_party/coreboot/+/refs/heads/main/src/mainboard/google/sarien/variants/sarien/include/variant/ec.h)
- [Current Wilco PS/2 ACPI declaration](https://chromium.googlesource.com/chromiumos/third_party/coreboot/+/refs/heads/main/src/ec/google/wilco/acpi/superio.asl)
- [Chromium EC i8042 implementation](https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/main/common/keyboard_8042.c)

