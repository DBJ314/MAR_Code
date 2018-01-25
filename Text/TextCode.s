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