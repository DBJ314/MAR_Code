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