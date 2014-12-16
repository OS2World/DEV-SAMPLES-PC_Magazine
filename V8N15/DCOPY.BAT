

------------------------- DCOPY.BAT --------------------------
REM  This batch file is used to move .DOC files from the main
REM  word processing directory to sub-directories named JAN -
REM  DEC. It should be called from the main word processing
REM  directory. After checking to see that everything copied
REM  correctly the source files should be deleted manually.
ECHO OFF
ATTRIB +A *.DOC
MD JAN
MD FEB
MD MAR
MD APR
MD MAY
MD JUN
MD JUL
MD AUG
MD SEP
MD OCT
MD NOV
MD DEC
XCOPY *.DOC \DEC /D:12-01-1988 /M
XCOPY *.DOC \NOV /D:11-01-1988 /M
XCOPY *.DOC \OCT /D:10-01-1988 /M
XCOPY *.DOC \SEP /D:09-01-1988 /M
XCOPY *.DOC \AUG /D:08-01-1988 /M
XCOPY *.DOC \JUL /D:07-01-1988 /M
XCOPY *.DOC \JUN /D:06-01-1988 /M
XCOPY *.DOC \MAY /D:05-01-1988 /M
XCOPY *.DOC \APR /D:04-01-1988 /M
XCOPY *.DOC \MAR /D:03-01-1988 /M
XCOPY *.DOC \FEB /D:02-01-1988 /M
XCOPY *.DOC \JAN /D:01-01-1988 /M
ECHO ON
