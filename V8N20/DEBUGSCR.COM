�7   
DEBUGSCR 1.0 (C) 1989 Ziff Communications Co. 
PC Magazine � Michael J. Mefford

Syntax:  DEBUGSCR filespec [/N]

/N = No instruction messages in script

filename.SCR will be created
To recreate file, Enter

	DEBUG < filename.SCR

$                   File not found

$Disk error

$.SCR $.EXE
Input file too big; can't be more than 60K

$Not enough memory; requires 64K

$created

$ RCX
 W
 Q

	If you have downloaded this script file, remove
	any captured communications header and then enter

		DEBUG < filename

	where filename is the name of this script file.

	Note this is an EXE script.  Debug will not create
	a file with an EXE name extension.  You have to add
	the EXE extension yourself AFTER the file is created
	by Debug by entering the following at the DOS prompt

	RENAME ���?� �J�!�gs���� �<t$</u�D��$_<Nu��<ar�<zw݀d�_�׾� �<u��< v�N��.���3ɬ<:t<\u��<.u��I< w�N� �6�����ո =�!s�$���B�غ���?�!s��.;�u�9�$��>�!���.�u������3� �u��݋6���+Ή����-��� ��3ɴ<�!s��� ������� �.����� �� � � ����� Mt���� �؋� ��� � �P�Ŀ�� X� � �{ ���
 �k �>t=���� �[ �>u-�U�� �K ��R��Q�> ��� �5 YZ�0 �3� �' ��>�!r���w ���q 2����g ��L�!�@�!r�ú���������
��� ���ðE�� ��	P��� X�	� �	�Q� �ر�Ê�$0<9v��Ju�Yô	�!� N 