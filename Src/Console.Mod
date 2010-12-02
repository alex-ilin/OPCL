(*
    Console output for command line wrapper for
    ETH Oberon compiler (Windows)
    Eugene Shcherbatyuk
    Nov 2002
 *)

MODULE Console;
	IMPORT Kernel32;

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

END Console.
