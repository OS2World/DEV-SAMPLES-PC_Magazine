;--------------------------------------------------------------------------
; FAMILY.SC - Prints the structure of all Paradox data bases (*.db) in
;             the current directory, along with listing of family members.
;             For Forms and Tables, the description is printed along with
;             the form/report number.
;--------------------------------------------------------------------------
CLEARALL

printok = PRINTERSTATUS()                        ;make sure printer is on
If printok THEN                                  ;printer is on, so go
   STYLE REVERSE                                 ;put message on screen
   @24,0
   ?? FORMAT("W80,ac","Printing Table Documentation")
   {Tools} {Info} {Inventory} {Tables} {}        ;get List of tables
   EDIT "list"
   OPEN PRINTER
   cur_rec = 1
   While cur_rec <= NRECORDS("list")             ;cycle through list of tables
      MOVETO RECORD cur_rec                      ;  but don't include the Pdox
      If    [Name] = "Answer"                    ;  temporary tables
         OR [Name] = "Struct"
         OR [Name] = "List"
         OR [Name] = "Family"
         OR [Name] = "Keyviol"
         OR [Name] = "Inserted"
         OR [Name] = "Changed"
         OR [Name] = "Crosstab"
         OR [Name] = "Deleted"
         OR [Name] = "Entry"
         THEN
         cur_rec = cur_rec + 1
         Loop
      EndIf
      cur_name = [Name]
      DO_IT!
      MENU {Tools} {Info} {Structure}            ;get structure of each table
      SELECT cur_name                            ;  and start printing
      PRINT  " \n\r"
      PRINT  "     " + cur_name + " Table\n\r"
      PRINT  " \n\r"
      PRINT  "     Field Name                 Field Type\n\r"
      PRINT  "     -------------------------  ----------\n\r"
      field_nbr = 1
      While field_nbr <= NRECORDS("struct")
         MOVETO RECORD field_nbr
         PRINT  "     " + [Field Name] +
         SPACES(27-LEN([Field Name])) + [Field Type] + "\n\r"
         field_nbr = field_nbr + 1
      EndWhile
      PRINT  " \n\r"                             ;two line feeds for spacing
      PRINT  " \n\r"
      MENU {Tools} {Info} {Family}               ;get family info for each table
      SELECT cur_name
      PRINT  "     Family Members \n\r"
      PRINT  "     --------------------------------------------------- \n\r"
      field_nbr = 1
      MOVETO RECORD field_nbr
      While field_nbr <= NRECORDS("family")
         While SEARCH("Form",[Name]) = 1         ;this gets info on all Forms
            If [Name] = "Form F" THEN            ;this is default Form
               MENU {Forms} {Change}
               SELECT cur_name
               SELECT "F"
               frdesc = MENUCHOICE()
               MENU ESC
               PRINT "     " + [Name] + " -- " + frdesc
               PRINT "\n\r"
               field_nbr = field_nbr + 1
               MOVETO RECORD field_nbr
            EndIf
            For ndx FROM 1 To 14 STEP 1
               If [Name] = "Form F" + strval(ndx) THEN    ;gets numbered forms
                  MENU {Forms} {Change}
                  SELECT cur_name
                  SELECT ndx
                  frdesc = MENUCHOICE()
                  MENU ESC
                  PRINT "     " + [Name] + " -- " + frdesc
                  PRINT "\n\r"
                  field_nbr = field_nbr + 1
                  MOVETO RECORD field_nbr
               EndIf
            EndFor
            If ATLAST() THEN
               QuitLoop
            EndIf
         EndWhile
         While SEARCH("Report",[Name]) = 1       ;gets Report info
            If [Name] = "Report R" THEN
               MENU {Report} {Change}
               SELECT cur_name
               SELECT "R"
               frdesc = MENUCHOICE()
               MENU ESC
               PRINT "     " + [Name] + " -- " + frdesc
               PRINT "\n\r"
               field_nbr = field_nbr + 1
               MOVETO RECORD field_nbr
            EndIf
            For ndx FROM 1 To 14 STEP 1
               If [Name] = "Report R" + strval(ndx) THEN
                  MENU {Report} {Change}
                  SELECT cur_name
                  SELECT ndx
                  frdesc = MENUCHOICE()
                  MENU ESC
                  PRINT "     " + [Name] + " -- " + frdesc
                  PRINT "\n\r"
                  field_nbr = field_nbr + 1
                  MOVETO RECORD field_nbr
               EndIf
            EndFor
            If ATLAST() THEN
               QuitLoop
            EndIf
         EndWhile
         If SEARCH("Form",[Name]) = 0 and search("Report",[Name]) = 0 THEN
            If field_nbr=1 THEN PRINT "     " + [Name] + " -- Table name \n\r"
            Else PRINT "     " + [Name] + "\n\r"
            EndIf
            field_nbr = field_nbr + 1
         EndIf
         MOVETO RECORD field_nbr
      EndWhile
      UPIMAGE
      UPIMAGE
      cur_rec = cur_rec + 1
      PRINT CHR(012)                             ;Page eject between tables
   EndWhile
   CLOSE PRINTER
   RELEASE VARS ALL
   CLEARALL
EndIf
