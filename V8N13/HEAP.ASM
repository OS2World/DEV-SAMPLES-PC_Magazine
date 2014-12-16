        title   HEAP.ASM  Simple MASM Heap manager
        page    55,132

; HEAP.ASM --- Simple Heap Manager for MASM Programs
; Copyright (C) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; To trade safety for speed, change the CHKPTRS equate.
;
; The routines in this module all assume that the 
; CPU direction flag is clear!!

true    equ     -1
false   equ     0

chkptrs equ     true                    ; if true, HREALLOC and 
                                        ; HFREE check all pointers

DGROUP  group   _DATA

_DATA   segment word public 'DATA'

hbase   dw      0                       ; base address of heap
hsize   dw      0                       ; size of heap

_DATA   ends


_TEXT   segment word public 'CODE'

        assume  cs:_TEXT,ds:DGROUP

;
; HINIT:        initialize local heap
; 
; Call with:    AX      = size in bytes
;               DS:BX   = address of heap base
;
; Returns:      If function successful,
;               Carry   = clear
;
;               If function failed
;               Carry   = set
;
        public  hinit
hinit   proc    near

        cmp     ax,2                    ; check heap size
        jbe     hinit1                  ; too small, return error
        cmp     ax,32768
        jae     hinit1                  ; too big, return error

        push    ax                      ; save registers
        push    bx

        mov     hsize,ax                ; save heap size
        mov     hbase,bx                ; save heap base address
        sub     ax,2                    ; create header for block
        mov     [bx],ax                 ; containing all free space
        inc     ax
        add     bx,ax                   ; set Carry if segment wrap

        pop     bx                      ; restore registers     
        pop     ax
        ret                             ; return to caller

hinit1: stc                             ; bad parameter,
        ret                             ; return Carry = set

hinit   endp

;
; HALLOC:       allocate block from local heap
;
; Call with:    AX      = requested block size
;
; Returns:      If function successful
;               Carry   = clear
;               DS:BX   = address of allocated block
;
;               If function unsuccessful
;               Carry   = set
;
        public  halloc
halloc  proc    near

        call    hfind                   ; try and allocate block
        jnc     hal1                    ; jump if block was found

        call    hcoal                   ; coalesce free blocks
        call    hfind                   ; try again to allocate

hal1:   ret                             ; return to caller

halloc  endp

;
; HREALLOC:     resize previously allocated block
;
; Call with:    AX      = new requested block size
;               DS:BX   = address of existing block
;
; Returns:      If function successful
;               Carry   = clear
;               DS:BX   = address of resized block
;
;               If function unsuccessful
;               Carry   = set
;
        public  hrealloc
hrealloc proc   near

        push    ax                      ; save registers
        push    cx
        push    si
        push    di
        push    es

        if      chkptrs
        call    hvalid                  ; check if valid pointer
        jnc     hreal1                  ; pointer is OK
        jmp     hreal6                  ; bad pointer, exit
        endif

hreal1: mov     cx,ax                   ; save new requested size
        mov     si,bx                   ; save block base address
        mov     di,hbase                ; get address of heap end
        add     di,hsize

        mov     ax,[si-2]               ; get current block size
        and     ax,7fffh                ; remove in-use bit
        cmp     cx,ax                   ; is block growing?
        ja      hreal2                  ; yes, jump
        je      hreal5                  ; no size change, exit

        sub     ax,cx                   ; block shrinking, find excess
        cmp     ax,2                    ; enough for another header?
        jb      hreal5                  ; no, leave block alone

        mov     [si-2],cx               ; shrink existing block
        or      word ptr [si-2],8000h   ; and set in-use bit
        add     si,cx                   ; create new block to hold
        sub     ax,2                    ; the excess memory
        mov     [si],ax
        jmp     hreal5                  ; now exit

hreal2: call    hcoal                   ; coalesce free blocks

        add     si,ax                   ; get addr. of next block
        cmp     si,di                   ; reached end of heap?
        je      hreal4                  ; yes, jump

        test    word ptr [si],8000h     ; next block free?
        jnz     hreal4                  ; no, must try elsewhere
        add     ax,[si]                 ; yes, are combined blocks
        add     ax,2                    ; large enough?
        cmp     cx,ax
        ja      hreal4                  ; no, jump

        mov     [bx-2],cx               ; update block header and
        or      word ptr [bx-2],8000h   ; set in-use flag

        sub     ax,cx                   ; find excess memory
        cmp     ax,2                    ; large enough for header?
        jb      hreal3                  ; no, jump

        mov     si,bx                   ; create header for block
        add     si,cx                   ; containing excess memory
        sub     ax,2
        mov     [si],ax
        jmp     hreal5                  ; now exit

hreal3: add     ax,cx                   ; excess is 0 or 1 bytes,
        mov     [bx-2],ax               ; fold it into the block
        or      word ptr [bx-2],8000h
        jmp     hreal5                  ; now exit

hreal4: mov     ax,cx                   ; look elsewhere for
        mov     si,bx                   ; sufficiently large block
        call    hfind
        jc      hreal6                  ; none available, exit

        and     word ptr [si-2],7fffh   ; mark old block available
        mov     cx,[si-2]               ; get its length for move
        mov     di,bx                   ; copy old block to new
        push    ds
        pop     es
        rep movsb

hreal5: clc                             ; successful reallocation,
                                        ; return Carry = clear

hreal6: pop     es                      ; restore registers
        pop     di
        pop     si
        pop     cx
        pop     ax
        ret                             ; return to caller

hrealloc endp

;
; HFREE:        release heap block
; 
; Call with:    DS:BX   = block pointer
;
; Returns:      If CHKPTRS is FALSE
;               Nothing
;
;               If CHKPTRS is TRUE and pointer valid
;               Carry   = clear
;
;               If CHKPTRS is TRUE and pointer invalid
;               Carry   = set
;
        public  hfree
hfree   proc    near

        if      chkptrs
        call    hvalid                  ; check if valid pointer
        jc      hfree1                  ; jump if bad pointer
        endif

        and     word ptr [bx-2],07fffh  ; turn off in-use flag
hfree1: ret                             ; back to caller

hfree   endp

;
; HFIND:        private subroutine for HALLOC and HREALLOC,
;               finds a free block in heap
;
; Call with:    AX      = requested block size
;
; Returns:      If function successful
;               Carry   = clear
;               DS:BX   = address of allocated block
;
;               If function unsuccessful
;               Carry   = set
;               
hfind   proc    near

        push    ax                      ; save registers
        push    cx
        push    si
        push    di

        mov     cx,ax                   ; save requested block size
        mov     si,hbase                ; get heap base address
        mov     di,si
        add     di,hsize                ; get address of heap end
        
hfind1: lodsw                           ; pick up next block header
        or      ax,ax                   ; this block free?
        js      hfind2                  ; not free if bit 15 set, jump
        cmp     ax,cx                   ; block free, large enough?
        jae     hfind4                  ; size is adequate, jump

hfind2: and     ax,07fffh               ; go to next block
        add     si,ax
        cmp     si,di                   ; end of heap reached?
        jne     hfind1                  ; not yet, try next block

hfind3: stc                             ; couldn't allocate block,
        jmp     hfind7                  ; return Carry = set

hfind4: mov     bx,si                   ; save block base in BX
        je      hfind6                  ; jump if exactly right size

        sub     ax,cx                   ; find excess amount
        cmp     ax,2                    ; enough for another header?
        jae     hfind5                  ; yes, jump

        add     ax,cx                   ; no, skip this block
        jmp     hfind2

hfind5: add     si,cx                   ; subdivide existing block
        sub     ax,2                    ; create header for free block
        mov     [si],ax                 ; containing excess memory
        
hfind6: or      cx,8000h                ; set block size and in-use
        mov     [bx-2],cx               ; flag, also clear Carry

hfind7: pop     di                      ; restore registers
        pop     si
        pop     cx
        pop     ax                       
        ret                             ; return to caller 

hfind   endp

;
; HCOAL:        private subroutine for HALLOC and HREALLOC,
;               coalesces adjacent free blocks in heap
;
; Call with:    nothing
;
; Returns:      nothing
;
hcoal   proc    near

        push    ax                      ; save registers
        push    bx
        push    si
        push    di

        mov     bx,hbase                ; get heap base address
        mov     di,bx
        add     di,hsize                ; get heap end address
        
hcoal1: mov     si,bx                   ; point to block header

hcoal2: lodsw                           ; get length from header
        mov     bx,ax                   ; calc. address of next block
        and     bx,7fffh
        add     bx,si
        cmp     bx,di                   ; end of heap reached?
        je      hcoal3                  ; yes, exit

        or      ax,ax                   ; not last block, is it free?
        js      hcoal1                  ; not free if bit 15 set, jump

        test    word ptr [bx],8000h     ; next block free also?
        jnz     hcoal1                  ; no, jump

        add     ax,[bx]                 ; merge two blocks together
        add     ax,2
        sub     si,2
        mov     [si],ax                 ; update header of 1st block
        jmp     hcoal2                  ; try for another merge

hcoal3: pop     di                      ; restore registers
        pop     si
        pop     bx
        pop     ax
        ret                             ; return to caller

hcoal   endp

        if      chkptrs
;
; HVALID:       tests whether a heap pointer is valid
;
; Call with:    DS:BX   = questionable pointer to block
;
; Returns:      If pointer is valid
;               Carry   = clear
;
;               If pointer is invalid
;               Carry   = set
;               
        public  hvalid
hvalid  proc    near

        push    ax                      ; save registers
        push    si
        push    di

        test    word ptr [bx-2],8000h   ; make sure already allocated
        je      hval2                   ; no, pointer invalid

        mov     si,hbase                ; get heap base address
        mov     di,si
        add     di,hsize                ; get heap end address

hval1:  lodsw                           ; get length of this block
        cmp     si,bx                   ; do pointers match?
        je      hval3                   ; yes, jump (carry is clear)
        and     ax,7fffh                ; strip in-use bit and
        add     si,ax                   ; advance to next block
        cmp     si,di                   ; end of heap?
        jne     hval1                   ; no, try again
hval2:  stc                             ; end of heap, pointer invalid

hval3:  pop     di                      ; restore registers
        pop     si
        pop     ax
        ret                             ; return to caller

hvalid  endp
        endif

_TEXT   ends

        end


