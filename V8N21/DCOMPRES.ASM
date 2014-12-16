.MODEL	small
cseg	segment para	public 'CODE'
assume	cs:cseg
;;;;;;;;;;;;;;;;;
;;
;;	DCOMPRES - Keeps track of last access time and date for a file,
;;                 decompresses already compressed files when accessed
;;	Copyright (c) 1989 by Ziff Communications Co.
;;	Program by Ross M. Greenberg
;;;;;;;;;;;;;;;;;


org	100h

TRUE		equ	1
FALSE		equ	0
NULL		equ	0

CR	equ	0dh
LF	equ	0ah
BELL	equ	07h

start:
	jmp	install				; It's traditional!

MAX_FILES	equ	100			; max files in index
FN_SIZE		equ	14			; filename + dot + extension
MAX_FN_SIZE	equ	64 + FN_SIZE		; and the maximum path

;;;;;;;;;;;;;;;;;
;; this structure should be an even number of bytes or contortions in C will
;; occur
;;;;;;;;;;;;;;;;
file	struc
	filename_len	dw	0
	filename	db	FN_SIZE	dup (0)
	left_ptr	dw	0
	right_ptr	dw	0
	date		dw	2	dup (0)
	time		dw	2	dup (0)
	status		db	0	;normal = 0, compressed = 1 , del = 2
	access_cnt	db	0	; extra byte. Why not?
file	ends

BUF_SIZE	equ	size file * MAX_FILES

NORMAL		equ	0
COMPRESSED	equ	1
DELETED		equ	2


num_files	dw	0		;don't separate these three!!!
dir_name2	db	MAX_FN_SIZE	dup(0)
buffer		db	BUF_SIZE	dup(0)

tag		db	0cdh, 020h, 'PCOMPRES'	; don't separate these two
TAG_LEN		equ	$ - tag
file_out	db	'PCOMPRES.$$$', 0 	; or these two
FILE_OUT_LEN	equ	$ - file_out
index_name	db	'INDEX.CMP',0		; don;t separate these two
INDEX_NAME_LEN	equ	$ - index_name


dir_name	db	MAX_FN_SIZE	dup(0)
dir_name3	db	MAX_FN_SIZE	dup(0)
dir_name4	db	MAX_FN_SIZE	dup(0)
file_name	db	FN_SIZE		dup(0)
tmp_buffer	db	MAX_FN_SIZE	dup(0)
tmp_buf2	db	FN_SIZE		dup(0)
dos_handle	dw	0
in_handle	dw	0
was_compressed	dw	0
tmp_len		dw	0
my_psp		dw	0
users_psp	dw	0
index_handle	dw	0
file_seg	dw	0
file_off	dw	0
dirty_bit	dw	0
in_use		dw	0
switch_off	dw	0
last_dos	dw	0
old_dx		dw	0
ignore_status	dw	0
attributes	dw	1
old_attrb	dw	0
tag_buf		db	TAG_LEN	dup	(0)

table	struc
	cmp_code	dw	0
	suffix		db	0
table	ends

MAX_CODE	equ	4096
RESET_TABLE	equ	(MAX_CODE - 1)

codes	db	(MAX_CODE * size table)	dup (0)
which_code	dw	0
	
codes_used	dw	0

stack		db	MAX_CODE	dup	(0)
s_ptr		dw	stack

INBUF_SIZE	equ	3000
in_buffer	db	INBUF_SIZE	dup	(0)
out_buf		db	INBUF_SIZE	dup	(0)
out_handle	dw	0
out_cnt		dw	0
buff_cnt	dw	0
buff_size	dw	0
tmp		db	0
hold		dw	0
old_code	dw	0
last_char	db	0
incode		dw	0

screen_msg	db	'Decompressing File...Standby'
SCREEN_LEN	equ	($ - screen_msg)
screen_attrb	db	SCREEN_LEN dup(09fh);
screen_segment	dw	0b800h
SCREEN_OFFSET	equ	2 * ((12 * 80) + (40 - SCREEN_LEN/2))
 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function 6c -- new to DOS 4.x is a pain.  All other functions operating
;; on files have consistent usage of ds:dx for the pointer to the file name.
;; Not this puppy.  Dile name is in ds:si.  Makes more sense, but it isn't
;; consistant.  This kludge makes it *look* consistent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

set_6c:	cmp	byte ptr cs:[last_dos + 1], 06ch
	jnz	not_6c1
	mov	cs:[old_dx], dx
	mov	dx, si
not_6c1:
	ret

;;;;;;;;;;;;;;;;;;;;;;;;
;; The reverse of the above
;;;;;;;;;;;;;;;;;;;;;;;;
reset_6c:	cmp	byte ptr cs:[last_dos + 1], 06ch
	jnz	not_6c2
	mov	dx, cs:[old_dx]
not_6c2:
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Routine called by PCMANAGE to turn on and off the COMPRES program,
;;  dump out and read back in the file (if one is on memory)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
set_flag:
	push	ds
	push	cs
	pop	ds

	mov	[switch_off], dx
	mov	bx, [index_handle]		; close file on change
	cmp	bx, 0				; first time?
	jz	not_yet				; yes

	inc	[in_use]
	push	ax
	push	bx

	mov	ah, 051h
	int	21h
	mov	[users_psp], bx
	mov	bx, [my_psp]
	mov	ah, 050h
	int	21h

	pop	bx
	pop	ax
	call	update_file
	mov	ah, 03eh
	int	21h

	push	cx
	push	dx
	mov	ax, 04301h
	mov	dx, offset dir_name
	mov	cx, [old_attrb]
	int	21h
	pop	dx
	pop	cx

	mov	[dir_name], 0

	mov	bx, [users_psp]
	mov	ah, 050h
	int	21h
	dec	[in_use]

not_yet:
	pop	ds
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; New Dos Interrupt Service Routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
old_dos	dw	0			; first the offset
	dw	0			; then the segment

new_dos	proc	far
	pushf				; save current flags,
	sti				; and turn on ints

	cmp	ax, 0fedch		; our installation call?
	jnz	@F
	mov	ax, 0cdefh		; yes. Return the inverse
	popf
	iret

@@:	cmp	ah, 0dch		; one of our calls to toggle?
	jnz	@F			; no
	call	set_flag		; yes.  Do it, and pass it on.
@@:
	cmp	cs:[in_use], TRUE	; no recursion!
	jz	@F
	cmp	cs:[switch_off], TRUE	; turned off?
	jz	@F

;;;;;;;;;;;;;;;;;;;;;;;;
;;  We care about any file access call.  If not a function we care about,
;;  simply call the original DOS
;;;;;;;;;;;;;;;;;;;;;;;;

	cmp	ah, 0fh
	jz	open
;	cmp	ah, 013h
;	jz	delete
	cmp	ah, 016h
	jz	create
	cmp	ah, 03ch
	jz	h_create
	cmp	ah, 03dh
	jz	h_open
	cmp	ah, 06ch
	jz	h_open
;	cmp	ah, 041h
;	jz	n_delete
	cmp	ah, 04bh
	jnz	not_execute			; kludge
	jmp	execute
not_execute:
	cmp	ah, 05ah
	jz	h_create
	cmp	ah, 05bh
	jz	h_create
	
@@:
	popf
	jmp	dword ptr cs:[old_dos]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Process all the FCB calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

open:
delete:
create:
	mov	cs:[last_dos], ax		; save for re-execute later
	mov	cs:[in_use], TRUE		; no recursion!
	call	dword ptr cs:[old_dos]		; do the original call
	pushf
	jnc	op_good				; if good continue
	jmp	op_failed			; else why bother?

op_good:
	push	dx				; translate FCB filenames into
	push	ds				; ASCIIZ filenames
	call	fcb_stuff
	push	ax
	push	bx

	mov	ax, 03d00h			; open with handle for the
	int	21h				; ioctl -- our psp
	mov	cs:[dos_handle], ax
	call	lookup				; main function call
	mov	bx, cs:[dos_handle]		; close file in our psp
	mov	ah, 03eh
	int	21h
	pop	bx
	pop	ax

	pop	ds
	pop	dx

	cmp	cs:[was_compressed], TRUE	; must we play?
	jnz	normal1				; no, skip

						; yes, continue
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; first, close then delete the file using users fcb, then rename the tmp
;; file to the name in the fcb, then re-do the users operation
;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	cs:[was_compressed], FALSE
	push	ax
	mov	ah, 010h
	int	21h				; close the file
	mov	ah, 013h
	int	21h				; delete it

;;;;;;;;;;;;;;;
;; use handle rename. Filename in tmp_buffer still. Decompressed in temp file
;;;;;;;;;;;;;;;
	call	rename

	mov	ax, cs:[last_dos]		; reissue the call
	int	21h

	pop	ax

normal1:
	jmp	op_failed			; common return

;;;;;;;;;;;;;;;;;;;
;; Process all handle operations here....
;;;;;;;;;;;;;;;;;;;
h_create:
h_open:
n_delete:
	mov	cs:[last_dos], ax
	mov	cs:[in_use], TRUE
	call	dword ptr cs:[old_dos]		; issue the users call.
	pushf
	sti
	jc	op_failed			; if it failed, simply return
	mov	cs:[dos_handle], ax

	call	set_6c				; kludge on 4.x 6c call

	call	lookup				; main call, file is open

	call	reset_6c			; reset from 4.x call

	cmp	cs:[was_compressed], TRUE	; do anything unusual?
	jnz	normal2				; no

;;;;;;;;;;;;;;;;;;
;;  Rename the file
;;;;;;;;;;;;;;;;;;

	push	ax
	call	handle_stuff			; do the rename
	mov	ax, cs:[last_dos]		; issue original call again
	int	21h

	pop	ax

normal2:
op_failed:
	popf
	mov	cs:[in_use], FALSE
	ret	2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reset the compressed flag, close the file, delete it, rename it, return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

handle_stuff proc near

	mov	cs:[was_compressed], FALSE

	push	bx
	push	dx
	push	ds

	mov	bx, cs:[dos_handle]
	mov	ah, 03eh
	int	21h
	push	cs
	pop	ds
	mov	dx, offset cs:tmp_buffer
	mov	ah, 041h
	int	21h
	call	rename

	pop	ds
	pop	dx
	pop	bx
	ret
handle_stuff	endp

;;;;;;;;;;;;;;;;;;;;;
;; handles a little differently.  Obviously, the file must be decompressed
;; before the call...
;;;;;;;;;;;;;;;;;;;;;
execute:
	mov	cs:[in_use], TRUE

	push	ax
	push	bx

	mov	ax, 03d00h			; open with handle
	int	21h
	mov	cs:[dos_handle], ax

	call	lookup				; main work

	mov	bx, cs:[dos_handle]		; close file
	mov	ah, 03eh
	int	21h

	pop	bx
	pop	ax

	cmp	cs:[was_compressed], TRUE	; skip exciting stuff?
	jnz	normal3				; yes

	push	ax
	call	handle_stuff			; do the rename
	pop	ax

normal3:
	popf
	mov	cs:[in_use], FALSE
	jmp	dword ptr cs:[old_dos]		; execute the program

new_dos	endp

;;;;;;;;;;;;;;;;;;;;;;;;;
;;  This routine makes an FCB entry, extended or not, into a semi-qualified
;;  ASCIIZ filename
;;;;;;;;;;;;;;;;;;;;;;;;;

fcb_stuff	proc	near
	push	ax
	push	cx
	push	si
	push	di
	push	es

	mov	si, dx
	cmp	byte ptr ds:[si], 0ffh		; extended FCB?
	jnz	@F				; normal
	add	si, 7				; point to the filename, 7
						; bytes into extended FCB
@@:	push	cs
	pop	es
	mov	di, offset cs:tmp_buf2		; ASCIIZ buffer
	cmp	byte ptr ds:[si], 0		; default drive?
	jz	@F				; yes
	mov	al, ds:[si]			; no. add drive to buffer
	mov	es:[di], al
	add	byte ptr es:[di], 'A' - 1
	mov	byte ptr es:[di + 1], ':'
	add	di, 2				; to filename position

@@:	inc	si				; and bypass the drive in FCB

	mov	cx, 11				; filename(8) + extension(3)
						; always left justified, space
						; filled
file_lp:
	mov	al, ds:[si]
	cmp	al, ' '				; space?
	jz	@F				; yes, so skip it
	mov	es:[di], al			; no, stuff the character
	inc	di

@@:	cmp	cx, 4				; at start of extension?
	jnz	@F
	mov	byte ptr es:[di], '.'		; yes. stuff a dot
	inc	di

@@:	inc	si
	loop	file_lp				; for entire filename
	mov	byte ptr es:[di], 0		; zero the end byte

	pop	es
	pop	di
	pop	si
	pop	cx
	pop	ax

	push	cs
	pop	ds
	mov	dx, offset tmp_buf2		; point to the ASCIIZ filename

	ret

fcb_stuff	endp

;;;;;;;;;;;;;;;;;;;;;;;
;; Main routine.
;;
;; 1.  Determine if a file or device.  If device, return.
;; 2.  Determine if fixed disk. If not, return
;; 3.  Fully qualify file/pathname with undocumented AH=60h call
;; 4.  Save users PSP, reset with our own.  Handle table in users might be
;;     full...
;; 5.  Scan path name, isolate last '\' (separates path from filename)
;;     saving the length of the path.
;; 6.  Save the path in one location, the filename in another
;; 7.  Stuff the name of the index file to the tail of the path
;; 8.  Determine if this is the same index filepath as already loaded
;; 9.  If not, write file if needed.
;;10.  Load new file.  If not there, create one -- and dummy the file out.
;;11.  Reset to the beginning of the binary tree index
;;12.  Find the file in index.  If found, then goto 14
;;13.  File not in index. If room, add it and return:  file has not been
;;     compressed, obviously.  New entry updated with current date and time.
;;14.  If file not compressed, merely update date and time and return.
;;15.  If file is compressed, check to make sure it is, then decompress it
;;     into temporary file named PCOMPRESS.$$$ and return
;;16.  If, upon examination file is not a compressed one, reset to normal
;;     status
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lookup:
	mov	cs:[was_compressed], FALSE

	cld
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	es


	push	dx
	mov	ax, 04400h			; ioctl call returns status
	mov	bx, cs:[dos_handle]		; in the dx register
	mov	cx, 2
	xor	dx, dx
	int	21h
	test	dx, 080h			; devices have high bit set
	pop	dx

	jz	@F				; not set, a file
	jmp	done2				; is a character device
	
@@:	push	cs				; a regular file
	pop	es
	mov	si, dx
	mov	di, offset tmp_buffer
	mov	ah, 60h				; undocumented DOS call to
	int	21h				; fully qualify a file/path
						; knows about SUBST and ASSIGN

	mov	dl, es:[di]			; get the disk letter
	sub	dl, 'A' - 1			; A=1, B=2, etc...
	mov	ah, 1ch				; get disk parameters
	int	21h
	cmp	byte ptr [bx], 0f8h		; on return, DS:BX points to
	jz	@F				; first FAT entry. F8 is fixed
	jmp	done2				; disk. Anything else, we skip

@@:	mov	ah, 051h			; get users PSP, save
	int	21h				; then swap our's in.
	mov	cs:[users_psp], bx
	mov	bx, cs:[my_psp]
	mov	ah, 050h
	int	21h

;;;;;;;;;;;;;;;;;
;; separate the path from the filename into two buffers.
;;;;;;;;;;;;;;;;;

	xor	cx, cx
end_path:
	mov	al, es:[di]
	cmp	al, 0			; end of path? (ASCIIZ)
	jz	@F			; yes
	inc	cx
	inc	di
	cmp	al, '\'			; path delimiter?
	jnz	end_path
	mov	cs:[tmp_len], cx	; save length
	jmp	end_path

@@:	push	cs			; create path to filename
	pop	ds
	mov	si, offset cs:[tmp_buffer]
	mov	di, offset cs:[dir_name]
	mov	cx, cs:[tmp_len]

	cld
@@:	movsb					; move the path over
	loop	@B

;;;;;;;;;;;;;;;;
;;  Stuff index name onto path
;;;;;;;;;;;;;;;;

	mov	si, offset cs:[index_name]
	mov	cx, INDEX_NAME_LEN
	cld
@@:	movsb
	loop	@B

;;;;;;;;;;;;;;;;
;;  Stuff temporary filename onto path
;;;;;;;;;;;;;;;;
	mov	si, offset cs:[tmp_buffer]
	mov	di, offset cs:[dir_name3]
	mov	cx, cs:[tmp_len]

	cld
@@:	movsb					; move the path over
	loop	@B


	mov	si, offset cs:[file_out]
	mov	cx, FILE_OUT_LEN
	cld
@@:	movsb
	loop	@B

;;;;;;;;;;;;;;;;;;;;;;;;
;;  Same index name as last time?
;;;;;;;;;;;;;;;;;;;;;;;;

	mov	si, offset cs:[dir_name]
	mov	di, offset cs:[dir_name2]
	mov	cx, cs:[tmp_len]
	cld
	repz	cmpsb				; pop out on no match
	cmp	byte ptr cs:[di], 'I'		;first letter of "INDEX.CMP"
	jnz	@F				; not a match
	cmp	cx, 0				; all through and a match?
	jnz	@F
	jmp	a_match				; yes
						; no match, fall through

;;;;;;;;;;;;;;;;;;;;;
;;  New index file.  Close the old one first, then create a new one
;;  if needed with blank entries.
;;;;;;;;;;;;;;;;;;;;;

index_open:
@@:	mov	bx, [index_handle]		; close file on change
	cmp	bx, 0				; first time?
	jz	@F				; yes
	call	update_file			; update the old file and
	mov	ah, 03eh			; do the close
	int	21h

reset_attrb:
	push	cx
	mov	ax, 04301h
	mov	dx, offset dir_name2
	mov	cx, [old_attrb]
	int	21h
	pop	cx


@@:	mov	ax, 04300h			; save the current attributes
	mov	dx, offset dir_name
	int	21h
	jc	no_file
	mov	[old_attrb], cx

	mov	ax, 04301h			; make it readable
	mov	dx, offset dir_name
	mov	cx, 0
	int	21h

	mov	ax, 3d02h			; open the new file up
	mov	dx, offset dir_name
	int	21h
	jc	no_file				; no file. Create one.

	mov	cs:[index_handle], ax
	mov	bx, ax

	mov	cs:[num_files], 0		;; ??
	mov	cx, size num_files + BUF_SIZE + MAX_FN_SIZE
	mov	dx, offset cs:[num_files]	; buffer to read into
	mov	ah, 03fh
	int	21h
	jnc	a_match				; read okay!

no_file:
	mov	ah, 03ch			; create a new file
	mov	dx, offset cs:dir_name
	mov	cx, 0
	int	21h

	push	cs:[attributes]			; mov attributes as if old file
	pop	cs:[old_attrb]

	jnc	@F
	jmp	done				;problem


;;;;;;;;;;;;;
;; Zero out what will be the contents of the new file
;;;;;;;;;;;;;
@@:	mov	bx, ax
	mov	cs:[index_handle], ax

	mov	cx, size num_files + BUF_SIZE + MAX_FN_SIZE
						; Zero out buffer
	mov	di, offset cs:num_files
@@:	mov	byte ptr cs:[di], 0
	inc	di
	loop	@B

	mov	si, offset cs:[dir_name]	; but load index file name
	mov	di, offset cs:[dir_name2]
	mov	cx, cs:[tmp_len]
	add	cx, INDEX_NAME_LEN

	cld
@@:	movsb
	loop	@B

;;;;;;;;;;;;;;;;;;;
;; write out with zero files, index filename, an empty buffer
;;;;;;;;;;;;;;;;;;;
	mov	cx, BUF_SIZE + size num_files + MAX_FN_SIZE
	mov	dx, offset cs:num_files
	mov	ah, 040h
	int	21h
	call	commit				; make sure it gets written

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;	At this point, the index is loaded into memory. Find the file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

a_match:
	mov	si, offset cs:[tmp_buffer]
	add	si, cs:[tmp_len]			;pointer to filename
	mov	di, offset cs:[file_name]
	mov	cs:[file_seg], es
	mov	cs:[file_off], di

@@:	mov	al, ds:[si]				; move filename again
	mov	es:[di], al
	inc	di
	inc	si
	cmp	al, 0
	jnz	@B

	push	cs
	pop	ds

	mov	ax, 1				; get first one
	call	get_pointer			; bx gets pointer to entry

look_lp:
	mov	ds, cs:[file_seg]		; source seg
	push	cs
	pop	es				; target seg - the buffer

	mov	si, cs:[file_off]		; get back the filename
	mov	di, bx
	add	di, filename			; and point to it in record
	mov	cx, word ptr cs:[bx].filename_len	
	cmp	cx, 0
	jz	no_match			; if empty record

@@:	mov	al, ds:[si]
	cmp	al, es:[di]
	jnz	no_match			; try again
	inc	si
	inc	di
	loop	@B

	inc	cs:[dirty_bit]			; found it!
	call	update				; a match.  Update it.
	jmp	done

						
done:
	mov	bx, cs:[users_psp]		;reset users PSP and return
	mov	ah, 050h
	int	21h
done2:
	pop	es
	pop	ds
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

;;;;;;;;;;;;;;;
;; Current entry isn't what we want.  Try next one.
;;;;;;;;;;;;;;;

no_match:
	push	cs
	pop	ds
	mov	ax, [bx].left_ptr	; assume less than
	mov	dx, left_ptr
	jl	@F
	mov	ax, [bx].right_ptr	; greater than, use right pointer
	mov	dx, right_ptr
@@:	cmp	ax, 0			; end of the line?
	jz	@F			; yes
	call	get_pointer		; bx points to next entry
	jmp	look_lp			; se if a match

;;;;;;;;;;
;; insert routine
;;;;;;;;;;
@@:	cmp	cs:[num_files], MAX_FILES	; full already?
	jnz	@F			; no
	jmp	done			; yes.  Ignore it.
@@:	inc	cs:[num_files]		; increase the count
	mov	ax, cs:[num_files]
	add	bx, dx			; left or right pointer offset
	mov	cs:[bx], ax
	inc	cs:[dirty_bit]
	call	get_pointer		; point to empty record

;;;;;;;;;;;;;;;;;;
;; copy the name into the buffer
;;;;;;;;;;;;;;;;;;
	mov	ds, cs:[file_seg]	; source seg
	push	cs
	pop	es			; target seg - the buffer

	mov	si, cs:[file_off]	; get back the filename
	mov	di, bx
	add	di, filename
	xor	cx, cx
	cld
@@:	movsb
	inc	cx
	cmp	byte ptr ds:[si], 0
	jnz	@B
;;;;;;;;;;;;;;;;
;; set up the rest of the entry
;;;;;;;;;;;;;;;;

	mov	byte ptr es:[di], 0		; trailing null: nice for 'C'
	mov	cs:[bx].filename_len, cx
	mov	cs:[bx].left_ptr, 0
	mov	cs:[bx].right_ptr, 0
	mov	cs:[bx].access_cnt, 1
	mov	cs:[bx].status, NORMAL
	inc	cs:[dirty_bit]

	call	update				; add date and time
	jmp	done

;;;;;;;;;;;;;;;;;;;;;
;;  Returns bx as in  bx = (ax * size entry) + buffer offset
;;  ax is the entry we seek
;;;;;;;;;;;;;;;;;;;;


get_pointer	proc	near
	push	cx
	push	dx

	dec	ax
	mov	bx, ax
	mov	cx, size file
	mul	cx
	xchg	ax, bx
	add	bx, offset cs:[buffer]

	pop	dx
	pop	cx
	ret
get_pointer	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Write all the stuff in the current buffer out to disk
;;;;;;;;;;;;;;;;;;;;;;;;;;;
update_file	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	ds

	push	cs
	pop	ds


	mov	cs:[dirty_bit], 0		; now we're clean

	xor	cx, cx				; lseek to beginning
	xor	dx, dx
	mov	ax, 04200h
	mov	bx, cs:[index_handle]
	int	21h

	mov	dx, offset num_files 		; write it
	mov	cx, BUF_SIZE + size num_files + MAX_FN_SIZE
	mov	ah, 040h
	int	21h

	call	commit				; make sure it's written

	pop	ds
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
update_file	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Add date and time.  If compressed, decompress.
;;;;;;;;;;;;;;;;;;;;;;;;;;;

update:
	mov	ah, 02ah		; get the date
	int	21h
	mov	cs:[bx].date, cx
	mov	cs:[bx].date + 2, dx
	mov	ah, 02ch		; get the time
	int	21h
	mov	cs:[bx].time, cx	; stuff them
	mov	cs:[bx].time + 2, dx
	inc	cs:[bx].access_cnt	; up the access count
	cmp	cs:[ignore_status], TRUE
	jz	do_it_anyway
	cmp	cs:[bx].status, COMPRESSED
	jnz	@F			; normal
do_it_anyway:
	push	bx			; save the entry pointer
	call	decompress		; expand the file
	pop	bx
	mov	cs:[bx].status, NORMAL	; reset the status
	inc	cs:[dirty_bit]		; we have to write now.
@@:	ret

;;;;;;;;;;;;;;;;;;;;;;;;
;;  Is it really compressed?
;;;;;;;;;;;;;;;;;;;;;;;;
decompress:
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si

;;;;;;;;;;;;
;; Read the first few bytes, see if it matches our unique entry
;;;;;;;;;;;;
	mov	dx, offset cs:tmp_buffer
	add	dx, filename
	mov	ax, 3d00h
	int	21h
	jc	bad_decom2		; can't decompress if can't open!

	mov	cs:[in_handle], ax
	mov	bx, ax
	mov	cx, TAG_LEN 		; read the first coupla bytes in
	mov	dx, offset cs:tag_buf
	mov	ah, 03fh
	int	21h
	jc	bad_decom		; too short for one of ours!
	cmp	ax, TAG_LEN
	jl	bad_decom

	mov	si, offset cs:tag	; our tag line?
	mov	di, dx
	mov	cx, TAG_LEN
@@:	mov	al, byte ptr cs:[si]
	cmp	al, byte ptr cs:[di]
	jnz	bad_decom
	loop	@B			; a match?

	call	do_decomp		; yes! Decompress it

bad_decom:
	mov	bx, cs:[in_handle]	; close the file
	mov	ah, 03eh
	int	21h
bad_decom2:
	cmp	cs:[bx].status, NORMAL	; if it was normal, don't set dirty bit
	jz	@F
	mov	cs:[dirty_bit], TRUE

@@:	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Open a duplicate handle on the file, then close the duplicate handle.
;;  This causes brain damaged dos to commit the file, regardless of
;;  version
;;;;;;;;;;;;;;;;;;;;;;;;;;
commit	proc	near
	push	ax
	push	bx
	mov	ah, 045h
	mov	bx, cs:[index_handle]
	int	21h
	mov	bx, ax
	mov	ah, 03eh
	int	21h
	pop	bx
	pop	ax
	ret
commit	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  LZW compression routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;
;; Zero out the table.
;;;;;;;;;;;;;;;;

init_tab	proc	near
	push	ax
	push	cx
	push	si
	push	ds

	xor	ax, ax
	mov	cx, 256
	mov	si, offset cs:codes
	push	cs
	pop	ds
lp:
	mov	[si].cmp_code, 0
	mov	[si].suffix, al
	inc	al
	add	si, size table
	loop	lp

	mov	cs:[codes_used], 256

	pop	ds
	pop	si
	pop	cx
	pop	ax
	ret
init_tab	endp

;;;;;;;;;;;;;;;;;;;;;
;;  Actual decompression routine
;;;;;;;;;;;;;;;;;;;;;

do_decomp	proc	near

	call 	paint			; XT owners don't think we crashed...

	call	init_tab

	mov	cs:[which_code], 0	; initialize a bunch of variables
	mov	cs:[hold], 0
	mov	cs:[s_ptr], offset cs:stack	; not a real stack
	mov	cs:[out_cnt], 0
	mov	cs:[buff_cnt], 0
	mov	cs:[buff_size], 0
	mov	cs:[tmp], 0

	push	cs
	pop	ds

	mov	dx, offset cs:dir_name3		; create the temporary file
	xor	cx, cx
	mov	ah, 03ch
	int	21h
	mov	cs:[out_handle], ax

	call	get_code		; read a code in
	mov	bl, al			; save it
	call	stuff			; stuff on the stack
	call	unstuff			; unstuff into the output file
	mov	cs:[old_code], ax	; save it
	mov	cs:[last_char], bl	; save it
decode:
	call	get_code		; loop. Get a code. expand it.
	jc	exit			; we're done on carry
	cmp	ax, RESET_TABLE		; table full in compressor?
	jnz	no_exit

	call	init_tab		; yes. Reset everything

	call	get_code		; and start over
	mov	bl, al
	call	stuff
	call	unstuff
	mov	cs:[old_code], ax
	jmp	decode			; now we're back to normal

exit:
	call	output			; exit. Force output of last code
	mov	bx, cs:[out_handle]
	mov	ah, 03eh
	int	21h			; close decomp'ed temp file

	mov	cs:[was_compressed], TRUE

	call	paint			; Yo! XT owner! Wake up!
	ret				; good-run exit point

no_exit:
	mov	cs:[incode], ax		; save the code
	cmp	ax, cs:[codes_used]	; already in table?
	jl	@F			; yes

;;;;;;;;;;;;;;;;;;;;;;;;;
;; Special class of codes for highly repetitive strings.  The code can
;; be transmitted before it exists!  So, we simply add a new code
;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	ax, cs:[old_code]
	mov	bl, cs:[last_char]
	call	stuff

@@:	push	ax			; save the code
	mov	cx, size table		; get the suffix
	mul	cx
	mov	si, ax
	add	si, offset cs:codes
	pop	ax
	cmp	ax, 256			; "low" code?
	jl	@F			; yup. End loop
	mov	bl,cs:[si].suffix
	call	stuff			; enter onto stack
	mov	ax, cs:[si].cmp_code	; next code in code sequence
	jmp	@B			; loop

@@:	mov	bl, cs:[si].suffix	; do the last char
	mov	cs:[last_char], bl	; and save it
	call	stuff			; add to stack
	call	unstuff			; write out whole stack
	
	cmp	cs:[codes_used], MAX_CODE	; full table?
	jz	@F				; yup

;;;;;;;;;;;;;;;;;;;;
;;  Add the code into the table
;;;;;;;;;;;;;;;;;;;;;
	mov	ax, cs:[codes_used]
	mov	cx, size table
	mul	cx
	mov	si, ax
	add	si, offset cs:codes
	mov	ax, cs:[old_code]
	mov	cs:[si].cmp_code, ax
	mov	al, cs:[last_char]
	mov	cs:[si].suffix, al
	inc	cs:[codes_used]		; up the number of codes used in table

@@:	mov	ax, cs:[incode]		; save original code
	mov	cs:[old_code], ax
	jmp	decode			; next!

do_decomp	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  The codes are actually 12 bit entities:  a byte and a half.  So, take
;;  turns reading two bytes, returning 12 bits, then one byte, returning
;;  old half byte (a nibble) and new byte.  That's a code.  And it fits
;;  within a register.  How nifty!
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
get_code:
	cmp	cs:[which_code], 0		; even or odd code?
	jnz	odd_code

	call	get_byte			; get the first byte
	jc	get_code_ret			; eof

	xor	ax, ax
	mov	al, byte ptr cs:[tmp]		; get byte 
	mov	cl, 4				; and pop it down a nibble
	shl	ax, cl

	call	get_byte			; get next byte
	jc	get_code_ret			; eof

	mov	bx, ax				; turn it into a code and save
	xor	ax, ax				; left over nibble.
	mov	al, byte ptr cs:[tmp]
	mov	cs:[hold], ax
	and	cs:[hold], 0fh			; set the leftover flag.
	mov	cl, 4
	shr	ax, cl
	or	ax, bx
	mov	cs:[which_code], 1
	clc
	jmp	get_code_ret

odd_code:
	mov	ax, cs:[hold]			; retrieve left over nibble
	mov	cl, 8				; pop it up
	shl	ax, cl
	call	get_byte			; get next byte
	jc	get_code_ret			; eof?  Shouldn't happen
	or	al, byte ptr cs:[tmp]		; add it in
	mov	cs:[which_code], 0		; set for even read next time

get_code_ret:
	ret					; code in ax

;;;;;;;;;;;;;;;;;;;;;;
;;  characfter in bl gets stuffed onto stack
;;;;;;;;;;;;;;;;;;;;;;
stuff:
	push	si
	mov	si, cs:[s_ptr]
	inc	cs:[s_ptr]
	mov	byte ptr cs:[si], bl
	pop	si
	ret

;;;;;;;;;;;;;;;;;;;;;;;;
;;  Get characters off stack in reverse order. Add to buffer. Write buffer
;;  if it gets too large
;;;;;;;;;;;;;;;;;;;;;;;;
unstuff:
	push	ax
	push	bx
	push	si

	mov	si, cs:[s_ptr]

unstuff_lp:
	dec	si
	cmp	si, offset cs:stack
	jl	unstuff_end
	cmp	cs:[out_cnt], INBUF_SIZE
	jnz	@F
	call	output
@@:	mov	al, byte ptr cs:[si]
	mov	bx, cs:[out_cnt]
	inc	cs:[out_cnt]
	add	bx, offset cs:out_buf
	mov	byte ptr cs:[bx], al
	jmp	unstuff_lp

unstuff_end:
	mov	cs:[s_ptr], offset cs:stack	; reset the stack
	pop	si
	pop	bx
	pop	ax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Write the data out to the output temporary file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
output	proc	near
	cmp	cs:[out_cnt], 0
	jz	output_ret

	push	ax
	push	bx
	push	cx
	push	dx
	push	ds

	mov	bx, cs:[out_handle]
	mov	cx, cs:[out_cnt]
	mov	ah, 040h
	push	cs
	pop	ds
	mov	dx, offset cs:out_buf
	int	21h
	mov	cs:[out_cnt], 0

	pop	ds
	pop	dx
	pop	cx
	pop	bx
	pop	ax

output_ret:
	ret
output	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Read a buffer in. Return next byte in buffer, reading in buffers as
;;  required.
;;  Return with carry set when you reach EOF.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
get_byte	proc	near
	push	ax
	push	bx
	push	cx
	push	dx

	mov	ax, cs:[buff_cnt]
	cmp	ax, cs:[buff_size]
	jnz	buffer_ok


	mov	dx, offset cs:in_buffer
	mov	cx, INBUF_SIZE		; must be evenly divisible by 1.5
	mov	bx, cs:[in_handle]
	mov	ah, 03fh
	int	21h
	mov	cs:[buff_size], ax
	mov	cs:[buff_cnt], 0
	cmp	ax, 0
	jz	eof

buffer_ok:
	clc
	mov	bx, cs:[buff_cnt]
	inc	cs:[buff_cnt]
	mov	al, byte ptr cs:[bx + in_buffer]
	mov	cs:[tmp], al
	jmp	get_byte_ret

eof:
	stc

get_byte_ret:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
get_byte	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Simply rename the temporary file into the real filename name
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

rename	proc	near
	push	ax
	push	dx
	push	di
	push	ds
	push	es

	push	cs
	pop	ds
	push	cs
	pop	es
	mov	di, offset cs:tmp_buffer
	mov	dx, offset cs:dir_name3
	mov	ah, 056h
	int	21h

	pop	es
	pop	ds
	pop	di
	pop	dx
	pop	ax
	ret

rename	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Paint message on screen by exchanging bytes. Two calls and everything
;;  is back to normal
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
paint	proc	near
	push	ax
	push	cx
	push	si
	push	di
	push	es
	mov	es, cs:[screen_segment]
	mov	si, SCREEN_OFFSET
	xor	di, di
	mov	cx, SCREEN_LEN
scr_lp1:
	mov	ax, word ptr es:[si]
	xchg	al, cs:[screen_msg + di]
	xchg	ah, cs:[screen_attrb + di]
	mov	word ptr es:[si], ax
	inc	si
	inc	si
	inc	di
	loop	scr_lp1

	pop	es
	pop	di
	pop	si
	pop	cx
	pop	ax
	ret
paint	endp
;; end of resident code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; start of transient code


;;;;;;;;;;;;;;;;;;;;;;
;;  See if we're already installed.  If so, print a message and exit
;;  Otherwise, save the old Dos interrupt vector, take it over for our
;;  purposes, output a nice message, and save our own psp in the code
;;  segment before exiting with a bunch of memory saved

install:
	mov	ax, 0fedch
	int	21h
	cmp	ax, 0cdefh
	jnz	@F
	jmp	already_in
@@:	mov	ax, 03521h
	int	21h
	mov	cs:[old_dos], bx
	mov	cs:[old_dos + 2], es

	mov	ax, 02521h
	push	cs
	pop	ds
	mov	dx, offset new_dos
	int	21h
	mov	dx, offset good_inst_msg
	mov	ah, 9
	int	21h
	mov	ah, 051h
	int	21h
	mov	cs:[my_psp], bx
	mov	ax, 03100h

	mov	si, 80h			; point to arguments
	mov	cl, byte ptr [si]
	xor	ch, ch
	cmp	cx, 0
	jz	@F
@@:	inc	si
	cmp	byte ptr [si], '-'
	jz	got_minus
	cmp	byte ptr [si], '/'
	jnz	not_arg
got_minus:
	cmp	byte ptr [si + 1], 'i'
	jz	got_arg
	cmp	byte ptr [si + 1], 'I'
	jnz	not_ignore
got_arg:
	mov	cs:[ignore_status], TRUE
	jmp	not_arg

not_ignore:					; -A#
	cmp	byte ptr [si + 1], 'a'
	jz	got_arg2
	cmp	byte ptr [si + 1], 'A'
	jnz	not_arg
got_arg2:
	mov	al, byte ptr [si + 2]
	sub 	al, '0'
	jl	not_arg
	cmp	al, 3
	jg	not_arg
					;0= visible, writable
					;1= hidden, writable
					;2= visible, not writable
					;3= hidden, not writable
	test	al, 1
	jz	not_hidden
	or	cs:[attributes], 2
not_hidden:
	test	al, 2
	jz	not_write_protect
	or	cs:[attributes], 1

not_write_protect:

not_arg:
	loop	@B

@@:	mov	dx, offset install
	shr	dx, 1
	shr	dx, 1
	shr	dx, 1
	shr	dx, 1

	inc	dx
	int	21h
	int	20h

already_in:
	mov	dx, offset bad_inst_msg
	mov	ah, 9
	int	21h
	mov	ax, 04c01h
	int	21h
	
bad_inst_msg	db	CR, LF, BELL, 'DCOMPRES already installed...'
		db	CR, LF, '$'
good_inst_msg	db	CR, LF, 'DCOMPRES Copyright (c) 1989 by Ziff Communications Co.  Program by Ross M. Greenberg'
		db	CR, LF, LF, 'COMPRESS installed.', CR, LF, LF, '$'
@@	equ	good_inst_msg


cseg	ends
end	start

