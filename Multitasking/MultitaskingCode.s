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