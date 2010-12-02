(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Objects; (** portable / source: Win32.Objects.Mod *)	(* JG 21.9.93/comments jm 28.2.95*)

(** Module Objects forms the basis of the object-oriented part of the Oberon system. It provides the system with the type Object and defines what messages objects understand. Most entities in Oberon are derived from this base type. *)

	IMPORT SYSTEM, Kernel32, Kernel, Files, Modules;

	CONST
		enum* = 0; get* = 1; set* = 2; (** AttrMsg and LinkMsg id *)
		shallow* = 0; deep* = 1; (** CopyMsg id *)
		load* = 0; store* = 1; (** FileMsg id*)

		(** AttrMsg class *)
		Inval* = 0; String* = 2; Int* = 3; Real* = 4; LongReal* = 5; Char* = 6; Bool* = 7;

		MaxNews = 64; MaxRuns = 64;
		StepSize = 64; 	(* number of elems to grow an index block *)
		Version = 052454942H;

	TYPE
		Name* = ARRAY 32 OF CHAR;
		Object* = POINTER TO ObjDesc;
		Dummy* = POINTER TO DummyDesc;
		Library* = POINTER TO LibDesc;

		ObjMsg* = RECORD	(** Base type of all messages sent to objects. *)
			stamp*: LONGINT;	(** Message time stamp. *)
			dlink*: Object	(** Sender of the message. *)
		END;

		Handler* = PROCEDURE (obj: Object; VAR M: ObjMsg);

		ObjDesc* = RECORD	(** Base type of all objects. *)
			stamp*: LONGINT;	(** Time stamp of last message processed by object. *)
			dlink*,	(** Next object in the message thread. *)
			slink*: Object;	(** Next object in a list of objects. *)
			lib*: Library; ref*: INTEGER;	(** Library and reference number of object. *)
			handle*: Handler	(** Message handler. *)
		END;

		(** Set, get and enumerate the attributes of an object. *)
		AttrMsg* = RECORD (ObjMsg)
			id*: INTEGER;	(** get, set or enum. *)
			Enum*: PROCEDURE (name: ARRAY OF CHAR);	(** Called by object to enumerate attribute names. *)
			name*: Name;	(** Name of the attribute to be set or retrieved. *)
			res*: INTEGER;	(** Return result: < 0 = no response, >= 0 action completed. *)
			class*: INTEGER;	(** Attribute class (Inval, String, Int, Real, LongReal, Char or Bool). *)
			i*: LONGINT;
			x*: REAL;
			y*: LONGREAL;
			c*: CHAR;
			b*: BOOLEAN;
			s*: ARRAY 64 OF CHAR
		END;

		(** Link objects with each other or retrieve the link structure between objects *)
		LinkMsg* = RECORD (ObjMsg)
			id*: INTEGER;	(** get, set or enum. *)
			Enum*: PROCEDURE (name: ARRAY OF CHAR);	(** Called by object to enumerate link names. *)
			name*: Name;	(** Link name. *)
			res*: INTEGER;	(** Return result: < 0 = no response, >= 0 action completed. *)
			obj*: Object	(** Value of the link to be set, or link result. *)
		END;

		(** Request to an object to make a copy of itself *)
		CopyMsg* = RECORD (ObjMsg)
			id*: INTEGER;	(** Copy style: deep or shallow. *)
			obj*: Object	(** Result of the copy operation. *)
		END;

		(** Request to an object to bind itself to a library. *)
		BindMsg* = RECORD (ObjMsg)
			lib*: Library	(** Library where object should be bound. *)
		END;

		(** Request to an object to load/store itself. *)
		FileMsg* = RECORD (ObjMsg)
			id*: INTEGER;	(** load or store *)
			len*: LONGINT;	(** Length of the object data on loading. *)
			R*: Files.Rider	(** Rider with which to load or store data. *)
		END;

		(** Search request for an object with the specified name. *)
		FindMsg* = RECORD (ObjMsg)
			name*: Name;
			obj*: Object	(** Result object, if found. *)
		END;

		(** A placeholder object created for objects that cannot be loaded. *)
		DummyDesc* = RECORD (ObjDesc)
			GName*: Name;	(** Generator procedure of failed object. *)
			len: LONGINT;	(* length of data block *)
			blk: POINTER TO ARRAY OF CHAR	(* stores the data on file *)
		END;

		(** (Hidden) Data structure containing the objects of a library. *)
		Index* = POINTER TO IndexDesc;
		IndexDesc* = RECORD END;

		(** (Hidden) Map of (ref) numbers and corresponding object names. *)
		Dictionary* = POINTER TO DictionaryDesc;
		DictionaryDesc* = RECORD END;

		Block = POINTER TO ARRAY OF Object;
		ArrayIndex = POINTER TO ArrayIndexDesc;
		ArrayIndexDesc = RECORD (IndexDesc)
			index: Block;	(* index block, containing the objects *)
			org: LONGINT;	(* offset in libfile where index block starts *)
			size: INTEGER	(* size of the actual index block *)
		END;

		Entry = POINTER TO EntryDesc;
		EntryDesc = RECORD
			next: Entry;
			key: INTEGER;
			name: Name
		END;

		ListDict = POINTER TO ListDictDesc;
		ListDictDesc = RECORD (DictionaryDesc)
			key: INTEGER;
			first: Entry
		END;

		GenName = ARRAY 64 OF CHAR;

		LibDesc* = RECORD	(** Container for persistent objects. *)
			next[UNTRACED]: Library; (* offset used by Fonts.GetCharObj, also next offset *)
			ind*: Index;	(** Library contents. *)
			f: Files.File;	(* file containing data *)
			R: Files.Rider;	(* a rider on the lib file *)
			name*: Name;	(** name of the library. Private library when "", else public library. *)
			dict*: Dictionary;	(** Object names. *)
			maxref*: INTEGER;	(** Highest ref number used in library. *)
			GName: POINTER TO ARRAY OF GenName;

			(** Return a free reference number. *)
			GenRef*: PROCEDURE (L: Library; VAR ref: INTEGER);

			(** Return the object with the indicated reference number. *)
			GetObj*: PROCEDURE (L: Library; ref: INTEGER; VAR obj: Object);

			(** Insert an object under the indicated reference number. *)
			PutObj*: PROCEDURE (L: Library; ref: INTEGER; obj: Object);

			(** Free object with indicated reference number. *)
			FreeObj*: PROCEDURE (L: Library; ref: INTEGER);

			(** Initialize/load library with L.name. *)
			Load*: PROCEDURE (L: Library);

			(** Store library under L.name. *)
			Store*: PROCEDURE (L: Library)
		END;

		NewProc* = PROCEDURE (): Library;	(** Library generator. *)
		EnumProc* = PROCEDURE (L: Library);	(** Enumerator of public libraries *)

		RunRec = RECORD beg, end: INTEGER END;

		Alias = POINTER TO AliasDesc;
		AliasDesc = RECORD
			next: Alias;
			name: Name;
			lib[UNTRACED]: Library
		END;

	VAR
		LibBlockId*: CHAR;	(** Identification character as first character of a Library file. *)
		FirstLib: Library;
		NoObj: Object;

		NewObj*: Object;	(** Newly generated objects are returned here. *)
		stamp: LONGINT;

		nofreg: INTEGER;
		LibExt: ARRAY	8, 8 OF CHAR;
		LibNew: ARRAY 8 OF NewProc;

		FirstAlias: Alias;

	PROCEDURE Stamp*(VAR M: ObjMsg);	(** Timestamp a message.	*)
	BEGIN
		M.stamp := stamp; INC(stamp)
	END Stamp;

	(* general library management *)

	(* Delete library L from the list, without changing L.next. *)

	PROCEDURE *Cleanup(L: SYSTEM.PTR);
		VAR p0, p: Library; a0, a: Alias;
	BEGIN
		WITH L: Library DO
			p0 := FirstLib; p := p0.next;
			WHILE (p # NIL) & (p # L) DO p0 := p; p := p.next END;
			IF p = L THEN (* found in list *)
				p0.next := p.next
			END;
			a0 := FirstAlias; a := a0.next;
			WHILE (a # NIL) & (a.lib # L) DO a0 := a; a := a.next END;
			IF a # NIL THEN a0.next := a.next END
		END
	END Cleanup;

	(* Check if end of s matches ext. len returns length of ext. *)

	PROCEDURE Match(VAR s, ext: ARRAY OF CHAR; VAR len: LONGINT): BOOLEAN;
		VAR i, j: LONGINT;
	BEGIN
		i := 0; WHILE ext[i] # 0X DO INC(i) END; len := i;
		j := 0; WHILE s[j] # 0X DO INC(j) END;
		REPEAT DEC(i); DEC(j)
		UNTIL (i < 0) OR (j < 0) OR (ext[i] # s[j]);
		RETURN i < 0
	END Match;

	(** Search, load and cache a public library. *)
	PROCEDURE ThisLibrary*(name: ARRAY OF CHAR): Library;
		VAR L: Library; len, n, n0, t: LONGINT; proc: NewProc; A: Alias;
	BEGIN
		A := FirstAlias.next;
		WHILE (A # NIL) & (name # A.name) DO A := A.next END;
		IF A # NIL THEN
			L := A.lib
		ELSE
			L := FirstLib.next;
			WHILE (L # NIL) & (name # L.name) DO L := L.next END;
			IF L = NIL THEN
				n := nofreg; n0 := 0; len := -1;
				WHILE n0 # nofreg DO	(* find longest matching extension *)
					IF Match(name, LibExt[n0], t) & (t >= len) THEN
						n := n0; len := t
					END;
					INC(n0)
				END;
				IF n # nofreg THEN
					proc := LibNew[n]; L := proc();
					COPY(name, L.name);
					L.Load(L); Kernel.RegisterObject(L, Cleanup, FALSE);
					IF name = L.name THEN
						L.next := FirstLib.next; FirstLib.next := L
					ELSE
						NEW(A); COPY(name, A.name); A.lib := L; A.next := FirstAlias.next; FirstAlias.next := A;
						Kernel32.Str("Alias: ");
						Kernel32.Str(name); Kernel32.Str(" -> "); Kernel32.Str(L.name);
						Kernel32.Ln()
					END
				END
			END
		END;
		RETURN L
	END ThisLibrary;

(** Free library from public library cache *)
	PROCEDURE FreeLibrary*(name: ARRAY OF CHAR);
		VAR L: Library;
	BEGIN
		L := FirstLib.next;
		WHILE L # NIL DO
			IF name = L.name THEN Cleanup(L) END;
			L := L.next
		END
	END FreeLibrary;

(** Enumerate public libraries. Don't free libraries during enumeration! *)
	PROCEDURE Enumerate*(P: EnumProc);
		VAR L: Library;
	BEGIN
		L := FirstLib.next;
		WHILE L # NIL DO P(L); L := L.next END
	END Enumerate;

(** Register a new library file extension and its associated generator procedure. *)
	PROCEDURE Register*(ext: ARRAY OF CHAR; new: NewProc);
		VAR n, len: LONGINT; L: Library;
	BEGIN
		n := 0;
		WHILE (n # nofreg) & (ext # LibExt[n]) DO INC(n) END;
		IF n # nofreg THEN LibNew[n] := new
		ELSE COPY(ext, LibExt[nofreg]); LibNew[nofreg] := new; INC(nofreg)
		END;
		(* free library entries that match *)
		L := FirstLib.next;
		WHILE L # NIL DO
			IF Match(L.name, ext, len) THEN Cleanup(L) END;
			L := L.next
		END
	END Register;

	(*standard libraries*)

	PROCEDURE ReadName(VAR R: Files.Rider; VAR name: ARRAY OF CHAR);
		VAR i: LONGINT; ch: CHAR;
	BEGIN
		i := 0; Files.Read(R, ch);
		WHILE (ch # ".") & (ch # 0X) DO name[i] := ch; INC(i); Files.Read(R, ch) END;
		name[i] := "."; INC(i); Files.Read(R, ch);
		WHILE ch # 0X DO name[i] := ch; INC(i); Files.Read(R, ch) END;
		name[i] := 0X
	END ReadName;

	PROCEDURE SplitName(VAR name, MName, PName: ARRAY OF CHAR);
		VAR i, j: LONGINT;
	BEGIN i := 0;
		WHILE name[i] # "." DO MName[i] := name[i]; INC(i) END;
		MName[i] := 0X; INC(i); j := 0;
		WHILE name[i] # 0X DO PName[j] := name[i]; INC(i); INC(j) END;
		PName[j] := 0X
	END SplitName;

	PROCEDURE *HandleDummy(obj: Object; VAR M: ObjMsg);
		VAR dum: Dummy;
	BEGIN
		WITH obj: Dummy DO
			IF M IS AttrMsg THEN
				WITH M: AttrMsg DO
					IF (M.id = get) & (M.name = "Gen") THEN COPY(obj.GName, M.s) END
				END
			ELSIF M IS CopyMsg THEN
				WITH M: CopyMsg DO
					IF M.stamp = obj.stamp THEN M.obj := obj.dlink
					ELSE
						NEW(dum); obj.stamp := M.stamp; obj.dlink := dum;
						dum.handle := obj.handle;
						COPY(obj.GName, dum.GName); dum.len := obj.len; dum.blk := obj.blk;
						M.obj := dum
					END
				END
			ELSIF M IS FileMsg THEN
				WITH M: FileMsg DO
					IF M.id = load THEN
						obj.len := M.len; NEW(obj.blk, obj.len);
						Files.ReadBytes(M.R, obj.blk^, obj.len)
					ELSIF M.id = store THEN
						Files.WriteBytes(M.R, obj.blk^, obj.len)
					END
				END
			END
		END
	END HandleDummy;

	PROCEDURE NewDummy(VAR GName: ARRAY OF CHAR);
		VAR dum: Dummy;
	BEGIN
		NEW(dum); dum.handle := HandleDummy;
		COPY(GName, dum.GName);
		NewObj := dum
	END NewDummy;

	PROCEDURE *GetObj(L: Library; ref: INTEGER; VAR obj: Object);
		VAR objOrg: LONGINT; ind: ArrayIndex; MName, PName: ARRAY 32 OF CHAR; n: INTEGER;
				Mod: Modules.Module; Cmd: Modules.Command; M: FileMsg;
	BEGIN
		ind := L.ind(ArrayIndex);
		IF (ref < 0) OR (ref >= ind.size) THEN obj := NIL; RETURN END;
		obj := ind.index[ref];
		IF obj = NIL THEN
			IF L.f # NIL THEN
				Files.Set(L.R, L.f, ind.org + ref*4);
				Files.ReadLInt(L.R, objOrg);
				IF objOrg > ind.org THEN
					NewObj := NIL;
					Files.Set(L.R, L.f, objOrg);
					Files.ReadInt(L.R, n);
					SplitName(L.GName[n], MName, PName);
					Mod := Modules.ThisMod(MName);
					IF Modules.res = 0 THEN
						Cmd := Modules.ThisCommand(Mod, PName);
						IF Modules.res = 0 THEN Cmd
						ELSE NewDummy(L.GName[n])
						END
					ELSE NewDummy(L.GName[n])
					END;
					obj := NewObj;
					IF obj # NIL THEN
						obj.lib := L; obj.ref := ref;
						ind.index[ref] := obj;
						(* read in data *)
						M.id := load; Stamp(M);
						Files.ReadLInt(L.R, M.len);
						Files.Set(M.R, L.f, Files.Pos(L.R));
						IF M.len > 0 THEN obj.handle(obj, M) END
					ELSE ind.index[ref] := NoObj
					END
				ELSE ind.index[ref] := NoObj
				END
			ELSE ind.index[ref] := NoObj
			END
		ELSIF obj = NoObj THEN obj := NIL
		END
	END GetObj;

	PROCEDURE *PutObj(L: Library; ref: INTEGER; obj: Object);
		VAR index: Block; ind: ArrayIndex; i, size: LONGINT;
	BEGIN
		IF (ref < 0) OR (obj = NIL) THEN RETURN END;
		ind := L.ind(ArrayIndex);
		IF ref >= ind.size THEN
			size := (ref DIV StepSize + 1) * StepSize;
			NEW(index, size);
			IF ind.index # NIL THEN SYSTEM.MOVE(SYSTEM.ADR(ind.index^), SYSTEM.ADR(index^), ind.size*4) END;
			FOR i := ind.size TO size-1 DO index[i] := NoObj END;
			ind.size := SHORT(size); ind.index := index
		END;
		ind.index[ref] := obj; obj.lib := L; obj.ref := ref;
		IF ref >= L.maxref THEN L.maxref := ref + 1 END
	END PutObj;

	PROCEDURE *FreeObj(L: Library; ref: INTEGER);
	BEGIN
		IF (ref >= 0) & (ref < L.ind(ArrayIndex).size) THEN L.ind(ArrayIndex).index[ref] := NoObj END
	END FreeObj;

	PROCEDURE *GenRef(L: Library; VAR ref: INTEGER);
	BEGIN
		ref := L.maxref; INC(L.maxref)
	END GenRef;

(* Load a standard object library (old format) from position pos in file f. *)
	PROCEDURE OldLoadLibrary(L: Library; f: Files.File; pos: LONGINT; VAR len: LONGINT);
		VAR R, S: Files.Rider; Mod: Modules.Module; Cmd: Modules.Command; NofRuns, key, N, i, k, m: INTEGER;
				clen, dlen: LONGINT; type, n: SHORTINT; ch: CHAR; entry: Entry;
				obj: Object; M: FileMsg; MName, PName: Name; GName: ARRAY MaxNews OF Name;
				run: ARRAY MaxRuns OF RunRec; ind: ArrayIndex; dict: ListDict;
	BEGIN
		ind := L.ind(ArrayIndex); dict:= L.dict(ListDict);
		Files.Set(R, f, pos); Files.Read(R, type);
		Files.ReadLInt(R, clen);
		Files.Set(S, f, pos + 1 + clen);
		Files.ReadLInt(S, dlen);
		Files.ReadInt(S, key);
		WHILE key # MIN(INTEGER) DO NEW(entry);
			Files.ReadString(S, entry.name);
			entry.key := key;
			entry.next := dict.first; dict.first := entry;
			IF key < dict.key THEN dict.key := key END;
			Files.ReadInt(S, key)
		END;
		IF type >= 0 THEN (*old format*)
			Files.Read(R, ch); Files.Read(R, ch);
			Files.ReadInt(R, i); Files.ReadInt(R, i); Files.ReadInt(R, i);
			Files.ReadInt(R, i); Files.ReadInt(R, i)
		END;
		Files.ReadInt(R, NofRuns);
		k := 0;
		 WHILE k # NofRuns DO
			Files.ReadInt(R, run[k].beg); Files.ReadInt(R, run[k].end);
			INC(k)
		END;
		N := 0; k := 0; m := 0;
		WHILE k < NofRuns DO m := run[k].beg;
			WHILE m < run[k].end DO Files.Read(R, n);
				IF n = N THEN ReadName(R, GName[N]); INC(N) END;
				SplitName(GName[n], MName, PName);
				Mod := Modules.ThisMod(MName);
				IF Modules.res = 0 THEN
					Cmd := Modules.ThisCommand(Mod, PName);
					IF Modules.res = 0 THEN Cmd
					ELSE NewDummy(GName[n])
					END
				ELSE NewDummy(GName[n])
				END;
				PutObj(L, m, NewObj);
				NewObj.lib := L; NewObj.ref := m;
				INC(m)
			END;
			INC(k)
		END;
		L.maxref := m;
		M.id := load; Stamp(M);
		Files.Set(M.R, f, Files.Pos(R));
		k := 0; m := 0;
		WHILE k < NofRuns DO m := run[k].beg;
			WHILE m < run[k].end DO
				Files.ReadLInt(M.R, M.len);
				pos := Files.Pos(M.R)+M.len;
				IF M.len # 0 THEN
					obj := ind.index[m];
					obj.handle(obj, M)
				END;
				IF Files.Pos(M.R) < pos THEN (*ejz skip rest of obj data *)
					Files.Set(M.R, f, pos)
				ELSIF Files.Pos(M.R) > pos THEN (*ejz object read too much *)
					HALT(99)
				END;
				INC(m)
			END;
			INC(k)
		END;
		len := 1 + clen + dlen
	END OldLoadLibrary;

(** Load a standard object library from position pos in file f. *)
	PROCEDURE LoadLibrary*(L: Library; f: Files.File; pos: LONGINT; VAR len: LONGINT);
		VAR ind: ArrayIndex; dict: ListDict; i, n, N, version, dorg, gorg: LONGINT; key: INTEGER; entry: Entry;
				R: Files.Rider;
	BEGIN
		ind := L.ind(ArrayIndex);
		Files.Set(R, f, pos);
		Files.ReadLInt(R, version);
		IF version = Version THEN
			Files.ReadLInt(R, gorg); Files.ReadLInt(R, dorg);
			Files.ReadInt(R, L.maxref); ind.size := L.maxref; ind.org := Files.Pos(R);
			IF L.maxref > 0 THEN NEW(ind.index, L.maxref) END;
			FOR i := 0 TO L.maxref - 1 DO ind.index[i] := NIL END;
			(* read generator table *)
			Files.Set(R, f, gorg);
			Files.ReadInt(R, key); N := key;
			IF N > 0 THEN
				NEW(L.GName, N);
				FOR n := 0 TO N - 1 DO Files.ReadString(R, L.GName[n]) END
			ELSE
				L.GName := NIL
			END;
			(* read dict *)
			dict := L.dict(ListDict);
			Files.Set(R, f, dorg);
			Files.ReadInt(R, key);
			WHILE (key # MIN(INTEGER)) & ~R.eof DO
				NEW(entry);
				Files.ReadString(R, entry.name);
				entry.key := key;
				entry.next := dict.first; dict.first := entry;
				IF key < dict.key THEN dict.key := key END;
				Files.ReadInt(R, key)
			END;
			L.f := f; Files.Set(L.R, f, ind.org);
			len := Files.Pos(R) - pos
		ELSE
			ind.org := 0; ind.size := 0; ind.index := NIL;
			L.f := NIL; Files.Set(L.R, NIL, 0);
			OldLoadLibrary(L, f, pos, len)
		END
	END LoadLibrary;

(** Store a standard object library at position pos in file f. *)
	PROCEDURE StoreLibrary*(L: Library; f: Files.File; pos: LONGINT; VAR len: LONGINT);
		VAR obj: Object; ind: ArrayIndex; i, olen, org, indorg, n, N: LONGINT; m: INTEGER; entry: Entry;
				ch: CHAR; GName: ARRAY MaxNews OF GenName; R, indR: Files.Rider; M: FileMsg; A: AttrMsg;
	BEGIN
		ind := L.ind(ArrayIndex);
		Files.Set(R, f, pos);
		Files.Write(R, LibBlockId);
		Files.WriteLInt(R, Version);
		Files.WriteLInt(R, -1);	(* place holder genTable pos *)
		Files.WriteLInt(R, -1);	(* place holder dict pos *)
		Files.WriteInt(R, L.maxref);
		indorg := Files.Pos(R); Files.Set(indR, f, indorg);
		IF L.maxref > 0 THEN Files.WriteBytes(R, ind.index^, L.maxref*4) END;

		(* store obj data *)
		A.id := get; A.name := "Gen";
		N := 0;
		M.id := store; Stamp(M);
		FOR i := 0 TO L.maxref-1 DO
			obj := ind.index[i];
			IF obj = NIL THEN	(* object is not load yet *)
				Files.Set(L.R, L.f, ind.org + 4*i);
				Files.ReadLInt(L.R, org);
				IF org >= 0 THEN	(* there is an object in the file *)
					Files.Set(L.R, L.f, org);
					Files.ReadInt(L.R, m); Files.ReadLInt(L.R, olen);
					COPY(L.GName[m], GName[N]);
					n := 0;
					WHILE GName[n] # GName[N] DO INC(n) END;
					IF n = N THEN INC(N) END;

					Files.WriteLInt(indR, Files.Pos(R));	(* write index *)
					Files.WriteInt(R, SHORT(n));
					Files.WriteLInt(R, olen);
					WHILE olen > 0 DO Files.Read(L.R, ch); Files.Write(R, ch); DEC(olen) END
				ELSE	(* there was never an object with this ref *)
					Files.WriteLInt(indR, -1)
				END
			ELSIF obj # NoObj THEN	(* there is an object to store *)
				A.res := -1; obj.handle(obj, A); COPY(A.s, GName[N]);
				n := 0;
				WHILE GName[n] # GName[N] DO INC(n) END;
				IF n = N THEN INC(N) END;

				Files.WriteLInt(indR, Files.Pos(R));	(* write index *)
				Files.WriteInt(R, SHORT(n));
				Files.Set(M.R, f, Files.Pos(R));
				Files.WriteLInt(M.R, 0); obj.handle(obj, M);
				olen := Files.Pos(M.R) - Files.Pos(R) - 4;
				Files.WriteLInt(R, olen);
				Files.Set(R, f, Files.Pos(M.R))
			ELSE	(* no object *)
				Files.WriteLInt(indR, -1)
			END
		END;

		(* write generator table *)
		i := Files.Pos(R);
		Files.Set(R, f, pos + 5); Files.WriteLInt(R, i); Files.Set(R, f, i);
		Files.WriteInt(R, SHORT(N));
		IF N > 0 THEN
			NEW(L.GName, N);
			FOR n := 0 TO N-1 DO
				Files.WriteString(R, GName[n]);
				COPY(GName[n], L.GName[n])
			END
		END;

		(* store dict *)
		i := Files.Pos(R);
		Files.Set(R, f, pos + 9); Files.WriteLInt(R, i); Files.Set(R, f, i);
		entry := L.dict(ListDict).first;
		WHILE entry # NIL DO
			Files.WriteInt(R, entry.key); i := 0;
			Files.WriteString(R, entry.name);
			entry := entry.next
		END;
		Files.WriteInt(R, MIN(INTEGER));
		len := Files.Pos(R) - pos;
		L.f := f; ind.org := indorg;
		Files.Set(L.R, L.f, ind.org)
	END StoreLibrary;

	PROCEDURE *LoadFileLib(L: Library);
		VAR f: Files.File; R: Files.Rider; len: LONGINT; id: CHAR;
	BEGIN
		f := Files.Old(L.name);
		IF f # NIL THEN
			Files.Set(R, f, 0); Files.Read(R, id);
			IF id = LibBlockId THEN LoadLibrary(L, f, 1, len)
			ELSE L.f := NIL; L.ind(ArrayIndex).size := 0; L.ind(ArrayIndex).index := NIL
			END
		END
	END LoadFileLib;

	PROCEDURE *StoreFileLib(L: Library);
		VAR f: Files.File; len: LONGINT;
	BEGIN
		f := Files.New(L.name);
		IF f # NIL THEN StoreLibrary(L, f, 0, len); Files.Register(f) END
	END StoreFileLib;

(** Initialize a standard object library. *)
	PROCEDURE OpenLibrary*(L: Library);
		VAR ind: ArrayIndex; dict: ListDict;
	BEGIN
		L.Load := LoadFileLib; L.Store := StoreFileLib;
		L.GenRef:= GenRef; L.GetObj := GetObj;
		L.PutObj := PutObj; L.FreeObj := FreeObj;
		NEW(ind); ind.org:= 0; ind.size := 0; ind.index := NIL; L.ind := ind;
		NEW(dict); dict.first := NIL; dict.key := 0; L.dict := dict;
		L.maxref := 0
	END OpenLibrary;

	PROCEDURE *NewLibrary(): Library;
		VAR L: Library;
	BEGIN NEW(L); OpenLibrary(L); RETURN L
	END NewLibrary;

(** Given an object name, return the object reference number from the dictionary. *)
	PROCEDURE GetRef*(VAR D: Dictionary; name: ARRAY OF CHAR; VAR ref: INTEGER);
		VAR cur: Entry;
	BEGIN
		IF D IS ListDict THEN
			cur := D(ListDict).first;
			WHILE (cur # NIL) & ((cur.key < 0) OR (cur.name # name)) DO cur := cur.next END;
			IF cur = NIL THEN ref := MIN(INTEGER) ELSE ref := cur.key END
		ELSE ref := MIN(INTEGER)
		END
	END GetRef;

(** Allocate a key (any integer < 0) to a name. *)
	PROCEDURE GetKey*(VAR D: Dictionary; name: ARRAY OF CHAR; VAR key: INTEGER);
		VAR cur: Entry;
	BEGIN
		IF D IS ListDict THEN
			WITH D: ListDict DO
				cur := D.first;
				WHILE (cur # NIL) & ((cur.key >= 0) OR (cur.name # name)) DO cur := cur.next END;
				IF cur = NIL THEN DEC(D.key);
					NEW(cur); cur.key := D.key; COPY(name, cur.name); cur.next := D.first; D.first := cur
				END;
				key := cur.key
			END
		ELSE key := MIN(INTEGER)
		END
	END GetKey;

(** Get name associated with a key/reference number. *)
	PROCEDURE GetName*(VAR D: Dictionary; key: INTEGER; VAR name: ARRAY OF CHAR);
		VAR cur: Entry;
	BEGIN
		IF D IS ListDict THEN
			cur := D(ListDict).first;
			WHILE (cur # NIL) & (cur.key # key) DO cur := cur.next END;
			IF cur = NIL THEN name[0] := 0X ELSE COPY(cur.name, name) END
		ELSE name[0] := 0X
		END
	END GetName;

(** Associate a name with a reference number. *)
	PROCEDURE PutName*(VAR D: Dictionary; key: INTEGER; name: ARRAY OF CHAR);
	(* Note: D could be value parameter *)
		VAR cur: Entry;
	BEGIN
		IF D IS ListDict THEN
			IF key >= 0 THEN
				WITH D: ListDict DO
					cur := D.first;
					WHILE (cur # NIL) & (cur.key # key) DO cur := cur.next END;
					IF cur = NIL THEN
					NEW(cur); cur.key := key; cur.next := D.first; D.first := cur
					END;
					COPY(name, cur.name)
				END
			END
		END
	END PutName;

BEGIN LibBlockId := 0DBX;
	NEW(FirstLib); FirstLib.next := NIL;
	NEW(FirstAlias); FirstAlias.next := NIL;
	stamp := MIN(LONGINT);
	NEW(NoObj);
	nofreg := 0;
	Register("Lib", NewLibrary)
END Objects.