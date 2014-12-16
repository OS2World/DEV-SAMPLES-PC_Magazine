ECHO OFF
IF %2'==' GOTO syntax_error
SET movepath=%3
IF %3'==' GOTO begin
SET movepath=%1\
SHIFT
GOTO begin
:syntax_error
ECHO Syntax is: MOVE [source_directory] filename destination_directory
GOTO end
:begin
IF EXIST %movepath%%1 GOTO L1
ECHO Error. Source file does not exist!
GOTO end
:L1
REM DELETE==* IF EXIST %2\%1 DEL %2\%1 
REM DELETE==* IF NOT EXIST %2\%1 GOTO L2 
REM DELETE==* ECHO Error. Old version could not be deleted! 
REM DELETE==* GOTO end
REM DELETE==* :L2
COPY %movepath%%1 %2\%1
IF EXIST %2\%1 GOTO L3
ECHO Error. Copy unsuccessful!
GOTO end
:L3
DEL %movepath%%1
IF NOT EXIST %movepath%%1 GOTO L4
ECHO Error. Could not delete the original!
GOTO end
:L4
ECHO Successful Move.
:end
