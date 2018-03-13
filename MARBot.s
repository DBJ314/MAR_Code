MaxContextSwitches EQU 0x20
TaskStructSize EQU 0x200 ;task struct + stack space
TaskStackStart EQU 0x1FF ;start of stack
;offsets into task structures
TSNextTask EQU 0
TSPrevTask EQU 1
TSPC EQU 2
TSSP EQU 3
TSBP EQU 4
TSRA EQU 5
TSRB EQU 6
TSRC EQU 7
TSRD EQU 8
TSRX EQU 9
TSRY EQU 0xA
TSCycleCounter EQU 0xB
TSLocks EQU 0xC
TSFlags EQU 0xD

;flags
FlagDone EQU 1

;locks
LLegs EQU 1
LKeyboard EQU 2
LDisplay EQU 4
;default color of console
DefaultRed EQU 0xFF
DefaultGreenBlue EQU 0x00
NORTH EQU 0
SOUTH EQU 2
EAST EQU 1
WEST EQU 3

MaxBlackLength EQU 0x10
TextMaxLength EQU 8
.data
TickCount: DW 0
;number of remaining allowed context switches. Probably just paranoia
RemainingCycleCount: DW 0
;keeps track of resources already claimed by tasks
HeldLocks: DW 0

;First task in the queue.
FirstTask: DW ColdBootStruct
;Current running task
CurTask: DW 0

;fake task structure used only during the first tick.
ColdBootStruct:
DW 0,0,ColdBoot,0xFFFF,0xFFFF,0,0,0,0,0,0,0,0,0

SpecialTaskStruct:
DW 0,0
SpecialTaskPC: DW 0,0,0,0,0,0,0,0,0,0,0,0

;register saves used by internal multitasking calls when it is unsafe to use the stack
SavedFT: DW 0
SavedCT: DW 0
TempPC: DW 0
TempA: DW 0
TempB: DW 0
TempC: DW 0
CmdMsg: DW "CmdLp",0
TestMsg: DW "Test",0
OffMsg: DW "Offline",0
CycMsg: DW "Ticks:",0
BatMsg: DW "BAT Lvl:",0
BatMCMsg: DW "BAT Max:",0
ItemMsg: DW "Item:",0
AfterREnd: DW "A REnd",0
;blacklisted global coordinates for world movement
BlackX: DW 0x10 DUP(0)
BlackY: DW 0x10 DUP(0)
BlackLength: DW 0
BlackIPoint: DW 0
TextIndex: DW 0
TextLength: DW 0
TextBuffer: DW 0,0,0,0,0,0,0,0,0
.text
    ADD [TickCount],1
    MOV [RemainingCycleCount],MaxContextSwitches
    MOV [HeldLocks],0
    MOV [TempPC],_RestartAtTop
    JMP _ReadyTasks
_RestartAtTop:
    MOV [CurTask],[FirstTask]
Schedule:
    MOV A,[CurTask]
    CMP A,0
    JZ Break
    MOV B,[A+TSLocks]
    AND B,[HeldLocks]
    JNZ _SkipThisTask
    MOV B,[A+TSFlags]
    AND B,FlagDone
    JNZ _SkipThisTask
    SUB [RemainingCycleCount],1
    JZ Break
    MOV [TempPC],[A+TSPC]
    MOV SP,[A+TSSP]
    MOV BP,[A+TSBP]
    ADD [A+TSCycleCounter],1
    MOV [TempA],[A+TSRA];load registers
    MOV B,[A+TSRB]
    MOV C,[A+TSRC]
    MOV D,[A+TSRD]
    MOV X,[A+TSRX]
    MOV Y,[A+TSRY]
    MOV A,[TempA]
    JMP [TempPC]

;TaskPtr CreateTask(numArgs, entryPoint)
;Creates a new task with the specified entry point and inserts it at the top of the task queue.
;It moves numArgs additional stack arguments from the caller's stack to the new task's stack.
;All registers (except SP,BP, and FLAGS) are copied to the new task.
;The caller is deferred and the new task is run.
;The stack is initialized to place AbortThisTask where a return address would be.
;Usage:
;PUSH args       ;push all arguments for the new task
;PUSH numArgs    ;the number of arguments to give the new task. Usually 0.
;PUSH entryPoint ;where you want the task to start executing at
;CALL CreateTask ;call the function
CreateTask:
    CALL _BeginSpecial
    POP [TempPC]
    MOV [TempA],A
    MOV [TempB],B
    MOV [TempC],C
    PUSH TaskStructSize
    CALL _Malloc
    MOV [A+TSRA],[TempA]
    MOV [A+TSRB],[TempB]
    MOV [A+TSRC],[TempC]
    MOV [A+TSRD],D
    MOV [A+TSRX],X
    MOV [A+TSRY],Y
    POP [A+TSPC]
    MOV [A+TSLocks],0
    MOV [A+TSFlags],0
    MOV [A+TSCycleCounter],0
    MOV B,[FirstTask]
    MOV [A+TSNextTask],B
    MOV [A+TSPrevTask],0
    CMP B,0
    JZ CreateTaskNoFirstTask
    MOV [B+TSPrevTask],A
CreateTaskNoFirstTask:
    MOV [FirstTask],A
    POP B
    MOV C,A
    ADD C,TaskStackStart
    MOV [A+TSBP],C
    SUB C,B
    MOV [C],AbortThisTask
    MOV [A+TSSP],C
CreateTaskStackCopyLoop:
    CMP C,[A+TSBP]
    JZ CreateTaskStackCopyLoopDone
    POP [C+1]
    ADD C,1
    JMP CreateTaskStackCopyLoop
CreateTaskStackCopyLoopDone:
    MOV B,[TempB]
    MOV C,[TempC]
    PUSH [TempPC]
    CALL _SpecialDelayTask
    JMP _RestartAtTop

;void DestroyTask(TaskPtr)
;removes a task from the queue and deallocates its structure
;execution continues at the calling task, unless it just destroyed the task that called it.
DestroyTask:
    PUSH BP
    MOV BP,SP
    CALL _BeginSpecial
    PUSH A
    PUSH B
    PUSH C
    MOV A,[BP+2]
    CMP A,[FirstTask]
    JNZ DestroyTaskNotFirstTask
    MOV [FirstTask],[A+TSNextTask];set the first task to the one after the deleted task
    CMP [FirstTask],0
    JZ Panic
    JMP DestroyTaskPrevTaskDone
DestroyTaskNotFirstTask:
    MOV B,[A+TSPrevTask]
    MOV [B+TSNextTask],[A+TSNextTask]
DestroyTaskPrevTaskDone:
    CMP [A+TSNextTask],0
    JZ DestroyTaskNextTaskDone
    MOV B,[A+TSNextTask]
    MOV [B+TSPrevTask],[A+TSPrevTask]
DestroyTaskNextTaskDone:
    MOV [TempA],[A+TSNextTask]
    MOV B,A
    CALL _Free
    CMP B,[CurTask]
    JNZ DestroyTaskSimpleRet
    CMP [TempA],0
    JZ Break
    MOV [CurTask],[TempA]
    JMP Schedule
DestroyTaskSimpleRet:
    POP C
    POP B
    POP A
    MOV SP,BP
    POP BP
    RET 1
AbortThisTask:
    PUSH [CurTask]
    CALL DestroyTask
    ;no RET needed

;void Steamroll(lock_value)
;forcibly end all tasks that get in this tasks way.
;calls DestroyTask on any tasks that use the specified locks and run before the current task.
;used by the command loop to cancel multi-tick operations
Steamroll:
    PUSH BP
    MOV BP,SP
    PUSH A
    PUSH B
    PUSH C
    CALL _BeginSpecial
    MOV A,[BP+2]
    TEST [HeldLocks],A
    JZ SteamrollDone
    MOV B,[CurTask]
SteamrollLoop:   
    MOV B,[B+TSPrevTask]
    CMP B,0
    JZ SteamrollDone
    TEST [B+TSLocks],A
    JZ SteamrollLoop
    PUSH B
    MOV B,[B+TSNextTask]
    CALL DestroyTask
    JMP SteamrollLoop
SteamrollDone:
    NOT A
    AND [HeldLocks],A
    POP C
    POP B
    POP A
    MOV SP,BP
    POP BP
    RET 1

;void RBegin(requiredLocks)
;used to start a new recursive code section. 
;The next time this task is run, execution will continue at this location with SP and BP loaded from saved values.
;The state of the previous recursive section is stored on the stack, where it can be restored by a call to REnd.
;RBegin is also how you specify the locks that the task needs.
;There is also a cycle counter that keeps track of how many times the code section has restarted.
RBegin:
    CALL _BeginSpecial
    POP [TempPC]
    POP [TempC]
    MOV [TempA],A
    MOV A,[CurTask]
    PUSH [A+TSPC]
    PUSH [A+TSSP]
    PUSH [A+TSBP]
    PUSH [A+TSCycleCounter]
    PUSH [A+TSLocks]
    MOV [A+TSPC],[TempPC]
    MOV [A+TSSP],SP
    MOV [A+TSBP],BP
    MOV [A+TSCycleCounter],0
    OR [A+TSLocks],[TempC]
    MOV A,[TempA]
    CALL SaveRegisters
    JMP Schedule

;void REnd()
;used to end a recursive code section. It loads the previous state from the stack. 
;It returns normally, but the next time this task is run it will start with the old PC,SP,BP, and Locks.
;The old cycle counter is also reloaded.
;SP has to be at the same position it was in when the matching RBegin returned.
REnd:
    CALL _BeginSpecial
    POP [TempPC]
    MOV [TempA],A
    MOV A,[CurTask]
    POP [A+TSLocks]
    POP [A+TSCycleCounter]
    POP [A+TSBP]
    POP [A+TSSP]
    POP [A+TSPC]
    MOV A,[TempA]
    JMP [TempPC]

;void RCheckpoint()
;This function sets the recursive code state (PC,SP,BP, but not Locks or Cycles) without saving the previous state.
;It then gives up control of the CPU so that the next task is run.
;Usage:
;PUSH Locks
;CALL RBegin
;do something
;CALL RCheckpoint	;continue execution next tick
;do a different thing
;CALL REnd
;RET
RCheckpoint:
    CALL _BeginSpecial
    POP [TempPC]
    MOV [TempA], A
    MOV A,[CurTask]
    MOV [A+TSPC],[TempPC]
    MOV [A+TSSP],SP
    MOV [A+TSBP],BP
    MOV A,[TempA]
    JMP RLoopback

;void RLoopback()
;abandons the PC,SP,and BP and runs the next task.
;execution of this task continues at the recursion point next tick, with SP and BP reloaded.
;All other registers are unaffected.
RLoopback:
    CALL SaveRegisters
    MOV A,[CurTask]
    OR [HeldLocks],[A+TSLocks]
    OR [A+TSFlags],FlagDone
_SkipThisTask:
    MOV B,[A+TSNextTask]
    CMP B,0
    JZ Break
    MOV [CurTask],B
    JMP Schedule

;void Wait(numTicks)
;delays the current task for a number of ticks before returning normally
Wait:
    PUSH BP
    MOV BP,SP
    PUSH 0
    CALL RBegin
    CMP [BP+2],0
    JZ WaitDone
    SUB [BP+2],1
    JMP RLoopback
WaitDone:
    CALL REnd
    MOV SP,BP
    POP BP
    RET 1

;internal function used at the beginning of many internal multitasking calls. No longer does anything.
_BeginSpecial:
    RET


;void _SpecialDelayTask(task_return_point)
;INTERNAL USE ONLY. Even trying to describe what this does causes headaches
;
_SpecialDelayTask:
    CALL SaveRegisters
    MOV A,[CurTask]
    POP [TempPC]
    PUSH [A+TSPC]
    PUSH [A+TSSP]
    PUSH [A+TSBP]
    MOV [A+TSPC],__DelayEnd
    MOV [A+TSSP],SP
    MOV [A+TSBP],BP
    JMP [TempPC]
__DelayEnd:
    MOV [TempA],A
    MOV A,[CurTask]
    POP [A+TSBP]
    POP [A+TSSP]
    POP [A+TSPC]
    MOV A,[TempA]
    RET
SaveRegisters:
    POP [TempPC]
_SaveRegisters:
    MOV [TempA],A
    MOV A,[CurTask]
    MOV [A+TSRA],[TempA]
    MOV [A+TSRB],B
    MOV [A+TSRC],C
    MOV [A+TSRD],D
    MOV [A+TSRX],X
    MOV [A+TSRY],Y
    JMP [TempPC]

_ReadyTasks:;JMP with return in [TempPC]
    MOV A,[FirstTask]
__ReadyTaskLoop:
    AND [A+TSFlags],0xFFFE;mask out FlagDone
    MOV A,[A+TSNextTask]
    CMP A,0
    JNZ __ReadyTaskLoop
    JMP [TempPC]
;used when you want to break if a condition is true.
;JZ Break
Break:
    BRK
Panic:
    MOV A,[FirstTask]
    MOV [A+TSPC],PanicLoop
    MOV [A+TSFlags],0
PanicLoop:
    MOV B,0xDEAD
    MOV A,1
    HWI 0x0009
    BRK
;used when you want to return if a condition is true.
;only works if a function takes no arguments
Return:
    RET
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
LaserAttack:
    MOV A,3
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
ShieldCharge:
    MOV A,1
    HWI 0x000F
    RET
ShieldPoll:
    MOV A,2
    HWI 0x000F
    RET
SendMessage:
    MOV A,2
    HWI 0x000D
    RET
;function FindPath
;finds the path to something
;word FindPath(int X,int Y, int distance)
;returns 0 in A on success and 1 in A on failure
FindPath:
    PUSH BP
    MOV BP,SP
    MOV B,[BP+2]
    MOV X,[BP+4]
    MOV Y,[BP+3]
    MOV A,2
    HWI 0x0003
    MOV SP,BP
    POP BP
    MOV A,[0x0]
    CMP A,0xFFFF
    JZ FPFail
    MOV A,0
    RET 3
FPFail:
    MOV A,1
    RET 3
    
FollowPath:
    PUSH BP
    MOV BP,SP
    MOV A,1
    HWI 0x0003
    PUSH X
    PUSH Y
    PUSH 0
    PUSH LLegs
    CALL RBegin
    MOV A,1
    HWI 0x0003
    CMP X,[BP-1]
    JNZ FPDone
    CMP Y,[BP-2]
    JNZ FPDone
    MOV D,[BP-3]
    MOV B,[D]
    ADD [BP-3],1
    MOV A,0
    CMP B,0xAAAA
    JZ FPDone
    CALL CalcNextPos
    MOV [BP-1],X
    MOV [BP-2],Y
    CALL SetDirWalk 
    JMP RLoopback
FPDone:
    CALL REnd
    MOV SP,BP
    POP BP
    RET
    
;word FindObject(int object ,int startingLoc)
FindObject:
    PUSH BP
    MOV BP,SP
    SUB SP,1
    MOV A,3
    HWI 0x0003
    MOV [BP-1],0x100
    ADD [BP-1],[BP+2]
FindObjectLoop:
    MOV A,[BP-1]
    MOV B,[A]
    CMP B,[BP+3]
    JZ FindObjectDone
    ADD [BP-1],1
    CMP [BP-1],0x200
    JNZ FindObjectLoop
    MOV A,0xFFFF
FindObjectDone:
    MOV SP,BP
    POP BP
    RET 2

HuntBiomass:
    PUSH BP
    MOV BP,SP
    SUB SP,1
    MOV [BP-1],0
    PUSH LLegs
    CALL RBegin
HuntBiomassLoop:
    PUSH 0x4000;id of biomass in map
    PUSH [BP-1]
    CALL FindObject
    CMP A,0xFFFF
    JZ HBLReturn
    MOV [BP-1],A
    MOV B,A
    MOV C,A
    AND B,0x0F
    AND C,0xF0
    ROR C,0x04
    PUSH B
    PUSH C
    PUSH 1
    CALL FindPath
    CMP A,0
    JNZ HuntBiomassLoop
    CALL FollowPath
    CALL FetchNearbyBiomass
HBLReturn:
    CALL REnd
    MOV SP,BP
    POP BP
    RET

FetchNearbyBiomass:
    PUSH BP
    MOV BP,SP
    SUB SP,2
    MOV A,3
    HWI 0x0003
    MOV A,1
    HWI 0x0003
    MOV [BP-1],X
    MOV [BP-2],Y
    CMP [BP-1],0
    JZ FNBNoWest
    MOV X,[BP-1]
    MOV Y,[BP-2]
    SUB X,1
    CALL CheckForBiomass
    CMP A,0
    JNZ FNBNoWest
    MOV B,WEST
    CALL SetDir
    MOV B,1
    PUSH FNBDone
    JMP LaserWithdraw
FNBNoWest:
    CMP [BP-1],0xF
    JZ FNBNoEast
    MOV X,[BP-1]
    MOV Y,[BP-2]
    ADD X,1
    CALL CheckForBiomass
    CMP A,0
    JNZ FNBNoEast
    MOV B,EAST
    CALL SetDir
    MOV B,1
    PUSH FNBDone
    JMP LaserWithdraw
FNBNoEast:
    CMP [BP-2],0
    JZ FNBNoNorth
    MOV X,[BP-1]
    MOV Y,[BP-2]
    SUB Y,1
    CALL CheckForBiomass
    CMP A,0
    JNZ FNBNoNorth
    MOV B,NORTH
    CALL SetDir
    MOV B,1
    PUSH FNBDone
    JMP LaserWithdraw
FNBNoNorth:
    CMP [BP-2],0x0F
    JZ FNBNoSouth
    MOV X,[BP-1]
    MOV Y,[BP-2]
    ADD Y,1
    CALL CheckForBiomass
    CMP A,0
    JNZ FNBNoSouth
    MOV B,SOUTH
    CALL SetDir
    MOV B,1
    PUSH FNBDone
    JMP LaserWithdraw
FNBNoSouth:
FNBDone:
    MOV SP,BP
    POP BP
    RET
CheckForBiomass:
    MOV A,1
    MOV C,X
    MOV B,Y
    ROL B,4
    ADD C,B
    ADD C,0x100
    MOV B,[C]
    CMP B,0x4000
    JNZ Return
    MOV A,0
    RET

GoToCoords:
    CALL WaitForHex
    PUSH A
    CALL WaitForHex
    PUSH A
    PUSH 0
    CALL FindPath
    CMP A,0
    JNZ Return
    CALL FollowPath
    RET

CalcNextPos:
    AND B,3
    JMP [B+CalcNextPosJumpTable]
CalcNextPosJumpTable: DW CalcNextPosNorth,CalcNextPosEast,CalcNextPosSouth,CalcNextPosWest
CalcNextPosNorth:
    SUB Y,1
    RET
CalcNextPosEast:
    ADD X,1
    RET
CalcNextPosSouth:
    ADD Y,1
    RET
CalcNextPosWest:
    SUB X,1
    RET

; success ChangeWorld(Direction)
ChangeWorld:
    PUSH BP
    MOV BP,SP
    SUB SP,4
    PUSH A
    PUSH B
    PUSH C
    MOV A,[BP+2]
    AND A,3
    SHL A,2
    ADD A,ChangeWorldCoordTable
    MOV [BP-3],A
    ADD A,4
    MOV [BP-4],A
ChangeWorldTargetLoop:
    MOV C,[BP-3]
    MOV B,[C]
    ADD [BP-3],1
    MOV A,B
    AND A,0x0f
    SHR B,4
    AND B,0x0f
    PUSH B
    PUSH A
    PUSH 0
    CALL FindPath
    CMP A,0
    JZ ChangeWorldTargetLoopDone
    CMP [BP-3],[BP-4]
    JNZ ChangeWorldTargetLoop
    JMP ChangeWorldReturnFailure
ChangeWorldTargetLoopDone:
    MOV [BP-1],X
    MOV [BP-2],Y
    PUSH LLegs
    CALL RBegin
    PUSH [BP-1]
    PUSH [BP-2]
    PUSH 0
    CALL FindPath
    CMP A,0
    JZ ChangeWorldPathValid
    CALL REnd
    JMP ChangeWorldReturnFailure
ChangeWorldPathValid:
    CALL FollowPath
    CMP A,0
    JNZ RLoopback
    MOV B,[BP+2]
    CALL SetDirWalk
    CALL RCheckpoint ;don't return until fresh tick
    CALL REnd
ChangeWorldReturnSuccess:
    POP C
    POP B
    POP A
    MOV SP,BP
    POP BP
    MOV A,0
    RET 1
ChangeWorldReturnFailure:
    POP C
    POP B
    POP A
    MOV SP,BP
    POP BP
    MOV A,1
    RET 1
ChangeWorldCoordTable:
DW 0x60,0x70,0x80,0x90
DW 0xf6,0xf7,0xf8,0xf9
DW 0x6f,0x7f,0x8f,0x9f
DW 0x06,0x07,0x08,0x09

Travel:
    PUSH BP
    MOV BP,SP
    SUB SP,2
    CALL GetString
    CMP A,0
    JNZ Return
    CMP [TextLength],8
    JNZ Return

    ;get x coord
    CALL GetNextChar
    CALL ReadAsHex
    SHL A,0xc
    MOV [BP-1],A
    CALL GetNextChar
    CALL ReadAsHex
    SHL A,0x08
    OR [BP-1],A
    CALL GetNextChar
    CALL ReadAsHex
    SHL A,0x04
    OR [BP-1],A
    CALL GetNextChar
    CALL ReadAsHex
    OR [BP-1],A

    ;get y coord
    CALL GetNextChar
    CALL ReadAsHex
    SHL A,0xc
    MOV [BP-2],A
    CALL GetNextChar
    CALL ReadAsHex
    SHL A,0x08
    OR [BP-2],A
    CALL GetNextChar
    CALL ReadAsHex
    SHL A,0x04
    OR [BP-2],A
    CALL GetNextChar
    CALL ReadAsHex
    OR [BP-2],A
    PUSH [BP-1]
    PUSH [BP-2]
    CALL MoveGlobal
    MOV SP,BP
    POP BP
    RET

;success MoveGlobal(worldX,worldY)
MoveGlobal:
    PUSH BP
    MOV BP,SP
    SUB SP,3
    CALL ClearBlackList
    PUSH LLegs
    CALL RBegin
    CALL GetGlobalCoords
    MOV [BP-1],X
    MOV [BP-2],Y
    CMP X,[BP+3]
    JNZ MoveGlobalNotDone
    CMP Y,[BP+2]
    JZ MoveGlobalSuccess
MoveGlobalNotDone:
    CMP X,[BP+3]
    JC MGEast
    JA MGWest
MoveGlobalSecondTry:
    CMP Y,[BP+2]
    JC MGSouth
    JA MGNorth
    MOV B,0
    JMP MoveGlobalTargetInvalid
MGSouth:
    MOV B,SOUTH
    PUSH MoveGlobalTargetChosen
    JMP CalcNextPos
MGNorth:
    MOV B,NORTH
    PUSH MoveGlobalTargetChosen
    JMP CalcNextPos
MGEast:
    MOV B,EAST
    PUSH MoveGlobalTargetChosen
    JMP CalcNextPos
MGWest:
    MOV B,WEST
    PUSH MoveGlobalTargetChosen
    JMP CalcNextPos
MoveGlobalTargetChosen:
    PUSH X
    PUSH Y
    CALL IsBlackListed
    CMP A,0
    JNZ MoveGlobalTargetInvalid
    PUSH B
    CALL ChangeWorld
    CMP A,0
    JZ RLoopback
MoveGlobalTargetInvalid:
    MOV X,[BP-1]
    MOV Y,[BP-2]
    TEST B,1
    JNZ MoveGlobalSecondTry;if the invalid direction was e/w, check if n/s works
    PUSH [BP-1]
    PUSH [BP-2]
    CALL AddBLEntry
    CALL GetRandom
    AND B,3
    MOV [BP-3],B
    ADD B,1
MGTILoop:
    CMP B,[BP-3]
    JZ MoveGlobalFail
    MOV X,[BP-1]
    MOV Y,[BP-2]
    CALL CalcNextPos
    ADD B,1
    PUSH X
    PUSH Y
    CALL IsBlackListed
    CMP A,0
    JNZ MGTILoop
    PUSH B
    CALL ChangeWorld
    CMP A,0
    JZ RLoopback
    JMP MGTILoop
MoveGlobalFail:
    MOV A,1
    JMP MoveGlobalDone
MoveGlobalSuccess:
    MOV A,0
MoveGlobalDone:
    CALL REnd
    MOV SP,BP
    POP BP
    RET 2
 
;boolean IsBlackListed(worldX,worldY)
IsBlackListed:
    PUSH BP
    MOV BP,SP
    PUSH B
    PUSH C
    PUSH D
    MOV B,0
IBLLoop:
    CMP B,[BlackLength]
    JZ IBLNo
    MOV C,[B+BlackX]
    MOV D,[B+BlackY]
    ADD B,1
    CMP C,[BP+3]
    JNZ IBLLoop
    CMP D,[BP+2]
    JNZ IBLLoop
IBLYes:
    MOV A,1
    JMP IBLDone
IBLNo:
    MOV A,0
    JMP IBLDone
IBLDone:
    POP D
    POP C
    POP B
    MOV SP,BP
    POP BP
    RET 2

ClearBlackList:
    MOV [BlackLength],0
    MOV [BlackIPoint],0
    RET

;void AddBLEntry(worldX,worldY)
AddBLEntry:
    PUSH BP
    MOV BP,SP
    PUSH A
    CMP [BlackLength],MaxBlackLength
    JZ AddBLEntryHard
    ADD [BlackLength],1
    MOV A,[BlackIPoint]
    ADD [BlackIPoint],1
    MOV [A+BlackX],[BP+3]
    MOV [A+BlackY],[BP+2]
    JMP AddBLEntryDone
AddBLEntryHard:
    CMP [BlackIPoint],MaxBlackLength
    JNZ AddBLEntryHardIPNotZ
    MOV [BlackIPoint],0
AddBLEntryHardIPNotZ:
    MOV A,[BlackIPoint]
    ADD [BlackIPoint],1
    MOV [A+BlackX],[BP+3]
    MOV [A+BlackY],[BP+2]
AddBLEntryDone:
    POP A
    MOV SP,BP
    POP BP
    RET 2
TextProcess:
    PUSH 6
    CALL RBegin
TextProcessLoop:
    CALL GetString
    CMP A,0
    JNZ TextProcessDone
    MOV X,TextBuffer
    CALL DisplayString
    JMP TextProcessLoop
TextProcessDone:
    CALL REnd
    RET

;success GetString()
GetString:
    PUSH BP
    MOV BP,SP
    SUB SP,2
    CALL ClearChars
    PUSH 6;display+keyboard
    CALL RBegin
GetStringLoop:
    MOV X,TextBuffer
    CALL DisplayString
    CALL GetKey
    CMP B,0x00
    JZ RLoopback
    CMP B,0x08
    JNZ NotBackspace
    PUSH GetStringCycleEnd
    JMP RemoveChar
NotBackspace:
    CMP B,0x1b
    JNZ NotEscape
    CALL ClearChars
    MOV A,1
    JMP GetStringDone
NotEscape:
    CMP B,0x0D
    JNZ NotCR
    MOV A,0
    JMP GetStringDone
NotCR:
    CALL AddChar
GetStringCycleEnd:
    MOV X,TextBuffer
    CALL DisplayString
    JMP GetStringLoop
GetStringDone:
    CALL REnd
    MOV SP,BP
    POP BP
    RET

AddChar:
    CMP [TextLength],TextMaxLength
    JZ CycleChars
    MOV A,[TextLength]
    MOV C,A
    ADD C,TextBuffer
    MOV [C],B
    ADD A,1
    CALL SetCBufLen
    RET
CycleChars:
    MOV A,TextBuffer
    MOV C,TextMaxLength
    ADD C,A
CCLoop:
    MOV [A],[A+1]
    ADD A,1
    CMP A,C
    JNZ CCLoop
    MOV [A-1],B
    RET
RemoveChar:
    CMP [TextLength],0
    JZ Return
    MOV A,[TextLength]
    SUB A,1
    CALL SetCBufLen
    RET
ClearChars:
    MOV [TextLength],0
    MOV [TextBuffer],0
    MOV [TextIndex],0
    RET
GetNextChar:
    MOV B,0
    CMP [TextIndex],[TextLength]
    JZ Return
    MOV A,TextBuffer
    ADD A,[TextIndex]
    MOV B,[A]
    ADD [TextIndex],1
    RET
SetCBufLen:
    MOV [TextLength],A
    ADD A,TextBuffer
    MOV [A],0
    RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   I hope you enjoy my heap implementation.
;   Please report any bugs you might encounter.
;
;   Code to test the heap is available in
;   heap-testing.mar
;
;   Copy and paste this whole file to the end
;   of your code
;
;   Usable functions:
;       _Malloc
;       _Free
;       _Realloc
;       _Calloc
;       _Memcpy
;       _Memset
;
;   Please don't forget to put the
;   label at end of file
;
;   Author: Jaggernaut
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;; heap code start

; Change this to say where you want the heap to
; limit as it's last usable address.
; It must be further than your heap label
HEAP_END_ADDR equ 0xF000

; void * memset ( void * ptr, int value, size_t num );
;
;   MOV A, dest
;   MOV B [value]
;   MOV B [size]
;   CALL __Memset
;
_Memset:
    PUSH A
    PUSH B
    PUSH C

    ADD C, A
___memset_loop:
    MOV [A], B
    ADD A, 1
    CMP A, C
    JL ___memset_loop

    POP C
    POP B
    POP A
    RET
;_Memset end

; void * memcpy ( void * destination, const void * source, size_t num );
;
;   MOV A, dest
;   MOV B, source
;   MOVE B [size]
;   CALL _Memcpy
;
_Memcpy:
    PUSH A
    PUSH B
    PUSH C

    ADD C, A
___memcpy_loop:
    MOV [A], [B]
    ADD B, 1
    ADD A, 1
    CMP A, C
    JL ___memcpy_loop

    POP C
    POP B
    POP A
    RET
;_Memcpy end

; A = Malloc(int size)
; usage: 
;
;   PUSH [size]     ; Push size to allocate
;   CALL _Malloc    ; A now points to first address of allocated memory
;   
;   PUSH pointer
;   PUSH 1
;   CALL _Malloc
;
;   TEST A, A
;   JZ failure
;
;   MOV [A], 5
;
;   Currently if you go over the heap limit things will just sort of not allocate
;   Sets A register to the new 
_Malloc:
    PUSH BP
    MOV BP, SP
    PUSH B
    PUSH C
    PUSH D
    PUSH X
    PUSH Y

    CALL __InitializeAllocator

    MOV D, [BP+2]   ; D is the size we want
    TEST D,D
    JZ ___Malloc_search_not_found      ; Don't waste time malloc(ptr,0)         ;;; this could be changed to make a pointer that's distinctly set to [0]?

    ADD D, 2        ; We need to have add room for the control word and the range word

    CMP [____heap_total_available], D
    JC ___Malloc_search_not_found      ; Fail if heap total < requested size

    MOV C, [____heap_size]              ; Get current total allocated
    ADD C, D                        ; Add the new size we want
    JC ___Malloc_search_not_found      ; fail if new size + ____heap_size > 0xFFFF
    CMP [____heap_total_available],C    ; Check if the new total is more than is available
    JC ___Malloc_search_not_found      ; Fail if taking up too much memory

    MOV X, heap     ; X is the heap pointer

___Malloc_search_loop:
    TEST [X], [X]  ; if X address is allocated, move on to the next available address
    JNZ ___Malloc_search_loop_continue

    MOV A, X
    CALL __CombineEmptyBlocks

    MOV B, [X+1]    ; Get our available space this block

    TEST B, B       ; if size hasn't been set, we're good to go
    JZ ___Malloc_search_found_size_zero

    CMP D, B        ; if Our size is less than or equal to the space available, take the spot
    JLE  ___Malloc_search_found_existing

    ADD X, B

    JMP ___Malloc_search_loop_continue

___Malloc_search_loop_continue:
    ADD X, [X+1]        ; increment by range word
    JMP ___Malloc_search_loop

___Malloc_search_found_size_zero:
    ADD [____heap_size], D              ; ADD new block our heap size

    MOV A, X
    MOV [A], 0                      ; Make sure the next control word
    MOV [A+1], 0                    ; and range word are 0

    JMP ___Malloc_search_found
___Malloc_search_found_existing:
    SUB B, D                        ; Remove our current size from the existing free block
    CMP B, 3                        ; If there's less than 3 blocks left, take them
    JGE ___Malloc_search_found_existing_skip
    ADD D, B
___Malloc_search_found_existing_skip:
    MOV A, X                        ; Copy address of current control word
    ADD A, D                        ; Mov current size forward to create a new block control word
    TEST [A], [A]
    JNZ ___Malloc_search_found      ; If block allocated, do not overwrite
    MOV [A+1], B                    ; If not allocated, set the new space available

___Malloc_search_found:
    MOV [X+1], D                    ; Set the range word
    MOV [X], 1                      ; Set the control word
    ADD X,2                         ; Do not send back the allocator control word or the range word
    MOV A, X                      ; Send back the allocated memory address

    JMP ___Malloc_done

___Malloc_search_not_found:
    MOV A, 0      ; We could not alloc, sad day

___Malloc_done:
    POP Y
    POP X
    POP D
    POP C
    POP B
    POP BP
    RET 1   ; we pushed 1 thing to call
;_Malloc end

; free(void *ptr)
; usage:
;
;   MOV A, [ptr]    ; Push pointer
;   CALL _Free      ; If successful A will now be zero
;                   ; If you tried to free something outside of the heap
;                   ; It will remain as it was
;   TEST A, A
;   JZ failure
;
; Does not change any registers
_Free:
    PUSH BP
    MOV BP, SP
    PUSH B
    PUSH C
    PUSH Y

    CALL __InitializeAllocator

    MOV Y, A            ; Y is ptr
    ;MOV X, [Y]         ; X is the location Y is pointing at
    SUB Y, 2

    CMP Y, heap    ; if Y is less than the heap starting point, this is not ours
    JC ___Free_done

    MOV C, [____heap_size]
    ADD C, heap     ; add heap address and ____heap_size to get to the end of the heap
    CMP C,Y        ; if Y is greater than the heap ending point, this is not ours
    JC  ___Free_done
    
    MOV [Y], 0        ; Unset the control word
    MOV A, 0            ; Set pointer to nil

___Free_done:
    POP Y
    POP C
    POP B
    POP BP
    RET
;_Free end

; A = realloc (void *ptr, int new_size)
;
;   MOV A, [ptr]        ; Push address of existing pointer
;   PUSH [new_size]     ; Push new size you want
;   CALL _Realloc
;
;   TEST A, A           ; if [A]  is zero, realloc has failed
;   JZ  failure         ; pointer is freed
_Realloc:
    PUSH BP
    MOV BP, SP
    PUSH B
    PUSH C

    CALL __InitializeAllocator

    MOV B, A        ; B is old pointer (at data section)

    ; alloc
    PUSH [BP+2]     ; alloc a new block of new_size
    CALL _Malloc    ; this puts the new pointer in A

    ; memcpy
                    ; A is already new pointer
                    ; B is already old pointer
    MOV C, [B-1]    ; Get the old pointer's range word
    CMP C, [A-1]    ; Check if old size is larger than new size
    JL ___Realloc_old_smaller
    MOV C, [A-1]    ; old size is currently in C, if new size is bigger use old size
___Realloc_old_smaller:
    SUB C, 2        ; account for allocated/range words
    CALL _Memcpy

    MOV C, A        ; C is the new pointer
    ; free
    MOV A, B        ; Free the old pointer
    CALL _Free

    MOV A,C         ; Return new pointer in A

    POP C
    POP B
    POP BP
    RET 1
;_Realloc end

; A = Calloc(int size)
; usage:
;
;   PUSH [size]     ; Push size to allocate
;   CALL _Calloc    ; A now points to first address of allocated memory
;
;   PUSH pointer
;   PUSH 1
;   CALL _Calloc
;
;   TEST A, A
;   JZ failure
;
;   TEST [A], [A]   ; the block will always be zero'd out
;   JNZ failure
;
;   MOV [A], 5
;
_Calloc:
    PUSH BP
    MOV BP, SP
    PUSH B
    PUSH C

    CALL __InitializeAllocator

    MOV C, [BP+2]   ; c is the size of our block

    PUSH C     ; push the size again for malloc
    CALL _Malloc

                    ; A is new pointer
    MOV B, 0        ; B is zero
                    ; C is our size
    CALL _Memset    ; Zero out the new block

    POP C
    POP B
    POP BP
    RET 1
;_Calloc end


; Combines empty blocks for found during malloc
__CombineEmptyBlocks:
    PUSH C
    PUSH D

    MOV C, A
    ADD C, [A+1]                ; we know current block is available, so move to next one

___CombineEmptyBlocks_loop:
    TEST [C], [C]               ; If the current control block is allocated, stop if so
    JNZ ___CombineEmptyBlocks_done

    TEST [C+1], [C+1]           ; Check if the current range word is zero
    JZ ___CombineEmptyBlocks_zero

    MOV D, C                    ; Hold on to current control word
    ADD D, [C+1]                ; Get to next control word

    ADD [A+1], [C+1]            ; Current block is free to add it's size onto A

    MOV [C+1], 0                ; Clear this block's size
    MOV C,D                     ; Move on to next control word
    JMP ___CombineEmptyBlocks_loop

___CombineEmptyBlocks_zero:
    SUB [____heap_size], [A+1]      ; We are at the end, this is no longer part of the heap
    MOV [A], 0                  ; If we came across a completely unset control bit
    MOV [A+1],0                 ; we must be at the end of the allocated section
___CombineEmptyBlocks_done:     ; of the heap
    POP D
    POP C
    RET
;__CombineEmptyBlocks end

; This MUST be called for heap to work
; All functions will attempt to call it to make sure
; It only needs to be called once
; Initialize allocator
; Set ____heap_total_available
__InitializeAllocator:
    TEST [____allocator_initialized], [____allocator_initialized]
    JNZ ___InitializeAllocator_done
    PUSH A
    MOV [____allocator_initialized], 1
    MOV A, HEAP_END_ADDR   ; last address heap can try to occupy
    SUB A, heap
    JC __InvalidHeap
    MOV [____heap_total_available], A
    POP A
___InitializeAllocator_done:
    RET
____heap_total_available: DW 0  ; This data is needed for the heap
____heap_size: DW 0             ; It will not work if removed
____allocator_initialized: DW 0 ; Make sure a user cannot run this multiple times
;__InitializeAllocator end

__InvalidHeap:
    MOV A, 2
    MOV X, ____InvalidHeap_holo_text
    HWI 0x0009
    MOV A, 3
    MOV X, ____InvalidHeap_text
    HWI 0x000D
    ADD X, 8
    HWI 0x000D
    ADD X, 8
    HWI 0x000D
    BRK
____InvalidHeap_text: DW "\nInvalid heap end", 7 DUP(0)
____InvalidHeap_holo_text: DW "Heap ERR",0
;__InvalidHeap end

;;;;; heap code end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;   MUST BE AT END OF FILE
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

heap: DW 0
