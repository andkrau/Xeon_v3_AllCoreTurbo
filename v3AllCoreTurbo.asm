format pe64 dll efiboot
entry main
include 'efi.inc'

;-------------------------------------------------------------------------------------------------------

; Negative dynamic voltage offsets
VID_MINUS_000_MV = 0x00000000    ; Unchanged VID
VID_MINUS_010_MV = 0xFEC00000    ; -10 mV  (-0.010 V)
VID_MINUS_020_MV = 0xFD800000    ; -20 mV  (-0.020 V)
VID_MINUS_030_MV = 0xFC200000    ; -30 mV  (-0.030 V)
VID_MINUS_040_MV = 0xFAE00000    ; -40 mV  (-0.040 V)
VID_MINUS_050_MV = 0xF9A00000    ; -50 mV  (-0.050 V)
VID_MINUS_055_MV = 0xF9000000    ; -55 mV  (-0.055 V)
VID_MINUS_060_MV = 0xF8600000    ; -60 mV  (-0.060 V)
VID_MINUS_065_MV = 0xF7A00000    ; -65 mV  (-0.065 V)
VID_MINUS_070_MV = 0xF7000000    ; -70 mV  (-0.070 V)
VID_MINUS_075_MV = 0xF6600000    ; -75 mV  (-0.075 V)
VID_MINUS_080_MV = 0xF5C00000    ; -80 mV  (-0.080 V)
VID_MINUS_085_MV = 0xF5200000    ; -85 mV  (-0.085 V)
VID_MINUS_090_MV = 0xF4800000    ; -90 mV  (-0.090 V)
VID_MINUS_095_MV = 0xF3E00000    ; -95 mV  (-0.095 V)
VID_MINUS_100_MV = 0xF3400000    ; -100 mV (-0.100 V)

;-------------------------------------------------------------------------------------------------------

CoreVoltage1        = VID_MINUS_050_MV
CacheVoltage1       = VID_MINUS_050_MV
SysAgentVoltage1    = VID_MINUS_050_MV
CoreVoltage2        = VID_MINUS_050_MV
CacheVoltage2       = VID_MINUS_050_MV
SysAgentVoltage2    = VID_MINUS_050_MV

;-------------------------------------------------------------------------------------------------------

section '.text' code executable readable

main:
mov     [Handle], rcx
mov     [SystemTable], rdx
mov     [OriginalStack], rsp
lea     rdx, [_Start]
mov     rcx, [SystemTable]
mov     rcx, [rcx + EFI_SYSTEM_TABLE.ConOut]
sub     rsp, 0x20
call    [rcx + SIMPLE_TEXT_OUTPUT_INTERFACE.OutputString]
add     rsp, 0x20
lea     rcx, [efi_mp_services_protocol_guid]    ; Locate mp_services
xor     rdx, rdx
lea     r8, [efi_mp_services_protocol_Ptr]
mov     r10, [SystemTable]
mov     r10, [r10 + EFI_SYSTEM_TABLE.BootServices]
sub     rsp, 0x20
call    [r10 + EFI_BOOT_SERVICES_TABLE.LocateProtocol]
add     rsp, 0x20
cmp     eax, EFI_SUCCESS
jne     MPServices

mov     rcx, [efi_mp_services_protocol_Ptr]    ; Get total core count
lea     rdx, [NumberOfProcessors]
lea     r8, [NumberOfEnabledProcessors]
sub     rsp, 0x20
call    [rcx + EFI_MP_SERVICES_PROTOCOL.GetNumberOfProcessors]
add     rsp, 0x20
cmp     eax, EFI_SUCCESS
jne     MPServices

mov     rcx, [efi_mp_services_protocol_Ptr]    ; Get original BSP
lea     rdx, [OriginalBSP]
sub     rsp, 0x20
call    [rcx + EFI_MP_SERVICES_PROTOCOL.WhoAmI]
add     rsp, 0x20
cmp     eax, EFI_SUCCESS
jne     MPServices

cmp     [OriginalBSP], 0x0
je      Skip_Initial_BSP_Switch

xor     rdx, rdx
call    BSP_Switch

Skip_Initial_BSP_Switch:
xor     eax, eax
xor     edx, edx
mov     ecx, 0x8b
wrmsr
xor     ecx, ecx
inc     eax
cpuid
cmp     eax, 0x306f2
jne     WrongCPU

mov     ecx, 0x8b
rdmsr
cmp     edx, 0x0
jne     MicroCodePresent

mov     ecx, 0x194
rdmsr
bt      eax, 0x14
jb      OC_Locked

mov     [CoreVoltage], CoreVoltage1
mov     [CacheVoltage], CacheVoltage1
mov     [SysAgentVoltage], SysAgentVoltage1
call    Config_CPU
mov     rdx, [NumberOfProcessors]
sub     rdx, 0x1
call    BSP_Switch
mov     ecx, 0x194
rdmsr
bt      eax, 0x14
jb      Success1

mov     [CoreVoltage], CoreVoltage2
mov     [CacheVoltage], CacheVoltage2
mov     [SysAgentVoltage], SysAgentVoltage2
call    Config_CPU
mov     rdx, [OriginalBSP]
call    BSP_Switch
lea     rdx, [_Success2]
jmp     Text_Exit


Success1:
mov     rdx, [OriginalBSP]
call    BSP_Switch
lea     rdx, [_Success1]
jmp     Text_Exit


WrongCPU:
lea     rdx, [_WrongCPU]
jmp     Text_Exit


MicroCodePresent:
lea     rdx, [_MicroCodePresent]
jmp     Text_Exit


OC_Locked:
lea     rdx, [_OC_Locked]
jmp     Text_Exit


MailBoxError:
lea     rdx, [_MailBoxError]
jmp     Text_Exit


MPServices:
lea     rdx, [_MPServices]
jmp     Text_Exit


Text_Exit:
mov     rcx, [SystemTable]
mov     rcx, [rcx + EFI_SYSTEM_TABLE.ConOut]
sub     rsp, 0x20
call    [rcx + SIMPLE_TEXT_OUTPUT_INTERFACE.OutputString]
add     rsp, 0x20
mov     rax, EFI_SUCCESS
xor     rcx, rcx
mov     rsp, [OriginalStack]
retn


BSP_Switch:
mov     rcx, [efi_mp_services_protocol_Ptr]
mov     r8, 0x1
sub     rsp, 0x20
call    [rcx + EFI_MP_SERVICES_PROTOCOL.SwitchBSP]
add     rsp, 0x20
cmp     eax, EFI_SUCCESS
jne     MPServices
retn


Config_CPU:
mov     ecx, 0x150    ; Get core OC ratio and capabilities
mov     edx, 0x80000001
xor     eax, eax
wrmsr
rdmsr
cmp     dl, 0x0
jne     MailBoxError

mov     [TopCore], al
mov     edx, 0x80000201    ; Get cache OC ratio and capabilities
xor     eax, eax
wrmsr
rdmsr
cmp     dl, 0x0
jne     MailBoxError

mov     [TopCache], al
mov     eax, [CoreVoltage]    ; Set core voltage
mov     al, [TopCore]
mov     edx, 0x80000011
wrmsr
rdmsr
cmp     dl, 0x0
jne     MailBoxError

mov     eax, [CacheVoltage]    ; Set cache voltage
mov     al, [TopCache]
mov     edx, 0x80000211
wrmsr
rdmsr
cmp     dl, 0x0
jne     MailBoxError

mov     eax, [SysAgentVoltage]    ; Set system agent voltage
mov     edx, 0x80000311
wrmsr
rdmsr
cmp     dl, 0x0
jne     MailBoxError

mov     ecx, 0x620    ; Set cache min/max ratios
rdmsr
xor     eax, eax
mov     al, [TopCore]    ; Set turbo ratios
mov     ebx, 0x1010101
mul     ebx
mov     edx, eax
mov     ecx, 0x1ad
wrmsr
inc     ecx
wrmsr
inc     ecx
or      edx, 0x80000000
wrmsr
mov     ecx, 0x194    ; Lock OC
rdmsr
bts     eax, 0x14
wrmsr
retn


section '.data' data readable writeable

OriginalStack                    dq ?
Handle                           dq ?
SystemTable                      dq ?
TopCore                          db ?
TopCache                         db ?
OriginalBSP                      dq ?
NumberOfProcessors               dq ?
NumberOfEnabledProcessors        dq ?
CoreVoltage                      dd ?
CacheVoltage                     dd ?
SysAgentVoltage                  dd ?
efi_mp_services_protocol_Ptr     dq ?
efi_mp_services_protocol_guid    db EFI_MP_SERVICES_PROTOCOL_GUID

_Start               du 13,10,'Xeon v3 All-Core Turbo Boost EFI Driver v1.0',13,10,0
_WrongCPU            du 'Failure - Wrong CPU.',13,10,0
_MicroCodePresent    du 'Failure - Microcode present.',13,10,0
_OC_Locked           du 'Failure - Overclocking Locked.',13,10,0
_MailBoxError        du 'Failure - Mailbox Error.',13,10,0
_MPServices          du 'Failure - EFI_MP_SERVICES_PROTOCOL Error.',13,10,0
_Success1            du 'Success on first CPU, no second CPU or failure on second CPU.',13,10,0
_Success2            du 'Success on both CPUs.',13,10,0
