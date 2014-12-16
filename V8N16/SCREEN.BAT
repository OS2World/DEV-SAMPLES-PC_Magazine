ECHO OFF
IF "%PROM%"=="" SET PROM=%PROMPT%
ECHO [1;37;40m
CLS
IF NOT "%1"=="" GOTO GotParams
ECHO Each row is numbered with a foreground color.
ECHO Each column is numbered with a background color.
ECHO To select a color, simply enter "SCREEN f b",
ECHO where f is the foreground color and b the background.
ECHO Add a B for Bright, e.g. "SCREEN 3 1 B".
ECHO Press a key when you're done looking at the chart.
REM Five spaces between 7 and 0 in next line.
ECHO [9;26H0 1 2 3 4 5 6 7     0 1 2 3 4 5 6 7
REM 14 spaces between Normal and Bright in next line.
ECHO [18;26HNormal              Bright
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;24H%%c
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;26H[0;3%%c;40mXX[18C[1mXX
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;28H[0;3%%c;41mXX[18C[1mXX
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;30H[0;3%%c;42mXX[18C[1mXX
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;32H[0;3%%c;43mXX[18C[1mXX
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;34H[0;3%%c;44mXX[18C[1mXX
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;36H[0;3%%c;45mXX[18C[1mXX
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;38H[0;3%%c;46mXX[18C[1mXX
FOR %%c IN (0 1 2 3 4 5 6 7) DO ECHO [1%%c;40H[0;3%%c;47mXX[18C[1mXX
PAUSE > NUL
ECHO [1;37;40m
GOTO end
:GotParams
IF "%2"=="" GOTO BadParams
IF NOT "%3"=="" IF NOT "%3"=="b" IF NOT "%3"=="B" GOTO BadParams
SET fore=X
FOR %%c IN (0 1 2 3 4 5 6 7) DO IF %1==%%c SET fore=%1
IF %fore%==X GOTO BadParams
SET back=X
FOR %%c IN (0 1 2 3 4 5 6 7) DO IF %2==%%c SET back=%2
IF %back%==X GOTO BadParams
SET bright=0
IF NOT "%3"=="" SET bright=1
PROMPT %PROM%[%bright%;4%back%;3%fore%m
ECHO ON
CLS
ECHO OFF
SET fore=
SET back=
SET bright=
GOTO end
:BadParams
ECHO To display all color combinations, enter "SCREEN" with no parameters.
ECHO To set foreground color f and background color b, enter
ECHO     SCREEN f b
ECHO where f and b are both from 0 to 7.  To make the foreground
ECHO color BRIGHT, add a B.  For example, to set bright yellow text
ECHO on a red background,
ECHO     SCREEN 3 1 B
:End

