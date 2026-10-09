# Experimental top-row modes

This branch preserves the unreleased v0.2 keyboard experiment. It is separate
from the official v0.1 release and contains two mutually exclusive builds.

| Build | Top-row behavior | SHA-256 |
| --- | --- | --- |
| `SarienI8042-ActionKeys-Release-x64.zip` | Chromebook actions; snapshot becomes Print Screen | `57A961396C3339EC57B91BC01938ABB7FDE825783A7DAA16DF7A47E16725F77A` |
| `SarienI8042-FunctionKeys-Release-x64.zip` | F1-F9 and F12; native F10/F11 remain unchanged | `5FA134F079AF3ECC0B9D03B7D9E3E4554E8ECEDCC1943D86897BE1F4D648DABD` |

The ZIP files are committed under `experimental-builds/` so the exact tested
binaries cannot be lost even though no GitHub Release is created for them.

Fn is handled inside the embedded controller and normally produces no scan code
visible to the host. Therefore the FunctionKeys build cannot use Fn as a live
toggle; it maps the action positions to function keys all the time.

The convenient `INSTALL-KEYBOARD.ps1` script is included in both ZIPs. These
remain experimental kernel-driver builds: keep an external USB keyboard
connected and retain a recovery path before installation.
