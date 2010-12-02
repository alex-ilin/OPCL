(* 
    Command line wrapper for ETH Oberon PELinker (Windows).
    This version of 'PELinker' module was reduced to console i/o.
    Eugene Shcherbatyuk (ugns@mail.ru)
    Dec 2002
 *)

(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE O2ETHCLL; (** non-portable / source: Win32.PELinker.Mod *)	(* ejz *)
	IMPORT SYSTEM, Kernel32, FileDir, Files, Modules,
	                            Exceptions, Strings, Dates, Texts, BootLink,
	                            Console, CmdLine;

	CONST
		ImageDosSignature = 05A4DH; (* MZ *)
		ImageNtSignature = 000004550H; (* PE00 *)
		ImageFileRelocsStripped = 00001H; (* Relocation info stripped from file. *)
		ImageFileExecutableImage = 00002H; (* File is executable (i.e. no unresolved external references). *)
		ImageFileLineNumsStripped = 00004H; (* Line nunbers stripped from file. *)
		ImageFileLocalSymsStripped = 00008H; (* Local symbols stripped from file. *)

		ImageFile32BitMachine = 00100H; (* 32 bit word machine. *)

		ImageFileDll = 02000H; (* File is a DLL. *)

		ImageFileMachineI386 = 014CH; (* Intel 386. *)
		ImageNumberofDirectoryEntries = 16;
		ImageOptionalMagic = 010BH;
		ImageSubsystemNative = 1; (* Image doesn't require a subsystem. *)
		ImageSubsystemWindowsGui = 2; (* Image runs in the Windows GUI subsystem. *)
		ImageSubsystemWindowsCui = 3; (* Image runs in the Windows character subsystem. *)
		ImageDirectoryEntryExport = 0; (* Export Directory *)
		ImageDirectoryEntryImport = 1; (* Import Directory *)
		ImageDirectoryEntryResource = 2; (* Resource Directory *)

		ImageDirectoryEntryBasereloc = 5; (* Base Relocation Table *)

		ImageDirectoryEntryIat = 12; (* Import Address Table *)
		ImageSizeofShortName = 8; 

		ImageScnCntCode = 000000020H; (* Section contains code. *)
		ImageScnCntInitializedData = 000000040H; (* Section contains initialized data. *)
		ImageScnCntUninitializedData = 000000080H; (* Section contains uninitialized data. *)
		ImageScnMemDiscardable = 02000000H; (* Section can be discarded. *)
		ImageScnNotPaged = 08000000H; (* Section is not paged. *)
		ImageScnMemShared = 010000000H; (* Section is shareable. *)
		ImageScnMemExecute = 020000000H; (* Section is executable. *)
		ImageScnMemRead = 040000000H; (* Section is readable. *)
		ImageScnMemWrite = 080000000H; (* Section is writeable. *)
		ImageRelBasedAbsolute = 0; 
		ImageRelBasedHigh = 1; 
		ImageRelBasedLow = 2; 
		ImageRelBasedHighLow = 3; 
		ImageRelBasedHighAdj = 4; 
		ImageRelBasedMipsJmpAddr = 5; 
		ImageRelBasedSection = 6; 
		ImageRelBasedRel32 = 7;

		RtCursor = 1; RtIcon = 3;
		RtGroupCursor = RtCursor+11; RtGroupIcon = RtIcon+11;
		RtVersion = 16;

		DefaultLanguage = 0400H;
		VsFfiSignature = 0FEEF04BDH;
		VsFfiStrucVersion = 000010000H;
		VsFfiFileFlagsMask = 00000003FH; 
		VosNtWindows32 = 000040004H; 
		VftApp = 000000001H; 
		VftDll = 000000002H; 
		Vft2Unknown = 000000000H; 

		MajorLinkerVersion = CHR(0); MinorLinkerVersion = CHR(90);
		PageSize = 01000H; SectorSize = 0200H;
		DefaultFileAlign = SectorSize; DefaultSectionAlign = PageSize;
		BaseRVA = DefaultSectionAlign;
		DefaultHeapSize = 64*1024; DefaultStackSize = 1024*1024;
		DefaultImageSubsystem = ImageSubsystemWindowsGui;
		DefaultEXEImageBase = 0400000H; DefaultDLLImageBase = 010000000H;
		DefaultStub = "stub.exe";

		MaxRelocs = 16*1024;

	TYPE
		ImageDosHeader = RECORD(* DOS .EXE header *)
			emagic: INTEGER; (* Magic number *)
			ecblp: INTEGER; (* Bytes on last page of file *)
			ecp: INTEGER; (* Pages in file *)
			ecrlc: INTEGER; (* Relocations *)
			ecparhdr: INTEGER; (* Size of header in paragraphs *)
			eminalloc: INTEGER; (* Minimum extra paragraphs needed *)
			emaxalloc: INTEGER; (* Maximum extra paragraphs needed *)
			ess: INTEGER; (* Initial (relative) SS value *)
			esp: INTEGER; (* Initial SP value *)
			ecsum: INTEGER; (* Checksum *)
			eip: INTEGER; (* Initial IP value *)
			ecs: INTEGER; (* Initial (relative) CS value *)
			elfarlc: INTEGER; (* File address of relocation table *)
			eovno: INTEGER; (* Overlay number *)
			eres: ARRAY 4 OF INTEGER; (* Reserved words *)
			eoemid: INTEGER; (* OEM identifier (for e_oeminfo) *)
			eoeminfo: INTEGER; (* OEM information; e_oemid specific *)
			eres2: ARRAY 10 OF INTEGER; (* Reserved words *)
			elfanew: LONGINT (* File address of new exe header *)
		END;

		ImageFileHeader = RECORD
			Machine: INTEGER;
			NumberOfSections: INTEGER;
			TimeDateStamp: LONGINT;
			PointerToSymbolTable: LONGINT;
			NumberOfSymbols: LONGINT;
			SizeOfOptionalHeader: INTEGER;
			Characteristics: INTEGER
		END;

		ImageDataDirectory = RECORD
			VirtualAddress: LONGINT;
			Size: LONGINT
		END;

		ImageOptionalHeader = RECORD
			(* Standard fields. *)
			Magic: INTEGER;
			MajorLinkerVersion: CHAR;
			MinorLinkerVersion: CHAR;
			SizeOfCode: LONGINT;
			SizeOfInitializedData: LONGINT;
			SizeOfUninitializedData: LONGINT;
			AddressOfEntryPoint: LONGINT;
			BaseOfCode: LONGINT;
			BaseOfData: LONGINT;
			(* NT additional fields. *)
			ImageBase: LONGINT;
			SectionAlignment: LONGINT;
			FileAlignment: LONGINT;
			MajorOperatingSystemVersion: INTEGER;
			MinorOperatingSystemVersion: INTEGER;
			MajorImageVersion: INTEGER;
			MinorImageVersion: INTEGER;
			MajorSubsystemVersion: INTEGER;
			MinorSubsystemVersion: INTEGER;
			Win32VersionValue: LONGINT;
			SizeOfImage: LONGINT;
			SizeOfHeaders: LONGINT;
			CheckSum: LONGINT;
			Subsystem: INTEGER;
			DllCharacteristics: INTEGER;
			SizeOfStackReserve: LONGINT;
			SizeOfStackCommit: LONGINT;
			SizeOfHeapReserve: LONGINT;
			SizeOfHeapCommit: LONGINT;
			LoaderFlags: LONGINT;
			NumberOfRvaAndSizes: LONGINT;
			DataDirectory: ARRAY ImageNumberofDirectoryEntries OF ImageDataDirectory
		END;

		ImageSectionHeader = RECORD
			Name: ARRAY ImageSizeofShortName OF CHAR; 
			VirtualSize: LONGINT; 
			VirtualAddress: LONGINT; 
			SizeOfRawData: LONGINT; 
			PointerToRawData: LONGINT; 
			PointerToRelocations: LONGINT; 
			PointerToLinenumbers: LONGINT; 
			NumberOfRelocations: INTEGER; 
			NumberOfLinenumbers: INTEGER; 
			Characteristics: LONGINT;
		END;

		ImageImportDescriptor = RECORD
			Characteristics: LONGINT; (* 0 for terminating null import descriptor *)
				(* RVA to original unbound IAT *)
			TimeDateStamp: LONGINT; (* 0 if not bound, *)
				(* -1 if bound, and real date\time stamp *)
				(* in IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT (new BIND) *)
				(* O.W. date/time stamp of DLL bound to (Old BIND) *)
			ForwarderChain: LONGINT; (* -1 if no forwarders *)
			Name: LONGINT; 
			FirstThunk: LONGINT (* RVA to IAT (if bound this IAT has actual addresses) *)
		END;

		ImageExportDirectory = RECORD
			Characteristics: LONGINT; 
			TimeDateStamp: LONGINT; 
			MajorVersion: INTEGER; 
			MinorVersion: INTEGER; 
			Name: LONGINT; 
			Base: LONGINT; 
			NumberOfFunctions: LONGINT; 
			NumberOfNames: LONGINT; 
			AddressOfFunctions: LONGINT; 
			AddressOfNames: LONGINT; 
			AddressOfNameOrdinals: LONGINT
		END;

		ImageBaseRelocation = RECORD
			VirtualAddress: LONGINT; 
			SizeOfBlock: LONGINT
		END;

		ImageResourceDirectory = RECORD
			Characteristics: LONGINT; 
			TimeDateStamp: LONGINT; 
			MajorVersion: INTEGER; 
			MinorVersion: INTEGER; 
			NumberOfNamedEntries: INTEGER; 
			NumberOfIdEntries: INTEGER
			(* ImageResourceDirectoryEntry DirectoryEntries[]; *)
		END;

		ImageResourceDirectoryEntry = RECORD
			Name: LONGINT;
			OffsetToData: LONGINT
		END;

		ImageResourceDataEntry = RECORD
			OffsetToData: LONGINT;
			Size: LONGINT;
			CodePage: LONGINT;
			Reserved: LONGINT
		END;

		ResourceHeader = RECORD
			reserved, type, count: INTEGER
		END;

		Bitmapinfoheader = RECORD
			biSize: LONGINT;
			biWidth: LONGINT;
			biHeight: LONGINT;
			biPlanes: INTEGER;
			biBitCount: INTEGER;
			biCompression: LONGINT;
			biSizeImage: LONGINT;
			biXpelsPerMeter: LONGINT;
			biYpelsPerMeter: LONGINT;
			biClrUsed: LONGINT;
			biClrImportant: LONGINT
		END;

		IconDirEntry = RECORD
			width, height, colorCount, res: CHAR;
			planes, bitCount: INTEGER;
			bytes: LONGINT;
			name: INTEGER
		END;

		CursorDirEntry = RECORD
			width, height, planes, bitCount: INTEGER;
			bytes: LONGINT;
			name: INTEGER
		END;

		VsFixedFileInfo = RECORD
			dwSignature: LONGINT; (* e.g. 0xfeef04bd *)
			dwStrucVersion: LONGINT; (* e.g. 0x00000042 = "0.42" *)
			dwFileVersionMs: LONGINT; (* e.g. 0x00030075 = "3.75" *)
			dwFileVersionLs: LONGINT; (* e.g. 0x00000031 = "0.31" *)
			dwProductVersionMs: LONGINT; (* e.g. 0x00030010 = "3.10" *)
			dwProductVersionLs: LONGINT; (* e.g. 0x00000031 = "0.31" *)
			dwFileFlagsMask: LONGINT; (* = 0x3F for version "0.42" *)
			dwFileFlags: LONGINT; (* e.g. VFF_DEBUG | VFF_PRERELEASE *)
			dwFileOs: LONGINT; (* e.g. VOS_DOS_WINDOWS16 *)
			dwFileType: LONGINT; (* e.g. VFT_DRIVER *)
			dwFileSubtype: LONGINT; (* e.g. VFT2_DRV_KEYBOARD *)
			dwFileDateMs: LONGINT; (* e.g. 0 *)
			dwFileDateLs: LONGINT (* e.g. 0 *)
		END;

		NameList = POINTER TO RECORD
			name: FileDir.FileName;
			next: NameList
		END;

		ValueList = POINTER TO RECORD (NameList)
			value: FileDir.FileName
		END;

		EntryList = POINTER TO RECORD (ValueList)
			entry, fixup: LONGINT
		END;

		ImportList = POINTER TO RECORD (NameList)
			impDesc: ImageImportDescriptor;
			entries: EntryList
		END;

		ExportEntryList = POINTER TO RECORD (EntryList)
			nextOrd: ExportEntryList
		END;

		ResList = POINTER TO RECORD (EntryList)
			adr: LONGINT;
			head: ResourceHeader
		END;

		IconList = POINTER TO RECORD (ResList)
			dentry: IconDirEntry
		END;

		CursorList = POINTER TO RECORD (ResList)
			dentry: CursorDirEntry
		END;

		ScanProc = PROCEDURE (T: Texts.Text; VAR S: Texts.Scanner);

		ErrorException = RECORD (Exceptions.UserException)
			msg: ARRAY 128 OF CHAR
		END;

	VAR
		W: Texts.Writer;
		error: ErrorException;
		image, stub: FileDir.FileName;
		isEXE: BOOLEAN;
		imgHead: ImageOptionalHeader;
		text, idata, edata, reloc, rsrc: ImageSectionHeader;
		version: ValueList;
		imports: ImportList;
		exports, exportOrds: ExportEntryList;
		modules: NameList;
		icons: IconList;
		cursors: CursorList;
		relocs: ARRAY MaxRelocs OF LONGINT; nRelocs: LONGINT;

	PROCEDURE Error(str1, str2: ARRAY OF CHAR);
	BEGIN
	    Console.WriteString(str1);
	    Console.WriteString(str2);
		COPY(str1, error.msg); Strings.Append(error.msg, str2);
		Exceptions.Raise(error);
		Texts.Append(Texts.Log, W.buf)
	END Error;
	
	PROCEDURE Assert(cond: BOOLEAN; str1, str2: ARRAY OF CHAR);
	BEGIN
		IF ~cond THEN Error(str1, str2) END
	END Assert;

	PROCEDURE LongOr(a, b: LONGINT): LONGINT;
	BEGIN
		RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, a) + SYSTEM.VAL(SET, b))
	END LongOr;

	PROCEDURE SetHighBit(VAR i: LONGINT);
	BEGIN
		INCL(SYSTEM.VAL(SET, i), 31)
	END SetHighBit;

	PROCEDURE Align(value, align: LONGINT): LONGINT;
	BEGIN
		RETURN value + ((align-(value MOD align)) MOD align)
	END Align;

	PROCEDURE FileAlign(VAR R: Files.Rider; align: LONGINT; pad: CHAR);
		VAR n: LONGINT;
	BEGIN
		n := Files.Pos(R);
		n := Align(n, align)-n;
		WHILE n > 0 DO
			Files.Write(R, pad); DEC(n)
		END
	END FileAlign;

	PROCEDURE InitImageOptionalHeader(VAR head: ImageOptionalHeader);
		VAR i: LONGINT;
	BEGIN
		head.Magic := ImageOptionalMagic;
		head.MajorLinkerVersion := MajorLinkerVersion;
		head.MinorLinkerVersion := MinorLinkerVersion;
		head.SizeOfCode := 0;
		head.SizeOfInitializedData := 0;
		head.SizeOfUninitializedData := 0;
		head.AddressOfEntryPoint := 0;
		head.BaseOfCode := 0;
		head.BaseOfData := 0;
		head.ImageBase := 0;
		head.SectionAlignment := DefaultSectionAlign;
		head.FileAlignment := DefaultFileAlign;
		head.MajorOperatingSystemVersion := 4;
		head.MinorOperatingSystemVersion := 0;
		head.MajorImageVersion := 0;
		head.MinorImageVersion := 0;
		head.MajorSubsystemVersion := 4;
		head.MinorSubsystemVersion := 0;
		head.Win32VersionValue := 0;
		head.SizeOfImage := 0;
		head.SizeOfHeaders := DefaultFileAlign;
		head.CheckSum := 0;
		head.Subsystem := DefaultImageSubsystem;
		head.DllCharacteristics := 0;
		head.SizeOfStackReserve := DefaultStackSize;
		head.SizeOfStackCommit := PageSize;
		head.SizeOfHeapReserve := DefaultHeapSize;
		head.SizeOfHeapCommit := PageSize;
		head.LoaderFlags := 0;
		head.NumberOfRvaAndSizes := ImageNumberofDirectoryEntries;
		FOR i := 0 TO ImageNumberofDirectoryEntries-1 DO
			head.DataDirectory[i].VirtualAddress := 0;
			head.DataDirectory[i].Size := 0
		END
	END InitImageOptionalHeader;

	PROCEDURE InitSectionHeader(VAR head: ImageSectionHeader; name: ARRAY OF CHAR; scnCnt, scnMem: LONGINT);
		VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO ImageSizeofShortName-1 DO
			head.Name[i] := 0X
		END;
		COPY(name, head.Name);
		head.VirtualSize := 0;
		head.VirtualAddress := 0;
		head.SizeOfRawData := 0;
		head.PointerToRawData := 0;
		head.PointerToRelocations := 0;
		head.PointerToLinenumbers := 0;
		head.NumberOfRelocations := 0;
		head.NumberOfLinenumbers := 0;
		head.Characteristics := LongOr(scnCnt, scnMem)
	END InitSectionHeader;

	PROCEDURE InitImageImportDescriptor(VAR impDesc: ImageImportDescriptor);
	BEGIN
		impDesc.Characteristics := 0;
		impDesc.TimeDateStamp := 0;
		impDesc.ForwarderChain := 0;
		impDesc.Name := 0;
		impDesc.FirstThunk := 0
	END InitImageImportDescriptor;

	PROCEDURE TimeDateStamp(): LONGINT;
		VAR st: Kernel32.SystemTime; days, secs: LONGINT;
	BEGIN
		Kernel32.GetSystemTime(st);
		days := Dates.NumberOfDays(Dates.ToDate(st.wYear, st.wMonth, st.wDay));
		days := days-Dates.NumberOfDays(Dates.ToDate(1970, 1, 1));
		secs := st.wSecond+60*(st.wMinute+60*(st.wHour+24*days));
		RETURN secs
	END TimeDateStamp;

	PROCEDURE WriteImageHeader(VAR R: Files.Rider; sections: INTEGER);
		VAR
			F: Files.File; sR: Files.Rider;
			dosHead: ImageDosHeader;
			imgHead: ImageFileHeader;
			char: LONGINT; ch: CHAR;
	BEGIN
		F := Files.Old(stub); 
		Files.Set(sR, F, 0);
		IF F=NIL THEN
		   Console.WriteString(stub); Console.WriteString(" not found."); Console.WriteLn();
		   HALT(100);
		END;
		(*Assert(F # NIL, stub, " Files.Old failed");*)
		Files.ReadBytes(sR, dosHead, SIZE(ImageDosHeader));
		IF dosHead.emagic # ImageDosSignature THEN
		   Console.WriteString(stub); Console.WriteString(" not a valid stub file."); Console.WriteLn();
		   HALT(100);
		END;
		(*Assert(dosHead.emagic = ImageDosSignature, stub, " not a valid stub file");*)
		dosHead.elfanew := Align(Files.Length(F), 16);
		Files.WriteBytes(R, dosHead, SIZE(ImageDosHeader));
		Files.Read(sR, ch);
		WHILE ~sR.eof DO
			Files.Write(R, ch); Files.Read(sR, ch)
		END;
		FileAlign(R, 16, 0X);
		imgHead.Machine := ImageFileMachineI386;
		imgHead.NumberOfSections := sections;
		imgHead.TimeDateStamp := TimeDateStamp();
		imgHead.PointerToSymbolTable := 0;
		imgHead.NumberOfSymbols := 0;
		imgHead.SizeOfOptionalHeader := SIZE(ImageOptionalHeader);
		char := LongOr(ImageFileExecutableImage, ImageFile32BitMachine);
		IF isEXE THEN
			char := LongOr(char, ImageFileRelocsStripped)
		ELSE
			char := LongOr(char, ImageFileDll)
		END;
		char := LongOr(char, ImageFileLineNumsStripped);
		char := LongOr(char, ImageFileLocalSymsStripped);
		imgHead.Characteristics := SHORT(char);
		Files.WriteLInt(R, ImageNtSignature);
		Files.WriteBytes(R, imgHead, SIZE(ImageFileHeader));
	END WriteImageHeader;

	PROCEDURE ScanName(VAR S: Texts.Scanner; VAR name: ARRAY OF CHAR);
	BEGIN
		IF S.class = Texts.Name THEN
			COPY(S.s, name); Texts.Scan(S)
		ELSE
			Error("name expected", "")
		END
	END ScanName;

	PROCEDURE ScanString(VAR S: Texts.Scanner; VAR str: ARRAY OF CHAR);
	BEGIN
		IF S.class IN {Texts.Name, Texts.String} THEN
			COPY(S.s, str); Texts.Scan(S)
		ELSE
			Error("name or string expected", "")
		END
	END ScanString;

	PROCEDURE ScanInt(VAR S: Texts.Scanner; VAR i: LONGINT);
	BEGIN
		IF S.class = Texts.Int THEN
			i := S.i; Texts.Scan(S)
		ELSE
			Error("integer expected", "")
		END
	END ScanInt;

	PROCEDURE CheckCh(VAR S: Texts.Scanner; ch: CHAR);
	BEGIN
		IF (S.class = Texts.Char) & (S.c = ch) THEN
			Texts.Scan(S)
		ELSE
			S.s[0] := ch; S.s[1] := 0X;
			Error(S.s, " expected")
		END
	END CheckCh;

	PROCEDURE Clean();
	BEGIN
		version := NIL; imports := NIL; exports := NIL; exportOrds :=  NIL; modules := NIL;
		icons := NIL; cursors := NIL;

	END Clean;

	PROCEDURE Init();
		VAR readWrite, readWriteExec, readDisc: LONGINT;
	BEGIN
		Clean(); image := ""; COPY(DefaultStub, stub); isEXE := TRUE;
		readWrite := LongOr(ImageScnMemRead, ImageScnMemWrite);
		readWriteExec := LongOr(readWrite, ImageScnMemExecute);
		readDisc := LongOr(ImageScnMemRead, ImageScnMemDiscardable);
		InitImageOptionalHeader(imgHead); nRelocs := 0;
		InitSectionHeader(text, ".text", ImageScnCntCode, readWriteExec);
		InitSectionHeader(reloc, ".reloc", ImageScnCntInitializedData, readDisc);
		InitSectionHeader(idata, ".idata", ImageScnCntInitializedData, readWrite);
		InitSectionHeader(edata, ".edata", ImageScnCntInitializedData, ImageScnMemRead);
		InitSectionHeader(rsrc, ".rsrc", ImageScnCntInitializedData, ImageScnMemRead);
		NEW(imports); imports.next := NIL; imports.name := ""; imports.entries := NIL;

	END Init;

	PROCEDURE *ScanVersion(T: Texts.Text; VAR S: Texts.Scanner);
		VAR
			val: ValueList;
			R: Texts.Reader; pos, i: LONGINT; ch, end: CHAR;
	BEGIN
		NEW(val); val.next := version; version := val;
		pos := Texts.Pos(S); ScanName(S, val.name);
		Texts.OpenReader(R, T, pos); Texts.Read(R, ch);
		WHILE ~R.eot & (ch <= " ") DO
			Texts.Read(R, ch)
		END;
		IF ch # "=" THEN Error("=", " expected") END;
		Texts.Read(R, ch);
		WHILE ~R.eot & (ch <= " ") DO Texts.Read(R, ch) END;
		IF (ch = '"') OR (ch = "'") THEN
			end := ch; i := 0;
			Texts.Read(R, ch);
			WHILE ~R.eot & (ch # end) DO
				val.value[i] := ch; INC(i);
				Texts.Read(R, ch)
			END;
			val.value[i] := 0X;
			Texts.OpenScanner(S, T, Texts.Pos(R)); Texts.Scan(S)
		ELSE
			Texts.OpenScanner(S, T, Texts.Pos(R)-1); Texts.Scan(S);
			ScanString(S, val.value)
		END
	END ScanVersion;

	PROCEDURE *ScanImport(T: Texts.Text; VAR S: Texts.Scanner);
		VAR p, q: NameList; imp: EntryList; lib: ImportList; libname: FileDir.FileName; i, j: LONGINT;
	BEGIN
		NEW(imp); imp.next := NIL;
		ScanName(S, imp.name);
		CheckCh(S, "=");
		ScanName(S, imp.value);
		IF S.class = Texts.Int THEN
			ScanInt(S, imp.entry)
		ELSE
			imp.entry := 0
		END;
		i := 0;
		WHILE (imp.value[i] # 0X) & (imp.value[i] # ".") DO
			libname[i] := imp.value[i]; INC(i)
		END;
		IF imp.value[i] # "." THEN
			libname := ""; (* pseudo lib *)
			Strings.Upper(imp.value, imp.value)
		ELSE
			libname[i] := 0X; Strings.Append(libname, ".DLL");
			INC(i); j := 0;
			WHILE imp.value[i] # 0X DO
				imp.value[j] := imp.value[i]; INC(i); INC(j)
			END;
			imp.value[j] := 0X
		END;
		p := imports;
		WHILE (p # NIL) & (p.name # libname) DO
			p := p.next
		END;
		IF p = NIL THEN
			NEW(lib); COPY(libname, lib.name); lib.entries := NIL;
			InitImageImportDescriptor(lib.impDesc);
			q := imports; p := imports.next;
			WHILE (p # NIL) & (p.name < lib.name) DO
				q := p; p := p.next
			END;
			lib.next := p; q.next := lib
		ELSE
			lib := p(ImportList)
		END;
		q := NIL; p := lib.entries;
		WHILE (p # NIL) & (p(EntryList).value < imp.value) DO
			q := p; p := p.next
		END;
		imp.next := p;
		IF q # NIL THEN
			q.next := imp
		ELSE
			lib.entries := imp
		END
	END ScanImport;

	PROCEDURE *ScanExport(T: Texts.Text; VAR S: Texts.Scanner);
		VAR exp, e: ExportEntryList; p, q: NameList;
	BEGIN
		NEW(exp); exp.next := NIL; exp.nextOrd := NIL;
		ScanName(S, exp.name);
		IF S.class = Texts.Int THEN
			ScanInt(S, exp.entry)
		ELSE
			exp.entry := 0
		END;
		CheckCh(S, "=");
		ScanName(S, exp.value);
		q := NIL; p := exports;
		WHILE (p # NIL) & (p(NameList).name < exp.name) DO
			q := p; p := p.next
		END;
		Assert((p = NIL) OR (p(NameList).name > exp.name), exp.name, " exported names must be unique");
		exp.next := p;
		IF q # NIL THEN
			q.next := exp
		ELSE
			exports := exp
		END;
		IF exp.entry > 0 THEN
			q := NIL; e := exportOrds;
			WHILE (e # NIL) & (e.entry < exp.entry) DO
				q := e; e := e.nextOrd
			END;
			Assert((e = NIL) OR (e.entry > exp.entry), exp.name, " exported ordinals must be unique");
			exp.nextOrd := e;
			IF q # NIL THEN
				q(ExportEntryList).nextOrd := exp
			ELSE
				exportOrds := exp
			END
		ELSE
			exp.nextOrd := exportOrds; exportOrds := exp
		END
	END ScanExport;

	PROCEDURE *ScanModule(T: Texts.Text; VAR S: Texts.Scanner);
		VAR mod, m: NameList;
	BEGIN
		NEW(mod); ScanName(S, mod.name); mod.next := NIL;
		IF modules # NIL THEN
			m := modules; WHILE m.next # NIL DO m := m.next END;
			m.next := mod
		ELSE
			modules := mod
		END
	END ScanModule;

	PROCEDURE *ScanIcon(T: Texts.Text; VAR S: Texts.Scanner);
		VAR ico: IconList; p, q: NameList;
	BEGIN
		NEW(ico); ico.next := NIL;
		ScanName(S, ico.name); Strings.Upper(ico.name, ico.name);
		CheckCh(S, "="); ScanString(S, ico.value);
		q := NIL; p := icons;
		WHILE (p # NIL) & (p.name < ico.name) DO
			q := p; p := p.next
		END;
		ico.next := p;
		IF q # NIL THEN
			q.next := ico
		ELSE
			icons := ico
		END
	END ScanIcon;

	PROCEDURE *ScanCursor(T: Texts.Text; VAR S: Texts.Scanner);
		VAR cur: CursorList; p, q: NameList;
	BEGIN
		NEW(cur); cur.next := NIL;
		ScanName(S, cur.name); Strings.Upper(cur.name, cur.name);
		CheckCh(S, "="); ScanString(S, cur.value);
		q := NIL; p := cursors;
		WHILE (p # NIL) & (p.name < cur.name) DO
			q := p; p := p.next
		END;
		cur.next := p;
		IF q # NIL THEN
			q.next := cur
		ELSE
			cursors := cur
		END
	END ScanCursor;

	PROCEDURE ScanList(T: Texts.Text; VAR S: Texts.Scanner; entry: ScanProc);
	BEGIN
		entry(T, S);
		WHILE (S.class = Texts.Char) & (S.c = ",") DO
			Texts.Scan(S); entry(T, S)
		END
	END ScanList;

	PROCEDURE ScanLinkText(T: Texts.Text);
		VAR
			S: Texts.Scanner; R: Texts.Reader;
			keyword: ARRAY 32 OF CHAR;
			pos, i, j: LONGINT; k: INTEGER;
			ch: CHAR;
	BEGIN
		
		Texts.OpenScanner(S, T, 0); Texts.Scan(S);
		WHILE S.class = Texts.Name DO
			Strings.Upper(S.s, keyword);
			pos := Texts.Pos(S); Texts.Scan(S);
			IF keyword = "PROGRAM" THEN
				ScanName(S, image); Strings.Append(image, ".EXE");
				isEXE := TRUE;
				IF imgHead.ImageBase = 0 THEN
					imgHead.ImageBase := DefaultEXEImageBase
				END
			ELSIF keyword = "LIBRARY" THEN
				ScanName(S, image); Strings.Append(image, ".DLL");
				isEXE := FALSE;
				IF imgHead.ImageBase = 0 THEN
					imgHead.ImageBase := DefaultDLLImageBase
				END
			ELSIF keyword = "STUB" THEN
				ScanString(S, stub)
			ELSIF keyword = "HEAPSIZE" THEN
				ScanInt(S, imgHead.SizeOfHeapReserve);
				imgHead.SizeOfHeapReserve := Align(imgHead.SizeOfHeapReserve, PageSize);
				IF imgHead.SizeOfHeapReserve > 0 THEN
					imgHead.SizeOfHeapCommit := PageSize
				ELSE
					imgHead.SizeOfHeapCommit := 0
				END
			ELSIF keyword = "STACKSIZE" THEN
				ScanInt(S, imgHead.SizeOfStackReserve);
				imgHead.SizeOfStackReserve := Align(imgHead.SizeOfStackReserve, PageSize);
				IF imgHead.SizeOfStackReserve > 0 THEN
					imgHead.SizeOfStackCommit := PageSize
				ELSE
					imgHead.SizeOfStackCommit := 0
				END
			ELSIF keyword = "BASE" THEN
				ScanInt(S, imgHead.ImageBase)
			ELSIF keyword = "IMGVERSION" THEN
				i := 0; Texts.OpenReader(R, T, pos); Texts.Read(R, ch);
				WHILE ~R.eot & (Strings.IsDigit(ch) OR (ch = ".") OR (ch <= " ")) DO
					IF ch > " " THEN keyword[i] := ch; INC(i) END;
					Texts.Read(R, ch)
				END;
				keyword[i] := 0X;
				k := 0; Strings.StrToIntPos(keyword, j, k);
				imgHead.MajorImageVersion := SHORT(j);
				IF keyword[k] = "." THEN
					INC(k); Strings.StrToIntPos(keyword, j, k);
					imgHead.MinorImageVersion := SHORT(j)
				END;
				Texts.OpenScanner(S, T, Texts.Pos(R)-1); Texts.Scan(S)
			ELSIF keyword = "VERSION" THEN
				ScanList(T, S, ScanVersion)
			ELSIF keyword = "SUBSYSTEM" THEN
				ScanName(S, keyword);
				Strings.Upper(keyword, keyword);
				IF keyword = "GUI" THEN
					imgHead.Subsystem := ImageSubsystemWindowsGui
				ELSIF keyword = "CUI" THEN
					imgHead.Subsystem := ImageSubsystemWindowsCui
				ELSIF keyword = "NATIVE" THEN
					imgHead.Subsystem := ImageSubsystemNative
				ELSE
					Error("unknown subsystem ", keyword)
				END
			ELSIF keyword = "IMPORTS" THEN
				ScanList(T, S, ScanImport)
			ELSIF keyword = "EXPORTS" THEN
				ScanList(T, S, ScanExport)
			ELSIF keyword = "MODULES" THEN
				ScanList(T, S, ScanModule)
			ELSIF keyword = "ICONS" THEN
				ScanList(T, S, ScanIcon)
			ELSIF keyword = "CURSORS" THEN
				ScanList(T, S, ScanCursor)
			ELSE
				Error("unknown keyword ", keyword)
			END;
		END;
		
END ScanLinkText;

	PROCEDURE AddReloc(offs, val: LONGINT);
	BEGIN
		IF ~isEXE & (val # 0) THEN
			ASSERT(val >= imgHead.ImageBase);
			IF nRelocs < MaxRelocs THEN
				relocs[nRelocs] := text.VirtualAddress+offs; INC(nRelocs)
			ELSE
				Error("Too many relocations", "")
			END
		END
	END AddReloc;

	PROCEDURE AddFileReloc(VAR R: Files.Rider; val: LONGINT);
		VAR offs: LONGINT;
	BEGIN
		IF ~isEXE & (val # 0) THEN
			offs := Files.Pos(R)-text.PointerToRawData;
			AddReloc(offs, val)
		END
	END AddFileReloc;

	PROCEDURE GetObjAdr(objname: ARRAY OF CHAR; type: LONGINT): LONGINT;
		VAR name: BootLink.Name; mod: BootLink.Module; adr, i, j: LONGINT;
	BEGIN
		i := 0;
		WHILE (objname # 0X) & (objname[i] # ".") DO
			name[i] := objname[i]; INC(i)
		END;
		name[i] := 0X;
		IF objname[i] = "." THEN
			mod := BootLink.FindModule(name);
			Assert(mod # NIL, name, ": module not found");
			INC(i); j := 0;
			WHILE objname[i] # 0X DO
				name[j] := objname[i]; INC(i); INC(j)
			END;
			name[j] := 0X;
			adr := BootLink.FindAdr(mod, name, type);
			Assert(adr # 0, name, ": not found");
			IF type = BootLink.Var THEN
				RETURN mod.sb+adr
			ELSIF type = BootLink.Proc THEN
				RETURN mod.codeBase+adr
			ELSE
				Error("invalid object type", "")
			END
		END;
		Error(objname, ": not a variable");
		RETURN Kernel32.NULL
	END GetObjAdr;

	PROCEDURE WriteText(VAR R: Files.Rider; offs: LONGINT);
		VAR F: Files.File; adr, pos, heapSize, unload, exit: LONGINT; name, obj: NameList;
	BEGIN
		heapSize := Files.Pos(R)-text.PointerToRawData; F := Files.Base(R);
		imgHead.AddressOfEntryPoint := text.VirtualAddress+Files.Pos(R)-text.PointerToRawData;
		Files.Write(R, CHR(053H)); (* PUSH EBX *)
		Files.Write(R, CHR(055H)); (* PUSH EBP *)
		Files.Write(R, CHR(056H)); (* PUSH ESI *)
		Files.Write(R, CHR(057H)); (* PUSH EDI *)
		IF ~isEXE THEN
			Files.Write(R, CHR(08BH)); (* MOV EBX, ReasonForCall *)
			Files.Write(R, CHR(05CH));
			Files.Write(R, CHR(024H));
			Files.Write(R, CHR(018H));
			Files.Write(R, CHR(083H)); (* CMP EBX, 0 *)
			Files.Write(R, CHR(0FBH));
			Files.Write(R, CHR(000H));
			Files.Write(R, CHR(00FH)); (* JNE x *)
			Files.Write(R, CHR(085H));
			Files.WriteLInt(R, 005H);
			Files.Write(R, CHR(0E9H)); (* JMP DLLUnload *)
			unload := Files.Pos(R);
			Files.WriteLInt(R, 0);
(* x: *)
			Files.Write(R, CHR(083H)); (* CMP EBX, 1 *)
			Files.Write(R, CHR(0FBH));
			Files.Write(R, CHR(001H));
			Files.Write(R, CHR(00FH)); (* JNE Exit *)
			Files.Write(R, CHR(085H));
			exit := Files.Pos(R);
			Files.WriteLInt(R, 0);
(* DLLLoad: *)
		END;

		(* fixup dll imports *)
		name := imports.next;
		WHILE name # NIL DO
			obj := name(ImportList).entries;
			WHILE obj # NIL DO
				WITH obj: EntryList DO
					adr := GetObjAdr(obj.name, BootLink.Var);
					Files.Write(R, CHR(08BH)); (* MOX EBX, [imgHead.ImageBase+obj.dllAdr] *)
					Files.Write(R, CHR(01DH));
					obj.fixup := Files.Pos(R);
					AddFileReloc(R, imgHead.ImageBase);
					Files.WriteLInt(R, 0 (*obj.dllAdr*));
					Files.Write(R, CHR(089H)); (* MOX [adr], EBX *)
					Files.Write(R, CHR(01DH));
					AddFileReloc(R, adr);
					Files.WriteLInt(R, adr)
				END;
				obj := obj.next
			END;
			name := name.next
		END;

		(* loader fixups *)
		obj := imports.entries;
		WHILE obj # NIL DO
			WITH obj: EntryList DO
				adr := GetObjAdr(obj.name, BootLink.Var);
				IF obj.value = "HEAPSIZE" THEN
					Files.Write(R, CHR(0BBH)); (* MOX EBX, HeapSize *)
					Files.WriteLInt(R, heapSize)
				ELSIF obj.value = "HEAPADR" THEN
					Files.Write(R, CHR(0BBH)); (* MOX EBX, HeapAdr *)
					AddFileReloc(R, imgHead.ImageBase+text.VirtualAddress);
					Files.WriteLInt(R, imgHead.ImageBase+text.VirtualAddress)
				ELSIF obj.value = "HINSTANCE" THEN
					IF isEXE THEN
						Files.Write(R, CHR(0BBH)); (* MOX EBX, NULL *)
						Files.WriteLInt(R, Kernel32.NULL)
					ELSE
						Files.Write(R, CHR(08BH)); (* MOV EBX, x[ESP] *)
						Files.Write(R, CHR(05CH));
						Files.Write(R, CHR(024H));
						Files.Write(R, CHR(014H)) (* x *)
					END
				ELSE
					Error(obj.value, ": unknown entry")
				END;
				Files.Write(R, CHR(089H)); (* MOX [adr], EBX *)
				Files.Write(R, CHR(01DH));
				AddFileReloc(R, adr);
				Files.WriteLInt(R, adr)
			END;
			obj := obj.next
		END;
		(* init calls *)
		pos := Files.Pos(R);
		Files.Write(R, CHR(0E8H)); (* CALL *);
		Files.WriteLInt(R, text.PointerToRawData+offs-pos-5);
		IF ~isEXE THEN
			Files.Write(R, CHR(0E9H)); (* JMP Exit *)
			Files.WriteLInt(R, 5);
(* DLLUnload: *)
			pos := Files.Pos(R); Files.Set(R, F, unload);
			Files.WriteLInt(R, pos-unload-4);
			Files.Set(R, F, text.PointerToRawData+offs+1);
			Files.ReadLInt(R, adr); Files.Set(R, F, pos);
			Files.Write(R, CHR(0E8H)); (* CALL first module (Kernel32) *)
			Files.WriteLInt(R, text.PointerToRawData+offs+adr-pos);
			pos := Files.Pos(R); Files.Set(R, F, exit);
			Files.WriteLInt(R, pos-exit-4);
			Files.Set(R, F, pos)
(* Exit: *)
		END;

		Files.Write(R, CHR(05FH)); (* POP EDI *)
		Files.Write(R, CHR(05EH)); (* POP ESI *)
		Files.Write(R, CHR(05DH)); (* POP EBP *)
		Files.Write(R, CHR(05BH)); (* POP EBX *)
		IF isEXE THEN
			Files.Write(R, CHR(0B8H)); Files.WriteLInt(R, 0); (* MOV EAX, 0 *)
			Files.Write(R, CHR(0C3H)) (* RET *)
		ELSE
			Files.Write(R, CHR(0B8H)); Files.WriteLInt(R, -1); (* MOV EAX, TRUE *)
			Files.Write(R, CHR(0C2H)); Files.Write(R, CHR(00CH)); Files.Write(R, CHR(000H)) (* RET 12 *)
		END;
		text.VirtualSize := Files.Pos(R)-text.PointerToRawData;
		FileAlign(R, DefaultFileAlign, CHR(0CCH)); (* INT 3 *)
		text.SizeOfRawData := Files.Pos(R)-text.PointerToRawData
	END WriteText;

	PROCEDURE WriteIData(VAR R: Files.Rider);
		VAR
			F: Files.File; name, obj, imps: NameList;
			pos, p, i, shift, adr: LONGINT;
	BEGIN
		imps := imports.next;
		idata.PointerToRawData := Files.Pos(R); F := Files.Base(R);
		idata.VirtualAddress := text.VirtualAddress+Align(text.SizeOfRawData, DefaultSectionAlign);
		imgHead.DataDirectory[ImageDirectoryEntryImport].VirtualAddress := idata.VirtualAddress;
		shift := idata.VirtualAddress-idata.PointerToRawData;
		name := imps;
		WHILE name # NIL DO
			Files.WriteBytes(R, name(ImportList).impDesc, SIZE(ImageImportDescriptor));
			name := name.next
		END;
		FOR i := 0 TO SIZE(ImageImportDescriptor)-1 DO
			Files.Write(R, 0X)
		END;
		imgHead.DataDirectory[ImageDirectoryEntryImport].Size := Files.Pos(R)-idata.PointerToRawData;
		name := imps;
		WHILE name # NIL DO
			WITH name: ImportList DO
				name.impDesc.Characteristics := Files.Length(F);
				Files.Set(R, F, name.impDesc.Characteristics);
				obj := name.entries;
				WHILE obj # NIL DO
					Files.WriteLInt(R, 0); obj := obj.next
				END;
				Files.WriteLInt(R, 0)
			END;
			name := name.next
		END;
		pos := Files.Pos(R);
		imgHead.DataDirectory[ImageDirectoryEntryIat].VirtualAddress := pos+shift;
		name := imps;
		WHILE name # NIL DO
			WITH name: ImportList DO
				name.impDesc.FirstThunk := Files.Length(F);
				Files.Set(R, F, name.impDesc.FirstThunk);
				obj := name.entries;
				WHILE obj # NIL DO
					Files.WriteLInt(R, 0); obj := obj.next
				END;
				Files.WriteLInt(R, 0)
			END;
			name := name.next
		END;
		imgHead.DataDirectory[ImageDirectoryEntryIat].Size := Files.Pos(R)-pos;
		Files.Set(R, F, idata.PointerToRawData);
		name := imps;
		WHILE name # NIL DO
			WITH name: ImportList DO
				pos := Files.Pos(R);
				i := 0; obj := name.entries;
				WHILE obj # NIL DO
					WITH obj: EntryList DO
						p := Files.Length(F);
						Files.Set(R, F, p);
						Files.WriteInt(R, SHORT(obj.entry));
						Files.WriteString(R, obj.value);
						FileAlign(R, 2, 0X);
						p := p+shift;
						Files.Set(R, F, name.impDesc.Characteristics+i*4);
						Files.WriteLInt(R, p);
						adr := name.impDesc.FirstThunk+i*4;
						Files.Set(R, F, adr);
						Files.WriteLInt(R, p);
						Files.Set(R, F, obj.fixup);
						Files.WriteLInt(R, imgHead.ImageBase+adr+shift)
					END;
					obj := obj.next; INC(i)
				END;
				name.impDesc.Name := Files.Length(F);
				Files.Set(R, F, name.impDesc.Name);
				Files.WriteString(R, name.name);
				FileAlign(R, 2, 0X);
				name.impDesc.Characteristics := name.impDesc.Characteristics+shift;
				name.impDesc.FirstThunk := name.impDesc.FirstThunk+shift;
				name.impDesc.Name := name.impDesc.Name+shift;
				Files.Set(R, F, pos);
				Files.WriteBytes(R, name.impDesc, SIZE(ImageImportDescriptor))
			END;
			name := name.next
		END;
		Files.Set(R, F, Files.Length(F));
		idata.VirtualSize := Files.Pos(R)-idata.PointerToRawData;
		FileAlign(R, DefaultFileAlign, 0X);
		idata.SizeOfRawData := Files.Pos(R)-idata.PointerToRawData
	END WriteIData;

	PROCEDURE AssignExportOrdinals(): LONGINT;
		VAR e, f, g, next, new: ExportEntryList; n: LONGINT;
	BEGIN
		f := NIL; e := exportOrds;
		WHILE (e # NIL) & (e.entry <= 0) DO
			f := e; e := e.nextOrd
		END;
		IF f # NIL THEN f.nextOrd := NIL END; new := e;
		e := exportOrds;
		WHILE e # NIL DO
			next := e.nextOrd;
			g := NIL; f := new; n := 1;
			WHILE (f # NIL) & (f.entry = n) DO
				g := f; f := f.nextOrd; INC(n)
			END;
			e.entry := n;
			e.nextOrd := f;
			IF g # NIL THEN
				g.nextOrd := e
			ELSE
				new := e
			END;
			e := next
		END;
		e := new; n := 1;
		WHILE (e # NIL) & (e.entry = n) DO
Kernel32.Str(e.name); Kernel32.Str(" "); Kernel32.Int(e.entry); Kernel32.Ln();
			e := e.nextOrd; INC(n)
		END;
		(* Assert(e = NIL, e.name, " exported ordinals must be unique") *)
		IF e # NIL THEN Error(e.name, " exported ordinals must be unique") END;
		exportOrds := new;
		RETURN n-1
	END AssignExportOrdinals;

	PROCEDURE WriteEData(VAR R: Files.Rider);
		VAR F: Files.File; head: ImageExportDirectory; adr, i, n, pos, fix: LONGINT; e: ExportEntryList; p: NameList;
	BEGIN
		n := AssignExportOrdinals();
		edata.PointerToRawData := Files.Pos(R); F := Files.Base(R);
		edata.VirtualAddress := idata.VirtualAddress+Align(idata.SizeOfRawData, DefaultSectionAlign);
		imgHead.DataDirectory[ImageDirectoryEntryExport].VirtualAddress := edata.VirtualAddress;
		head.Characteristics := 0;
		head.TimeDateStamp := TimeDateStamp();
		head.MajorVersion := 0; head.MinorVersion := 0;
		head.Base := 1;
		head.NumberOfFunctions := n; head.NumberOfNames := n;
		head.AddressOfFunctions := edata.VirtualAddress+SIZE(ImageExportDirectory);
		head.AddressOfNames := head.AddressOfFunctions+n*4;
		head.AddressOfNameOrdinals := head.AddressOfNames+n*4;
		head.Name := head.AddressOfNameOrdinals+n*2;
		Files.WriteBytes(R, head, SIZE(ImageExportDirectory));
		e := exportOrds;
		WHILE e # NIL DO
			adr := GetObjAdr(e.value, BootLink.Proc);
			Files.WriteLInt(R, adr-imgHead.ImageBase);
			e := e.nextOrd
		END;
		fix := Files.Pos(R); FOR i := 1 TO n DO Files.WriteLInt(R, 0) END;
		p := exports;
		WHILE p # NIL DO
			Files.WriteInt(R, SHORT(p(ExportEntryList).entry-head.Base));
			p := p.next
		END;
		Files.WriteString(R, image); FileAlign(R, 2, 0X);
		p := exports;
		WHILE p # NIL DO
			pos := Files.Pos(R); Files.Set(R, F, fix);
			Files.WriteLInt(R, pos-edata.PointerToRawData+edata.VirtualAddress);
			Files.Set(R, F, pos); INC(fix, 4);
			Files.WriteString(R, p.name); FileAlign(R, 2, 0X);
			p := p.next
		END;
		edata.VirtualSize := Files.Pos(R)-edata.PointerToRawData;
		imgHead.DataDirectory[ImageDirectoryEntryExport].Size := edata.VirtualSize;
		FileAlign(R, DefaultFileAlign, 0X);
		edata.SizeOfRawData := Files.Pos(R)-edata.PointerToRawData
	END WriteEData;

	PROCEDURE QuickSortRelocs(lo, hi: LONGINT);
		VAR i, j, t, rva: LONGINT;
	BEGIN
		IF lo < hi THEN
			i := lo; j := hi; rva := relocs[(lo + hi) DIV 2];
			REPEAT
				WHILE relocs[i] < rva DO INC(i) END;
				WHILE rva < relocs[j] DO DEC(j) END;
				IF i <= j THEN
					t := relocs[i]; relocs[i] := relocs[j]; relocs[j] := t;
					INC(i); DEC(j)
				END
			UNTIL i > j;
			QuickSortRelocs(lo, j); QuickSortRelocs(i, hi)
		END
	END QuickSortRelocs;

	PROCEDURE WriteOffs(VAR R: Files.Rider; offs, type: LONGINT);
	BEGIN
		Files.WriteInt(R, SHORT(ASH(type, 12)+offs))
	END WriteOffs;

	PROCEDURE WriteReloc(VAR R: Files.Rider);
		VAR F: Files.File; head: ImageBaseRelocation; last, this, i, fix: LONGINT;
		PROCEDURE BeginHeader();
		BEGIN
			fix := Files.Pos(R);
			head.VirtualAddress := this - (this MOD PageSize);
			head.SizeOfBlock := SIZE(ImageBaseRelocation);
			Files.WriteBytes(R, head, SIZE(ImageBaseRelocation))
		END BeginHeader;
		PROCEDURE EndHeader();
			VAR pos: LONGINT;
		BEGIN
			WriteOffs(R, 0, ImageRelBasedAbsolute); INC(head.SizeOfBlock, 2);
			IF (head.SizeOfBlock MOD 4) # 0 THEN
				WriteOffs(R, 0, ImageRelBasedAbsolute); INC(head.SizeOfBlock, 2)
			END;
			pos := Files.Pos(R); Files.Set(R, F, fix);
			Files.WriteBytes(R, head, SIZE(ImageBaseRelocation));
			Files.Set(R, F, pos)
		END EndHeader;
	BEGIN
		reloc.PointerToRawData := Files.Pos(R); F := Files.Base(R);
		IF exports # NIL THEN
			reloc.VirtualAddress := edata.VirtualAddress+Align(edata.SizeOfRawData, DefaultSectionAlign)
		ELSE
			reloc.VirtualAddress := idata.VirtualAddress+Align(idata.SizeOfRawData, DefaultSectionAlign)
		END;
		imgHead.DataDirectory[ImageDirectoryEntryBasereloc].VirtualAddress := reloc.VirtualAddress;
		QuickSortRelocs(0, nRelocs-1);
		i := 0; this := relocs[0]; last := -1; BeginHeader();
		WHILE i < nRelocs DO
			IF this # last THEN
ASSERT(this > last);
				IF this >= (head.VirtualAddress+PageSize) THEN
					EndHeader(); BeginHeader()
				END;
ASSERT((this >= text.VirtualAddress) & (this <= (text.VirtualAddress+text.VirtualSize)));
				WriteOffs(R, this-head.VirtualAddress, ImageRelBasedHighLow); INC(head.SizeOfBlock, 2);
				last := this
			END;
			INC(i); this := relocs[i]
		END;
		EndHeader();
		reloc.VirtualSize := Files.Pos(R)-reloc.PointerToRawData;
		imgHead.DataDirectory[ImageDirectoryEntryBasereloc].Size := reloc.VirtualSize;
		FileAlign(R, DefaultFileAlign, 0X);
		reloc.SizeOfRawData := Files.Pos(R)-reloc.PointerToRawData
	END WriteReloc;

	PROCEDURE WriteResDir(VAR R: Files.Rider; named, id: LONGINT);
		VAR dir: ImageResourceDirectory;
	BEGIN
		dir.Characteristics := 0; dir.TimeDateStamp := TimeDateStamp();
		dir.MajorVersion := 0; dir.MinorVersion := 0;
		dir.NumberOfNamedEntries := SHORT(named); dir.NumberOfIdEntries := SHORT(id);
		Files.WriteBytes(R, dir, SIZE(ImageResourceDirectory))
	END WriteResDir;

	PROCEDURE WriteResEntry(VAR R: Files.Rider; name, offset: LONGINT; leaf: BOOLEAN);
		VAR entry: ImageResourceDirectoryEntry;
	BEGIN
		entry.Name := name; entry.OffsetToData := offset;
		IF leaf THEN
			SetHighBit(entry.OffsetToData)
		END;
		Files.WriteBytes(R, entry, SIZE(ImageResourceDirectoryEntry))
	END WriteResEntry;

	PROCEDURE WriteUString(VAR R: Files.Rider; str: ARRAY OF CHAR; zero: BOOLEAN);
		VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE str[i] # 0X DO
			Files.Write(R, Strings.OberonToISO[ORD(str[i])]); Files.Write(R, 0X);
			INC(i)
		END;
		IF zero THEN
			Files.Write(R, 0X); Files.Write(R, 0X)
		END
	END WriteUString;

	PROCEDURE WriteResNameTable(VAR R: Files.Rider; res: ResList);
		VAR name: NameList;
	BEGIN
		name := res;
		WHILE name # NIL DO
			WITH name: ResList DO
				name.adr := Files.Pos(R)-rsrc.PointerToRawData;
				SetHighBit(name.adr);
				Files.WriteInt(R, SHORT(Strings.Length(name.name)));
				WriteUString(R, name.name, FALSE)
			END;
			name := name.next
		END
	END WriteResNameTable;

	PROCEDURE WriteResLeafDir(VAR R: Files.Rider; res: ResList);
		VAR name: NameList;
	BEGIN
		name := res;
		WHILE name # NIL DO
			WITH name: ResList DO
				WriteResDir(R, 0, 1);
				WriteResEntry(R, DefaultLanguage, name.adr, FALSE)
			END;
			name := name.next
		END
	END WriteResLeafDir;

	PROCEDURE CopyIcon(icoRes: IconList; VAR rR: Files.Rider);
		VAR
			F: Files.File; R: Files.Rider;
			bHead: Bitmapinfoheader;
			offs, i: LONGINT; ch: CHAR;
	BEGIN
		F := Files.Old(icoRes.value);
		IF F # NIL THEN
			Files.Set(R, F, 0);
			Files.ReadBytes(R, icoRes.head, 6);
			IF (icoRes.head.reserved = 0) & (icoRes.head.type = 1) & (icoRes.head.count = 1) THEN
				Files.ReadBytes(R, icoRes.dentry, 12);
				Files.ReadLInt(R, offs);
				Files.Set(R, F, offs);
				Files.ReadBytes(R, bHead, SIZE(Bitmapinfoheader));
				icoRes.dentry.planes := bHead.biPlanes;
				icoRes.dentry.bitCount := bHead.biBitCount;
				Files.Set(R, F, offs);
				FOR i := 1 TO icoRes.dentry.bytes DO
					Files.Read(R, ch); Files.Write(rR, ch)
				END;
				RETURN
			END
		END;
		Error(icoRes.value, " invalid icon file")
	END CopyIcon;

	PROCEDURE CopyCursor(curRes: CursorList; VAR rR: Files.Rider);
		VAR
			F: Files.File; R: Files.Rider;
			bHead: Bitmapinfoheader;
			offs, i: LONGINT; x, y: INTEGER; ch: CHAR;
	BEGIN
		F := Files.Old(curRes.value);
		IF F # NIL THEN
			Files.Set(R, F, 0);
			Files.ReadBytes(R, curRes.head, 6);
			IF (curRes.head.reserved = 0) & (curRes.head.type = 2) & (curRes.head.count = 1) THEN
				Files.ReadLInt(R, i);
				Files.ReadInt(R, x); Files.ReadInt(R, y);
				Files.ReadLInt(R, curRes.dentry.bytes);
				Files.ReadLInt(R, offs);
				Files.Set(R, F, offs);
				Files.ReadBytes(R, bHead, SIZE(Bitmapinfoheader));
				curRes.dentry.width := SHORT(bHead.biWidth);
				curRes.dentry.height := SHORT(bHead.biHeight);
				curRes.dentry.planes := bHead.biPlanes;
				curRes.dentry.bitCount := bHead.biBitCount;
				Files.WriteInt(rR, x); Files.WriteInt(rR, y);
				Files.Set(R, F, offs);
				FOR i := 1 TO curRes.dentry.bytes DO
					Files.Read(R, ch); Files.Write(rR, ch)
				END;
				INC(curRes.dentry.bytes, 4);
				RETURN
			END
		END;
		Error(curRes.value, " invalid cursor file")
	END CopyCursor;

	PROCEDURE WriteVersionRes(VAR R: Files.Rider);
		VAR
			F: Files.File;
			info: VsFixedFileInfo; ver: NameList;
			fix, fix0, fix1, fix2, ret: LONGINT;
	BEGIN
		F := Files.Base(R); fix0 := Files.Pos(R);
		Files.WriteInt(R, 0);
		Files.WriteInt(R, SIZE(VsFixedFileInfo));
		Files.WriteInt(R, 0);
		WriteUString(R, "VS_VERSION_INFO", TRUE);
		FileAlign(R, 4, 0X);
		info.dwSignature := VsFfiSignature;
		info.dwStrucVersion := VsFfiStrucVersion;
		info.dwFileVersionMs := imgHead.MajorImageVersion;
		info.dwFileVersionLs := imgHead.MinorImageVersion;
		info.dwProductVersionMs := imgHead.MajorImageVersion;
		info.dwProductVersionLs := imgHead.MinorImageVersion;
		info.dwFileFlagsMask := VsFfiFileFlagsMask;
		info.dwFileFlags := 0;
		info.dwFileOs := VosNtWindows32;
		IF isEXE THEN
			info.dwFileType := VftApp
		ELSE
			info.dwFileType := VftDll
		END;
		info.dwFileSubtype := Vft2Unknown;
		info.dwFileDateMs := 0;
		info.dwFileDateLs := 0;
		Files.WriteBytes(R, info, SIZE(VsFixedFileInfo));
		fix1 := Files.Pos(R);
		Files.WriteInt(R, 0); Files.WriteInt(R, 0);
		Files.WriteInt(R, 1);
		WriteUString(R, "StringFileInfo", TRUE);
		FileAlign(R, 4, 0X);
		fix2 := Files.Pos(R);
		Files.WriteInt(R, 0); Files.WriteInt(R, 0);
		Files.WriteInt(R, 1);
		WriteUString(R, "040904e4", TRUE);
		FileAlign(R, 4, 0X);
		ver := version;
		WHILE ver # NIL DO
			WITH ver: ValueList DO
				fix := Files.Pos(R);
				Files.WriteInt(R, 0);
				Files.WriteInt(R, SHORT(Strings.Length(ver.value)+1));
				Files.WriteInt(R, 1);
				WriteUString(R, ver.name, TRUE);
				FileAlign(R, 4, 0X);
				WriteUString(R, ver.value, TRUE);
				ret := Files.Pos(R);
				Files.Set(R, F, fix);
				Files.WriteInt(R, SHORT(ret-fix));
				Files.Set(R, F, ret);
				FileAlign(R, 4, 0X)
			END;
			ver := ver.next
		END;
		ret := Files.Pos(R);
		Files.Set(R, F, fix0);
		Files.WriteInt(R, SHORT(ret-fix0));
		Files.Set(R, F, fix1);
		Files.WriteInt(R, SHORT(ret-fix1));
		Files.Set(R, F, fix2);
		Files.WriteInt(R, SHORT(ret-fix2));
		Files.Set(R, F, ret)
	END WriteVersionRes;

	PROCEDURE WriteRSRC(VAR R: Files.Rider);
		VAR
			F: Files.File; name: NameList; data: ImageResourceDataEntry;
			n, pos, base, fix1, fix2, curPos, icoPos, grpCurPos, grpIcoPos, verPos: LONGINT;
	BEGIN
		rsrc.PointerToRawData := Files.Pos(R); F := Files.Base(R);
		IF ~isEXE THEN
			rsrc.VirtualAddress := reloc.VirtualAddress+Align(reloc.SizeOfRawData, DefaultSectionAlign)
		ELSIF exports # NIL THEN
			rsrc.VirtualAddress := edata.VirtualAddress+Align(edata.SizeOfRawData, DefaultSectionAlign)
		ELSE
			rsrc.VirtualAddress := idata.VirtualAddress+Align(idata.SizeOfRawData, DefaultSectionAlign)
		END;
		imgHead.DataDirectory[ImageDirectoryEntryResource].VirtualAddress := rsrc.VirtualAddress;
		IF (icons # NIL) & (cursors # NIL) THEN
			WriteResDir(R, 0, 5)
		ELSIF (icons # NIL) OR (cursors # NIL) THEN
			WriteResDir(R, 0, 3)
		ELSE
			WriteResDir(R, 0, 1)
		END;
		IF cursors # NIL THEN
			curPos := Files.Pos(R); WriteResEntry(R, RtCursor, 0, FALSE)
		END;
		IF icons # NIL THEN
			icoPos := Files.Pos(R); WriteResEntry(R, RtIcon, 0, FALSE)
		END;
		IF cursors # NIL THEN
			grpCurPos := Files.Pos(R); WriteResEntry(R, RtGroupCursor, 0, FALSE)
		END;
		IF icons # NIL THEN
			grpIcoPos := Files.Pos(R); WriteResEntry(R, RtGroupIcon, 0, FALSE)
		END;
		verPos := Files.Pos(R); WriteResEntry(R, RtVersion, 0, FALSE);
		IF cursors # NIL THEN
			name := cursors; n := 0;
			WHILE name # NIL DO
				WITH name: CursorList DO
					INC(n); name.dentry.name := SHORT(n)
				END;
				name := name.next
			END;
			WriteResNameTable(R, cursors); FileAlign(R, 4, 0X);
			pos := Files.Pos(R); base := pos-rsrc.PointerToRawData;
			Files.Set(R, F, curPos); WriteResEntry(R, RtCursor, base, TRUE);
			base := base+SIZE(ImageResourceDirectory)+n*SIZE(ImageResourceDirectoryEntry);
			Files.Set(R, F, grpCurPos); WriteResEntry(R, RtGroupCursor, base, TRUE);
			base := base+SIZE(ImageResourceDirectory)+n*SIZE(ImageResourceDirectoryEntry);
			Files.Set(R, F, pos);
			WriteResDir(R, 0, n);
			name := cursors;
			WHILE name # NIL DO
				WITH name: CursorList DO
					WriteResEntry(R, name.dentry.name, base, TRUE);
					base := base+SIZE(ImageResourceDirectory)+SIZE(ImageResourceDirectoryEntry)
				END;
				name := name.next
			END;
			WriteResDir(R, n, 0);
			name := cursors;
			WHILE name # NIL DO
				WITH name: ResList DO
					WriteResEntry(R, name.adr, base, TRUE);
					base := base+SIZE(ImageResourceDirectory)+SIZE(ImageResourceDirectoryEntry)
				END;
				name := name.next
			END;
			fix1 := Files.Pos(R); WriteResLeafDir(R, cursors);
			fix2 := Files.Pos(R); WriteResLeafDir(R, cursors);
			name := cursors;
			WHILE name # NIL DO
				WITH name: CursorList DO
					pos := Files.Pos(R);
					name.adr := pos-rsrc.PointerToRawData;
					data.OffsetToData := pos-rsrc.PointerToRawData+rsrc.VirtualAddress+SIZE(ImageResourceDataEntry);
					data.Size := 0;
					data.CodePage := 0;
					data.Reserved := 0;
					Files.WriteBytes(R, data, SIZE(ImageResourceDataEntry));
					data.Size := Files.Pos(R);
					CopyCursor(name, R);
					data.Size := Files.Pos(R)-data.Size;
					Files.Set(R, F, pos);
					Files.WriteBytes(R, data, SIZE(ImageResourceDataEntry));
					Files.Set(R, F, Files.Pos(R)+data.Size);
					FileAlign(R, 8, 0X)
				END;
				name := name.next
			END;
			pos := Files.Pos(R); Files.Set(R, F, fix1);
			WriteResLeafDir(R, cursors);
			Files.Set(R, F, pos);
			name := cursors;
			WHILE name # NIL DO
				WITH name: CursorList DO
					pos := Files.Pos(R);
					name.adr := pos-rsrc.PointerToRawData;
					data.OffsetToData := pos-rsrc.PointerToRawData+rsrc.VirtualAddress+SIZE(ImageResourceDataEntry);
					data.Size := 6+14;
					data.CodePage := 0;
					data.Reserved := 0;
					Files.WriteBytes(R, data, SIZE(ImageResourceDataEntry));
					Files.WriteBytes(R, name.head, 6);
					Files.WriteBytes(R, name.dentry, 14);
					FileAlign(R, 4, 0X)
				END;
				name := name.next
			END;
			pos := Files.Pos(R); Files.Set(R, F, fix2);
			WriteResLeafDir(R, cursors);
			Files.Set(R, F, pos)
		END;
		IF icons # NIL THEN
			name := icons; n := 0;
			WHILE name # NIL DO
				WITH name: IconList DO
					INC(n); name.dentry.name := SHORT(n)
				END;
				name := name.next
			END;
			WriteResNameTable(R, icons); FileAlign(R, 4, 0X);
			pos := Files.Pos(R); base := pos-rsrc.PointerToRawData;
			Files.Set(R, F, icoPos); WriteResEntry(R, RtIcon, base, TRUE);
			base := base+SIZE(ImageResourceDirectory)+n*SIZE(ImageResourceDirectoryEntry);
			Files.Set(R, F, grpIcoPos); WriteResEntry(R, RtGroupIcon, base, TRUE);
			base := base+SIZE(ImageResourceDirectory)+n*SIZE(ImageResourceDirectoryEntry);
			Files.Set(R, F, pos);
			WriteResDir(R, 0, n);
			name := icons;
			WHILE name # NIL DO
				WITH name: IconList DO
					WriteResEntry(R, name.dentry.name, base, TRUE);
					base := base+SIZE(ImageResourceDirectory)+SIZE(ImageResourceDirectoryEntry)
				END;
				name := name.next
			END;
			WriteResDir(R, n, 0);
			name := icons;
			WHILE name # NIL DO
				WITH name: ResList DO
					WriteResEntry(R, name.adr, base, TRUE);
					base := base+SIZE(ImageResourceDirectory)+SIZE(ImageResourceDirectoryEntry)
				END;
				name := name.next
			END;
			fix1 := Files.Pos(R); WriteResLeafDir(R, icons);
			fix2 := Files.Pos(R); WriteResLeafDir(R, icons);
			name := icons;
			WHILE name # NIL DO
				WITH name: IconList DO
					pos := Files.Pos(R);
					name.adr := pos-rsrc.PointerToRawData;
					data.OffsetToData := pos-rsrc.PointerToRawData+rsrc.VirtualAddress+SIZE(ImageResourceDataEntry);
					data.Size := 0;
					data.CodePage := 0;
					data.Reserved := 0;
					Files.WriteBytes(R, data, SIZE(ImageResourceDataEntry));
					data.Size := Files.Pos(R);
					CopyIcon(name, R);
					data.Size := Files.Pos(R)-data.Size;
					Files.Set(R, F, pos);
					Files.WriteBytes(R, data, SIZE(ImageResourceDataEntry));
					Files.Set(R, F, Files.Pos(R)+data.Size);
					FileAlign(R, 8, 0X)
				END;
				name := name.next
			END;
			pos := Files.Pos(R); Files.Set(R, F, fix1);
			WriteResLeafDir(R, icons);
			Files.Set(R, F, pos);
			name := icons;
			WHILE name # NIL DO
				WITH name: IconList DO
					pos := Files.Pos(R);
					name.adr := pos-rsrc.PointerToRawData;
					data.OffsetToData := pos-rsrc.PointerToRawData+rsrc.VirtualAddress+SIZE(ImageResourceDataEntry);
					data.Size := 6+14;
					data.CodePage := 0;
					data.Reserved := 0;
					Files.WriteBytes(R, data, SIZE(ImageResourceDataEntry));
					Files.WriteBytes(R, name.head, 6);
					Files.WriteBytes(R, name.dentry, 14);
					FileAlign(R, 4, 0X)
				END;
				name := name.next
			END;
			pos := Files.Pos(R); Files.Set(R, F, fix2);
			WriteResLeafDir(R, icons);
			Files.Set(R, F, pos)
		END;
		pos := Files.Pos(R);
		Files.Set(R, F, verPos); WriteResEntry(R, RtVersion, pos-rsrc.PointerToRawData, TRUE);
		Files.Set(R, F, pos);
		WriteResDir(R, 0, 1); WriteResEntry(R, 1, pos-rsrc.PointerToRawData+SIZE(ImageResourceDirectory)+SIZE(ImageResourceDirectoryEntry), TRUE);
		pos := Files.Pos(R);
		WriteResDir(R, 0, 1); WriteResEntry(R, DefaultLanguage, pos-rsrc.PointerToRawData+SIZE(ImageResourceDirectory)+SIZE(ImageResourceDirectoryEntry), FALSE);
		verPos := Files.Pos(R);
		data.OffsetToData := 0;
		data.Size := 0;
		data.CodePage := 0;
		data.Reserved := 0;
		Files.WriteBytes(R, data, SIZE(ImageResourceDataEntry));
		FileAlign(R, 16, 0X);
		pos := Files.Pos(R);
		data.OffsetToData := pos-rsrc.PointerToRawData+rsrc.VirtualAddress;
		WriteVersionRes(R);
		pos := Files.Pos(R);
		data.Size := pos-verPos-SIZE(ImageResourceDataEntry);
		Files.Set(R, F, verPos); Files.WriteBytes(R, data, SIZE(ImageResourceDataEntry));
		Files.Set(R, F, pos);
		rsrc.VirtualSize := Files.Pos(R)-rsrc.PointerToRawData;
		imgHead.DataDirectory[ImageDirectoryEntryResource].Size := rsrc.VirtualSize;
		FileAlign(R, DefaultFileAlign, 0X);
		rsrc.SizeOfRawData := Files.Pos(R)-rsrc.PointerToRawData
	END WriteRSRC;

	PROCEDURE DoLink*(T: Texts.Text): BOOLEAN;
		VAR
			context: Exceptions.Context;
			F: Files.File; R: Files.Rider;
			mod: BootLink.Module; base, offs: LONGINT; name: NameList;
			sections: INTEGER; done: BOOLEAN;
		PROCEDURE *Handler(VAR e: Exceptions.Exception): LONGINT;
		BEGIN
			IF e IS ErrorException THEN
				RETURN Exceptions.ReturnFail(context)
			ELSE
				RETURN Exceptions.Forward
			END
		END Handler;
	BEGIN
		Init();
		IF ~Exceptions.Failed(context) THEN
			ScanLinkText(T);
			Texts.WriteString(W, "linking "); Texts.WriteString(W, image);
			Texts.WriteLn(W); Texts.Append(Texts.Log, W.buf);
			sections := 3; (* .text, .idata, .rsrc *)
			F := Files.New(image); Files.Set(R, F, 0);
			Assert(F # NIL, image, " Files.New failed");
			WriteImageHeader(R, sections);
			imgHead.SizeOfHeaders := Files.Pos(R);
			Files.WriteBytes(R, imgHead, SIZE(ImageOptionalHeader));
			Files.WriteBytes(R, text, SIZE(ImageSectionHeader));
			Files.WriteBytes(R, idata, SIZE(ImageSectionHeader));
			IF exports # NIL THEN
				Files.WriteBytes(R, edata, SIZE(ImageSectionHeader));
				INC(sections)
			END;
			IF ~isEXE THEN
				Files.WriteBytes(R, reloc, SIZE(ImageSectionHeader));
				INC(sections)
			END;
			Files.WriteBytes(R, rsrc, SIZE(ImageSectionHeader));
			FileAlign(R, DefaultFileAlign, 0X);
			text.VirtualAddress := BaseRVA;
			base := imgHead.ImageBase+text.VirtualAddress;
			BootLink.AddReloc := AddReloc;
			BootLink.BeginLink(base, Modules.extension, base);
			name := modules;
			WHILE name # NIL DO
				Texts.WriteString(W, "  "); Texts.WriteString(W, name.name);
				Texts.WriteLn(W); Texts.Append(Texts.Log, W.buf);
				BootLink.Load(mod, name.name, base);
				name := name.next
			END;
			text.PointerToRawData := Files.Pos(R);
			BootLink.EndLink(R, base, offs);
			WriteText(R, offs);
			WriteIData(R);
			IF exports # NIL THEN WriteEData(R) END;
			IF ~isEXE THEN WriteReloc(R) END;
			WriteRSRC(R);
			imgHead.SizeOfCode := text.SizeOfRawData;
			imgHead.SizeOfInitializedData := idata.SizeOfRawData+rsrc.SizeOfRawData;
			imgHead.SizeOfUninitializedData := 0;
			imgHead.BaseOfCode := text.VirtualAddress;
			imgHead.BaseOfData := 0;
			imgHead.SizeOfHeaders := imgHead.SizeOfHeaders+SIZE(ImageOptionalHeader)+sections*SIZE(ImageSectionHeader);
			imgHead.SizeOfHeaders := Align(imgHead.SizeOfHeaders, DefaultFileAlign);
			imgHead.SizeOfImage := Align(imgHead.SizeOfHeaders, DefaultSectionAlign)+
													Align(text.SizeOfRawData, DefaultSectionAlign)+
													Align(idata.SizeOfRawData, DefaultSectionAlign)+
													Align(edata.SizeOfRawData, DefaultSectionAlign)+
													Align(reloc.SizeOfRawData, DefaultSectionAlign)+
													Align(rsrc.SizeOfRawData, DefaultSectionAlign);
			BootLink.Close();
			Files.Set(R, F, 0);
			WriteImageHeader(R, sections);
			Files.WriteBytes(R, imgHead, SIZE(ImageOptionalHeader));
			Files.WriteBytes(R, text, SIZE(ImageSectionHeader));
			Files.WriteBytes(R, idata, SIZE(ImageSectionHeader));
			IF exports # NIL THEN
				Files.WriteBytes(R, edata, SIZE(ImageSectionHeader))
			END;
			IF ~isEXE THEN
				Files.WriteBytes(R, reloc, SIZE(ImageSectionHeader))
			END;
			Files.WriteBytes(R, rsrc, SIZE(ImageSectionHeader));
			Files.Register(F); Texts.WriteString(W, " done"); done := TRUE
		ELSE
			Texts.WriteString(W, error.msg); done := FALSE;
		END;
		Clean(); Texts.WriteLn(W); Texts.Append(Texts.Log, W.buf);
		RETURN done
	END DoLink;
	
(***********************************)
PROCEDURE About();
BEGIN
  Console.WriteLn();
  Console.WriteString("Command line version of the ETH Oberon Plugin for");  Console.WriteLn();
  Console.WriteString("Windows   Release 2.4  Oberon  PELinker  utility.");  Console.WriteLn();
  Console.WriteLn();
  Console.WriteString("  PELinker by: Team of the Institute for Computer");  Console.WriteLn();
  Console.WriteString("  Systems  of  ETH  Zuerich  (www.oberon.ethz.ch)");  Console.WriteLn();
  Console.WriteString("  Wrapper  by: E.V. Shcherbatyuk   (ugns@mail.ru)");  Console.WriteLn();
  Console.WriteLn();
  Console.WriteString("Run 'O2ETHCLL /?' for this information.");  Console.WriteLn();
  Console.WriteString("Run 'O2ETHCLL file' to link executable.");  Console.WriteLn();
  Console.WriteLn();
  Console.WriteString("file - filename of the 'link' project file");  Console.WriteLn();
END About;

(***********************************)
PROCEDURE GetOptions(VAR name: ARRAY OF CHAR):BOOLEAN;
		VAR i, j, k : LONGINT; ch: CHAR;
BEGIN
		name[0] := 0X; i := 0;
		(* Skip executable pathname *)
		ch := CmdLine.text[i];
		WHILE (ch#" ") & (ch#0X) DO
	  	INC(i);
	  	ch := CmdLine.text[i];
		END;
		j := i;
		IF ch = 0X THEN
			Console.WriteString("No parameters specified"); Console.WriteLn;
			Console.WriteString("Run 'O2ETHCLL /?' for help"); Console.WriteLn;
			RETURN FALSE;
		END;
		(* look for switch *)
		WHILE (ch#"/") & (ch#0X) DO
	  	INC(i);
		  ch := CmdLine.text[i];
		END;
		IF ch = "/" THEN
		  INC(i);
		  ch := CmdLine.text[i];
		  IF     ch = "?"   THEN
		    About();
		    RETURN FALSE;
		  ELSIF (ch >= " ") THEN
		    Console.WriteString("Wrong parameter specified"); Console.WriteLn;
		    Console.WriteString("Run 'O2ETHCLL /?' for help"); Console.WriteLn;
		    RETURN FALSE;
		  ELSE
		    Console.WriteString("No parameter specified"); Console.WriteLn;
		    Console.WriteString("Run 'O2ETHCLL /?' for help"); Console.WriteLn;
		    RETURN FALSE;
		  END;
		ELSE
		  i := j; (* There were no switch *)
		  ch := CmdLine.text[i];
		END;
		(* look for  filename *)
		WHILE (ch<=" ") & (ch#0X) DO
		  INC(i); ch := CmdLine.text[i]; (* Skip blanks in front of filename *)
		END;
		k := 0;
		WHILE (ch >" ") & (k<LEN(name)) DO
		  name[k] := ch; INC(k);
		  INC(i); ch := CmdLine.text[i];
		END;
		name[k] := 0X;
		IF k = 0 THEN
		  Console.WriteString("No file specified"); Console.WriteLn;
		  Console.WriteString("Run 'O2ETHCLL /?' for help"); Console.WriteLn;
		  RETURN FALSE;
		END;
		Console.WriteString("file=");Console.WriteString(name); Console.WriteLn();
		RETURN TRUE;
END GetOptions;


(** PELinker.Link .Link-file *)
PROCEDURE Link();
		VAR  T: Texts.Text; done: BOOLEAN;
		     name : FileDir.FileName;
BEGIN
    IF GetOptions(name) THEN
	      NEW(T); Texts.Open(T, name);
	  IF T.len # 0 THEN
   	 done := DoLink(T);
      ELSE
	    Texts.WriteString(W, name); Texts.WriteString(W, " not found");
	    Texts.WriteLn(W); Texts.Append(Texts.Log, W.buf);
      END;
    END;
END Link;

BEGIN
	Link();
END O2ETHCLL.
