#------------------------
# BITFONTS.MAK make file
#------------------------

bitfont2.exe : bitfont2.obj bmf.obj bitfont2.def bitfont2.res
     link386 /BASE:0x10000 bitfont2 bmf,, NUL,, bitfont2
     rc bitfont2.res

bitfont2.obj : bitfont2.c bitfont2.h
     icc -C -Kbcpr -Ss bitfont2.c

bmf.obj : bmf.c bmf.h
     icc -C -Kbcpr -Ss bmf.c

bitfont2.res : bitfont2.rc bitfont2.h bmf.h
     rc -r bitfont2.rc
