* functest.prg RHS 2/20/89
* This program demonstrates the use of a dBASEIV User-Defined Function
* which you can use to create windowed error messages.
* 
* The function, wmsg() requires two parameters.
* The first parameter is the message you wish to print.
* The second parameter is used to prompt the user to press any key or a 
* particular key. The function will return the keystroke pressed.
*
* For instance,
*    choice = wmsg("Ready to re-index database.","Proceed? (Y/N)")
*    if upper(choice) = 'Y'
*        && reindex database
*    endif
*
*
* The only requirement for using the function, is that you must define the
* msg_win window somewhere in your program code.



Define Window msg_win from 12,5 to 15,75 double color gr+/r

retval = wmsg("This error message appears in a window...","...Press any key")
?"Return value was ",retval
return



Function wmsg
    Parameters msg,prompt
    Activate Window msg_win			&& activate the window
    @ 0,0 Say msg				&& print main message
    Wait prompt To retval			&& print prompt, wait for key 
    Deactivate Window msg_win			&& deactivate window
    Return retval				&& return key
	
