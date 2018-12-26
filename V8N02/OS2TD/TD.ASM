;----------------------------------------------------------------------
; TD.ASM --- Time and Date Formatting Functions - OS/2 version
;
; Copyright (c) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
;
; This module contains six public routines:
;
; TCVT          convert time to ASCII
; DCVT          convert date to ASCII
;
; SYSTCVT       convert current time to ASCII
; SYSDCVT       convert current date to ASCII
;
; DIRTCVT       convert time in directory format to ASCII
; DIRDCVT       convert date in directory format to ASCII
;----------------------------------------------------------------------
        .286

        extrn   DosGetDateTime:far  ; OS/2 API functions
        extrn   DosGetCtryInfo:far

DGROUP  group   _DATA

_DATA   segment word public 'DATA'

dtinfo  label   byte            ; receives date/time info
hour    db      0
min     db      0
sec     db      0
csec    db      0               ; hundredths of secs.
day     db      0
month   db      0
year    dw      0
zone    dw      0               ; time zone
dow     db      0               ; day of week

ccode   dw      0               ; country code (0=default)
        dw      0               ; code page ID (0=default)

cbuff   db      38 dup (0)      ; receives country info
cb_len  equ     $-cbuff         ; length of buffer

cbytes  dw      ?               ; receives actual length of country info

dbuff   db      8  dup (' ')    ; date formatting buffer
tbuff   db      11 dup (' ')    ; time formatting buffer

doffs   dw      0               ; filled in by 'getctry': offset of ASCII day
moffs   dw      0               ; offset of ASCII month
yoffs   dw      0               ; offset of ASCII year
                                ; date format determined by DosGetCtryInfo
dtab    dw      mdy             ; 0 = USA format
        dw      dmy             ; 1 = Europe format
        dw      ymd             ; 2 = Japan format       

mdy     dw      dbuff+3         ; USA: month day year
        dw      dbuff
        dw      dbuff+6

dmy     dw      dbuff           ; Europe: day month year
        dw      dbuff+3
        dw      dbuff+6

ymd     dw      dbuff+6         ; Japan: year month day
        dw      dbuff+3
        dw      dbuff

_DATA   ends
;----------------------------------------------------------------------
_TEXT   segment word public 'CODE'
        assume  cs:_TEXT,ds:DGROUP

        public  dcvt            ; make routines available 
        public  tcvt            ; to Linker
        public  systcvt
        public  sysdcvt
        public  dirtcvt
        public  dirdcvt

; format system date, BX = length, DS:SI = buffer, preserves all registers
sysdcvt proc    near

        push    ax              ; save registers
        push    bx
        push    cx
        push    dx

        push    ds              ; get current date...receives date/time info
        push    offset DGROUP:dtinfo
        call    DosGetDateTime  ; transfer to OS/2

        mov     dh,month        ; load up registers     
        mov     dl,day          ; with day/month/year
        mov     cx,year

        call    dcvt            ; convert to ASCII

        pop     dx              ; restore registers
        pop     cx
        pop     bx
        pop     ax
        ret                     ; back to caller

sysdcvt endp
;----------------------------------------------------------------------
; format system time, BX = length, DS:SI = buffer, preserves all registers
systcvt proc    near

        push    ax              ; save registers
        push    bx
        push    cx
        push    dx

        push    ds              ; get current time...receives date/time info
        push    offset DGROUP:dtinfo
        call    DosGetDateTime  ; transfer to OS/2

        mov     ch,hour         ; load up registers
        mov     cl,min          ; with hour/min/sec/csec
        mov     dh,sec
        mov     dl,csec

        call    tcvt            ; convert to ASCII

        pop     dx              ; restore registers
        pop     cx
        pop     bx
        pop     ax
        ret                     ; back to caller

systcvt endp
;----------------------------------------------------------------------
; format directory date, AX=directory date, BX=length, DS:SI=buffer
dirdcvt proc    near                      ; preserves all registers

        push    ax              ; save registers
        push    bx
        push    cx
        push    dx
        
        mov     dx,ax           ; isolate months & days
        and     dx,01ffh
        shl     dx,3            ; position month
        shr     dl,3            ; position day

        shr     ax,9            ; position year
        add     ax,1980
        mov     cx,ax

        call    dcvt            ; convert to ASCII

        pop     dx              ; restore registers
        pop     cx
        pop     bx
        pop     ax
        ret                     ; back to caller

dirdcvt endp
;----------------------------------------------------------------------
; format directory time, AX=directory time, BX=length, DS:SI=buffer
dirtcvt proc    near                      ; preserves all registers

        push    ax              ; save registers
        push    bx
        push    cx
        push    dx
        
        mov     dx,ax           ; isolate seconds field
        and     dx,1fh          ; and position it
        shl     dx,9            ; (includes seconds*2)

        shr     ax,3            ; position hours

        shr     al,2            ; position minutes
        mov     cx,ax

        call    tcvt            ; convert to ASCII

        pop     dx              ; restore registers
        pop     cx
        pop     bx
        pop     ax
        ret                     ; back to caller

dirtcvt endp
;----------------------------------------------------------------------
; format ASCII date, BX=length, CX=year (1980+), DH=month (1-12)
; DL=day (1-31), DS:SI=buffer, length clamped to 8, destroys AX BX CX DX
dcvt    proc    near

        cmp     bx,8            ; make sure length OK
        jle     dcvt1
        mov     bx,8            ; too long, use 8 max

dcvt1:  push    es              ; save registers
        push    di
        push    si
        push    bx

        call    getctry         ; get country info

        mov     si,moffs        ; convert month
        mov     al,dh
        call    b2dec   

        mov     si,doffs        ; convert day
        mov     al,dl
        call    b2dec

        mov     si,yoffs        ; convert year, 
        sub     cx,1900         ; corrected to 80-99
        mov     al,cl
        call    b2dec

        mov     ax,ds           ; transfer ASCII date
        mov     es,ax           ; to caller's buffer
        mov     si,offset DGROUP:dbuff
        pop     cx              ; buffer length
        pop     di              ; buffer address
        push    di
        rep movsb               ; copy string

        pop     si              ; restore registers     
        pop     di
        pop     es
        ret                     ; return to caller

dcvt    endp
;----------------------------------------------------------------------
; format ASCII time, BX=length, CH=hour, CL=minute, DH=second
; DL=hundredths, DS:SI=buffer, length clamped to 11, destroys AX BX CX DX
tcvt    proc    near

        cmp     bx,11           ; make sure length OK
        jle     tcvt1
        mov     bx,11           ; too long, use 11 max

tcvt1:  push    es              ; save registers
        push    di
        push    si
        push    bx

        call    getctry         ; get country info

        mov     al,ch           ; convert hours
        mov     si,offset DGROUP:tbuff
        call    b2dec

        mov     al,cl           ; convert minutes
        add     si,3
        call    b2dec

        mov     al,dh           ; convert seconds
        add     si,3
        call    b2dec

        mov     al,dl           ; convert hundredths
        add     si,3
        call    b2dec

        mov     ax,ds           ; transfer ASCII time
        mov     es,ax           ; to caller's buffer
        mov     si,offset DGROUP:tbuff
        pop     cx              ; buffer length
        pop     di              ; buffer address
        push    di
        rep movsb               ; copy string

        pop     si              ; restore registers     
        pop     di
        pop     es
        ret                     ; return to caller

tcvt    endp
;----------------------------------------------------------------------
; convert binary 0-99 to two ASCII digits.
; AL=value, DS:SI=storage address, destroys AX 
b2dec   proc    near

        aam                     ; divide AL by 10 -> AH = quot., AL = rem.
        add     ax,'00'         ; convert to ASCII
        xchg    ah,al
        mov     [si],ax         ; and store digits
        ret                     ; back to caller

b2dec   endp
;----------------------------------------------------------------------
getctry proc    near            ; get country information

        test    doffs,-1        ; did we already get info?
        jnz     getc3           ; if we did, just exit

        push    ax              ; save registers
        push    bx
        
                                ; get country info...
        push    cb_len          ; length of buffer
        push    ds              ; country code address
        push    offset DGROUP:ccode
        push    ds              ; receives country info
        push    offset DGROUP:cbuff
        push    ds              ; receives length of info
        push    offset DGROUP:cbytes
        call    DosGetCtryInfo  ; transfer to OS/2
        or      ax,ax           ; function successful?
        jz      getc1           ; jump, got country info

                                ; no, use USA defaults
        mov     al,'.'          ; decimal separator
        mov     bl,':'          ; time separator
        mov     bh,'-'          ; date separator
        jmp     getc2

getc1:  mov     al,cbuff+0dh    ; get decimal separator
        mov     bl,cbuff+11h    ; get time separator
        mov     bh,cbuff+0fh    ; get date separator

getc2:  mov     tbuff+8,al      ; store decimal separator 

        mov     tbuff+2,bl      ; store time separator
        mov     tbuff+5,bl

        mov     dbuff+2,bh      ; store date separator
        mov     dbuff+5,bh

                                
        mov     bx,word ptr cbuff+4 ; set date field offsets using cntry info
        shl     bx,1            ; date code*2=dtab index
        mov     bx,[bx+dtab]
        mov     ax,[bx]         ; offset for ASCII day
        mov     doffs,ax
        mov     ax,[bx+2]       ; offset for ASCII month
        mov     moffs,ax
        mov     ax,[bx+4]       ; offset for ASCII year
        mov     yoffs,ax

        pop     bx              ; restore registers
        pop     ax
getc3:  ret                     ; back to caller

getctry endp

_TEXT   ends
        end
