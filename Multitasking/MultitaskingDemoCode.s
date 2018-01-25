ColdBoot:
    MOV [FirstTask],0;ensure this task struct is not entered in the task queue
    PUSH 0
    PUSH MainTask
    CALL CreateTask;this function usually returns, but it doesn't when [FirstTask] was 0 at time of call
MainTask:
    PUSH BP
    MOV BP,SP
    SUB SP,1
;create counting task
    PUSH 0
    PUSH CountingTask
    CALL CreateTask
;start main loop
    PUSH 0; no locks required for this task
    CALL RBegin;set recursion point
;create task that moves north
    PUSH NORTH
    PUSH 1;pass 1 stack argument to new task
    PUSH MovingTask
    CALL CreateTask
;wait 2 ticks
    PUSH 2
    CALL Wait
;create task that locks counter
    PUSH 0
    PUSH ABCDTask
    CALL CreateTask
    MOV [BP-1],A;store created task structure
;wait 2 ticks
    PUSH 2
    CALL Wait
;create task that moves south
    PUSH SOUTH
    PUSH 1
    PUSH MovingTask
    CALL CreateTask
;wait 2 ticks
    PUSH 2
    CALL Wait
;delete abcd task
    PUSH [BP-1]
    CALL DestroyTask
;create task that moves east
    PUSH EAST
    PUSH 1
    PUSH MovingTask
    CALL CreateTask
;wait 2 ticks
    PUSH 2
    CALL Wait
;steamroll all leg using tasks
    PUSH LLegs
    CALL Steamroll
;wait a tick
    PUSH 1
    CALL Wait
;move back and forth
    CALL MoveBackAndForth
    JMP RLoopback

CountingTask:
    MOV C,[CurTask]
    ADD C,TSCycleCounter
    PUSH LDisplay
    CALL RBegin
    MOV B,[C];normal registers are preserved across recursion points
    CALL DisplayHex
    JMP RLoopback

MovingTask:
    PUSH BP
    MOV BP,SP
    PUSH LLegs;requires use of legs
    CALL RBegin
    MOV B,[BP+2];get stack argument
    CALL SetDirWalk
    JMP RLoopback

ABCDTask:
    MOV B,0xABCD
    PUSH LDisplay;requires use of display
    CALL RBegin
    CALL DisplayHex
    JMP RLoopback

MoveBackAndForth:
    PUSH LLegs
    CALL RBegin
    MOV B,EAST
    CALL SetDirWalk
    CALL RCheckpoint;set recursion point to here and continue next tick
    MOV B,WEST
    CALL SetDirWalk
    CALL RCheckpoint
    CALL REnd
    RET
    