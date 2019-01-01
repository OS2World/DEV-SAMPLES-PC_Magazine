;----------------------------------------------------------------------
; GETENV --- Return address and length of variable portion of environment
;            string OS/2 version using DosGetEnv
;
; Copyright (c) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
;
; Call with:    DS:SI = ASCIIZ env. variable name
; Returns:      ES:DI = address of env. variable
;               AX    = length (0 = not found)
; Uses:         nothing
;----------------------------------------------------------------------
        .286
        extrn   DosGetEnv:far   ; OS/2 API function

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT
                                ; local variables...
envseg  equ     [bp-2]          ; environment segment
cmdoffs equ     [bp-4]          ; command line offset   

        public  getenv          ; make visible to Linker

getenv  proc    near

        enter   4,0             ; allocate local variables
        push    cx              ; save registers
        push    si

        push    ss              ; get selector for environment 
        lea     ax,envseg       ; and offset of command line 
        push    ax
        push    ss
        lea     ax,cmdoffs
        push    ax
        call    DosGetEnv       ; transfer to OS/2      
        or      ax,ax           ; did function succeed?
        jz      get1            ; jump if successful

        xor     ax,ax           ; DosGetEnv failed, 
        jmp     get5            ; return AX = 0

get1:   mov     es,envseg       ; set ES:BX = command line
        mov     cx,8000h        ; assume max env. = 32 KB       
        xor     di,di           ; initial env. offset
        xor     ax,ax           ; default length result 

get2:   cmp     byte ptr es:[di],0 ; check for end of environment
        je      get5            ; end reached, return AX = 0

        pop     si              ; initialize address of target
        push    si              ; variable to be found

        repe cmpsb              ; compare target and env. strings
        cmp     byte ptr [si-1],0       
        jne     get3            ; jump if incomplete match
        cmp     byte ptr es:[di-1],'='
        je      get4            ; jump if match was complete

get3:   repne scasb             ; match incomplete, scan for end of env str
        jmp     get2            ; and try again to match

get4:   push    di              ; save address after = sign
        repne scasb             ; look for end of this string
        pop     ax              ; get back starting address 
        xchg    di,ax           ; find string length
        sub     ax,di
        dec     ax              ; don't include null byte

get5:   pop     si              ; common exit point restore registers
        pop     cx
        leave                   ; discard local variables
        ret                     ; return to caller

getenv  endp

_TEXT   ends
        end
