(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE ADVAPI32; (** non-portable / source: Win32.ADVAPI32.Mod *)	(* ejz *)
	IMPORT SYSTEM, Kernel32;

(** This module defines all the Win32 ADVAPI32 APIs used by Oberon.
	Note this module is part of the Oberon inner-core and must be linked with PELinker. *)

	CONST
		(** HKEYs *)
		HKEYClassesRoot* = 080000000H; HKEYCurrentUser* = 080000001H;

		(** value type *)
		RegNone* = 0; RegSZ* = 01H;

		(** sam *)
		KeyQueryValue* = 0; KeySetValue* = 1; KeyCreateSubKey* = 2; KeyEnumerateSubKeys* = 3; KeyAllAccess* = {19, 18, 17, 16, 5, 4 ,3, 2, 1, 0};

		(** options *)
		RegOptionNonVolatile* = {};

		(** error codes *)
		Success* = 0H; ErrorMoreData* = 234;

	TYPE
		(** Handle to a registry key. *)
		HKEY* = Kernel32.ADDRESS;

	VAR
		(** The GetUserName function retrieves the user name of the current thread. *)
		GetUserName-: PROCEDURE [WINAPI] (VAR lpBuffer: ARRAY [NOTAG] OF CHAR; VAR nSize: LONGINT): Kernel32.BOOL;
		(** The RegCloseKey function releases a handle to the specified key. *)
		RegCloseKey-: PROCEDURE [WINAPI] (hKey: HKEY): LONGINT;
		(** The RegCreateKeyEx function creates the specified key. *)
		RegCreateKeyEx-: PROCEDURE [WINAPI] (hKey: HKEY; lpSubKey: ARRAY [NOTAG] OF CHAR; Reserved: LONGINT; lpClass: ARRAY [NOTAG] OF CHAR; dwOptions, samDesired: SET; lpSecurityAttributes: PTR; VAR phkResult: HKEY; VAR lpdwDisposition: LONGINT): LONGINT;
		(** The RegDeleteKey function deleted a subkey. *)
		RegDeleteKey-: PROCEDURE [WINAPI] (hKey: HKEY; lpSubKey: ARRAY [NOTAG] OF CHAR): LONGINT;
		(** The RegDeleteValue function removes a named value from the specified registry key. *)
		RegDeleteValue-: PROCEDURE [WINAPI] (hKey: HKEY; lpValueName: ARRAY [NOTAG] OF CHAR): LONGINT;
		(** The RegEnumKeyEx function enumerates subkeys of the specified open registry key. *)
		RegEnumKeyEx-: PROCEDURE [WINAPI] (hKey: HKEY; dwIndex: LONGINT; VAR lpName: ARRAY [NOTAG] OF CHAR; VAR lpcbName: LONGINT; VAR lpReserved: LONGINT; VAR lpClass: ARRAY [NOTAG] OF CHAR; VAR lpcbClass: LONGINT; VAR lpftLastWriteTime: Kernel32.FileTime): LONGINT;
		(** The RegEnumValue function enumerates the values for the specified open registry key. *)
		RegEnumValue-: PROCEDURE [WINAPI] (hKey: HKEY; dwIndex: LONGINT; VAR lpValueName: ARRAY [NOTAG] OF CHAR; VAR lpcbValueName: LONGINT; VAR lpReserved, type: LONGINT; VAR lpData: ARRAY [NOTAG] OF SYSTEM.BYTE; VAR lpcbData: LONGINT): LONGINT;
		(** The RegOpenKeyEx function opens the specified key. *)
		RegOpenKeyEx-: PROCEDURE [WINAPI] (hKey: HKEY; lpSubKey: ARRAY [NOTAG] OF CHAR; ulOptions: LONGINT; samDesired: SET; VAR phkResult: HKEY): LONGINT;
		(** The RegQueryValueEx function retrieves the type and data for a specified value name associated with an
			open registry key. *)
		RegQueryValueEx-: PROCEDURE [WINAPI] (hKey: HKEY; lpValueName: ARRAY [NOTAG] OF CHAR; VAR lpReserved, lpType: LONGINT; VAR lpData: ARRAY [NOTAG] OF SYSTEM.BYTE; VAR lpcbData: LONGINT): LONGINT;
		(** The RegSetValueEx function sets the data and type of a specified value under a registry key. *)
		RegSetValueEx-: PROCEDURE [WINAPI] (hKey: HKEY; lpValueName: ARRAY [NOTAG] OF CHAR; Reserved, dwType: LONGINT; VAR lpData: ARRAY [NOTAG] OF SYSTEM.BYTE; cbData: LONGINT): LONGINT;
		(** The GetFileVersionInfo function returns version information about a specified file. *)
		GetFileVersionInfo-: PROCEDURE [WINAPI] (lpstrFilename: ARRAY [NOTAG] OF CHAR; dwHandle, dwLen: LONGINT; VAR lpDate: ARRAY [NOTAG] OF SYSTEM.BYTE): Kernel32.BOOL;
		(** The GetFileVersionInfoSize function determines whether the operating system can obtain version information
			about a specified file. *)
		GetFileVersionInfoSize-: PROCEDURE [WINAPI] (lpstrFilename: ARRAY [NOTAG] OF CHAR; VAR lpdwHandle: LONGINT): LONGINT;
		(** The VerQueryValue function returns selected version information from the specified version-information resource. *)
		VerQueryValue-: PROCEDURE [WINAPI] (pBlock: ARRAY [NOTAG] OF SYSTEM.BYTE; lpSubBlock: ARRAY [NOTAG] OF CHAR; VAR lplpBuffer: Kernel32.ADDRESS; VAR puLen: LONGINT): Kernel32.BOOL;

END ADVAPI32.
