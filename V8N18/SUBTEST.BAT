
SUBTEST.BAT

1    ECHO OFF 
2    REM Batch file to illustrate internal subroutines. 
3    REM Usage: 
4    REM C> SUBTEST MAIN1 
5    REM C> SUBTEST MAIN2 
6     
7    GOTO %1 
8     
9    :main1 
10   ECHO Entered MAIN1 routine 
11   SET arg=Arg #1 
12   SET rtn1=main1rtn 
13   GOTO sub1 
14   :main1rtn 
15   ECHO Returned from SUB1 to MAIN1RTN 
16   GOTO done 
17    
18   :main2 
19   ECHO Entered MAIN2 routine 
20   SET arg=Arg #2 
21   SET rtn1=main2rtn 
22   GOTO sub1 
23   :main2rtn 
24   ECHO Returned from SUB1 to MAIN2RTN 
25   GOTO done 
26    
27   :sub1 
28   ECHO Entered SUB1 routine with arg = %arg% 
29   SET rtn2=sub1rtn 
30   GOTO sub2 
31   :sub1rtn 
32   ECHO Returned from SUB2 to SUB1RTN 
33   GOTO %rtn1% 
34    
35   :sub2 
36   ECHO Entered SUB2 subroutine 
37   GOTO %rtn2% 
38    
39   :done 
40   SET rtn1= 
41   SET rtn2= 


