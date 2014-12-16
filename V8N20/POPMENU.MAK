#-------------------
# POPMENU make file
#-------------------

popmenu.obj : popmenu.c popmenu.h
     cl -c -G2sw -W3 popmenu.c

popmenu.res : popmenu.rc popmenu.h
     rc -r popmenu

popmenu.exe : popmenu.obj popmenu.def
     link popmenu, /align:16, NUL, os2, popmenu
     rc popmenu.res

popmenu.exe : popmenu.res
     rc popmenu.res



