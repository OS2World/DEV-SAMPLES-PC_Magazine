

ECHO off
REM This is a generic batch executor written to
REM save disk space since DOS allocates a minimum
REM of 2K bytes of disk space regardless of the
REM filesize.  
REM **************************************************
cls
if x%1==x goto syntax
goto %1
REM **************************************************
REM Lotus 123
:123
cd\123
%1 %2
cd\
goto end
REM **************************************************
REM AutoCad-21
:CAD
set acadfreeram=25
cd\cad
acad
cd\
set acadfreeram=
goto end
REM **************************************************
REM Multimate Advantage II
:WP
cd\wp
wp
cd\
goto end
REM **************************************************
REM Show syntax if no parameters.
:SYNTAX
cls
ECHO  Syntax: run PROGRAM [optional program parameters]
ECHO  -------
ECHO  where : PROGRAM maybe one of the following.
ECHO  -------
ECHO     1) 123      - Lotus 123 Spreadsheet version 2.01
ECHO     2) cad      - AutoCad-21 version 2.52
ECHO        . . .  (many other entries)
ECHO    12) wp       - Multimate Advantage II Word Processor
ECHO    ----------------------------------------------------
ECHO    EXAMPLE: Type 'run 123' (without the quotes) to run
ECHO             LOTUS 123. Type 'run 123 vga' to run Lotus
ECHO             123 using a vga driver.
goto end
:end
if not x%1==x cls




