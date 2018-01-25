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