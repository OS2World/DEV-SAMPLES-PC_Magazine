
�MDNM�QB.BAT



ECHO OFF
CD\
TYPE START.QB > START.QB
DIR C:\START.QB | FIND "START" >> C:\RECORDS\QB.LOG
DEL START.QB
CD\QB45
QB
CD\
TYPE END.QB > END.QB
DIR C:\END.QB | FIND "END" >> C:\RECORDS\QB.LOG
DEL END.QB


