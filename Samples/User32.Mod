	MODULE User32;
		IMPORT SYSTEM, Kernel32;

		CONST
			MBOk* = {}; MBIconExclamation* = {4, 5};
			HWNDDesktop* = Kernel32.NULL;

		TYPE
			HWND* = LONGINT;

		VAR
			MessageBox-: PROCEDURE [WINAPI] (hwnd: HWND; text, caption: ARRAY [NOTAG] OF CHAR; type: SET): LONGINT;

		PROCEDURE InitAPI();
			VAR mod: Kernel32.HMODULE;
		BEGIN
			mod := Kernel32.LoadLibrary("User32.DLL");
			Kernel32.GetProcAddress(mod, "MessageBoxA", SYSTEM.VAL(LONGINT, MessageBox))
		END InitAPI;

	BEGIN
		InitAPI()
	END User32.
