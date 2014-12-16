
emmname db      'EMMXXXX0',0    ; guaranteed device name for
                                ; Expanded Memory Manager

        .
        .
        .
                                ; attempt to open" EMM...
        mov     dx,seg emmname  ; DS:DX = address of EMM
        mov     ds,dx           ; logical device name
        mov     dx,offset emmname
        mov     ax,3d00h        ; fxn. 3DH = open
        interrupt     21h             ; transfer to MS-DOS
        jc      error           ; jump if open failed

                                ; open succeeded, make sure
                                ; it was not a file...
        mov     bx,ax           ; BX = handle from open
        mov     ax,4400h        ; fxn. 44H subfun. 00H =
                                ; IOCTL get device info.
        interrupt     21h             ; transfer to MS-DOS
        jc      error           ; jump if IOCTL call failed
        and     dx,80h          ; bit 7=1 if char. device
        jz      error           ; jump if it was a file

                                ; EMM is present, make sure
                                ; it is available...
                                ; (BX still contains handle)
        mov     ax,4407h        ; fxn. 44H subf. 07H =
                                ; IOCTL get output status
        interrupt     21h             ; transfer to MS-DOS
        jc      error           ; jump if IOCTL call failed
        or      al,al           ; test device status
        jz      error           ; if AL=0 EMM not available

                                ; now close handle ...
                                ; (BX still contains handle)
        mov     ah,3eh          ; fxn. 3EH = close
        interrupt     21h             ; transfer to MS-DOS
        jc      error           ; jump if close failed
        .
        .
        .
®MDNM¯