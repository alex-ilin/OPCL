(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Registry; (** non-portable / source: Win32.Registry.Mod *)	(* ejz *)
	IMPORT SYSTEM, Kernel32, ADVAPI32;

(** This module provides an interface to the Windows registry. To read Oberon configuration data stored in the registry use Oberon.OpenScanner and the commands System.Set and System.Get . *)

	CONST
		(** root keys *)
		ClassesRoot* = ADVAPI32.HKEYClassesRoot; CurrentUser* = ADVAPI32.HKEYCurrentUser;
		(** result codes *)
		Done* = 0; Failed* = 1; NotFound* = 2;

	TYPE
		PathEnumerator* = PROCEDURE (path: ARRAY OF CHAR);
		KeyValueEnumerator* = PROCEDURE (key, value: ARRAY OF CHAR);

	VAR
		res*: LONGINT; (** Done, Failed, NotFound *)
		stamp*: LONGINT; (** Time stamp of last modification to the registry. *)

	(** Set a key/value pair, key = "" sets the default value for path. *)
	PROCEDURE SetKeyValue*(root: ADVAPI32.HKEY; path, key, value: ARRAY OF CHAR);
		VAR hKey: ADVAPI32.HKEY; i: LONGINT;
	BEGIN
		IF ADVAPI32.RegCreateKeyEx(root, path, 0, NIL, ADVAPI32.RegOptionNonVolatile, {ADVAPI32.KeySetValue, ADVAPI32.KeyCreateSubKey}, NIL, hKey, NIL) # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		i := 0; WHILE value[i] # 0X DO INC(i) END; INC(i);
		IF ADVAPI32.RegSetValueEx(hKey, key, 0, ADVAPI32.RegSZ, value, i) = ADVAPI32.Success THEN
			INC(stamp); res := Done
		ELSE
			res := Failed
		END;
		ADVAPI32.RegCloseKey(hKey)
	END SetKeyValue;

	(** Retrieve the value stored under key. use key = "" to retrieve the default value for path. *)
	PROCEDURE GetKeyValue*(root: ADVAPI32.HKEY; path, key: ARRAY OF CHAR; VAR value: ARRAY OF CHAR);
		VAR hKey: ADVAPI32.HKEY; type, len, ret: LONGINT; buf: POINTER TO ARRAY OF CHAR;
	BEGIN
		IF ADVAPI32.RegOpenKeyEx(root, path, 0, {ADVAPI32.KeyQueryValue}, hKey) # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		len := LEN(value); type := ADVAPI32.RegNone;
		ret := ADVAPI32.RegQueryValueEx(hKey, key, NIL, type, value, len);
		IF (type # ADVAPI32.RegSZ) OR (ret # ADVAPI32.Success) THEN
			IF (type = ADVAPI32.RegSZ) & (ret = ADVAPI32.ErrorMoreData) THEN
				NEW(buf, len+1);
				ADVAPI32.RegQueryValueEx(hKey, key, NIL, type, buf^, len);
				COPY(buf^, value); res := Done
			ELSE
				res := NotFound
			END
		ELSE
			res := Done
		END;
		ADVAPI32.RegCloseKey(hKey)
	END GetKeyValue;

	(** Delete key and its value, key = "" deletes the default value for path. *)
	PROCEDURE DeleteKeyValue*(root: ADVAPI32.HKEY; path, key: ARRAY OF CHAR);
		VAR hKey: ADVAPI32.HKEY;
	BEGIN
		IF ADVAPI32.RegOpenKeyEx(root, path, 0, {ADVAPI32.KeySetValue}, hKey) # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		IF ADVAPI32.RegDeleteValue(hKey, key) = ADVAPI32.Success THEN
			INC(stamp); res := Done
		ELSE
			res := NotFound
		END;
		ADVAPI32.RegCloseKey(hKey)
	END DeleteKeyValue;

	(** Recursive delete all sub-paths, keys and values in path.
		Note: be very careful when using this procedure!!! *)
	PROCEDURE DeletePath*(root: ADVAPI32.HKEY; path: ARRAY OF CHAR);
		VAR buffer: ARRAY Kernel32.MaxPath OF CHAR; hKey: ADVAPI32.HKEY; size: LONGINT;
	BEGIN
		IF ADVAPI32.RegOpenKeyEx(root, path, 0, ADVAPI32.KeyAllAccess, hKey) # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		size := Kernel32.MaxPath;
		WHILE ADVAPI32.RegEnumKeyEx(hKey, 0, buffer, size, NIL, NIL, NIL, NIL) = ADVAPI32.Success DO
			DeletePath(hKey, buffer);
			IF res # Done THEN
				ADVAPI32.RegCloseKey(hKey); RETURN
			END;
			size := Kernel32.MaxPath
		END;
		ADVAPI32.RegCloseKey(hKey);
		IF ADVAPI32.RegDeleteKey(root, path) = ADVAPI32.Success THEN
			INC(stamp); res := Done
		ELSE
			res := Failed
		END
	END DeletePath;

	(** Enumerate all sub-paths in path. *)
	PROCEDURE EnumeratePath*(root: ADVAPI32.HKEY; path: ARRAY OF CHAR; enum: PathEnumerator);
		VAR subPath: ARRAY Kernel32.MaxPath OF CHAR; hKey: ADVAPI32.HKEY; ret, i, size: LONGINT;
	BEGIN
		ret := ADVAPI32.RegOpenKeyEx(root, path, 0, {ADVAPI32.KeyEnumerateSubKeys}, hKey);
		IF ret # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		i := 0;
		WHILE ret = ADVAPI32.Success DO
			size := Kernel32.MaxPath;
			ret := ADVAPI32.RegEnumKeyEx(hKey, i, subPath, size, NIL, NIL, NIL, NIL);
			IF ret = ADVAPI32.Success THEN enum(subPath) END;
			INC(i)
		END;
		ADVAPI32.RegCloseKey(hKey); res := Done
	END EnumeratePath;

	(** Enumerate all key/value pairs in path.*)
	PROCEDURE EnumerateKeyValue*(root: ADVAPI32.HKEY; path: ARRAY OF CHAR; enum: KeyValueEnumerator);
		VAR
			key, value: ARRAY Kernel32.MaxPath OF CHAR; hKey: ADVAPI32.HKEY;
			ret, i, type, kLen, vLen: LONGINT;
	BEGIN
		ret := ADVAPI32.RegOpenKeyEx(root, path, 0, {ADVAPI32.KeyQueryValue}, hKey);
		IF ret # ADVAPI32.Success THEN
			res := NotFound; RETURN
		END;
		i := 0;
		WHILE ret = ADVAPI32.Success DO
			kLen := Kernel32.MaxPath; vLen := Kernel32.MaxPath; type := ADVAPI32.RegNone;
			ret := ADVAPI32.RegEnumValue(hKey, i, key, kLen, NIL, type, value, vLen);
			IF (ret = ADVAPI32.Success) & (type = ADVAPI32.RegSZ) THEN enum(key, value) END;
			INC(i)
		END;
		ADVAPI32.RegCloseKey(hKey); res := Done
	END EnumerateKeyValue;

	PROCEDURE Init();
	BEGIN
		res := Done; stamp := 0;
	END Init;

BEGIN
	Init()
END Registry.
