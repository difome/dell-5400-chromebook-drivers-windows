#pragma once

#include <ntddk.h>
#include <wdf.h>
#include <vhf.h>

#define SARIEN_POOL_TAG 'K8RS'
#define I8042_DATA_PORT 0x60
#define I8042_STATUS_PORT 0x64
#define I8042_STATUS_OUTPUT_FULL 0x01
#define I8042_STATUS_INPUT_FULL 0x02
#define I8042_STATUS_AUX_DATA 0x20
#define I8042_COMMAND_READ_BYTE 0x20
#define I8042_COMMAND_WRITE_BYTE 0x60
#define I8042_COMMAND_DISABLE_KEYBOARD 0xAD
#define I8042_COMMAND_ENABLE_KEYBOARD 0xAE
#define I8042_COMMAND_BYTE_KEYBOARD_IRQ 0x01
#define I8042_COMMAND_BYTE_KEYBOARD_DISABLED 0x10
#define I8042_COMMAND_BYTE_AUX_DISABLED 0x20
#define I8042_COMMAND_BYTE_TRANSLATE 0x40
#define AT_KEYBOARD_ENABLE_SCANNING 0xF4
#define AT_KEYBOARD_SET_TYPEMATIC 0xF3
#define AT_KEYBOARD_ACK 0xFA
#define AT_KEYBOARD_RESEND 0xFE
/* 1.2 s of complete silence while keys are held means a break code was lost. */
#define SARIEN_STUCK_KEY_TIMEOUT 12000000ULL
#define SARIEN_MAX_KEYS 6
#define SARIEN_KEYBOARD_REPORT_ID 1
#define SARIEN_CONSUMER_REPORT_ID 2

#pragma pack(push, 1)
typedef struct _SARIEN_KEYBOARD_REPORT {
    UCHAR ReportId;
    UCHAR Modifiers;
    UCHAR Reserved;
    UCHAR Keys[SARIEN_MAX_KEYS];
} SARIEN_KEYBOARD_REPORT, *PSARIEN_KEYBOARD_REPORT;

typedef struct _SARIEN_CONSUMER_REPORT {
    UCHAR ReportId;
    USHORT ConsumerUsage;
} SARIEN_CONSUMER_REPORT, *PSARIEN_CONSUMER_REPORT;
#pragma pack(pop)

typedef struct _DEVICE_CONTEXT {
    VHFHANDLE VhfHandle;
    WDFTIMER PollTimer;
    SARIEN_KEYBOARD_REPORT KeyboardReport;
    SARIEN_CONSUMER_REPORT ConsumerReport;
    BOOLEAN ExtendedPending;
    UCHAR PauseBytesToSkip;
    ULONG64 LastByteTick;
    UCHAR MacroStep;
    UCHAR MacroModifiers;
    UCHAR MacroKey;
    ULONG StuckKeysReleased;
    ULONG BytesRead;
    ULONG ReportsSubmitted;
    ULONG UnmappedScanCodes;
    ULONG InitializationFailures;
    BOOLEAN ControllerConfigured;
} DEVICE_CONTEXT, *PDEVICE_CONTEXT;

WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(DEVICE_CONTEXT, SarienGetContext)

DRIVER_INITIALIZE DriverEntry;
EVT_WDF_DRIVER_DEVICE_ADD SarienEvtDeviceAdd;
EVT_WDF_OBJECT_CONTEXT_CLEANUP SarienEvtDeviceCleanup;
EVT_WDF_DEVICE_D0_ENTRY SarienEvtDeviceD0Entry;
EVT_WDF_DEVICE_D0_EXIT SarienEvtDeviceD0Exit;
EVT_WDF_TIMER SarienEvtPollTimer;

