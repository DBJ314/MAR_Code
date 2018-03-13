TickCount: DW 0
;number of remaining allowed context switches. Probably just paranoia
RemainingCycleCount: DW 0
;keeps track of resources already claimed by tasks
HeldLocks: DW 0

;This is a task struct for a special task that is hardcoded to run first each tick.
;Becuase TSNextTask EQU 0, it is also the varible for the top task in the queue.
;The default entry point for this task just gives up control immediately.
;It is up to the cold boot task to set up this struct so it does useful stuff.
;This is done by setting the value of FirstTaskIP to a function.
;That function should call RLoopback instead of returning when it is finished.
FirstTask: DW ColdBootStruct
DW 0
FirstTaskIP: DW RLoopback
DW 0xFFFF,0xFFFF,0,0,0,0,0,0,0,0,0

;Current running task
CurTask: DW 0

;fake task structure used only during the first tick.
ColdBootStruct:
DW 0,0,ColdBoot,0xFFFF,0xFFFF,0,0,0,0,0,0,0,0,0

;register saves used by internal multitasking calls when it is unsafe to use the stack
SavedFT: DW 0
SavedCT: DW 0
TempIP: DW 0
TempA: DW 0
TempB: DW 0
TempC: DW 0