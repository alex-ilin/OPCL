MODULE HelloDLLMain;
		IMPORT Kernel32;

VAR
	HelloDllDo: PROCEDURE (); (* imported from HelloDLL.dll by linker, see Link-file *)

BEGIN
	HelloDllDo;
	Kernel32.Shutdown(0);
END HelloDLLMain.
