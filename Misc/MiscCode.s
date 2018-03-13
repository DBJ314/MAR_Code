ColdBoot:
    MOV B,DefaultRed
    MOV C,DefaultGreenBlue
    MOV A,4
    HWI 0x0009;set console color to red
    MOV [FirstTask],0
    PUSH 0
    PUSH Command
    CALL CreateTask

Command:
    PUSH LKeyboard;requires use of keyboard
    CALL RBegin
    CALL GetKey
    CMP B,0x00
    JZ RLoopback
    CALL ChooseDir
    CMP C,0
    JNZ DirNotChosen
    PUSH LLegs
    CALL Steamroll
    CALL SetDirWalk
    JMP CMDDone
DirNotChosen:
    CMP B,0x49
    JNZ NotSS
    PUSH 0
    PUSH ShowStats
    PUSH CMDDone
    JMP CreateTask
NotSS:
    CMP B,0x4F
    JNZ NotOff
    PUSH CMDDone
    JMP Offline
NotOff:
    CMP B,0x47
    JNZ NotG
    PUSH 0
    PUSH GoToCoords
    PUSH CMDDone
    JMP CreateTask
NotG:
    CMP B,0x48
    JNZ NotHunt
    PUSH 0
    PUSH HuntBiomass
    PUSH CMDDone
    JMP CreateTask
NotHunt:
    CMP B,0x50
    JNZ NotPickup
    PUSH CMDDone
    CALL WaitForHex
    JMP LaserWithdraw
NotPickup:
    CMP B,0x4C
    JNZ NotLeave
    PUSH CMDDone
    CALL WaitForHex
    JMP LaserDeposit
NotLeave:
    CMP B,0x43
    JNZ NotClearInventory
    PUSH CMDDone
    JMP InventoryClear
NotClearInventory:
    CMP B,0x0d
    JNZ NotTextProcess
    PUSH CMDDone
    JMP TextProcess
NotTextProcess:
    CMP B,0x1b
    JNZ NotAbort
    PUSH 0xFFFF
    CALL Steamroll
NotAbort:
    CMP B,0x54
    JNZ NotTravel
    PUSH 0
    PUSH Travel
    PUSH CMDDone
    JMP CreateTask
NotTravel:
    CMP B,0x20
    JNZ NotAttack
    PUSH CMDDone
    JMP LaserAttack
NotAttack:
    CMP B,0x5A
    JNZ NotShield
    MOV B,25
    PUSH CMDDone
    JMP ShieldCharge
NotShield:
    CMP B,0x4D
    JNZ NotSendMessage
    CALL GetString
    MOV X,TextBuffer
    PUSH CMDDone
    JMP SendMessage
NotSendMessage:
CMDDone:
    CALL ClearKeyBuf
    JMP RLoopback
TestLP:
    PUSH 0xFF
    CALL RBegin
    MOV X,TestMsg
    CALL DisplayString
    CALL RLoopback
ChooseDir:
    MOV C,0
    CMP B,0x57
    JNZ NotW
    MOV B,NORTH
    JMP CDSuccess
NotW:
    CMP B,0x53
    JNZ NotS
    MOV B,SOUTH
    JMP CDSuccess
NotS:
    CMP B,0x41
    JNZ NotA
    MOV B,WEST
    JMP CDSuccess
NotA:
    CMP B,0x44
    JNZ NotD
    MOV B,EAST
    JMP CDSuccess
NotD:
    MOV C,1
    RET
CDSuccess:
    MOV C,0
    RET    
ShowStats:
    PUSH LDisplay
    CALL RBegin
    CALL RCheckpoint
    MOV X,CycMsg
    CALL DisplayString
    CALL RCheckpoint
    MOV B,[TickCount]
    CALL DisplayHex
    CALL RCheckpoint
    MOV X,BatMsg
    CALL DisplayString
    CALL RCheckpoint
    CALL GetCharge
    CALL DisplayHex
    CALL RCheckpoint
    MOV X,BatMCMsg
    CALL DisplayString
    CALL RCheckpoint
    CALL GetMaxCharge
    CALL DisplayHex
    CALL RCheckpoint
    MOV X,ItemMsg
    CALL DisplayString
    CALL RCheckpoint
    CALL InventoryPoll
    CALL DisplayHex
    CALL REnd
    RET
    
Offline:
    PUSH 0x06;display and keyboard
    CALL RBegin
    MOV X,OffMsg
    CALL DisplayString
    CALL GetKey
    CMP B,0
    JZ RLoopback
    CALL REnd
    RET

ReadAsHex:
    MOV A,0
    CMP B,0x30
    JL Return
    CMP B,0x39
    JG RAHIL
    SUB B,0x30
    MOV A,B
    RET
RAHIL:
    CMP B,0x41
    JL Return
    CMP B,0x46
    JG Return
    SUB B,0x41
    ADD B,0x0A
    MOV A,B
    RET

WaitForKey:
    CALL GetKey
    CMP B,0
    JNZ Return
    PUSH LKeyboard
    CALL RBegin
    CALL GetKey
    CMP B,0
    JZ RLoopback
    CALL REnd
    RET

WaitForHex:
    CALL WaitForKey
    CALL ReadAsHex
    MOV B,A
    RET