(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Files; (** portable, except where noted / source: Win32.Files.Mod *)	(* ejz *)
	IMPORT SYSTEM, Kernel32, Kernel, FileDir;

(** The Files module provided access to the file system of the host operating system by simulating an Oberon-like file system. *)

	CONST
		BufSize = 4*1024; MaxBufs = 4; WinPathChar = "\";

	TYPE
		Buffer = POINTER TO RECORD
			data: ARRAY BufSize OF SYSTEM.BYTE;
			org, size: LONGINT;
			dirty: BOOLEAN
		END;

		File* = POINTER TO RECORD (Kernel32.Object)	(** file descriptor *)
			name: FileDir.FileName;
			temp: POINTER TO RECORD temp, name: FileDir.FileName END;
			bufs: ARRAY MaxBufs OF Buffer;
			pos, len, swap: LONGINT;
			next[UNTRACED]: File
		END;

		Rider* = RECORD (** Riders are the access mechanisms for files. *)
			F: File; buf: Buffer;
			res*, org, offset: LONGINT; (** Rider operation result code. *)
			eof*: BOOLEAN (** Rider has reached the end of the file. *)
		END;

	VAR
		OpenFlags, NewFlags, GenericReadWrite, ShareReadWrite: SET;
		moduleCS: Kernel32.CriticalSection;
		root: File;

	PROCEDURE FindOpenFile(VAR name: ARRAY OF CHAR): File;
		VAR F: File;
	BEGIN
		F := root.next;
		WHILE (F # NIL) & ~FileDir.SameName(F.name, name) DO
			F := F.next
		END;
		RETURN F
	END FindOpenFile;

	PROCEDURE CloseFile(F: File);
	BEGIN
		IF F.handle # Kernel32.InvalidHandleValue THEN
			Kernel32.CloseHandle(F.handle); F.handle := Kernel32.InvalidHandleValue
		END
	END CloseFile;

	PROCEDURE MoveFile(VAR from, to: ARRAY OF CHAR): BOOLEAN;
	BEGIN
		IF Kernel32.MoveFileEx(from, to, {Kernel32.MoveFileReplaceExisting, Kernel32.MoveFileCopyAllowed}) = Kernel32.False THEN
			IF Kernel32.CopyFile(from, to, Kernel32.False) = Kernel32.False THEN
				RETURN FALSE
			ELSE
				RETURN Kernel32.DeleteFile(from) # Kernel32.False
			END
		ELSE
			RETURN TRUE
		END
	END MoveFile;

	PROCEDURE *FinalizeFile(F: PTR);
		VAR prev, cur: File;
	BEGIN
		WITH F: File DO
			CloseFile(F);
			IF F.temp # NIL THEN Kernel32.DeleteFile(F.temp.temp); F.temp := NIL END;
			prev := root; cur := root.next;
			WHILE cur # F DO
				prev := cur; cur := cur.next
			END;
			prev.next := cur.next
		END
	END FinalizeFile;

	PROCEDURE NewFile(handle: Kernel32.HANDLE): File;
		VAR F: File; i: LONGINT;
	BEGIN
		NEW(F); F.handle := handle;
		FOR i := 0 TO MaxBufs-1 DO F.bufs[i] := NIL END;
		F.pos := 0; F.len := 0; F.swap := -1;
		F.next := root.next; root.next := F;
		Kernel.RegisterObject(F, FinalizeFile, TRUE);
		RETURN F
	END NewFile;

	PROCEDURE old(VAR fName: ARRAY OF CHAR): File;
		VAR F: File; ret: LONGINT;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		F := FindOpenFile(fName);
		IF F = NIL THEN
			ret := Kernel32.CreateFile(fName, {Kernel32.GenericRead}, ShareReadWrite, NIL, Kernel32.OpenExisting, OpenFlags, Kernel32.NULL);
			IF ret # Kernel32.InvalidHandleValue THEN
				F := NewFile(ret); F.temp := NIL; COPY(fName, F.name);
				F.len := Kernel32.GetFileSize(F.handle, NIL);
				F.pos := Kernel32.SetFilePointer(F.handle, 0, NIL, Kernel32.FileBegin)
			END
		END;
		Kernel32.LeaveCriticalSection(moduleCS);
		RETURN F
	END old;

(** Open an existing file. The same file descriptor is returned if a file is opened multiple times. *)
	PROCEDURE Old*(name: ARRAY OF CHAR): File;
		VAR fName: FileDir.FileName;
	BEGIN
		IF (name # "") & FileDir.FindFile(name, fName, TRUE) THEN
			FileDir.ConvertChar(fName, FileDir.PathChar, WinPathChar);
			RETURN old(fName)
		ELSE
			RETURN NIL
		END
	END Old;

	PROCEDURE new(): File;
		VAR F: File;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		F := NewFile(Kernel32.InvalidHandleValue);
		NEW(F.temp); F.name := ""; F.temp.temp := "";
		Kernel32.LeaveCriticalSection(moduleCS);
		RETURN F
	END new;

(** Creates a new file with the specified name. The same file descriptor is not returned with multiple calls of New with the same filename (this results in multiple copies of a file with the same name. i.e. the files are not registered in the directory). *)
	PROCEDURE New*(name: ARRAY OF CHAR): File;
		VAR F: File;
	BEGIN
		IF name = "" THEN
			F := new(); F.temp.name := ""
		ELSIF FileDir.CheckName(name) THEN
			F := new(); FileDir.ConvertChar(name, FileDir.PathChar, WinPathChar); COPY(name, F.temp.name)
		ELSE
			F := NIL
		END;
		RETURN F
	END New;

	PROCEDURE TempName(VAR name: ARRAY OF CHAR);
		VAR tempDir: FileDir.FileName; pref: ARRAY 8 OF CHAR;
	BEGIN
		FileDir.GetTempDirectory(tempDir); FileDir.ConvertChar(tempDir, FileDir.PathChar, WinPathChar);
		pref := "Oberon"; Kernel32.GetTempFileName(tempDir, pref, 0, name)
	END TempName;

	PROCEDURE ReOpen(F: File);
		VAR ret: LONGINT;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		CloseFile(F);
		IF F.temp # NIL THEN
			TempName(F.temp.temp);
			ret := Kernel32.CreateFile(F.temp.temp, GenericReadWrite, {Kernel32.FileShareRead}, NIL, Kernel32.CreateAlways, NewFlags, Kernel32.NULL)
		ELSE
			ret := Kernel32.CreateFile(F.name, GenericReadWrite, {Kernel32.FileShareRead}, NIL, Kernel32.OpenExisting, OpenFlags, Kernel32.NULL);
			IF ret = Kernel32.InvalidHandleValue THEN
				ret := Kernel32.CreateFile(F.name, {Kernel32.GenericRead}, ShareReadWrite, NIL, Kernel32.OpenExisting, OpenFlags, Kernel32.NULL)
			END
		END;
		F.handle := ret; F.pos := Kernel32.SetFilePointer(F.handle, F.pos, NIL, Kernel32.FileBegin);
		Kernel32.LeaveCriticalSection(moduleCS)
	END ReOpen;

	PROCEDURE Error(unlock: BOOLEAN);
		VAR err: LONGINT;
	BEGIN
		err := Kernel32.GetLastError();
	(* error string *)
		IF unlock THEN Kernel32.LeaveCriticalSection(moduleCS) END;
		HALT(99)
	END Error;

	PROCEDURE WriteBuf(F: File; buf: Buffer);
		VAR nWr: LONGINT;
	BEGIN
		IF buf.dirty & (buf.size > 0) THEN
			IF F.pos # buf.org THEN F.pos := Kernel32.SetFilePointer(F.handle, buf.org, NIL, Kernel32.FileBegin) END;
			IF (Kernel32.WriteFile(F.handle, buf.data, buf.size, nWr, NIL) = Kernel32.False) OR (nWr # buf.size) THEN
				ReOpen(F);
				IF (Kernel32.WriteFile(F.handle, buf.data, buf.size, nWr, NIL) = Kernel32.False) OR (nWr # buf.size) THEN
					Error(FALSE)
				END
			END;
			IF (buf.org+buf.size) > F.len THEN F.len := buf.org+buf.size END;
			INC(F.pos, nWr)
		END;
		buf.dirty := FALSE
	END WriteBuf;

	PROCEDURE ReadBuf(F: File; buf: Buffer);
		VAR nRe: LONGINT;
	BEGIN
		IF (buf.org+BufSize) > F.len THEN
			buf.size := F.len-buf.org
		ELSE
			buf.size := BufSize
		END;
		IF buf.size > 0 THEN
			IF F.pos # buf.org THEN F.pos := Kernel32.SetFilePointer(F.handle, buf.org, NIL, Kernel32.FileBegin) END;
			IF (Kernel32.ReadFile(F.handle, buf.data, buf.size, nRe, NIL) = Kernel32.False) OR (nRe # buf.size) THEN
				IF F.handle # Kernel32.InvalidHandleValue THEN
					Error(FALSE)
				ELSE
				(* reading garbage *)
				END
			END;
			INC(F.pos, nRe)
		ELSE
			buf.size := 0
		END;
		buf.dirty := FALSE
	END ReadBuf;

(** Positions a Rider at a certain position in a file. Multiple Riders can be positioned at different locations in a file. A Rider
	cannot be positioned beyond the end of a file. *)
	PROCEDURE Set*(VAR R: Rider; F: File; pos: LONGINT);
		VAR buf: Buffer; org, offset, i: LONGINT;
	BEGIN
		IF F # NIL THEN
IF pos > F.len THEN pos := F.len ELSIF pos < 0 THEN pos := 0 END;
			offset := pos MOD BufSize; org := pos - offset;
			buf := NIL; i := 0;
			WHILE (i < MaxBufs) & (F.bufs[i] # NIL) & (F.bufs[i].org # org) DO
				INC(i)
			END;
			IF i < MaxBufs THEN
 				IF F.bufs[i] # NIL THEN
 					buf := F.bufs[i]
 				ELSE
					buf := NIL; i := 0;
					WHILE (i < MaxBufs) & (F.bufs[i] # NIL) & (F.bufs[i].org # (org-BufSize)) DO
						INC(i)
					END;
					IF (i < MaxBufs) & (F.bufs[i] # NIL) THEN (* sequential read *)
						buf := F.bufs[i]; WriteBuf(F, buf); F.swap := i
					ELSE
						NEW(buf); F.bufs[i] := buf; buf.dirty := FALSE;
						buf.org := -1; buf.size := 0
					END
				END
			ELSE
				F.swap := (F.swap+1) MOD MaxBufs;
				buf := F.bufs[F.swap]; WriteBuf(F, buf)
			END;
			IF buf.org # org THEN
				buf.org := org;
				IF org < F.len THEN
					ReadBuf(F, buf)
				ELSE
					buf.size := 0
				END
			END
		ELSE
			buf := NIL; org := 0; offset := 0
		END;
		R.F := F; R.buf := buf; R.org := org; R.offset := offset;
		R.eof := FALSE; R.res := 0
	END Set;

(** Returns the File a Rider is based on. *)
	PROCEDURE Base*(VAR R: Rider): File;
	BEGIN
		RETURN R.F
	END Base;

(** Returns the current length of a file. *)
	PROCEDURE Length*(F: File): LONGINT;
	BEGIN
		RETURN F.len
	END Length;

(** Returns the offset of a Rider positioned on a file. *)
	PROCEDURE Pos*(VAR R: Rider): LONGINT;
	BEGIN
		RETURN R.org+R.offset
	END Pos;

	PROCEDURE getName(F: File; VAR name: ARRAY OF CHAR);
		VAR FD: Kernel32.FindData; h: Kernel32.HANDLE; i, j, stream: LONGINT;
	BEGIN
		COPY(F.name, name);
		i := 0; j := 0; stream := -1;
		WHILE name[i] # 0X DO
			IF name[i] = WinPathChar THEN
				j := i+1
			ELSIF (name[i] = ":") & (i > 1) THEN
				name[i] := 0X; stream := i
			END;
			INC(i)
		END;
		h := Kernel32.FindFirstFile(name, FD); Kernel32.FindClose(h);
		i := 0;
		WHILE FD.cFileName[i] # 0X DO
			name[j] := FD.cFileName[i];
			INC(i); INC(j)
		END;
		IF stream > 0 THEN
			WHILE F.name[stream] # 0X DO
				name[j] := F.name[stream];
				INC(stream); INC(j)
			END
		END;
		name[j] := 0X
	END getName;

(** Returns the full name of a file. *)
	PROCEDURE GetName*(F: File; VAR name: ARRAY OF CHAR);
	BEGIN
		getName(F, name);
		FileDir.ConvertChar(name, WinPathChar, FileDir.PathChar)
	END GetName;

(** Flushes the changes made to a file to disk. Register will automatically Close a file.
		Note: Close will only do a flush, the file is closed by the GC! *)
	PROCEDURE Close*(F: File);
		VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < MaxBufs) & (F.bufs[i] # NIL) DO
			WriteBuf(F, F.bufs[i]); INC(i)
		END;
		Kernel32.FlushFileBuffers(F.handle)
	END Close;

(*	(** Flushes the changes made to a file to disk. Further access to F will fail. *)
	PROCEDURE Dispose*(F: File);	(** non-portable *)
		VAR i: LONGINT;
	BEGIN
		Close(F); FinalizeFile(F);
		F.pos := 0; F.len := 0;
		FOR i := 0 TO MaxBufs-1 DO
			IF F.bufs[i] # NIL THEN F.bufs[i] := NIL END
		END
	END Dispose;	*)

(** Deletes a file. res = 0 indicates success. *)
	PROCEDURE Delete*(name: ARRAY OF CHAR; VAR res: INTEGER);
		VAR fName: FileDir.FileName; F: File; ret: LONGINT;
	BEGIN
		res := 1;
		IF (name # "") & FileDir.FindFile(name, fName, FALSE) THEN
			FileDir.ConvertChar(fName, FileDir.PathChar, WinPathChar);
			Kernel32.EnterCriticalSection(moduleCS);
			F := FindOpenFile(fName);
			IF F # NIL THEN
				Close(F); CloseFile(F);
				NEW(F.temp); COPY(F.name, F.temp.name); F.name := "";
				TempName(F.temp.temp);
				IF ~MoveFile(F.temp.name, F.temp.temp) THEN res := 2 ELSE res := 0 END;
				ret := Kernel32.CreateFile(F.temp.temp, GenericReadWrite, {Kernel32.FileShareRead}, NIL, Kernel32.OpenExisting, NewFlags, Kernel32.NULL);
				F.handle := ret; F.pos := Kernel32.SetFilePointer(F.handle, F.pos, NIL, Kernel32.FileBegin)
			ELSIF Kernel32.DeleteFile(fName) = Kernel32.False THEN
				res := 2
			ELSE
				res := 0
			END;
			Kernel32.LeaveCriticalSection(moduleCS)
		END
	END Delete;

(** Returns the time (t) and date (d) when a file was last modified. *)
	PROCEDURE GetDate*(F: File; VAR t, d: LONGINT);
		VAR ft, lft: Kernel32.FileTime; st: Kernel32.SystemTime;
	BEGIN
		Kernel32.GetFileTime(F.handle, NIL, NIL, ft);
		Kernel32.FileTimeToLocalFileTime(ft, lft);
		Kernel32.FileTimeToSystemTime(lft, st);
		d := LONG(st.wYear-1900)*200H + LONG(st.wMonth)*20H + LONG(st.wDay);
		t := LONG(st.wHour)*1000H + LONG(st.wMinute)*40H + LONG(st.wSecond)
	END GetDate;

(** Sets the modification time (t) and date (d) of a file. *)
	PROCEDURE SetDate*(F: File; t, d: LONGINT);
		VAR ft, lft: Kernel32.FileTime; st: Kernel32.SystemTime;
	BEGIN
		st.wDay := SHORT(d MOD 20H); d := ASH(d, -5);
		st.wMonth := SHORT(d MOD 10H); d := ASH(d, -4);
		st.wYear := SHORT(d MOD 80H) + 1900;
		st.wMilliseconds := 0;
		st.wSecond := SHORT(t MOD 40H); t := ASH(t, -6);
		st.wMinute := SHORT(t MOD 40H); t := ASH(t, -6);
		st.wHour := SHORT(t MOD 20H);
		Kernel32.SystemTimeToFileTime(st, lft);
		Kernel32.LocalFileTimeToFileTime(lft, ft);
		Kernel32.SetFileTime(F.handle, NIL, NIL, ft)
	END SetDate;

(** Register a file created with New in the directory, replacing the previous file in the directory with the same name. The file is automatically closed. *)
	PROCEDURE Register*(F: File);
		VAR ret: LONGINT; res: INTEGER;
	BEGIN
		Close(F);
		IF (F.temp # NIL) & (F.temp.name # "") THEN
			Kernel32.EnterCriticalSection(moduleCS);
			IF F.handle = Kernel32.InvalidHandleValue THEN ReOpen(F); Close(F) END;
			IF FileDir.FindFile(F.temp.name, F.name, FALSE) THEN
				Delete(F.name, res); (*IF res # 0 THEN Error(TRUE) END;*)
				FileDir.ConvertChar(F.name, FileDir.PathChar, WinPathChar)
			ELSE
				COPY(F.temp.name, F.name)
			END;
			CloseFile(F);
			ret := Kernel32.CreateFile(F.name, {Kernel32.GenericRead}, ShareReadWrite, NIL, Kernel32.CreateAlways, OpenFlags, Kernel32.NULL);
			IF ret = Kernel32.InvalidHandleValue THEN Error(TRUE) END;
			F.handle := ret; CloseFile(F);
			COPY(F.name, F.temp.name);
			IF FileDir.FindFile(F.temp.name, F.name, FALSE) THEN
				FileDir.ConvertChar(F.name, FileDir.PathChar, WinPathChar);
				IF ~MoveFile(F.temp.temp, F.name) THEN Error(TRUE) END;
				ret := Kernel32.CreateFile(F.name, GenericReadWrite, {Kernel32.FileShareRead}, NIL, Kernel32.OpenExisting, OpenFlags, Kernel32.NULL);
				IF ret = Kernel32.InvalidHandleValue THEN Error(TRUE) END;
				F.handle := ret; F.pos := Kernel32.SetFilePointer(F.handle, F.pos, NIL, Kernel32.FileBegin)
			ELSE
				Error(TRUE)
			END;
			F.temp := NIL; Kernel32.LeaveCriticalSection(moduleCS)
		END
	END Register;

(** Read a byte from a file, advancing the Rider one byte further. R.eof indicates if the end of the file has been passed. *)
	PROCEDURE Read*(VAR R: Rider; VAR x: SYSTEM.BYTE);
		VAR F: File; buf: Buffer; offset: LONGINT;
	BEGIN
		buf := R.buf; F := R.F; offset := R.offset;
		IF R.org # buf.org THEN
			Set(R, F, R.org+offset); buf := R.buf; offset := R.offset
		END;
		IF offset < buf.size THEN
			x := buf.data[offset]; R.offset := offset+1
		ELSIF (R.org+offset) < F.len THEN
			Set(R, F, R.org+offset); x := R.buf.data[0]; R.offset := 1
		ELSE
			x := 0X; R.eof := TRUE
		END
	END Read;

(** Reads a sequence of length n bytes into the buffer x, advancing the Rider. Less bytes will be read when reading over the
	length of the file. r.res indicates the number of unread bytes. x must be big enough to hold n bytes.*)
	PROCEDURE ReadBytes*(VAR R: Rider; VAR x: ARRAY OF SYSTEM.BYTE; n: LONGINT);
		VAR F: File; buf: Buffer; xpos, min, remaining, offset: LONGINT;
	BEGIN
		ASSERT(LEN(x) >= n, 32);
		buf := R.buf; F := R.F; xpos := 0; offset := R.offset;
		WHILE n > 0 DO
			IF (R.org # buf.org) OR (offset >= BufSize) THEN
				Set(R, F, R.org + offset); buf := R.buf; offset := R.offset
			END;
			remaining := buf.size - offset;
			IF remaining = 0 THEN
				R.res := n; R.eof := TRUE; RETURN
			ELSE (* min := MIN(remaining, n) *)
				IF n > remaining THEN min := remaining ELSE min := n END
			END;
			SYSTEM.MOVE(SYSTEM.ADR(buf.data) + offset, SYSTEM.ADR(x) + xpos, min);
			INC(offset, min); R.offset := offset; INC(xpos, min); DEC(n, min)
		END;
		R.res := 0; R.eof := FALSE
	END ReadBytes;

(** Writes a byte into the file at the Rider position, advancing the Rider by one. *)
	PROCEDURE Write*(VAR R: Rider; x: SYSTEM.BYTE);
		VAR F: File; buf: Buffer; offset: LONGINT;
	BEGIN
		buf := R.buf; F := R.F; offset := R.offset;
		IF (R.org # buf.org) OR (offset >= BufSize) THEN
			Set(R, F, R.org+offset); buf := R.buf; offset := R.offset
		END;
		buf.data[offset] := x; buf.dirty := TRUE;
		IF offset = buf.size THEN
			INC(buf.size); INC(F.len)
		END;
		R.offset := offset+1; R.res := 0
	END Write;

(** Writes the buffer x containing n bytes into a file at the Rider position. *)
	PROCEDURE WriteBytes*(VAR R: Rider; VAR x: ARRAY OF SYSTEM.BYTE; n: LONGINT);
		VAR F: File; buf: Buffer; xpos, min, restInBuf, offset: LONGINT;
	BEGIN
		ASSERT(LEN(x) >= n, 32);
		buf := R.buf; F := R.F; xpos := 0; offset := R.offset;
		WHILE n > 0 DO
			IF (R.org # buf.org) OR (offset >= BufSize) THEN
				Set(R, F, R.org + offset); buf := R.buf; offset := R.offset;
			END;
			restInBuf := BufSize - offset;
			IF n < restInBuf THEN min := n ELSE min := restInBuf END;
			SYSTEM.MOVE(SYSTEM.ADR(x) + xpos, SYSTEM.ADR(buf.data) + offset, min);
			INC(offset, min); R.offset := offset;
			IF offset > buf.size THEN INC(F.len, offset - buf.size); buf.size := offset END;
			INC(xpos, min); DEC(n, min); buf.dirty := TRUE
		END;
		R.res := 0
	END WriteBytes;

(** Portable routines to read the standard Oberon types. *)

	PROCEDURE ReadInt*(VAR R: Rider; VAR x: INTEGER);
	BEGIN
		ReadBytes(R, x, 2)
	END ReadInt;

	PROCEDURE ReadLInt*(VAR R: Rider; VAR x: LONGINT);
	BEGIN
		ReadBytes(R, x, 4)
	END ReadLInt;

	PROCEDURE ReadSet*(VAR R: Rider; VAR x: SET);
	BEGIN
		ReadBytes(R, x, 4)
	END ReadSet;

	PROCEDURE ReadBool*(VAR R: Rider; VAR x: BOOLEAN);
	BEGIN
		Read(R, SYSTEM.VAL(SYSTEM.BYTE, x))
	END ReadBool;

	PROCEDURE ReadReal*(VAR R: Rider; VAR x: REAL);
	BEGIN
		ReadBytes(R, x, 4)
	END ReadReal;

	PROCEDURE ReadLReal*(VAR R: Rider; VAR x: LONGREAL);
	BEGIN
		ReadBytes(R, x, 8)
	END ReadLReal;

	PROCEDURE ReadString*(VAR R: Rider; VAR x: ARRAY OF CHAR);
		VAR i: LONGINT; ch: CHAR;
	BEGIN
		i := 0;
		REPEAT
			Read(R, ch); x[i] := ch; INC(i)
		UNTIL ch = 0X
	END ReadString;

(** Reads a number in compressed variable length notation using the minimum amount of bytes. *)
	PROCEDURE ReadNum*(VAR R: Rider; VAR x: LONGINT);
		VAR n: LONGINT; s: SHORTINT; ch: CHAR;
	BEGIN
		s := 0; n := 0; Read(R, ch);
		WHILE ORD(ch) >= 128 DO INC(n, ASH(ORD(ch) - 128, s) ); INC(s, 7); Read(R, ch) END;
		x := n + ASH(ORD(ch) MOD 64 - ORD(ch) DIV 64 * 64, s)
	END ReadNum;

(** Portable routines to write the standard Oberon types. *)

	PROCEDURE WriteInt*(VAR R: Rider; x: INTEGER);
	BEGIN
		WriteBytes(R, x, 2)
	END WriteInt;

	PROCEDURE WriteLInt*(VAR R: Rider; x: LONGINT);
	BEGIN
		WriteBytes(R, x, 4)
	END WriteLInt;

	PROCEDURE WriteSet*(VAR R: Rider; x: SET);
	BEGIN
		WriteBytes(R, x, 4)
	END WriteSet;

	PROCEDURE WriteBool*(VAR R: Rider; x: BOOLEAN);
	BEGIN
		Write(R, SYSTEM.VAL(SYSTEM.BYTE, x))
	END WriteBool;

	PROCEDURE WriteReal*(VAR R: Rider; x: REAL);
	BEGIN
		WriteBytes(R, x, 4)
	END WriteReal;

	PROCEDURE WriteLReal*(VAR R: Rider; x: LONGREAL);
	BEGIN
		WriteBytes(R, x, 8)
	END WriteLReal;

	PROCEDURE WriteString*(VAR R: Rider; x: ARRAY OF CHAR);
		VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE x[i] # 0X DO INC(i) END;
		WriteBytes(R, x, i+1)
	END WriteString;

(** Writes a number in a compressed format. *)
	PROCEDURE WriteNum*(VAR R: Rider; x: LONGINT);
	BEGIN
		WHILE (x < - 64) OR (x > 63) DO Write(R, CHR(x MOD 128 + 128)); x := x DIV 128 END;
		Write(R, CHR(x MOD 128))
	END WriteNum;

	PROCEDURE copy(VAR src, dest: ARRAY OF CHAR; move: BOOLEAN; VAR res: INTEGER);
		VAR
			srcName, destName: FileDir.FileName;
			srcF, destF: File;
			srcR, destR: Rider;
			t, d: LONGINT;
			buf: ARRAY 1024 OF CHAR;
	BEGIN
		res := 1;
		IF (src # "") & FileDir.FindFile(src, srcName, ~move) THEN
			FileDir.ConvertChar(srcName, FileDir.PathChar, WinPathChar);
			Kernel32.EnterCriticalSection(moduleCS);
			srcF := FindOpenFile(srcName);
			IF srcF = NIL THEN
				IF FileDir.FindFile(dest, destName, FALSE) THEN
					FileDir.ConvertChar(destName, FileDir.PathChar, WinPathChar);
					destF := FindOpenFile(destName)
				ELSE
					COPY(dest, destName);
					FileDir.ConvertChar(destName, FileDir.PathChar, WinPathChar);
					destF := NIL
				END;
				IF destF = NIL THEN
					IF move THEN
						IF MoveFile(srcName, destName) THEN res := 0 ELSE res := 2 END
					ELSE
						IF Kernel32.CopyFile(srcName, destName, Kernel32.False) = Kernel32.False THEN res := 2 ELSE res := 0 END
					END;
					Kernel32.LeaveCriticalSection(moduleCS); RETURN
				END;
				srcF := old(srcName)
			END;
			Kernel32.LeaveCriticalSection(moduleCS);
			IF srcF # NIL THEN
				GetDate(srcF, t, d); Set(srcR, srcF, 0);
				destF := New(dest);
				IF destF # NIL THEN
					Register(destF); Set(destR, destF, 0);
					ReadBytes(srcR, buf, 1024);
					WHILE ~srcR.eof DO
						WriteBytes(destR, buf, 1024); ReadBytes(srcR, buf, 1024)
					END;
					WriteBytes(destR, buf, 1024-srcR.res);
					Close(destF); SetDate(destF, t, d);
					IF move THEN
						Delete(src, res)
					ELSE
						res := 0
					END
				ELSE
					res := 3
				END
			END
		END
	END copy;

	(** Renames a file. res = 0 indicates success. *)
	PROCEDURE Rename*(old, new: ARRAY OF CHAR; VAR res: INTEGER);
	BEGIN
		copy(old, new, TRUE, res)
	END Rename;

	(** Copies a file. res = 0 indicates success. *)	(** non-portable *)
	PROCEDURE Copy*(src, dest: ARRAY OF CHAR; VAR res: INTEGER);
	BEGIN
		copy(src, dest, FALSE, res)
	END Copy;

	PROCEDURE *Shutdown();
	BEGIN
		Kernel32.DeleteCriticalSection(moduleCS)
	END Shutdown;

	PROCEDURE Init();
	BEGIN
		Kernel32.InitializeCriticalSection(moduleCS);
		Kernel32.EnterCriticalSection(moduleCS);
		Kernel.InstallTermHandler(Shutdown);
		NEW(root); root.next := NIL;
		OpenFlags := {Kernel32.FileAttributeNormal, Kernel32.FileFlagRandomAccess};
		NewFlags := OpenFlags;
		GenericReadWrite := {Kernel32.GenericRead, Kernel32.GenericWrite};
		ShareReadWrite := {Kernel32.FileShareRead, Kernel32.FileShareWrite};
		Kernel32.LeaveCriticalSection(moduleCS)
	END Init;

BEGIN
	Init()
END Files.

(** Remarks:

1. Oberon uses the little-endian byte ordering for exchanging files between different Oberon platforms.

2. Files are separate entities from directory entries. Files may be anonymous by having no name and not being registered in a directory. Files only become visible to other clients of the Files module by explicitly passing a File descriptor or by registering a file and then opening it from the other client. Deleting a file of which a file descriptor is still available, results in the file becoming anonymous. The deleted file may be re-registered at any time.

3. Files and their access mechanism (Riders) are separated. A file might have more than one rider operating on it at different offsets in the file.

4. The garbage collector will automatically close files when they are not required any more. File buffers will be discarded without flushing them to disk. Use the Close procedure to update modified files on disk.

5. Relative and absolute filenames written in the directory syntax of the host operating system are used. By convention, Oberon filenames consists of the letters A..Z, a..z, 0..9, and ".". The directory separator is typically / or :. Oberon filenames are case sensitive (not true for this implementation!!!). *)
