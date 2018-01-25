; this file has most of the hardware routines

GetKey:
    MOV A,1
    HWI 0x0004
    RET
ClearKeyBuf:
    MOV A,0
    HWI 0x0004
    RET
DisplayHex:
    MOV A,1
    HWI 0x0009
    RET
DisplayString:
    MOV A,2
    HWI 0x0009
    RET
SetDirWalk:
    MOV A,2
    HWI 0x0001
    RET
SetDir:
    MOV A,1
    HWI 0x0001
    RET
GetCharge:
    MOV A,1
    HWI 0x000A
    RET
GetMaxCharge:
    MOV A,2
    HWI 0x000A
    RET
LaserWithdraw:
    MOV A,1
    HWI 0x0002
    RET
LaserDeposit:
    MOV A,2
    HWI 0x0002
    RET
InventoryClear:
    MOV A,0
    HWI 0x0006
    RET
InventoryPoll:
    MOV A,1
    HWI 0x0006
    RET
GetRandom:
    HWI 0x0007
    RET
GetGlobalCoords:
    MOV A,4
    HWI 0x0003
    RET