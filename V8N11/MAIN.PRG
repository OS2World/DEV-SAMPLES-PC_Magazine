
* Program MAIN.PRG
	.
	.
	.
* Function ALLTRIM() is user-defined
SCAN
lc_pict = lc_pict + ALLTRIM(LASTNAME) + ','
ENDSCAN
	.
	.
	.
* EOP: MAIN.PRG
* Function ALLTRIM() is a user-defined function
* It removes leading and trailing blanks
FUNCTION ALLTRIM
PARAMETERS lc_string
PRIVATE lc_string
lc_string = LTRIM(RTRIM(lc_string))
RETURN(lc_string)
* EOF: FUNCTION ALLTRIM()
