

        title   DUMP --- display file contents
        page    55,132
        .386

; DUMP.ASM      Display contents of file in hex and ASCII.
;               80386 version for Phar Lap tools.
;               Also requires 80386 versions of ARGV.ASM,
;               ARGC.ASM, and HEXASC.ASM.
;
; Copyright (C) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
;
; Build:        C>386ASM  DUMP
;               C>386ASM  ARGC  
;               C>386ASM  ARGV  
;               C>386ASM  HEXASC
;               C>386LINK DUMP ARGC ARGV HEXASC  -EXE DUMP
; 
; MAKE File:	argc.obj : argc.asm
;		  386asm argc
;
;		argv.obj : argv.asm
;		  386asm argv
;
;		hexasc.obj : hexasc.asm
;		  386asm hexasc
;
;		dump.obj : dump.asm
;		  386asm dump
;
;		dump.exe : dump.obj argv.obj argc.obj hexasc.obj
;		  386link dump,argc,argv hexasc -exe dump
;		  bind386 c:\tools\run386b.exe dump.exp
;
;
; Usage:        C>DUMP unit:\path\filename.exe [ >device ]

cr      equ     0dh		; ASCII carriage return
lf      equ     0ah 		; ASCII line feed
tab     equ     09h		; ASCII tab code
blank   equ     20h		; ASCII space code

blksize equ     16		; input file record size

stdin   equ     0		; standard input handle
stdout  equ     1		; standard output handle
stderr  equ     2		; standard error handle


_TEXT   segment dword use32 public 'CODE'

        assume  cs:_TEXT,ds:_DATA,es:_DATA,ss:STACK

        extrn   argc:near	; get no. of command line args.
        extrn   argv:near	; get addr. of command line arg.
        extrn   d2asc:near	; convert dword to hex ASCII
        extrn   b2asc:near	; convert byte to hex ASCII

dump    proc    far		; entry point from MS-DOS

        call    argc		; count command arguments
        cmp     eax,2		; are there 2 arguments?
        je      dump1		; yes, proceed

        mov     edx,offset msg1	; missing or illegal filespec.
        mov     ecx,msg1_len
        jmp     dump7		; display error message and exit

dump1:            		; copy filename from command
			; tail to local buffer

        mov     eax,1		; get pointer to command
        call    argv		; tail argument in ES:EBX

        mov     ecx,eax	; let ECX = length
        mov     edi,offset fname; DS:EDI = local buffer address

dump2:  mov     al,es:[ebx]	; copy filename byte by byte
        mov     [edi],al
        inc     ebx
        inc     edi
        loop    dump2

        mov     ax,ds		; make our data segment
        mov     es,ax		; addressable by ES too

			; now open the file...
        mov     eax,3d00h	; Fxn 3DH = open file
			; mode 0 = read only
        mov     edx,offset fname; DS:EDX = filename
        int     21h		; transfer to MS-DOS
        mov     fhandle,eax	; save file handle if any
        jnc     dump3		; jump, open successful

        mov     edx,offset msg2	; open failed, display 
        mov     ecx,msg2_len	; error message and exit
        jmp     dump7

dump3:			; read block of file data...
        mov     ebx,fhandle	; EBX = file handle
        mov     ecx,blksize	; ECX = record length
        mov     edx,offset fbuff; DS:EDX = buffer
        mov     ah,3fh		; Fxn 3FH = read
        int     21h		; transfer to MS-DOS

        mov     flen,eax	; save actual length of data
        or      eax,eax	; end of file reached?
        jne     dump4		; no, proceed

        cmp     dword ptr fptr,0; was this the first record?
        jne     dump6		; no, exit normally

        mov     edx,offset msg3	; display "empty file"
        mov     ecx,msg3_len	; error message and exit
        jmp     dump7

dump4:  test    fptr,07fh	; heading needed?
        jnz     dump5		; jump, not 128-byte boundary

			; display heading...
        mov     edx,offset hdg	; ES:EDX = heading address
        mov     ecx,hdg_len	; ECX = heading length
        mov     ebx,stdout	; EBX = standard output handle
        mov     ah,40h	; Fxn 40H = write
        int     21h		; transfer to MS-DOS

dump5:  call    cnvblk	; convert record to ASCII
        
			; display formatted output...
        mov     edx,offset fout	; DX:EDX = output address
        mov     ecx,fout_len	; ECX = output length
        mov     ebx,stdout	; EBX = standard output
        mov     ah,40h	; Fxn 40H = write
        int     21h		; transfer to MS-DOS

        jmp     dump3		; go get another record

dump6:			; close input file...
        mov     ebx,fhandle	; EBX = file handle
        mov     ah,3eh	; Fxn 3EH = close file
        int     21h		; transfer to MS-DOS

        mov     eax,4c00h	; Fxn 4CH = terminate,
			; return code = 0
        int     21h		; transfer to MS-DOS

dump7:			; common error exit point...
			; DS:EDX = message address
			; ECX = message length
        mov     ebx,stderr	; standard error handle
        mov     ah,40h	; Fxn 40H = write
        int     21h		; transfer to MS-DOS

        mov     eax,4c01h	; Fxn 4CH = terminate,
			; return code = 1
        int     21h		; transfer to MS-DOS
        
dump    endp


cnvblk  proc    near		; convert record to ASCII

        mov     edi,offset fout	; clear output format 
        mov     ecx,fout_len-2	; area to blanks
        mov     al,blank
        rep stosb

        mov     edi,offset fout	; convert file offset
        mov     eax,fptr	; to ASCII for output
        call    d2asc

        xor     ebx,ebx	; reset buffer pointer

cb1:    mov     al,[fbuff+bx]	; fetch byte from buffer
        lea     edi,[ebx+foutb]	; point to output area
                        
			; format ASCII part...
        mov     byte ptr [edi],'.'; store '.' as default
        cmp     al,blank	; in range 20H - 7EH?
        jb      cb2		; jump, not alphanumeric.
        cmp     al,7eh	; in range 20H - 7EH?
        ja      cb2		; jump, not alphanumeric.
        mov     [edi],al	; store ASCII character.

cb2:			; format hex part...
        mov     edi,ebx	; calculate output address
        imul    edi,edi,3	; (position*3) + base address   
        add     edi,offset fouta        
        call    b2asc		; convert byte to hex 

        inc     ebx		; advance through record
        cmp     ebx,flen	; entire record converted?
        jne     cb1		; no, get another byte

        add     dword ptr fptr,blksize; update file pointer

        ret		; back to caller

cnvblk  endp

_TEXT   ends


_DATA   segment dword use32 public 'DATA'

fname   db      64 dup (0)	; buffer for input filespec

fhandle dd      0		; token from PCDOS for input file.

flen    dd      0		; actual length read

fptr    dd      0		; relative address in file 

fbuff   db      blksize dup (?)	; data from input file

fout    db      'nnnnnnnn'	; formatted output area
        db      blank,blank
fouta   db      16 dup ('nn',blank)
        db      blank
foutb   db      16 dup (blank),cr,lf
fout_len equ    $-fout

hdg     db      cr,lf		; heading for each 128 bytes
        db      11 dup (blank)	; of formatted output
        db      '0  1  2  3  4  5  6  7  '
        db      '8  9  A  B  C  D  E  F',cr,lf
hdg_len equ     $-hdg

msg1    db      cr,lf
        db      'dump: missing file name'
        db      cr,lf
msg1_len equ    $-msg1

msg2    db      cr,lf
        db      'dump: file not found'
        db      cr,lf
msg2_len equ    $-msg2

msg3    db      cr,lf
        db      'dump: empty file'
        db      cr,lf
msg3_len equ    $-msg3

_DATA   ends    


STACK   segment dword use32 stack 'STACK'

        dd      64 dup (?)

STACK   ends

        end     dump

