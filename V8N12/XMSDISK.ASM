        title   XMSDISK XMS-aware RAMdisk
        page    55,132

; XMSDISK.ASM --- XMS-aware RAMdisk device driver
; Copyright (C) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
; Also requires ITOA.ASM and ATOI.ASM.
;
; To build:     MASM XMSDISK;
;               MASM ATOI;
;               MASM ITOA;
;               LINK XMSDISK+ATOI+ITOA;
;               EXE2BIN XMSDISK.EXE XMSDISK.BIN
;               DEL XMSDISK.EXE
;
; To install:   copy XMSDISK.SYS to the boot disk, add
;
;                       DEVICE=XMSDISK.BIN  nnnK
; 
;               to the CONFIG.SYS file.  This must follow
;               the DEVICE= line that loads the XMM (usually
;               HIMEM.SYS).  The parameter nnn is the desired
;               RAMdisk size in KB.  If nnn is missing or zero,
;               all available extended memory is used.
;
_TEXT   segment public 'CODE'

        extrn   atoi:near
        extrn   itoa:near

        assume  cs:_TEXT,ds:_TEXT,es:NOTHING

        org     0

maxcmd  equ     24                      ; maximum driver command code

cr      equ     0dh                     ; ASCII carriage return
lf      equ     0ah                     ; ASCII line feed
blank   equ     020h                    ; ASCII space code
eom     equ     '$'                     ; end of message indicator

secsize equ     512                     ; bytes per sector (IBM standard)
dirsize equ     256                     ; entries in root directory             

request struc                           ; request packet template
len     db      ?                       ; length of request packet
unit    db      ?                       ; unit number for this request
command db      ?                       ; request packet's command code
status  dw      ?                       ; status returned by driver
        db      8 dup (?)               ; reserved area
media   db      ?                       ; media descriptor byte
address dd      ?                       ; memory address for transfer
count   dw      ?                       ; byte/sector count value
sector  dw      ?                       ; starting sector value
request ends                            ; end of request packet template

header  equ     $                       ; device driver header
        dd      -1                      ; link to next driver 
        dw      0                       ; device attribute word
        dw      strat                   ; device "Strategy" entry point
        dw      intr                    ; device "Interrupt" entry point
        db      1                       ; number of units, this device
        db      7 dup (0)               ; reserved (block drivers)

rqptr   dd      ?                       ; far pointer to request packet
savesp  dw      0                       ; save kernel SS:SP during switch
savess  dw      0                       ; to driver's private stack
xmm     dd      0                       ; address of XMM entry point
handle  dw      0                       ; handle for extended memory block
total   dw      0                       ; total extended mem available (KB)
largest dw      0                       ; largest free block available (KB)
alloc   dw      0                       ; extended memory allocated (KB)
clust   dw      0                       ; total clusters in RAMdisk
xfersec dw      0                       ; current sector for transfer
xfercnt dw      0                       ; sectors successfully transferred
xferreq dw      0                       ; number of sectors requested   

array   dw      bpb                     ; array of pointers to BPBs
                                        ; for each logical unit

movpars equ     $                       ; XMS Function 0BH parameter block 
movelen dd      0                       ; length to move in bytes
shandle dw      0                       ; source handle
soffset dd      0                       ; source offset or far pointer
dhandle dw      0                       ; destination handle
doffset dd      0                       ; destination offset or far pointer

bootrec equ     $                       ; boot record for logical sec. 0
        jmp     $                       ; phony JMP at start of boot
        nop                             ; sector (must be 3 bytes)
        db      'IBM  3.3'              ; OEM identity field
                                        ; BIOS Parameter Block (BPB)
bpb     dw      secsize                 ; 0   bytes per sector
        db      2                       ; 2   sectors per cluster
        dw      1                       ; 3   reserved sectors
        db      1                       ; 5   number of FATs
        dw      dirsize                 ; 6   root directory entries
        dw      0                       ; 8   total sectors
        db      0f8h                    ; 0AH medium descriptor byte
        dw      0                       ; 0BH sectors per FAT
bootrec_len equ $-bootrec               ; length of boot record

        even                            ; force word alignment
        dw      128 dup (0)
stk     equ     $                       ; local stack for driver

;
; Driver 'strategy' routine; called by MS-DOS kernel with
; ES:BX pointing to driver request packet.
;
strat   proc    far                     ; driver 'strategy' routine

        mov     word ptr cs:rqptr,bx    ; save request packet address
        mov     word ptr cs:rqptr+2,es
        ret                             ; back to MS-DOS kernel

strat   endp

;
; Driver 'interrupt' routine, called by MS-DOS kernel immediately
; after call to 'strategy' routine to process I/O request.
;
intr    proc    far                     

        push    ax                      ; save all registers
        push    bx
        push    cx
        push    dx
        push    ds
        push    es
        push    di
        push    si
        push    bp

        mov     ax,cs                   ; make local data addressable
        mov     ds,ax
        mov     savess,ss               ; save DOS kernel's stack
        mov     savesp,sp
        mov     ss,ax                   ; set SS:SP to point to 
        mov     sp,offset stk           ; (larger) local stack

        les     di,rqptr                ; ES:DI = request packet
        mov     bl,es:[di.command]      ; get BX = command code
        xor     bh,bh
        cmp     bx,maxcmd               ; make sure it's legal
        jle     intr1                   ; jump, function code is ok
        mov     ax,8003h                ; return 'unknown command' error
        jmp     intr2

intr1:  shl     bx,1                    ; branch to command code routine
        call    word ptr [bx+dispch]    ; must return AX = status
        les     di,rqptr                ; ES:DI = request packet again

intr2:  or      ax,0100h                ; merge 'done' bit into status
        mov     es:[di.status],ax       ; store into request packet

        mov     ss,savess               ; restore DOS kernel's stack
        mov     sp,savesp

        pop     bp                      ; restore general registers
        pop     si
        pop     di
        pop     es
        pop     ds
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret                             ; back to kernel

intr    endp

;
; Dispatch table for driver commands
;
dispch  dw      init                    ;  0 = initialize driver
        dw      medchk                  ;  1 = media check on block device
        dw      bldbpb                  ;  2 = build BIOS parameter block
        dw      error                   ;  3 = I/O control read 
        dw      read                    ;  4 = read from device
        dw      error                   ;  5 = non-destructive read 
        dw      error                   ;  6 = return current input status
        dw      error                   ;  7 = flush device input buffers
        dw      write                   ;  8 = write to device
        dw      write                   ;  9 = write with verify
        dw      error                   ; 10 = return current output status
        dw      error                   ; 11 = flush output buffers
        dw      error                   ; 12 = I/O control write 
        dw      error                   ; 13 = device open        (DOS 3.0+)
        dw      error                   ; 14 = device close       (DOS 3.0+)
        dw      error                   ; 15 = removeable media   (DOS 3.0+)
        dw      error                   ; 16 = output until busy  (DOS 3.0+)   
        dw      error                   ; 17 = not used
        dw      error                   ; 18 = not used
        dw      error                   ; 19 = generic IOCTL      (DOS 3.2+) 
        dw      error                   ; 20 = not used
        dw      error                   ; 21 = not used
        dw      error                   ; 22 = not used
        dw      error                   ; 23 = get logical device (DOS 3.2+)
        dw      error                   ; 24 = set logical device (DOS 3.2+)

;
; Media Check routine (command code 1).  Returns code indicating
; whether medium has been changed since last access.
;
medchk  proc    near

        mov     byte ptr es:[di+14],1   ; return "not changed" code
        xor     ax,ax                   ; return success status
        ret

medchk  endp

;
; Build BPB routine (command code 2).  Returns pointer to valid
; BIOS Parameter Block for logical drive.
;
bldbpb  proc    near

        mov     word ptr es:[di+20],cs  ; put BPB address in packet
        mov     word ptr es:[di+18],offset bpb
        xor     ax,ax                   ; return success status
        ret

bldbpb  endp

;
; Read routine (command code 4).  Transfers logical sector(s)
; from RAMdisk storage to specified address.
;
read    proc    near

        mov     ax,es:[di.sector]       ; ES:DI = request packet
        mov     xfersec,ax              ; save starting sector number
        mov     ax,es:[di.count]        
        mov     xferreq,ax              ; save sectors requested
        mov     xfercnt,0               ; init sectors transferred count
        mov     ax,word ptr es:[di.address]
        mov     word ptr doffset,ax     ; requestor's buffer address
        mov     ax,word ptr es:[di.address+2]
        mov     word ptr doffset+2,ax
        mov     ax,handle               ; source handle = extended
        mov     shandle,ax              ;                 memory handle
        mov     dhandle,0               ; destination handle = 0
        mov     word ptr movelen,secsize; logical sector length

read1:  mov     ax,xfercnt              ; done with all sectors yet?
        cmp     ax,xferreq
        je      read2                   ; jump if transfer completed

        mov     ax,xfersec              ; source offset = 
        mul     bpb                     ; sector no. * bytes/sector
        mov     word ptr soffset,ax
        mov     word ptr soffset+2,dx

        mov     ah,0bh                  ; move this sector from
        mov     si,offset movpars       ; extended memory to requestor
        call    xmm
        or      ax,ax                   ; any error?
        jz      read4                   ; yes, abort transfer

        inc     xfersec                 ; advance sector and address
        add     word ptr doffset+2,(secsize/16)
        inc     xfercnt                 ; count sectors transferred
        jmp     read1

read2:                                  ; all sectors transferred,
        xor     ax,ax                   ; return success status

read3:  les     di,rqptr                ; get address of request packet
        mov     bx,xfercnt              ; return sectors transferred count
        mov     es:[di.count],bx
        ret

read4:  mov     ax,800bh                ; XMM error, return 'read fault'
        jmp     read3

read    endp

;
; Write (command code 8) and Write with Verify (command code 9)
; routine.  Transfers logical sector(s) from specified address
; to RAMdisk storage.
;
write   proc    near

        mov     ax,es:[di.sector]       ; ES:DI = request packet
        mov     xfersec,ax              ; save starting sector number
        mov     ax,es:[di.count]        
        mov     xferreq,ax              ; save sectors requested
        mov     xfercnt,0               ; init sectors transferred count
        mov     ax,word ptr es:[di.address]     
        mov     word ptr soffset,ax     ; requestor's buffer address
        mov     ax,word ptr es:[di.address+2]
        mov     word ptr soffset+2,ax
        mov     ax,handle               ; destination handle = extended
        mov     dhandle,ax              ;                   memory handle
        mov     shandle,0               ; zero out source handle
        mov     word ptr movelen,secsize; logical sector length

write1: mov     ax,xfercnt              ; done with all sectors yet?
        cmp     ax,xferreq
        je      write2                  ; jump if transfer completed

        mov     ax,xfersec              ; destination offset = 
        mul     bpb                     ; sector no. * bytes/sector
        mov     word ptr doffset,ax
        mov     word ptr doffset+2,dx

        mov     ah,0bh                  ; move this sector from
        mov     si,offset movpars       ; requestor to extended memory
        call    xmm
        or      ax,ax                   ; any error?
        jz      write4                  ; yes, abort transfer

        inc     xfersec                 ; advance sector and address
        add     word ptr soffset+2,(secsize/16)
        inc     xfercnt                 ; count sectors transferred
        jmp     write1

write2:                                 ; all sectors successfully
        xor     ax,ax                   ; transferred, return ok status

write3:
        les     di,rqptr                ; get address of request packet
        mov     bx,xfercnt              ; return actual transfer count
        mov     es:[di.count],bx
        ret

write4: mov     ax,800ah                ; XMM error, return 'write fault'
        jmp     write3          

write   endp

;
; Dummy routine for unsupported driver command codes
;
error   proc    near

        mov     ax,8103h                ; return 'unknown command' error
        ret

error   endp

;
; Initialization routine, called at driver load time.  Returns
; address of 'init' label to MS-DOS as start of free memory, so
; that memory occupied by 'init' and its subroutines is reclaimed.
;
init    proc    near                    ; command code 0 = initialize

        mov     ax,4300h                ; check if XMM present
        int     2fh
        cmp     al,80h                  ; status = installed?
        je      init1                   ; yes, proceed
        mov     dx,offset msg1          ; no, display error message
        jmp     init8                   ; and abort installation

init1:  mov     ax,4310h                ; XMM available, request entry
        int     2fh                     ; point and save it
        mov     word ptr xmm,bx
        mov     word ptr xmm+2,es

        mov     ah,8                    ; get available extended memory
        call    xmm                     ; transfer to XMM
        mov     total,dx                ; save total KB available
        mov     largest,ax              ; save largest free block
        cmp     largest,64              ; at least 64 KB available?
        jae     init2                   ; yes, proceed
        mov     dx,offset msg2          ; no, display error message
        jmp     init8                   ; and abort installation

init2:  les     di,rqptr                ; let ES:DI = request packet
        lds     si,es:[di+18]           ; point to CONFIG.SYS line

init3:  lodsb                           ; scan for end of driver name
        cmp     al,blank
        ja      init3                   ; loop while within name
        dec     si                      ; point to delimiter and
        call    atoi                    ; convert size parameter
        push    cs                      ; make our data addressable
        pop     ds
        or      ax,ax                   ; size parameter missing?
        jz      init4                   ; yes, use all extended memory
        cmp     ax,largest              ; requested > available?
        jna     init5                   ; no, jump

init4:  mov     ax,largest              ; use all of available memory

init5:  mov     alloc,ax                ; save requested size
        mov     dx,ax                   ; DX = RAMdisk size in KB
        mov     ah,9                    ; XMS function 9 = allocate
        call    xmm                     ; transfer to XMM
        or      ax,ax                   ; allocation successful?
        jnz     init6                   ; yes, proceed
        mov     dx,offset msg3          ; no, display error message
        jmp     init8                   ; and abort installation

init6:  mov     handle,dx               ; save extended memory handle
        call    makebpb                 ; set up Bios Parameter Block
        call    format                  ; format the RAMdisk
        jnc     init7                   ; jump if no error during format
        mov     dx,offset msg4          ; formatting error, exit
        jmp     init8

init7:  les     di,rqptr                ; let ES:DI = request packet
        mov     al,es:[di+22]           ; get drive code from header,
        add     al,'A'                  ; convert to ASCII for output
        mov     ident1,al
        mov     ax,total                ; convert KB available to ASCII
        mov     si,offset ident2
        mov     cx,10
        call    itoa
        mov     ax,largest              ; convert KB largest free block
        mov     si,offset ident3
        call    itoa
        mov     ax,alloc                ; convert KB allocated to ASCII
        mov     si,offset ident4
        call    itoa

        mov     dx,offset ident         ; display sign-on message
        mov     ah,9                    ; function 9 = display string
        int     21h                     ; transfer to MS-DOS    

                                        ; set top of driver address
        mov     word ptr es:[di.address],offset init
        mov     word ptr es:[di.address+2],cs
        mov     byte ptr es:[di+13],1   ; indicate 1 logical unit
        mov     word ptr es:[di+20],cs  ; return address of BPB array
        mov     word ptr es:[di+18],offset array
        jmp     init9

init8:                                  ; XMSDISK initialization failed
        push    dx                      ; save specific error message
        mov     dx,offset errmsg        ; display error heading
        mov     ah,9                    ; function 9 = display string
        int     21h                     ; transfer to MS-DOS
        pop     dx                      ; display error description
        mov     ah,9                    ; function 9 = display string
        int     21h                     ; transfer to MS-DOS

        les     di,cs:rqptr             ; let ES:DI=request packet
                                        ; set driver end = driver start
        mov     word ptr es:[di.address],0
        mov     word ptr es:[di.address+2],cs
        mov     byte ptr es:[di+13],0   ; set no. of logical units = 0

init9:  xor     ax,ax                   ; return success status 
        ret

init    endp

;
; Set up total sectors and sectors per FAT fields of BIOS Parameter
; Block according to size of RAMdisk.  Calculate and save total
; clusters (indicates whether 12-bit or 16-bit FAT will be used).
;
makebpb proc    near
        
        mov     ax,alloc                ; get size of allocated block
        mov     dx,1024                 ; convert KB to bytes
        mul     dx                      ; divided by bytes/sector
        div     word ptr bpb            ; gives AX = total sectors
        mov     bpb+8,ax                ; update BPB with total sectors
        xor     dx,dx                   ; sectors / (sectors/cluster)
        xor     ch,ch                   ; = total clusters
        mov     cl,byte ptr bpb+2
        div     cx
        mov     clust,ax                ; save total clusters   
        cmp     ax,4086                 ; clusters < 4087?
        jna     makeb1                  ; yes, jump 
        shl     ax,1                    ; no, assume 16-bit FAT
        jmp     makeb2                  ; clusters * 2 = bytes/FAT

makeb1: mov     dx,ax                   ; if clusters < 4087, 12-bit FAT
        add     ax,ax                   ; clusters * 1.5 = bytes/FAT
        add     ax,dx
        shr     ax,1
        jnc     makeb2
        inc     ax                      ; round bytes up if necessary

makeb2: xor     dx,dx                   ; (bytes/FAT) / (bytes/sec)
        div     word ptr bpb            ; = sectors/FAT
        or      dx,dx                   ; any remainder?
        jz      makeb3                  ; no,jump
        inc     ax                      ; round up to next sector

makeb3: mov     bpb+0bh,ax              ; update FAT size in BPB
        ret

makebpb endp

;
; Format RAMdisk.  First write zeros into all sectors of reserved
; area, FAT, and root directory.  Then copy phony boot record to
; boot sector, initialize medium ID byte at beginning of FAT, and
; place phony volume label in first sector of root directory.
;
format  proc    near            

        push    ds                      ; initialize sector buffer
        pop     es                      ; to zeros so we can clear
        mov     di,offset secbuf        ; out reserved area, FAT,
        mov     cx,secsize              ; and root directory
        xor     al,al
        rep stosb

        mov     ax,bpb+6                ; no. of directory entries
        mov     cx,32                   ; * (32 bytes/entry)
        mul     cx                      ; = bytes in root directory
        div     bpb                     ; / (bytes/sector)
        or      dx,dx                   ; = sectors in root directory
        jz      fmt1
        inc     ax                      ; round up any partial sector

fmt1:   add     ax,bpb+3                ; + reserved sectors
        add     ax,bpb+0bh              ; + sectors in FAT
        mov     xferreq,ax              ; = total sectors to clear
        mov     xfercnt,0               ; initialize sector counter

                                        ; set up move parameter block
        mov     word ptr movelen,secsize; length to move
        mov     shandle,0               ; source handle and address
        mov     word ptr soffset,offset secbuf
        mov     word ptr soffset+2,cs
        mov     ax,handle               ; destination extended memory
        mov     dhandle,ax              ; block handle
        mov     word ptr doffset,0      ; initial destination offset
        mov     word ptr doffset+2,0

fmt2:   mov     ah,0bh                  ; write this sector
        mov     si,offset movpars       ; DS:SI = parameter block
        call    xmm                     ; transfer to XMM
        or      ax,ax                   ; test move status
        jnz     fmt3
        jmp     fmt5                    ; abort if move failed

fmt3:   add     word ptr doffset,secsize; increment destination address
        adc     word ptr doffset+2,0
        mov     ax,xfercnt              ; count sectors initialized
        inc     ax
        mov     xfercnt,ax
        cmp     ax,xferreq              ; done yet?
        jne     fmt2                    ; not done, write another

        mov     ax,bpb+3                ; calculate offset of first
        mul     bpb                     ; FAT sector in RAMdisk buffer
        mov     word ptr doffset,ax     ; set destination address
        mov     word ptr doffset+2,dx

        mov     al,byte ptr bpb+0ah     ; set up medium ID byte
        mov     secbuf,al               ; in first FAT sector
        mov     word ptr secbuf+1,-1    ; assume 12-bit FAT
        cmp     clust,4086              ; more than 4086 clusters?
        jna     fmt4                    ; no, jump
        mov     secbuf+3,0ffh           ; yes, use 16-bit FAT

fmt4:   mov     ah,0bh                  ; write first FAT sector
        mov     si,offset movpars
        call    xmm
        or      ax,ax                   ; test move status
        jz      fmt5                    ; abort if move failed

        mov     word ptr doffset,0      ; offset of logical sector 0
        mov     word ptr doffset+2,0
        mov     word ptr soffset,offset bootrec
        mov     word ptr movelen,bootrec_len
        mov     ah,0bh                  ; copy phony boot record
        mov     si,offset movpars       ; to logical sector 0
        call    xmm
        or      ax,ax                   ; test move status
        jz      fmt5                    ; abort if move failed

        mov     ax,bpb+0bh              ; calculate offset of first
        add     ax,bpb+3                ; root directory sector
        mul     bpb                     ; in RAMdisk buffer
        mov     word ptr doffset,ax
        mov     word ptr doffset+2,dx
        mov     word ptr soffset,offset volname
        mov     word ptr movelen,volname_len
        mov     ah,0bh                  ; copy phony volume label
        mov     si,offset movpars       ; to first directory sector
        call    xmm
        or      ax,ax                   ; test move status
        jz      fmt5                    ; abort if move failed

        clc                             ; successful format, 
        ret                             ; return CY = clear

fmt5:   stc                             ; format failed, 
        ret                             ; return CY = set

format  endp

;
; Miscellaneous data used during initialization, then discarded.
;
ident   db      cr,lf,lf                ; sign-on message
        db      'XMSDISK Extended Memory RAMdisk'
        db      cr,lf
        db      'Copyright (C) 1989 Ziff Davis Communications'
        db      cr,lf
        db      'PC Magazine * Ray Duncan'
        db      cr,lf,lf
        db      'XMSDISK will be drive '
ident1  db      'X:',cr,lf
        db      'Extended memory available:'
ident2  db      '       KB',cr,lf
        db      'Largest free memory block:'
ident3  db      '       KB',cr,lf
        db      'Extended memory allocated:'
ident4  db      '       KB',cr,lf,eom

errmsg  db      cr,lf
        db      'XMSDISK installation error:'
        db      cr,lf,eom

msg1    db      'Extended Memory Manager not found.'
        db      cr,lf,eom

msg2    db      'Insufficient extended memory available.'
        db      cr,lf,eom

msg3    db      'Extended memory allocation failed.'
        db      cr,lf,eom

msg4    db      'Unable to format RAMdisk.'
        db      cr,lf,eom

volname db      'XMSDISK    '           ; phony volume label
        db      08h                     ; volume label attribute byte
        db      10 dup (0)
        dw      0                       ; time = 00:00:00
        dw      1241h                   ; date = February 1, 1989
        db      6 dup (0)
volname_len equ $-volname

secbuf  db      secsize dup (?)         ; sector buffer for format

_TEXT   ends
        
        end

