(*
    Console output for command line wrapper for
    ETH Oberon compiler (Windows)
    Eugene Shcherbatyuk
    Nov 2002
 *)

MODULE Console;
	IMPORT Kernel32, Kernel;

	VAR hFile : Kernel32.HANDLE;

(************************)
	PROCEDURE WriteString*(str:ARRAY OF CHAR);
	BEGIN
		Kernel32.Str(str)
	END WriteString;

(************************)
	PROCEDURE Write*(ch: CHAR);
	VAR str: ARRAY 2 OF CHAR;
	BEGIN
		str[0] := ch;
		str[1] := 0X;
		Kernel32.Str(str)
	END Write;

(************************)
	PROCEDURE WriteLn*();
	BEGIN
		Kernel32.Ln()
	END WriteLn;

	PROCEDURE *OutputFileString(VAR str: ARRAY OF CHAR);
		VAR n: LONGINT;
	BEGIN
		n := 0; WHILE str[n] # 0X DO INC(n) END;
		Kernel32.WriteFile(hFile, str, n, n, NIL)
	END OutputFileString;

	PROCEDURE *ShutdownConsole();
	BEGIN
		IF hFile # Kernel32.InvalidHandleValue THEN
			Kernel32.CloseHandle(hFile); hFile := Kernel32.InvalidHandleValue
		END;
		Kernel32.OutputString := Kernel32.OutputDebugString (* todo: check utility value *)
	END ShutdownConsole;


	PROCEDURE Init();
	BEGIN
		hFile := Kernel32.GetStdHandle(Kernel32.STDOutput);
		IF hFile # Kernel32.InvalidHandleValue THEN
			Kernel32.OutputString := OutputFileString
		END;
		Kernel.InstallTermHandler(ShutdownConsole)
	END Init;

BEGIN
	Init()
END Console.
