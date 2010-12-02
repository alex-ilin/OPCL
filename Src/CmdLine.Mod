(*
	Exports command line which was issued to run an application.
	Eugene Shcherbatyuk (ugns@mail.ru)
	Nov 2002
 *)

MODULE CmdLine;

	IMPORT Kernel32, SYSTEM;

	CONST
		length* = 1025; (*Windows 95 limit is 1024*)

	VAR
		text*: ARRAY length OF CHAR;

	(*****************************)
	PROCEDURE Get();
		VAR
			adr: Kernel32.ADDRESS; i: LONGINT; ch: CHAR;
	BEGIN
		i := 0;
		adr := Kernel32.GetCommandLine();
		REPEAT
			SYSTEM.GET(adr, ch);
			INC(adr);
			text[i] := ch;
			INC(i);
		UNTIL (ch = 0X) OR (i = length);
		IF i < length THEN
			text[i] := ch;
		END;
	END Get;

(*****************************)
BEGIN
	Get();
END CmdLine.
