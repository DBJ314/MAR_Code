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