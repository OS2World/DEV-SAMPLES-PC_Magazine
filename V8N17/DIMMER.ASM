                page    66,132
;============================================================================
; DIMMER.COM allows VGA users to interactively brighten or dim the screen.
; Syntax is:
;
;       DIMMER [/U] [/V[+|-]] [/D mmm [+|-]xx] [[+|-]xx]
;
; where /U = Uninstall the program
;       /D = Adjust intensity by xx after mmm minutes of inactivity
;       xx = Numeric code from -63 to +63 representing relative
;            amount by which to adjust the intensity
;       /V = Reset delay timer on call to BIOS video interrupt. The
;	     default is V-.
;
; COMMAND LINE INTENSITY CONTROL
;
;       DIMMER /D 1 -63 causes the screen to blank after 1 minute of
;       inactivity.  DIMMER /D 0 cancels any time delay previously entered.
;       DIMMER -20 causes the screen to immediately dim 20 intensity levels.
;       DIMMER 0 restores the screen intensity to what it was when DIMMER
;       was installed.  In all cases, DIMMER becomes RAM-resident so that
;       intensity levels can also be adjusted interactively.
;       DIMMER /D 1 -63 /V causes the screen to blank after 1 minute of
;   	inactivity.  If a program calls any BIOS video routines, the
;       screen is reset to its original brightness.
;
; INTERACTIVE INTENSITY CONTROL
;
;       With DIMMER installed, Alt-UpArrow increases the display intensity
;       by 1 level, Alt-DnArrow decreases the intensity by 1 level, and
;       Alt-Home restores the screen intensity to what it was when DIMMER
;       was installed.
;============================================================================
 
                code    segment
                assume  cs:code
 
                org     2Ch
env_segment     dw      ?                       ;Address of environment block
                org     80h
command_tail    dw      ?                       ;Address of command tail
 
                org     100h
main:           jmp     initialize              ;Go to initialization code
 
program         db      "Dimmer 1.0 "
copyright       db      "(c) 1989 Ziff Communications Co.",13,10
authors         db      "PC Magazine ",254," Doug Boling and Jeff Prosise"
                db      "$",1Ah
 
dimmer_val      db      0                       ;Relative dimmer value
delaydimval     db      0                       ;Delayed dimmer value
wait_time       dw      -1                      ;Delay until screen blank
dim_counter     dw      -1                      ;Number of minutes to delay
second_cnt      dw      1092                    ;Timer ticks per minute
restorebyvid	db	0			;1 = delay reset by video call
vid_function    dw      0                       ;Saved video function
int08h          dd      ?                       ;Int 8 vector (Timer)
int09h          dd      ?                       ;Int 9 vector (Keyboard)
int10h          dd      ?                       ;Int 10 vector (Video)
 
;============================================================================
; TIMERINT services the BIOS timer interrupt.
;============================================================================
timerint        proc    far
                pushf                           ;Push flags
                call    int08h                  ;Call BIOS timer routine
                sti                             ;Enable interrupts
 
                push    ax                      ;Save AX
                mov     ax,cs:[dim_counter]     ;Get delay counter
                cmp     ax,0FFFFh               ;See if timer enabled
                je      timer_exit              ;Exit if not enabled
		or	ax,ax			;Exit if timer at 0 to
		je	timer_exit		;  prevent rollover.
 
                dec     cs:[second_cnt]         ;Decrement seconds and exit
                jnz     timer_exit              ;  if not zero
                mov     word ptr cs:[second_cnt],1092
                dec     ax                      ;Decrement minute counter
                mov     cs:[dim_counter],ax     ;Update delay counter
                or      ax,ax                   ;Exit if timer hasn't
                jne     timer_exit              ;  reached zero
 
                mov     ah,cs:[delaydimval]     ;Get dimmer value
                call    adj_palette_2           ;Modify color registers
timer_exit:
                pop     ax                      ;Restore AX and exit
                iret
timerint        endp
 
;============================================================================
; KBINT services the keyboard interrupt.
;============================================================================
kbint           proc    far
                sti                             ;Enable interrupts
                push    ax                      ;Save AX
                mov     cs:[second_cnt],1092    ;Reset delay counters
                mov     ax,cs:[wait_time]
                xchg    cs:[dim_counter],ax
                or      ax,ax                   ;If counter was 0, reset the
                jne     kbint0                  ;  screen intensity
 
                mov     ah,cs:[dimmer_val]
                call    adj_palette_2
kbint0:
                push    ds                      ;Save DS
                mov     ax,40h                  ;Point DS to BIOS data area
                mov     ds,ax
                mov     al,ds:[17h]             ;Get keyboard shift status
                pop     ds                      ;Restore DS
                and     al,0Fh                  ;Mask upper 4 bits
                cmp     al,8                    ;Check for Alt key
                je      alt_found               ;Continue if Alt is pressed

goto_bios:
                pop     ax                      ;Restore AX and exit to
                jmp     int09h                  ;  BIOS keyboard handler
 
alt_found:
                in      al,60h                  ;Get key pressed
                cmp     al,72                   ;Check for UpArrow
                jne     kbint1
                cmp     cs:[dimmer_val],63      ;Increment color registers
                jge     kbint3                  ;  by 1 if dimmer value
                inc     cs:[dimmer_val]         ;  isn't maxed out
                jmp     short kbint3
kbint1:
                cmp     al,80                   ;Check for DnArrow
                jne     kbint2
                cmp     cs:[dimmer_val],-63     ;Decrement color registers
                jle     kbint3                  ;  by 1 if dimmer value
                dec     cs:[dimmer_val]         ;  isn't zeroed out
                jmp     short kbint3
kbint2:
                cmp     al,71                   ;Reset color registers if
                jne     goto_bios               ;  Alt-Home was pressed
                mov     cs:[dimmer_val],0
kbint3:
                mov     ah,cs:[dimmer_val]      ;Get dimmer value
                call    adj_palette_2           ;Modify color registers
 
                cli                             ;Disable interrupts
                in      al,61h                  ;Reset the keyboard
                mov     ah,al                   ;  controller
                or      al,80h
                out     61h,al
                mov     al,ah
                out     61h,al
 
                mov     al,20h                  ;Signal end-of-interrupt to
                out     20h,al                  ;  the interrupt controller
                sti                             ;Enable interrupts
 
                pop     ax                      ;Restore AX and exit
                iret
kbint           endp
 
;============================================================================
; VIDEOINT services the BIOS video interrupt.
;============================================================================
videoint        proc    far
                mov     cs:[vid_function],ax    ;Save function number
                pushf                           ;Push flags
                call    int10h                  ;Call video BIOS routine
                sti                             ;Enable interrupts
                push    ax                      ;Save AX
 
		cmp	cs:[restorebyvid],0     ;If video checking enabled,
		je	video_1			;  check delay counter.
                cmp     word ptr cs:[dim_counter],0
                jne     video_1                 ;Restore color register
                mov     ah,cs:[dimmer_val]      ;  values if timed delay
                call    adj_palette_2           ;  has dimmed the screen
                mov     cs:[second_cnt],1092    ;Reset delay counters
                mov     ax,cs:[wait_time]
                mov     cs:[dim_counter],ax
 
video_1:
                mov     ax,cs:[vid_function]    ;See what function was called
                or      ah,ah                   ;Check for mode change
                je      refresh_palette
                cmp     ah,11h                  ;Check for mode reset
                je      refresh_palette
 
                cmp     ax,1010h                ;Check for changes to the
                je      refresh_buffer          ;  VGA color registers
                cmp     ax,1012h                ;  made thru the video
                je      refresh_buffer          ;  BIOS
                cmp     ax,101Bh
                jne     video_exit
refresh_buffer:
                call    get_palette             ;Reload register array
                jmp     short video_exit
 
refresh_palette:
                mov     ah,cs:[dimmer_val]      ;Get dimmer adjust value
                call    adj_palette_2           ;Modify palette
video_exit:
                pop     ax                      ;Restore AX and exit
                iret
videoint        endp
 
;----------------------------------------------------------------------------
; ADJ_PALETTE_1 adjusts the VGA color registers to their original values
; plus the current dimmer value.
;   Entry:  AH - Dimmer value
;           DS - Segment where color register values are stored
;----------------------------------------------------------------------------
adj_palette_1   proc    near
                cld                             ;Clear direction flag
                push    cx                      ;Save registers
                push    dx
                push    si
 
                mov     si,offset end_res       ;Point SI to buffer
                                                ;  containing original values
                mov     dx,03C8h                ;Write address register
                xor     al,al                   ;Set beginning address
		cli				;Disable interrupts
                out     dx,al
                mov     cx,256 * 3              ;256 color registers
                mov     dx,03C9h                ;Write data register
adj_loop1:
                lodsb                           ;Get color value
                call    mod64_add               ;Add dimmer value
                out     dx,al                   ;Write data to color register
                loop    adj_loop1               ;Loop until done
 
		sti				;Enable interrupts
                pop     si                      ;Restore registers and exit
                pop     dx
                pop     cx
                ret
adj_palette_1   endp
 
;----------------------------------------------------------------------------
; ADJ_PALETTE_2 adjusts the VGA color registers to their original values
; plus the current dimmer value.
;   Entry:  AH - Dimmer value
;----------------------------------------------------------------------------
adj_palette_2   proc    near
                push    ds                      ;Save DS
                push    cs                      ;Point DS to code segment
                pop     ds
                call    adj_palette_1           ;Modify color registers
                pop     ds                      ;Restore DS and exit
                ret
adj_palette_2   endp
 
;----------------------------------------------------------------------------
; MOD64_ADD adds AH to AL using modulo 64 math.
;----------------------------------------------------------------------------
mod64_add       proc    near
                or      al,al                   ;If 0, don't brighten
                je      mod2
                add     al,ah
                cmp     al,0                    ;See if underflow
                jg      mod1
                mov     al,0                    ;If so, set at minimum
                jmp     short mod2
mod1:
                cmp     al,63                   ;See if overflow
                jbe     mod2
                mov     al,63                   ;If so, set at maximum
mod2:
                ret
mod64_add       endp
 
;----------------------------------------------------------------------------
; GET_PALETTE buffers the current values of the VGA color registers.
;----------------------------------------------------------------------------
get_palette     proc    near
                cld                             ;Clear direction flag
                push    ax                      ;Save registers
                push    cx
                push    dx
                push    di
                push    es
 
                mov     cx,cs                   ;Point ES to the code segment
                mov     es,cx
                mov     di,offset end_res       ;Point DI to save buffer
                mov     dx,03C7h                ;Read address register
                xor     al,al                   ;Begin with register 0
		cli				;Disable interrupts
                out     dx,al
                mov     cx,256 * 3              ;256 color registers
                mov     dx,03C9h                ;Read data register
getp_loop1:
                in      al,dx                   ;Get color register value
                and     al,3Fh                  ;Mask off the upper 2 bits
                stosb                           ;Store it
                loop    getp_loop1              ;Loop until done
 
		sti				;Enable interrupts
                pop     es                      ;Restore registers and exit
                pop     di
                pop     dx
                pop     cx
                pop     ax
                ret
get_palette     endp
 
;----------------------------------------------------------------------------
; FINAL_INSTALL is the last of the resident code.
;----------------------------------------------------------------------------
final_install:
                assume  ds:code
                call    get_palette             ;Get color register values
                mov     ah,dimmer_val           ;Adjust color registers and
                call    adj_palette_2           ;  terminate
                mov     dx,(offset end_res-offset code+768+15) SHR 4
                mov     ax,3100h
                int     21h
end_res         =       $                       ;End of resident code
 
;============================================================================
; Start of non-resident section.
;============================================================================
 
alrdy_installed db      0                       ;Installed flag
other_seg       dw      0                       ;Segment of installed code
change_flag     db      0                       ;Set if dimmer or delay
                                                ;  value is modified
infomsg1        db      "Program uninstalled$"
errmsg1         db      "Program not installed$"
errmsg2         db      "Syntax: DIMMER [/U] [/V[+|-]] [/D mmm [+|-]xx]"
		db	" [[+|-]xx]$"
errmsg3         db      "Can",39,"t uninstall$"
errmsg4         db      "VGA required$"
errmsg5         db      "Intensity value must be between -63 and +63$"
errmsg6         db      "Invalid delay value$"
errmsg7         db      "Program already installed$"
errmsg8         db      "Invalid intensity value$"
 
initialize      proc    near
                assume  cs:code,ds:code
;
;See if a copy of DIMMER is already resident in memory.
;
                cld                             ;Clear direction flag
                mov     word ptr [main],0       ;Initialize fingerprint
                xor     bx,bx                   ;Zero BX for start
                mov     ax,cs                   ;Keep CS value in AX
find_copy:
                inc     bx                      ;Increment search segment
                mov     es,bx
                cmp     ax,bx                   ;Not installed if current
                je      find_copy1              ;  segment is found
                mov     si,offset main          ;Search this segment for ASCII
                mov     di,si                   ;  fingerprint.
                mov     cx,16
                repe    cmpsb
                jne     find_copy               ;Loop back if not found
                inc     alrdy_installed         ;Set installed flag
find_copy1:
                mov     other_seg,es            ;Save segment value
;
;Verify that a VGA is installed.
;
                mov     ax,1A00h                ;BIOS read display function
                int     10h
                mov     dx,offset errmsg4
                cmp     al,1Ah                  ;See if VGA present
                jne     disp_error              ;Exit on error if no VGA
;
;Parse the command line for switches.
;
                mov     si,offset command_tail+1        ;Point SI to command
parse_line_loop:                                        ;  tail in PSP
                lodsb                           ;Scan command line for / or a
                cmp     al,32                   ;  number.  Continue scanning
                je      parse_line_loop         ;  until a carriage return is
                cmp     al,13                   ;  found.
                je      parse_line_end
 
                cmp     al,"/"                  ;Is this a / character?
                jne     check_numeric           ;No, then check for numeric
                lodsb                           ;Get next character
                or      al,20h                  ;Convert to lower case
                cmp     al,"u"                  ;Check for uninstall switch
                je      uninstall_found
                cmp     al,"d"                  ;Check for delay switch
                je      delay_found
                cmp     al,"v"                  ;Check for reset delay by
                je      vidflag_found		;  video call switch.
parse_line_error:
                mov     dx,offset errmsg2       ;Syntax error
                jmp     short disp_error        ;Display message and exit
;
;Read the dimmer value from the command line if entry is numeric.
;
check_numeric:
                cmp     al,"-"                  ;Convert ASCII number into
                je      numeric_start           ;  binary.  Check for leading
                cmp     al,"+"                  ;  sign.
                je      numeric_start
                cmp     al,"0"
                jb      parse_line_error
                cmp     al,"9"
                ja      parse_line_error
                dec     si
numeric_start:
                or      change_flag,1           ;Set bit 0 in change flag
                call    setdim                  ;Read and set dimmer value
                jmp     short chk_err_and_loop  ;Check for error return
;
;Read the time delay and dimmer values from the command line.
;
vidflag_found:
                call    setvidflag              ;Modify the state of video flg
                jmp     short chk_err_and_loop  ;Check for error return
delay_found:
                or      change_flag,2           ;Set bit 1 in change flag
                call    setdelay                ;Read and set delay value
chk_err_and_loop:
                jc      disp_error
                jmp     short parse_line_loop
;
;Uninstall the program from memory.
;
uninstall_found:
                mov     dx,offset errmsg1       ;Make sure program is
                cmp     alrdy_installed,0       ;  installed and signal
                je      disp_error              ;  error if it is not
                call    remove                  ;Remove program from memory
                mov     dx,offset errmsg3
                jc      disp_error              ;Error if can't remove
                mov     dx,offset infomsg1      ;Acknowledge if removed
                call    print_string
exit:
                mov     ax,4C00h                ;Exit with RC = 0
                int     21h
;
;Process new dimmer and/or delay values now if DIMMER is already resident.
;
parse_line_end:
                cmp     alrdy_installed,0       ;Program already installed?
                je      install                 ;No, then install it
                cmp     change_flag,0           ;Changes to resident copy?
                jne     check_dimmer_change     ;Yes, then process them
                mov     dx,offset errmsg7
disp_error:
                call    print_string            ;No, then display error
                mov     ax,4C01h                ;  message and exit
                int     21h                     ;  with RC = 1
check_dimmer_change:
                test    change_flag,1           ;Adjust color registers if
                jz      check_delay_change      ;  dimmer value was changed
                push    ds
                mov     ds,other_seg            ;Point DS to installed
                assume  ds:nothing              ;  segment
                mov     ah,ds:[dimmer_val]
                call    adj_palette_1
                pop     ds
                assume  ds:code
                jmp     exit                    ;Terminate
check_delay_change:
                test    change_flag,2           ;Exit now if delay value
                jnz     exit                    ;  was modified
;
;Install a copy of DIMMER.
;
install:
                mov     ax,3508h                ;Hook into interrupt 8
                int     21h
                mov     word ptr int08h,bx
                mov     word ptr int08h[2],es
                mov     ax,2508h
                mov     dx,offset timerint
                int     21h
 
                mov     ax,3509h                ;Hook into interrupt 9
                int     21h
                mov     word ptr int09h,bx
                mov     word ptr int09h[2],es
                mov     ax,2509h
                mov     dx,offset kbint
                int     21h
 
                mov     ax,3510h                ;Hook into interrupt 10h
                int     21h
                mov     word ptr int10h,bx
                mov     word ptr int10h[2],es
                mov     ax,2510h
                mov     dx,offset videoint
                int     21h
 
                mov     dx,offset program       ;Display copyright notice
                call    print_string            ;  and jump to final
                jmp     final_install           ;  install code
initialize      endp
 
;-----------------------------------------------------------------------------
; PRINT_STRING displays a DOS "$"-delimited text string with leading and
; trailing CRLFs.
;   Entry: DS:DX - String address
;-----------------------------------------------------------------------------
crlf            db      13,10,"$"
 
print_string    proc    near
                push    dx                      ;Save entry-level value of DX
                mov     ah,9                    ;Print leading CRLF
                mov     dx,offset crlf
                int     21h
                mov     ah,9                    ;Print text string
                pop     dx
                int     21h
                mov     ah,9                    ;Print trailing CRLF
                mov     dx,offset crlf
                int     21h
                ret                             ;Exit to caller
print_string    endp
 
;-----------------------------------------------------------------------------
; SETVIDFLAG modifies the video reset flag.
;   Entry: DS:SI - Address of optional sign value.
;-----------------------------------------------------------------------------
setvidflag      proc    near
                mov     al,1                    ;Assume video flag enable
                cmp     byte ptr [si],"-"       ;Check for video flag disable
                jne     setvidflag_1
                dec     al
setvidflag_1:
                mov     es,other_seg            ;Point ES to installed seg
                mov     es:[restorebyvid],al    ;Set/Reset video flag
                clc
                ret
setvidflag      endp
 
;-----------------------------------------------------------------------------
; SETDIM sets the dimmer value.
;   Entry: DS:SI - Address of first digit
;   Exit:  CF set on error (DX points to error message text)
;-----------------------------------------------------------------------------
setdim          proc    near
                mov     di,si                   ;Copy command line pointer
                call    asc2bin                 ;Convert ASCII to binary
                mov     dx,offset errmsg8       ;Exit on error
                jc      setdim_error
                cmp     byte ptr [di-1],"-"     ;Negate value if negative
                jne     setdim_1
                neg     ax
setdim_1:
                mov     dx,offset errmsg5
                cmp     ax,63                   ;Error if value is less than
                jg      setdim_error            ;  -63 or greater than +63
                cmp     ax,-63
                jl      setdim_error
 
                mov     es,other_seg            ;Point ES to installed seg
                mov     es:[dimmer_val],al      ;Record dimmer value
                clc
setdim_exit:
                ret
setdim_error:
                stc
                jmp     short setdim_exit
setdim          endp
 
;-----------------------------------------------------------------------------
; SETDELAY sets the delay counter.
;   Entry: DS:SI - Address of first character past /D switch
;   Exit:  CF set on error (DX points to error message text)
;-----------------------------------------------------------------------------
setdelay        proc    near
setdelay_l1:
                lodsb
                cmp     al,32                   ;Skip spaces
                je      setdelay_l1
                mov     dx,offset errmsg2       ;Error if no delay value
                cmp     al,13                   ;  was specified
                je      setdelay_error
 
                dec     si                      ;Back up to first character
                call    asc2bin                 ;Convert ASCII to binary
                mov     dx,offset errmsg6       ;Exit on error
                jc      setdelay_error
                mov     bx,0FFFFh               ;If delay value 0, disable
                or      ax,ax                   ;  delay counter with FFFFh
                je      delay_2
                mov     bx,ax                   ;Save delay value
setdelay_l2:
                lodsb                           ;Get next character
                cmp     al,32                   ;Skip spaces
                je      setdelay_l2
                mov     dx,offset errmsg2       ;Error if no delay value
                cmp     al,13                   ;  was specified
                je      setdelay_error
 
                mov     di,si                   ;Copy pointer to number
                cmp     al,"-"                  ;Check for leading sign
                je      setdelay_1              ;  identifier
                cmp     al,"+"
                je      setdelay_1
                dec     si                      ;Back up to first character
setdelay_1:
                push    bx                      ;Save delay value
                call    asc2bin                 ;ASCII --> binary
                pop     bx                      ;Retrieve delay value
                mov     dx,offset errmsg8       ;Exit on error
                jc      setdelay_error
                cmp     byte ptr [di-1],"-"     ;Negate value if negative
                jne     delay_1
                neg     ax
delay_1:
                mov     dx,offset errmsg5       ;Check to see if the value
                cmp     ax,63                   ;  is out of range
                jg      setdelay_error
                cmp     ax,-63
                jl      setdelay_error
delay_2:
                mov     es,other_seg            ;Load new delay and dimmer
                mov     es:[delaydimval],al     ;  values into the
                mov     es:[wait_time],bx       ;  program
                mov     es:[dim_counter],bx
                mov     es:[second_cnt],1092
                clc
setdelay_exit:
                ret
setdelay_error:
                stc
                jmp     short setdelay_exit
setdelay        endp
 
;-----------------------------------------------------------------------------
; REMOVE removes a resident copy of the program from memory.
;   Exit: CF set on error
;-----------------------------------------------------------------------------
remove          proc    near
                cmp     alrdy_installed,0       ;See if installed
                je      remove_error            ;No, error
                mov     ax,3508h                ;Get timer vector
                int     21h
                mov     ax,es                   ;Check to make sure timer
                cmp     ax,other_seg            ;  vector not modified
                jne     remove_error
 
                mov     ax,3509h                ;Get keyboard vector
                int     21h
                mov     ax,es                   ;Check to make sure keyboard
                cmp     ax,other_seg            ;  vector not modified
                jne     remove_error
 
                mov     ax,3510h                ;Get video vector
                int     21h
                mov     ax,es                   ;Check to make sure video
                cmp     ax,other_seg            ;  vector not modified
                jne     remove_error
 
                push    ds
                lds     dx,es:[int08h]          ;Get old interrupt 8 vector
                mov     ax,2508h                ;Set interrupt
                int     21h
                lds     dx,es:[int09h]          ;Get old interrupt 9 vector
                mov     ax,2509h                ;Set interrupt
                int     21h
                lds     dx,es:[int10h]          ;Get old interrupt 10 vector
                mov     ax,2510h                ;Set interrupt
                int     21h
                pop     ds
 
                mov     cx,es:[env_segment]
                mov     ah,49h                  ;Free PSP block
                int     21h
                mov     es,cx                   ;Free environment block
                mov     ah,49h
                int     21h
remove_exit:    
                clc
remove_exit1:
                ret
remove_error:
                stc
                jmp     remove_exit1
remove          endp
 
;-----------------------------------------------------------------------------
; ASC2BIN Converts an ASCII number pointed to by SI to a hex value.
;   Entry: SI = pointer to ASCII number
;   Exit:  AX = binary value
;          CF set on error
;-----------------------------------------------------------------------------
ten             dw      10
 
asc2bin         proc near
                xor     ax,ax                   ;Clear accumulator
                xor     bx,bx                   ;Clear BX
asc_loop:
                mov     bl,[si]                 ;Get ASCII character
                cmp     bl,13                   ;Done if carriage return or
                je      asc_exit                ;  space encountered
                cmp     bl,32
                je      asc_exit
                inc     si
                sub     bl,"0"                  ;ASCII --> binary
                jb      asc_error               ;Error if binary value is
                cmp     bl,9                    ;  less than 0 or greater
                ja      asc_error               ;  than 9
                mul     ten                     ;Multiply accumulator by 10
                add     ax,bx                   ;Add last digit to sum
                jmp     short asc_loop          ;Loop until done
asc_exit:
                clc
asc_exit1:
                ret
asc_error:
                stc
                jmp     short asc_exit1
asc2bin         endp
 
code            ends
 
                end     main
