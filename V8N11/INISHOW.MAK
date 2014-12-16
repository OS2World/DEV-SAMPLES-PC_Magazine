
#-------------------
# INISHOW make file
#-------------------

inishow.obj : inishow.c
     cl -c -G2 -W3 inishow.c

inishow.exe : inishow.obj inishow.def
     link inishow, /align:16, NUL, os2, inishow


