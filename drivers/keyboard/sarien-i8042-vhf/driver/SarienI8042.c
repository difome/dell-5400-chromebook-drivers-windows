#include "SarienI8042.h"

/* Keyboard plus a 16-bit Consumer Control usage for Chromebook action keys. */
static UCHAR g_ReportDescriptor[] = {
    0x05, 0x01,       /* Usage Page (Generic Desktop) */
    0x09, 0x06,       /* Usage (Keyboard) */
    0xA1, 0x01,       /* Collection (Application) */
    0x85, SARIEN_KEYBOARD_REPORT_ID, /*   Report ID */
    0x05, 0x07,       /*   Usage Page (Keyboard) */
    0x19, 0xE0,       /*   Usage Minimum (Left Control) */
    0x29, 0xE7,       /*   Usage Maximum (Right GUI) */
    0x15, 0x00,       /*   Logical Minimum (0) */
    0x25, 0x01,       /*   Logical Maximum (1) */
    0x75, 0x01,       /*   Report Size (1) */
    0x95, 0x08,       /*   Report Count (8) */
    0x81, 0x02,       /*   Input (Data, Variable, Absolute) */
    0x95, 0x01,       /*   Report Count (1) */
    0x75, 0x08,       /*   Report Size (8) */
    0x81, 0x01,       /*   Input (Constant) */
    0x95, 0x06,       /*   Report Count (6) */
    0x75, 0x08,       /*   Report Size (8) */
    0x15, 0x00,       /*   Logical Minimum (0) */
    0x25, 0x73,       /*   Logical Maximum (115) */
    0x05, 0x07,       /*   Usage Page (Keyboard) */
    0x19, 0x00,       /*   Usage Minimum (0) */
    0x29, 0x73,       /*   Usage Maximum (115) */
    0x81, 0x00,       /*   Input (Data, Array, Absolute) */
    0xC0,             /* End Collection */

    0x05, 0x0C,       /* Usage Page (Consumer) */
    0x09, 0x01,       /* Usage (Consumer Control) */
    0xA1, 0x01,       /* Collection (Application) */
    0x85, SARIEN_CONSUMER_REPORT_ID, /*   Report ID */
    0x15, 0x00,       /*   Logical Minimum (0) */
    0x26, 0xFF, 0x02, /*   Logical Maximum (0x2ff) */
    0x19, 0x00,       /*   Usage Minimum (0) */
    0x2A, 0xFF, 0x02, /*   Usage Maximum (0x2ff) */
    0x75, 0x10,       /*   Report Size (16) */
    0x95, 0x01,       /*   Report Count (1) */
    0x81, 0x00,       /*   Input (Data, Array, Absolute) */
    0xC0              /* End Collection */
};

/*
 * The Linux device name "AT Translated Set 2 keyboard" means that the i8042
 * controller translation bit is enabled: the keyboard generates set 2, but
 * bytes read by the host are set 1.  These extended set-1 action-key values
 * come from the Chromium EC translation table and ChromeOS PS/2 ACPI map.
 */
static USHORT
SarienSet1ToConsumer(_In_ UCHAR scanCode, _In_ BOOLEAN extended)
{
    if (!extended) return 0;

    switch (scanCode) {
    case 0x10: return 0x00B6; /* Scan Previous Track */
    case 0x11: return 0x0230; /* AC Full Screen View */
    case 0x12: return 0x029F; /* AC Desktop Show All Windows */
    case 0x14: return 0x0070; /* Display Brightness Decrement */
    case 0x15: return 0x006F; /* Display Brightness Increment */
    case 0x19: return 0x00B5; /* Scan Next Track */
    case 0x1A: return 0x00CD; /* Play/Pause */
    case 0x20: return 0x00E2; /* Mute */
    case 0x2E: return 0x00EA; /* Volume Decrement */
    case 0x30: return 0x00E9; /* Volume Increment */
    case 0x67: return 0x0227; /* AC Refresh */
    case 0x69: return 0x0225; /* AC Forward */
    case 0x6A: return 0x0224; /* AC Back */
    default: return 0;
    }
}

/*
 * Optional Sarien-specific mode for users who want the printed F labels to
 * win over ChromeOS action-key behavior. Fn itself is handled by the EC and
 * normally never reaches the host, so this translates the action scan codes
 * that the host actually receives.
 */
static UCHAR
SarienActionToFunctionKey(_In_ UCHAR scanCode, _In_ BOOLEAN extended)
{
#if SARIEN_FUNCTION_ROW_MODE
    if (!extended) return 0;
    switch (scanCode) {
    case 0x6A: return 0x3A; /* Back -> F1 */
    case 0x67: return 0x3B; /* Refresh -> F2 */
    case 0x11: return 0x3C; /* Fullscreen -> F3 */
    case 0x12: return 0x3D; /* Overview -> F4 */
    case 0x14: return 0x3E; /* Brightness down -> F5 */
    case 0x15: return 0x3F; /* Brightness up -> F6 */
    case 0x20: return 0x40; /* Mute -> F7 */
    case 0x2E: return 0x41; /* Volume down -> F8 */
    case 0x30: return 0x42; /* Volume up -> F9 */
    case 0x13: return 0x45; /* Snapshot -> F12 */
    default: return 0;
    }
#else
    UNREFERENCED_PARAMETER(scanCode);
    UNREFERENCED_PARAMETER(extended);
    return 0;
#endif
}

static BOOLEAN
SarienWaitForInputEmpty(VOID)
{
    ULONG attempt;

    for (attempt = 0; attempt < 2000; ++attempt) {
        if ((READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT) &
            I8042_STATUS_INPUT_FULL) == 0) {
            return TRUE;
        }
        KeStallExecutionProcessor(50);
    }
    return FALSE;
}

static BOOLEAN
SarienReadControllerByte(_Out_ PUCHAR commandByte)
{
    ULONG attempt;

    *commandByte = 0;

    /* Remove stale output before asking for a controller response. */
    for (attempt = 0; attempt < 32; ++attempt) {
        UCHAR status = READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT);
        if ((status & I8042_STATUS_OUTPUT_FULL) == 0) break;
        (void)READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_DATA_PORT);
    }

    if (!SarienWaitForInputEmpty()) return FALSE;
    WRITE_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT,
        I8042_COMMAND_READ_BYTE);

    for (attempt = 0; attempt < 2000; ++attempt) {
        UCHAR status = READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT);
        if ((status & I8042_STATUS_OUTPUT_FULL) != 0) {
            UCHAR value = READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_DATA_PORT);
            if ((status & I8042_STATUS_AUX_DATA) == 0) {
                *commandByte = value;
                return TRUE;
            }
        }
        KeStallExecutionProcessor(50);
    }
    return FALSE;
}

static BOOLEAN
SarienWriteControllerByte(_In_ UCHAR commandByte)
{
    if (!SarienWaitForInputEmpty()) return FALSE;
    WRITE_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT,
        I8042_COMMAND_WRITE_BYTE);
    if (!SarienWaitForInputEmpty()) return FALSE;
    WRITE_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_DATA_PORT, commandByte);
    return SarienWaitForInputEmpty();
}

static BOOLEAN
SarienSendKeyboardCommand(_In_ UCHAR command)
{
    ULONG attempt;
    ULONG retry;

    for (retry = 0; retry < 2; ++retry) {
        if (!SarienWaitForInputEmpty()) return FALSE;
        WRITE_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_DATA_PORT, command);

        for (attempt = 0; attempt < 2000; ++attempt) {
            UCHAR status = READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT);
            if ((status & I8042_STATUS_OUTPUT_FULL) != 0) {
                UCHAR response = READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_DATA_PORT);
                if ((status & I8042_STATUS_AUX_DATA) != 0) continue;
                if (response == AT_KEYBOARD_ACK) return TRUE;
                if (response == AT_KEYBOARD_RESEND) break;
            }
            KeStallExecutionProcessor(50);
        }
    }
    return FALSE;
}

static BOOLEAN
SarienInitializeController(VOID)
{
    UCHAR commandByte;

    if (!SarienReadControllerByte(&commandByte)) return FALSE;

    /* Polling owns keyboard output: use translated set 1, no IRQ, no AUX. */
    commandByte |= I8042_COMMAND_BYTE_TRANSLATE |
        I8042_COMMAND_BYTE_AUX_DISABLED;
    commandByte &= (UCHAR)~(I8042_COMMAND_BYTE_KEYBOARD_DISABLED |
        I8042_COMMAND_BYTE_KEYBOARD_IRQ);
    if (!SarienWriteControllerByte(commandByte)) return FALSE;

    if (!SarienWaitForInputEmpty()) return FALSE;
    WRITE_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT,
        I8042_COMMAND_ENABLE_KEYBOARD);
    if (!SarienWaitForInputEmpty()) return FALSE;

    return SarienSendKeyboardCommand(AT_KEYBOARD_ENABLE_SCANNING);
}

static VOID
SarienDisableControllerKeyboard(VOID)
{
    if (!SarienWaitForInputEmpty()) return;
    WRITE_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT,
        I8042_COMMAND_DISABLE_KEYBOARD);
    (void)SarienWaitForInputEmpty();
}

static UCHAR
SarienSet1ToHid(_In_ UCHAR scanCode, _In_ BOOLEAN extended)
{
    if (extended) {
        switch (scanCode) {
        case 0x13: return 0x46; /* Chromebook Snapshot -> Print Screen */
        case 0x1C: return 0x58; /* Keypad Enter */
        case 0x1D: return 0xE4; /* Right Control */
        case 0x35: return 0x54; /* Keypad / */
        case 0x37: return 0x46; /* Print Screen (sequence simplified) */
        case 0x38: return 0xE6; /* Right Alt */
        case 0x47: return 0x4A; /* Home */
        case 0x48: return 0x52; /* Up */
        case 0x49: return 0x4B; /* Page Up */
        case 0x4B: return 0x50; /* Left */
        case 0x4D: return 0x4F; /* Right */
        case 0x4F: return 0x4D; /* End */
        case 0x50: return 0x51; /* Down */
        case 0x51: return 0x4E; /* Page Down */
        case 0x52: return 0x49; /* Insert */
        case 0x53: return 0x4C; /* Delete */
        case 0x5B: return 0xE3; /* Left GUI / ChromeOS Search */
        case 0x5C: return 0xE7; /* Right GUI */
        case 0x5D: return 0x65; /* Application */
        default: return 0;
        }
    }

    switch (scanCode) {
    case 0x01: return 0x29; case 0x02: return 0x1E;
    case 0x03: return 0x1F; case 0x04: return 0x20;
    case 0x05: return 0x21; case 0x06: return 0x22;
    case 0x07: return 0x23; case 0x08: return 0x24;
    case 0x09: return 0x25; case 0x0A: return 0x26;
    case 0x0B: return 0x27; case 0x0C: return 0x2D;
    case 0x0D: return 0x2E; case 0x0E: return 0x2A;
    case 0x0F: return 0x2B; case 0x10: return 0x14;
    case 0x11: return 0x1A; case 0x12: return 0x08;
    case 0x13: return 0x15; case 0x14: return 0x17;
    case 0x15: return 0x1C; case 0x16: return 0x18;
    case 0x17: return 0x0C; case 0x18: return 0x12;
    case 0x19: return 0x13; case 0x1A: return 0x2F;
    case 0x1B: return 0x30; case 0x1C: return 0x28;
    case 0x1D: return 0xE0; case 0x1E: return 0x04;
    case 0x1F: return 0x16; case 0x20: return 0x07;
    case 0x21: return 0x09; case 0x22: return 0x0A;
    case 0x23: return 0x0B; case 0x24: return 0x0D;
    case 0x25: return 0x0E; case 0x26: return 0x0F;
    case 0x27: return 0x33; case 0x28: return 0x34;
    case 0x29: return 0x35; case 0x2A: return 0xE1;
    case 0x2B: return 0x31; case 0x2C: return 0x1D;
    case 0x2D: return 0x1B; case 0x2E: return 0x06;
    case 0x2F: return 0x19; case 0x30: return 0x05;
    case 0x31: return 0x11; case 0x32: return 0x10;
    case 0x33: return 0x36; case 0x34: return 0x37;
    case 0x35: return 0x38; case 0x36: return 0xE5;
    case 0x37: return 0x55; case 0x38: return 0xE2;
    case 0x39: return 0x2C; case 0x3A: return 0x39;
    case 0x3B: return 0x3A; case 0x3C: return 0x3B;
    case 0x3D: return 0x3C; case 0x3E: return 0x3D;
    case 0x3F: return 0x3E; case 0x40: return 0x3F;
    case 0x41: return 0x40; case 0x42: return 0x41;
    case 0x43: return 0x42; case 0x44: return 0x43;
    case 0x45: return 0x53; case 0x46: return 0x47;
    case 0x47: return 0x5F; case 0x48: return 0x60;
    case 0x49: return 0x61; case 0x4A: return 0x56;
    case 0x4B: return 0x5C; case 0x4C: return 0x5D;
    case 0x4D: return 0x5E; case 0x4E: return 0x57;
    case 0x4F: return 0x59; case 0x50: return 0x5A;
    case 0x51: return 0x5B; case 0x52: return 0x62;
    case 0x53: return 0x63; case 0x56: return 0x64;
    case 0x57: return 0x44; case 0x58: return 0x45;
    case 0x59: return 0x68; case 0x5A: return 0x69;
    case 0x5B: return 0x6A;
    default: return 0;
    }
}

static BOOLEAN
SarienUpdateReport(_Inout_ PDEVICE_CONTEXT context, _In_ UCHAR usage, _In_ BOOLEAN released)
{
    ULONG index;

    if (usage >= 0xE0 && usage <= 0xE7) {
        UCHAR mask = (UCHAR)(1u << (usage - 0xE0));
        UCHAR old = context->KeyboardReport.Modifiers;
        if (released) context->KeyboardReport.Modifiers &= (UCHAR)~mask;
        else context->KeyboardReport.Modifiers |= mask;
        return old != context->KeyboardReport.Modifiers;
    }

    for (index = 0; index < SARIEN_MAX_KEYS; ++index) {
        if (context->KeyboardReport.Keys[index] == usage) {
            if (!released) return FALSE;
            context->KeyboardReport.Keys[index] = 0;
            return TRUE;
        }
    }

    if (released) return FALSE;
    for (index = 0; index < SARIEN_MAX_KEYS; ++index) {
        if (context->KeyboardReport.Keys[index] == 0) {
            context->KeyboardReport.Keys[index] = usage;
            return TRUE;
        }
    }

    /* HID boot protocol rollover marker. */
    RtlFillMemory(context->KeyboardReport.Keys, SARIEN_MAX_KEYS, 0x01);
    return TRUE;
}

static VOID
SarienSubmitKeyboardReport(_Inout_ PDEVICE_CONTEXT context)
{
    HID_XFER_PACKET packet;
    NTSTATUS status;

    RtlZeroMemory(&packet, sizeof(packet));
    packet.reportBuffer = (PUCHAR)&context->KeyboardReport;
    packet.reportBufferLen = sizeof(context->KeyboardReport);
    packet.reportId = SARIEN_KEYBOARD_REPORT_ID;
    status = VhfReadReportSubmit(context->VhfHandle, &packet);
    if (NT_SUCCESS(status)) ++context->ReportsSubmitted;
}

static VOID
SarienSubmitConsumerReport(_Inout_ PDEVICE_CONTEXT context)
{
    HID_XFER_PACKET packet;
    NTSTATUS status;

    RtlZeroMemory(&packet, sizeof(packet));
    packet.reportBuffer = (PUCHAR)&context->ConsumerReport;
    packet.reportBufferLen = sizeof(context->ConsumerReport);
    packet.reportId = SARIEN_CONSUMER_REPORT_ID;
    status = VhfReadReportSubmit(context->VhfHandle, &packet);
    if (NT_SUCCESS(status)) ++context->ReportsSubmitted;
}

static VOID
SarienConsumeScanCode(_Inout_ PDEVICE_CONTEXT context, _In_ UCHAR scanCode)
{
    UCHAR usage;
    BOOLEAN released;
    USHORT consumerUsage;

    if (context->PauseBytesToSkip != 0) {
        --context->PauseBytesToSkip;
        return;
    }
    if (scanCode == 0xE1) {
        context->PauseBytesToSkip = 5;
        return;
    }
    if (scanCode == 0xE0) {
        context->ExtendedPending = TRUE;
        return;
    }
    released = (scanCode & 0x80) != 0;
    scanCode &= 0x7F;

    /* Fake shifts in the translated Print Screen sequence. */
    if (context->ExtendedPending && scanCode == 0x2A) {
        context->ExtendedPending = FALSE;
        return;
    }

    usage = SarienActionToFunctionKey(scanCode, context->ExtendedPending);
    consumerUsage = (usage == 0) ?
        SarienSet1ToConsumer(scanCode, context->ExtendedPending) : 0;
#if DBG
    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_TRACE_LEVEL,
        "SarienI8042: set1 scan %s%s%02X\n",
        context->ExtendedPending ? "E0 " : "",
        released ? "break " : "make ", scanCode));
#endif
    if (usage != 0) {
        if (SarienUpdateReport(context, usage, released)) {
            SarienSubmitKeyboardReport(context);
        }
    } else if (consumerUsage != 0) {
        USHORT nextUsage = released ? 0 : consumerUsage;
        if (context->ConsumerReport.ConsumerUsage != nextUsage) {
            context->ConsumerReport.ConsumerUsage = nextUsage;
            SarienSubmitConsumerReport(context);
        }
    } else {
        usage = SarienSet1ToHid(scanCode, context->ExtendedPending);
        if (usage == 0) {
            ++context->UnmappedScanCodes;
            KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_TRACE_LEVEL,
                "SarienI8042: unmapped set-1 scan code %s%02X\n",
                context->ExtendedPending ? "E0 " : "", scanCode));
        } else if (SarienUpdateReport(context, usage, released)) {
            SarienSubmitKeyboardReport(context);
        }
    }

    context->ExtendedPending = FALSE;
}

VOID
SarienEvtPollTimer(_In_ WDFTIMER timer)
{
    PDEVICE_CONTEXT context = SarienGetContext(WdfTimerGetParentObject(timer));
    ULONG limit;

    for (limit = 0; limit < 32; ++limit) {
        UCHAR status = READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_STATUS_PORT);
        if ((status & I8042_STATUS_OUTPUT_FULL) == 0) break;
        if ((status & I8042_STATUS_AUX_DATA) != 0) {
            (void)READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_DATA_PORT);
            continue;
        }
        SarienConsumeScanCode(context,
            READ_PORT_UCHAR((PUCHAR)(ULONG_PTR)I8042_DATA_PORT));
        ++context->BytesRead;
    }
}

NTSTATUS
SarienEvtDeviceD0Entry(_In_ WDFDEVICE device, _In_ WDF_POWER_DEVICE_STATE previousState)
{
    PDEVICE_CONTEXT context = SarienGetContext(device);
    UNREFERENCED_PARAMETER(previousState);
    context->ExtendedPending = FALSE;
    context->PauseBytesToSkip = 0;
    context->ControllerConfigured = SarienInitializeController();
    if (!context->ControllerConfigured) {
        ++context->InitializationFailures;
        KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_ERROR_LEVEL,
            "SarienI8042: controller initialization timed out; continuing in passive-read mode\n"));
    }
    WdfTimerStart(context->PollTimer, WDF_REL_TIMEOUT_IN_MS(10));
    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_INFO_LEVEL,
        "SarienI8042: polling ports 60/64 started; initialized=%u\n",
        context->ControllerConfigured));
    return STATUS_SUCCESS;
}

NTSTATUS
SarienEvtDeviceD0Exit(_In_ WDFDEVICE device, _In_ WDF_POWER_DEVICE_STATE targetState)
{
    PDEVICE_CONTEXT context = SarienGetContext(device);
    UNREFERENCED_PARAMETER(targetState);
    WdfTimerStop(context->PollTimer, TRUE);
    if (context->ControllerConfigured) {
        SarienDisableControllerKeyboard();
        context->ControllerConfigured = FALSE;
    }
    RtlZeroMemory(&context->KeyboardReport, sizeof(context->KeyboardReport));
    context->KeyboardReport.ReportId = SARIEN_KEYBOARD_REPORT_ID;
    RtlZeroMemory(&context->ConsumerReport, sizeof(context->ConsumerReport));
    context->ConsumerReport.ReportId = SARIEN_CONSUMER_REPORT_ID;
    SarienSubmitKeyboardReport(context);
    SarienSubmitConsumerReport(context);
    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_INFO_LEVEL,
        "SarienI8042: stopped; bytes=%lu reports=%lu unmapped=%lu initFailures=%lu\n",
        context->BytesRead, context->ReportsSubmitted, context->UnmappedScanCodes,
        context->InitializationFailures));
    return STATUS_SUCCESS;
}

VOID
SarienEvtDeviceCleanup(_In_ WDFOBJECT object)
{
    PDEVICE_CONTEXT context = SarienGetContext(object);
    if (context->PollTimer != NULL) {
        WdfTimerStop(context->PollTimer, TRUE);
    }
    if (context->VhfHandle != NULL) {
        VhfDelete(context->VhfHandle, TRUE);
        context->VhfHandle = NULL;
    }
}

NTSTATUS
SarienEvtDeviceAdd(_In_ WDFDRIVER driver, _Inout_ PWDFDEVICE_INIT deviceInit)
{
    WDF_OBJECT_ATTRIBUTES attributes;
    WDF_PNPPOWER_EVENT_CALLBACKS powerCallbacks;
    WDF_TIMER_CONFIG timerConfig;
    WDF_OBJECT_ATTRIBUTES timerAttributes;
    VHF_CONFIG vhfConfig;
    WDFDEVICE device;
    PDEVICE_CONTEXT context;
    NTSTATUS status;

    UNREFERENCED_PARAMETER(driver);

    WDF_PNPPOWER_EVENT_CALLBACKS_INIT(&powerCallbacks);
    powerCallbacks.EvtDeviceD0Entry = SarienEvtDeviceD0Entry;
    powerCallbacks.EvtDeviceD0Exit = SarienEvtDeviceD0Exit;
    WdfDeviceInitSetPnpPowerEventCallbacks(deviceInit, &powerCallbacks);

    WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(&attributes, DEVICE_CONTEXT);
    attributes.EvtCleanupCallback = SarienEvtDeviceCleanup;
    status = WdfDeviceCreate(&deviceInit, &attributes, &device);
    if (!NT_SUCCESS(status)) return status;

    context = SarienGetContext(device);
    RtlZeroMemory(context, sizeof(*context));
    context->KeyboardReport.ReportId = SARIEN_KEYBOARD_REPORT_ID;
    context->ConsumerReport.ReportId = SARIEN_CONSUMER_REPORT_ID;

    VHF_CONFIG_INIT(&vhfConfig, WdfDeviceWdmGetDeviceObject(device),
        sizeof(g_ReportDescriptor), g_ReportDescriptor);
    vhfConfig.VendorID = 0x18D1;  /* Google */
    vhfConfig.ProductID = 0x5022; /* Project-local identifier */
    vhfConfig.VersionNumber = 0x0001;
    status = VhfCreate(&vhfConfig, &context->VhfHandle);
    if (!NT_SUCCESS(status)) return status;

    WDF_TIMER_CONFIG_INIT_PERIODIC(&timerConfig, SarienEvtPollTimer, 1);
    timerConfig.UseHighResolutionTimer = WdfTrue;
    WDF_OBJECT_ATTRIBUTES_INIT(&timerAttributes);
    timerAttributes.ParentObject = device;
    status = WdfTimerCreate(&timerConfig, &timerAttributes, &context->PollTimer);
    if (!NT_SUCCESS(status)) return status;

    status = VhfStart(context->VhfHandle);
    if (!NT_SUCCESS(status)) return status;

    return STATUS_SUCCESS;
}

NTSTATUS
DriverEntry(_In_ PDRIVER_OBJECT driverObject, _In_ PUNICODE_STRING registryPath)
{
    WDF_DRIVER_CONFIG config;
    WDF_DRIVER_CONFIG_INIT(&config, SarienEvtDeviceAdd);
    return WdfDriverCreate(driverObject, registryPath,
        WDF_NO_OBJECT_ATTRIBUTES, &config, WDF_NO_HANDLE);
}

