* wintest.prg RHS 2/19/89

* This program demonstrates the new windowing and menuing abilities of 
* dBASEIV. As a first task, the program creates a window, and prints a 
* message. Then, it waits until the user presses a key. Upon receiving the
* keystroke, the program moves the window from the upper left corner, to the
* upper right corner, to the lower right corner, to the lower left corner,
* and finally, back to the upper right corner.
*
* After removing the window, a horizontal menu, its pads, a popup menu for
* for each pad, and their bars are defined. Since each popup menu is 
* associated with a pad, each becomes a pulldown menu.

* You'll notice that the arrangement and titles of the menu pads and 
* pulldowns are a deliberate copy of the Windows-type user interface.

* It should be easy to copy the ideas presented in this example program for
* use in an application.

Set Talk off
* First, define a Window....
Define Window wtest from 1,5 to 7,25 double

* Then activate it
Activate Window wtest

* Print a message in it
@ 0,0 say "An example of dBASEIV windowing..."
Wait

* Now move the window around the screen, first right...
counter = 1
Do While counter < 50
    Move Window wtest by 0,1
    counter = counter+1
EndDo

* Then down...
counter2 = 1
Do While counter2 < 15
    Move Window wtest by 1, 0
    counter2 = counter2+1
EndDo

* Then left...
Do While counter > 0
    Move Window wtest by 0,-1
    counter = counter - 1
EndDo

* And back up...
Do While counter2 > 0
    Move Window wtest by -1,0
    counter2 = counter2-1
EndDo

* now deactivate it and remove it from memory
DeActivate Window wtest
Clear Windows

* now define a horizontal menu
Define Menu Main
* and define the individual pads (selections) in it...
Define Pad File of Main Prompt "File" At 0,4
Define Pad Edit of Main Prompt "Edit" At 0,16
Define Pad View of Main Prompt "View" At 0,30
Define Pad Search of Main Prompt "Search" At 0,38

* now associate popup menus with each pad to make pulldown menus
On Pad File Of Main Activate Popup File_pop
On Pad Edit of Main Activate Popup Edit_pop
On Pad View of Main Activate Popup View_pop
On Pad Search of Main Activate Popup Search_pop

* now define each popup menu...

* define the first popup
Define Popup File_pop from 1,4 Message "File Operations"
* define its menu bars
Define Bar 1 of File_pop Prompt "New"
Define Bar 2 of File_pop Prompt "Open..."
Define Bar 3 of File_pop Prompt "Open Last File"
Define Bar 4 of File_pop Prompt "Merge"
Define Bar 5 of File_pop Prompt "Save"
Define Bar 6 of File_pop Prompt "Save As..."
* Leave a blank bar on line 11 of the popup
Define Bar 8 of File_pop Prompt "Set Program List..."
Define Bar 9 of File_pop Prompt "Clear Program List..."
Define Bar 10 of File_pop Prompt "Edit Program List..."
* Leave a blank bar on line 11 of the popup
Define Bar 12 of File_pop Prompt "Print..."
Define Bar 13 of File_pop Prompt "DOS Shell"

* define the next popup
Define Popup Edit_pop from 1,16 Message "Editing Facilities"
* define its menu bars
Define Bar 1 of Edit_pop Prompt "Undo"
Define Bar 2 of Edit_pop Prompt "Cut"
Define Bar 3 of Edit_pop Prompt "Paste"
Define Bar 4 of Edit_pop Prompt "Clear"
*      Bar 6 remains blank
Define Bar 6 of Edit_pop Prompt "Read Only"

* define another popup
Define Popup View_pop from 1,30 Message "Views Available"
* define its menu bars
Define Bar 1 of View_pop Prompt "Source"
Define Bar 2 of View_pop Prompt "Include"
*      Bar 3 remains blank
Define Bar 4 of View_pop Prompt "Options..."
Define Bar 5 of View_pop Prompt "Output Screen"
*      Bar 6 remains blank
Define Bar 7 of View_pop Prompt "Errors"

* define the last popup
Define Popup Search_pop from 1,38 Message "Search Options"
* define its menu bars
Define Bar 1 of Search_pop Prompt "Find..."
Define Bar 2 of Search_pop Prompt "Selected Text"
Define Bar 3 of Search_pop Prompt "Repeat Last Find"
Define Bar 4 of Search_pop Prompt "Change"
Define Bar 5 of Search_pop Prompt "Function"

* Now set up a procedure to be executed if the File_pop popup is activated
On Selection Popup File_pop Do OpenFile

* activate the horizontal menu
Activate Menu Main
Return

Procedure OpenFile		&& can process menu selections for File_pop
    Do Case
	Case Bar() = 2		&& for "Open..."
		Define Popup files From 4,5 To 20,35 Prompt Files Like *.dbf
		Activate Popup Files
    Endcase
    Return

