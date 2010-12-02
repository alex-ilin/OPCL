(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE FileDir; (** non-portable / source: Win32.FileDir.Mod *)	(* ejz *)
	IMPORT SYSTEM, Kernel32, Kernel, Registry;

(** The FileDir module implements the naming of files in directories. *)

	CONST
		WinPathChar = "\"; pathChar = "/";
		(** File Atributes *)
		Readonly* = Kernel32.FileAttributeReadonly; Hidden* = Kernel32.FileAttributeHidden;
		System* = Kernel32.FileAttributeSystem; Directory* = Kernel32.FileAttributeDirectory;
		Archive* = Kernel32.FileAttributeArchive;

	TYPE
		(** file enumerator *)
		FileEnumerator* = PROCEDURE (path, name: ARRAY OF CHAR; time, date, size: LONGINT; attrs: SET);	(** non-portable *)

		(** (search-) path enumerator *)
		PathEnumerator* = PROCEDURE (path: ARRAY OF CHAR);	(** non-portable *)

		FileName* = ARRAY Kernel32.MaxPath OF CHAR;

	VAR
		searchPath: ARRAY 4*Kernel32.MaxPath OF CHAR;
		workPath, tempPath: FileName;
		PathChar-: CHAR; (** directory separator *)
		moduleCS: Kernel32.CriticalSection;

(** Replace all occurences of character from in name by to. *)
	PROCEDURE ConvertChar*(VAR name: ARRAY OF CHAR; from, to: CHAR);
		VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE name[i] # 0X DO
			IF name[i] = from THEN name[i] := to END;
			INC(i)
		END
	END ConvertChar;

(** Search the (relative) filename name in the current directory. If it could not be found all directories in the search path
are searched for name. fileName returns the full (absolute) name for the file found. *)
	PROCEDURE FindFile*(name: ARRAY OF CHAR; VAR fullname: ARRAY OF CHAR; usepath: BOOLEAN): BOOLEAN;
		VAR ret: LONGINT; fileName: Kernel32.LPSTR;
	BEGIN
		ConvertChar(name, pathChar, WinPathChar);
		Kernel32.EnterCriticalSection(moduleCS);
		ret := Kernel32.SearchPath(workPath, name, NIL, LEN(fullname), fullname, fileName);
		IF (ret <= 0) & usepath THEN
			ret := Kernel32.SearchPath(searchPath, name, NIL, LEN(fullname), fullname, fileName)
		END;
		Kernel32.LeaveCriticalSection(moduleCS);
		ConvertChar(fullname, WinPathChar, pathChar);
		RETURN ret > 0
	END FindFile;

	PROCEDURE CheckPath(VAR fullName: ARRAY OF CHAR): BOOLEAN;
		VAR i, j: LONGINT; done: BOOLEAN;
	BEGIN
		i := 0; j := -1;
		WHILE fullName[i] # 0X DO
			IF fullName[i] = WinPathChar THEN j := i END;
			INC(i)
		END;
		IF j > 0 THEN fullName[j] := 0X END;
		done := Kernel32.SetCurrentDirectory(fullName) # Kernel32.False;
		IF j > 0 THEN fullName[j] := WinPathChar END;
		Kernel32.SetCurrentDirectory(workPath);
		RETURN done
	END CheckPath;

(** Checks if name is a valid file name. *)
	PROCEDURE CheckName*(name: ARRAY OF CHAR): BOOLEAN;
		VAR
			fullName: FileName;
			fileNamePart: Kernel32.LPSTR;
			ret, i: LONGINT;
			ch: CHAR; stream, ok: BOOLEAN;
	BEGIN
		ConvertChar(name, pathChar, WinPathChar);
		Kernel32.EnterCriticalSection(moduleCS);
		ret := Kernel32.GetFullPathName(name, Kernel32.MaxPath, fullName, fileNamePart);
		IF (ret > 0) & CheckPath(fullName) & (fileNamePart # Kernel32.NULL) THEN
			ok := TRUE; stream := FALSE;
			i := fileNamePart-SYSTEM.ADR(fullName);
			fullName[i-1] := 0X; ch := fullName[i];
			WHILE (ch # 0X) & ok DO
				IF ch = ":" THEN
					IF stream THEN ok := FALSE ELSE stream := TRUE END
				ELSIF ~( ((CAP(ch) >= "A") & (CAP(ch) <= "Z")) OR ((ch >= "0") & (ch <= "9")) OR
						(ch = ".") OR (ch = "_") OR (ch = "-") ) THEN ok := FALSE
				END;
				INC(i); ch := fullName[i]
			END
		ELSE
			ok := FALSE
		END;
		Kernel32.LeaveCriticalSection(moduleCS); RETURN ok
	END CheckName;

(** Compare two filenames. *)
	PROCEDURE SameName*(VAR a, b: ARRAY OF CHAR): BOOLEAN;	(** non-portable *)
		VAR i, j: LONGINT;
	BEGIN
		i := 0; j := 0;
		WHILE (a[i] # 0X) & (b[j] # 0X) & (CAP(a[i]) = CAP(b[j])) DO
			INC(i); INC(j)
		END;
		RETURN (a[i] = 0X) & (b[j] = 0X)
	END SameName;

(** Compute the relative filename (relative to the working directory). *)
	PROCEDURE RelFileName*(fileName: ARRAY OF CHAR; VAR relFileName: ARRAY OF CHAR);
		VAR
			i, j, k, p: LONGINT;
			fullName: FileName;
			fileNamePart: Kernel32.LPSTR;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		IF ~FindFile(fileName, fullName, TRUE) THEN (* file does not exist -> would be created in the current dir *)
			ConvertChar(fileName, pathChar, WinPathChar);
			Kernel32.GetFullPathName(fileName, Kernel32.MaxPath, fullName, fileNamePart)
		ELSE
			ConvertChar(fullName, pathChar, WinPathChar)
		END; (* from here on all with WinPathChar and drive letter *)
		IF CAP(workPath[0]) # CAP(fullName[0]) THEN (* different drive letters -> nothing to be done *)
			COPY(fullName, relFileName)
		ELSE
			i := 0; j := -1; p := 0;
			WHILE CAP(fullName[i]) = CAP(workPath[i]) DO
				IF workPath[i] = WinPathChar THEN j := i END;
				INC(i)
			END;
			IF workPath[i] = 0X THEN
				IF fullName[i] # WinPathChar THEN (* first part of directories do match *)
					relFileName[p] := "."; relFileName[p+1] := "."; relFileName[p+2] := WinPathChar;
					INC(p, 3); INC(j);
					WHILE fullName[j] # 0X DO
						relFileName[p] := fullName[j] ; INC(j); INC(p)
					END
				ELSE (* file is in a subdirectory of the current dir *)
					INC(i);
					WHILE fullName[i] # 0X DO
						relFileName[p] := fullName[i]; INC(i); INC(p)
					END
				END
			ELSIF j > 2 THEN (* first part of directories do match *)
				k := j; i := j+1;
				WHILE workPath[k] # 0X DO
					IF workPath[k] = WinPathChar THEN
						relFileName[p] := "."; relFileName[p+1] := "."; relFileName[p+2] := WinPathChar; INC(p, 3)
					END;
					INC(k)
				END;
				WHILE fullName[i] # 0X DO
					relFileName[p] := fullName[i]; INC(i); INC(p)
				END
			ELSE (* only drive letters match *)
				i := j;
				WHILE fullName[i] # 0X DO
					relFileName[p] := fullName[i]; INC(i); INC(p)
				END
			END;
			relFileName[p] := 0X
		END;
		Kernel32.LeaveCriticalSection(moduleCS);
		ConvertChar(relFileName, WinPathChar, pathChar)
	END RelFileName;

(** Get the current directory. *)
	PROCEDURE GetWorkingDirectory*(VAR path: ARRAY OF CHAR);
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		Kernel32.GetCurrentDirectory(Kernel32.MaxPath, workPath);
		COPY(workPath, path);
		Kernel32.LeaveCriticalSection(moduleCS);
		ConvertChar(path, WinPathChar, pathChar)
	END GetWorkingDirectory;

(** Change to directory path. *)
	PROCEDURE ChangeDirectory*(path: ARRAY OF CHAR; VAR done: BOOLEAN);
	BEGIN
		ConvertChar(path, pathChar, WinPathChar);
		Kernel32.EnterCriticalSection(moduleCS);
		done := Kernel32.SetCurrentDirectory(path) # Kernel32.False;
		Kernel32.GetCurrentDirectory(Kernel32.MaxPath, workPath);
		Kernel32.LeaveCriticalSection(moduleCS)
	END ChangeDirectory;

(** Create a new directory. *)
	PROCEDURE CreateDirectory*(path: ARRAY OF CHAR; VAR done: BOOLEAN);
	BEGIN
		ConvertChar(path, pathChar, WinPathChar);
		Kernel32.EnterCriticalSection(moduleCS);
		done := Kernel32.CreateDirectory(path, NIL) # Kernel32.False;
		Kernel32.LeaveCriticalSection(moduleCS)
	END CreateDirectory;

(** Delete directory path. *)
	PROCEDURE DeleteDirectory*(path: ARRAY OF CHAR; VAR done: BOOLEAN);
	BEGIN
		ConvertChar(path, pathChar, WinPathChar);
		Kernel32.EnterCriticalSection(moduleCS);
		done := Kernel32.RemoveDirectory(path) # Kernel32.False;
		Kernel32.GetCurrentDirectory(Kernel32.MaxPath, workPath);
		Kernel32.LeaveCriticalSection(moduleCS)
	END DeleteDirectory;

(** Get the directory for temporary files. *)
	PROCEDURE GetTempDirectory*(VAR path: ARRAY OF CHAR);
	BEGIN
		COPY(tempPath, path);
		ConvertChar(path, WinPathChar, pathChar)
	END GetTempDirectory;

	PROCEDURE GetAttributes*(file: ARRAY OF CHAR): SET;	(** non-portable *)
		VAR attrs: SET;
	BEGIN
		ConvertChar(file, pathChar, WinPathChar);
		attrs := Kernel32.GetFileAttributes(file);
		IF attrs = {0 .. 31} THEN
			RETURN {}
		ELSE
			RETURN attrs
		END
	END GetAttributes;

	PROCEDURE SetAttributes*(file: ARRAY OF CHAR; attrs: SET);	(** non-portable *)
	BEGIN
		ConvertChar(file, pathChar, WinPathChar);
		Kernel32.SetFileAttributes(file, attrs)
	END SetAttributes;

(** Enumerate files. The detail flag indicates if time, date and size
must be calculated. When
	path = "."	=> enumerate files in current directory
	path = ""	=> enumerate files in the search path
	path = ?	=> enumerate files in the directory ?

	Directories are always returned independent of the pattern specified. The only wildcard allowed is *. *)
	PROCEDURE EnumerateFiles*(path, pattern: ARRAY OF CHAR; detail: BOOLEAN; enum: FileEnumerator);		(** non-portable *)
		VAR curPath: FileName; i, j: LONGINT;
		PROCEDURE EnumeratePath();
			VAR
				h: Kernel32.HANDLE; FD: Kernel32.FindData;
				ft: Kernel32.FileTime; st: Kernel32.SystemTime;
				i, j, t, d: LONGINT;
		BEGIN
			Kernel32.LeaveCriticalSection(moduleCS);
			i := 0; WHILE curPath[i] # 0X DO INC(i) END;
			IF curPath[i-1] # WinPathChar THEN
				curPath[i] := WinPathChar; INC(i); curPath[i] := 0X
			END;
			j := i-1; h := 0;
			WHILE pattern[h] # 0X DO
				curPath[i] := pattern[h]; INC(i); INC(h)
			END;
			IF h = 0 THEN
				curPath[i] := "*"; INC(i); curPath[i] := "."; INC(i); curPath[i] := "*"; INC(i)
			END;
			curPath[i] := 0X;
			h := Kernel32.FindFirstFile(curPath, FD); curPath[j] := 0X; ConvertChar(curPath, WinPathChar, pathChar);
			IF h # Kernel32.InvalidHandleValue THEN
				t := 0; d := 0;
				REPEAT
					IF ~(Kernel32.FileAttributeDirectory IN FD.dwFileAttributes) THEN
						IF detail THEN
							Kernel32.FileTimeToLocalFileTime(FD.ftLastWriteTime, ft);
							Kernel32.FileTimeToSystemTime(ft, st);
							d := LONG(st.wYear-1900)*200H + LONG(st.wMonth)*20H + LONG(st.wDay);
							t := LONG(st.wHour)*1000H + LONG(st.wMinute)*40H + LONG(st.wSecond)
						END;
						enum(curPath, FD.cFileName, t, d, FD.nFileSizeLow, FD.dwFileAttributes)
					END
				UNTIL Kernel32.FindNextFile(h, FD) = Kernel32.False;
				Kernel32.FindClose(h)
			END;
			i := j; curPath[i] := pathChar; INC(i); curPath[i] := "*"; INC(i); curPath[i] := 0X;
			ConvertChar(curPath, pathChar, WinPathChar);
			h := Kernel32.FindFirstFile(curPath, FD); curPath[j] := 0X; ConvertChar(curPath, WinPathChar, pathChar);
			IF h # Kernel32.InvalidHandleValue THEN
				t := 0; d := 0;
				REPEAT
					IF Kernel32.FileAttributeDirectory IN FD.dwFileAttributes THEN
						IF (FD.cFileName # "..") & (FD.cFileName # ".") THEN
							IF detail THEN
								Kernel32.FileTimeToLocalFileTime(FD.ftLastWriteTime, ft);
								Kernel32.FileTimeToSystemTime(ft, st);
								d := LONG(st.wYear-1900)*200H + LONG(st.wMonth)*20H + LONG(st.wDay);
								t := LONG(st.wHour)*1000H + LONG(st.wMinute)*40H + LONG(st.wSecond)
							END;
							enum(curPath, FD.cFileName, t, d, FD.nFileSizeLow, FD.dwFileAttributes)
						END
					END;
				UNTIL Kernel32.FindNextFile(h, FD) = Kernel32.False;
				Kernel32.FindClose(h)
			END;
			Kernel32.EnterCriticalSection(moduleCS)
		END EnumeratePath;
	BEGIN
		IF enum = NIL THEN RETURN END;
		Kernel32.EnterCriticalSection(moduleCS);
		IF path = "." THEN
			COPY(workPath, curPath); EnumeratePath()
		ELSIF path = "" THEN
			COPY(workPath, curPath); EnumeratePath();
			i := 0; j := 0;
			WHILE searchPath[i] # 0X DO
				IF searchPath[i] # ";" THEN
					curPath[j] := searchPath[i]; INC(j)
				ELSIF j > 0 THEN
					curPath[j] := 0X; EnumeratePath(); j := 0
				END;
				INC(i)
			END;
			IF j > 0 THEN
				curPath[j] := 0X; EnumeratePath()
			END
		ELSE
			COPY(path, curPath); ConvertChar(curPath, pathChar, WinPathChar);
			EnumeratePath()
		END;
		Kernel32.LeaveCriticalSection(moduleCS)
	END EnumerateFiles;

(** Enumerates all paths in Oberons search-path. *)
	PROCEDURE EnumerateSearchPaths*(enum: PathEnumerator);	(** non-portable *)
		VAR curPath: FileName; i, j: LONGINT;
		PROCEDURE EnumeratePath();
		BEGIN
			ConvertChar(curPath, WinPathChar, pathChar); enum(curPath)
		END EnumeratePath;
	BEGIN
		IF enum = NIL THEN RETURN END;
		Kernel32.EnterCriticalSection(moduleCS);
		COPY(workPath, curPath);
		Kernel32.LeaveCriticalSection(moduleCS);
		EnumeratePath();
		i := 0; j := 0;
		WHILE searchPath[i] # 0X DO
			IF searchPath[i] # ";" THEN
				curPath[j] := searchPath[i]; INC(j)
			ELSIF j > 0 THEN
				curPath[j] := 0X; EnumeratePath(); j := 0
			END;
			INC(i)
		END;
		IF j > 0 THEN
			curPath[j] := 0X; EnumeratePath()
		END
	END EnumerateSearchPaths;

	PROCEDURE *Shutdown();
	BEGIN
		Kernel32.DeleteCriticalSection(moduleCS)
	END Shutdown;

	PROCEDURE Init();
		VAR
			ret, i, j, k: LONGINT;
			dirs: ARRAY 4*Kernel32.MaxPath OF CHAR;
			dir, sysPath: FileName;
		PROCEDURE AddDir();
		BEGIN
			IF k > 0 THEN
				dir[k] := 0X; IF dir[k-1] = '"' THEN dir[k-1] := 0X END;
				ConvertChar(dir, pathChar, WinPathChar);
				Kernel32.SetCurrentDirectory(sysPath);
				IF Kernel32.SetCurrentDirectory(dir) # Kernel32.False THEN
					Kernel32.GetCurrentDirectory(LEN(dir), dir);
					searchPath[i] := ";"; INC(i);
					k := 0;
					WHILE dir[k] # 0X DO
						searchPath[i] := dir[k]; INC(i); INC(k)
					END
				ELSE
					Kernel32.Str(dir); Kernel32.Str(" not a vaild directory"); Kernel32.Ln()
				END;
				k := 0
			END
		END AddDir;
	BEGIN
		Kernel32.InitializeCriticalSection(moduleCS);
		Kernel32.EnterCriticalSection(moduleCS);
		Kernel.InstallTermHandler(Shutdown);
		PathChar := pathChar;
		Kernel32.GetCurrentDirectory(LEN(workPath), workPath);
		i := 0; ret := 0;
		Registry.GetKeyValue(Registry.CurrentUser, Registry.oberonSystem, "Files", sysPath);
		IF Registry.res = Registry.Done THEN
			IF Kernel32.SetCurrentDirectory(sysPath) # Kernel32.False THEN
				ret := Kernel32.GetCurrentDirectory(LEN(sysPath), sysPath)
			END
		END;
		IF ret = 0 THEN
			Kernel32.GetModuleFileName(Kernel.hInstance, sysPath, LEN(sysPath));
			j := -1;
			WHILE sysPath[i] # 0X DO
				IF sysPath[i] = WinPathChar THEN j := i END;
				INC(i)
			END;
			i := j+1; sysPath[i] := 0X;
			COPY(sysPath, searchPath)
		ELSE
			WHILE sysPath[i] # 0X DO
				searchPath[i] := sysPath[i]; INC(i)
			END;
			searchPath[i] := 0X
		END;
		Registry.GetKeyValue(Registry.CurrentUser, Registry.oberonSystem, "Directories", dirs);
		IF Registry.res # Registry.Done THEN dirs := "" END;
		IF dirs[0] = '"' THEN j := 1 ELSE j := 0 END;
		k := 0;
		WHILE dirs[j] # 0X DO
			IF (dirs[j] = ";") OR (dirs[j] < " ") THEN
				AddDir()
			ELSE
				dir[k] := dirs[j]; INC(k)
			END;
			INC(j)
		END;
		AddDir();
		searchPath[i] := 0X;
		ret := 0;
		Registry.GetKeyValue(Registry.CurrentUser, Registry.oberonSystem, "Temp", tempPath);
		IF Registry.res = Registry.Done THEN
			ConvertChar(tempPath, pathChar, WinPathChar);
			Kernel32.SetCurrentDirectory(sysPath);
			IF Kernel32.SetCurrentDirectory(tempPath) # Kernel32.False THEN
				ret := Kernel32.GetCurrentDirectory(LEN(tempPath), tempPath)
			END
		END;
		IF ret = 0 THEN
			Kernel32.GetTempPath(LEN(tempPath), tempPath)
		END;
		Registry.GetKeyValue(Registry.CurrentUser, Registry.oberonSystem, "Work", dir);
		IF (Registry.res = Registry.Done) & (dir # "") THEN
			ConvertChar(dir, pathChar, WinPathChar);
			Kernel32.SetCurrentDirectory(sysPath);
			IF Kernel32.SetCurrentDirectory(dir) # Kernel32.False THEN
				Kernel32.GetCurrentDirectory(LEN(workPath), workPath)
			END
		END;
		Kernel32.SetCurrentDirectory(workPath);
		Kernel32.LeaveCriticalSection(moduleCS)
	END Init;

BEGIN
	Init()
END FileDir.

(** Remarks:

1. Newly created files are always written in the working directory when no absolute filename is specified. Opening a file searches in the current directory, followed by each directory in the path in return.

2. The search path for files is specified by the Directories key in the System section of the Registry. *)
