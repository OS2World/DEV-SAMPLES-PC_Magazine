         name      callprtf
         page      55,132
         title     'CALLPRTF --- MASM call to printf'
;
; CALLPRTF.ASM --- demonstrates call to printf 
;                  from a MASM application
;
; by Ray Duncan, November 1987

cr      equ     0dh             ; ASCII carriage return
lf      equ     0ah             ; ASCII line feed

        extrn   __acrtused:abs  ; drag in C startup code

DGROUP  group   _DATA


_TEXT   segment word public 'CODE'

        assume  cs:_TEXT,ds:DGROUP

        extrn   _printf:near    ; drag in printf from the
                                ; C library, and its
                                ; dependent routines

        public  _main
_main   proc    near            ; entered from C startup...

        mov     ax,DGROUP       ; make our data segment
        mov     ds,ax           ; addressable

                                ; push arguments for printf

        mov     ax,-1           ; integer: -1
        push    ax

                                ; address of message string
        mov     ax,offset DGROUP:msgstr
        push    ax

                                ; address of format string
        mov     ax,offset DGROUP:fmtstr
        push    ax

        call    _printf         ; call C library function

        add     sp,6            ; clean up stack

        mov     ax,4c00h        ; now exit with 
        int     21h             ; return code = 0

_main   endp

_TEXT   ends


_DATA   segment word public 'DATA'

msgstr  db      'The value of x is',0   ; message string

fmtstr  db      cr,lf,'%s %d',cr,lf,0   ; format string

_DATA   ends

        end     
