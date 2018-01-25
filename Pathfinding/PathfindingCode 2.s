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
    MOV A,X
    SUB A,[BP+3]
    CMP A,0
    JL MGEast
    JG MGWest
MoveGlobalSecondTry:
    MOV A,Y
    SUB A,[BP+2]
    CMP A,0
    JL MGSouth
    JG MGNorth
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