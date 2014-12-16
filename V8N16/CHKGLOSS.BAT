
c:
cd \word
word
echo off
dir *.gly
dir bu\*.gly
echo	Please compare file sizes 
echo   	and hit ^C to leave batch file or
pause
xcopy c:\word\*.gly c:\word\bu /m
