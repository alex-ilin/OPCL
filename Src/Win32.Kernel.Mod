(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Kernel;	(** non-portable *)	(* rc/ard/nm/jm/jdv/pjm/rml/ejz *)
	IMPORT SYSTEM, Kernel32;

(** Module Kernel is responsible for memory allocation, garbage collection and other run-time support for the Oberon language, as well as interfacing to the underlying machine.  Using features exported from module Kernel may result in an unportable module, as not all Oberon Kernels are the same. This module is of little importance to most Oberon programmers. *)

CONST
		(* heap/GC *)
	B = 32;	(* heap block size, must be a multiple of 32 *)
	N = 9;	(* number of free lists - 1 *)
	nil = Kernel32.NULL;
	MarkBit = 0; ArrayBit = 1;  FreeBit = 2;  SubObjBit = 3;
	mark = {MarkBit}; array = {ArrayBit};  free = {FreeBit};  subobj = {SubObjBit};

		(* Windows *)
	HeapBlockSize = 512*1024;

TYPE
	ADDRESS = Kernel32.ADDRESS;
	Name* = ARRAY 32 OF CHAR;	(* module name *)
	Proc* = PROCEDURE;
	Cmd* = RECORD
		name*: Name;
		adr*: ADDRESS
	END;
	Module* = POINTER TO ModuleDesc;	(* module descriptor *)
	ExportPtr* = POINTER TO ExportDesc;
	ExportDesc* = RECORD
		fp*: LONGINT; adr*: LONGINT;
		nofExp*: INTEGER;
		dsc*: POINTER TO ARRAY OF ExportDesc
	END;
	ArrayPtr* = POINTER TO ARRAY OF LONGINT;
	ModuleDesc* = RECORD	(* Note: if this is changed, also update the static Linker *)
		next*: Module;
		name*: Name;
		init*, trapped*: BOOLEAN;
		refcnt*, sb*: LONGINT;
		entries*: POINTER TO ARRAY OF ADDRESS;
		cmds*: POINTER TO ARRAY OF Cmd;
		ptrTab*, tdescs*: POINTER TO ARRAY OF ADDRESS;
		imports*: POINTER TO ARRAY OF Module;
		data*, code*, refs*: POINTER TO ARRAY OF CHAR;
		publics*, privates*: LONGINT;	(* for slim binaries *)
		nofimp*: INTEGER; import*: ArrayPtr;
		nofstrc*: INTEGER; struct*: ArrayPtr;
		nofreimp*: INTEGER; reimp*: ArrayPtr;
		export*: ExportDesc;
		term*: Proc
	END;

		(* type descriptors *)
	Tag* = POINTER TO RECORD
		size: LONGINT;
		ptroff: LONGINT
	END;

		(* heap/GC *)
	FreeBlockPtr = POINTER TO RECORD
		(* off-4 *) tag: Tag;
		(* off0 *) size: LONGINT;	(* field size aligned to 8-byte boundary, size MOD B = B-4 *)
		(* off4 *) next: ADDRESS
	END;
	BlockPtr = POINTER TO RECORD
		lastElemToMark, currElem, firstElem: BlockPtr
	END;
	Blockm4Ptr = POINTER TO RECORD
		tag: Tag;
		lastElemToMark, currElem, firstElem: LONGINT
	END;
	InitPtr = POINTER TO RECORD tag: Tag; z0, z1, z2, z3, z4, z5, z6, z7: LONGINT END;
		(* the following type is used indirectly in InitHeap *)
	PtrElemDesc = RECORD a: SYSTEM.PTR END;	(* has same type descriptor as element of ARRAY OF POINTER *)

	Finalizer* = PROCEDURE (obj: SYSTEM.PTR);
	FinObj = POINTER TO RECORD
		next: FinObj;
		obj: ADDRESS;
		marked, basic: BOOLEAN;
		fin: Finalizer
	END;

	HeapBlock = POINTER TO HeapBlockDesc;
	HeapBlockDesc = RECORD
		next: (*HeapBlock*) ADDRESS;
		size: LONGINT;
		firstBlock, endBlock: (*FreeBlockPtr*) ADDRESS
	END;

VAR
		(* exported variables *)
	version*: ARRAY 32 OF CHAR;
	modules*: Module;	(** list of modules, patched by Linker *)
	runtime*: ARRAY 3 OF ADDRESS;	(** for internal use *)

		(* heap/GC *)
	A: ARRAY N+1 OF (*FreeBlockPtr*) ADDRESS;
	initres: InitPtr;	(* root for init calls *)
	ptrElemTag: ADDRESS;
	candidates: ARRAY 1024 OF ADDRESS;	(* stack pointer candidates *)
	nofcand: LONGINT;
	firstTry: BOOLEAN;	(* used with GC & reserve *)
	FinObjs: FinObj;
	GClevel*: LONGINT;

		(* Windows *)
	CheckStacks*: PROCEDURE ();
	BeginAtomic*: PROCEDURE(): BOOLEAN;
	EndAtomic*: PROCEDURE ();
	moduleCS: Kernel32.CriticalSection;
	hInstance-: Kernel32.HINSTANCE; (* init by linker/loader *)
	isEXE-: BOOLEAN; lock*: LONGINT;
	firstHeapBlock: (*HeapBlock*)ADDRESS;
	bootHeapBlockDesc: HeapBlockDesc;
	bootHeapAdr, bootHeapSize: ADDRESS; (* init by linker/loader *)
	minHeapAdr, maxHeapAdr: ADDRESS;

(** -- Trap handling -- *)

(** GetMod - Return the loaded module that contains code address pc. *)

PROCEDURE GetMod*(pc : LONGINT): Module;
VAR m: Module;  base: LONGINT;
BEGIN
	Kernel32.EnterCriticalSection(moduleCS);
	m := modules;
	WHILE m # NIL DO
		base := SYSTEM.ADR(m.code[0]);	(* include 1 byte after module in module, therefore <= below *)
		IF (base <= pc) & (pc <= base + LEN(m.code)) THEN
			Kernel32.LeaveCriticalSection(moduleCS);
			RETURN m
		ELSIF (SYSTEM.ADR(m.data[0]) <= pc) & (pc <= SYSTEM.ADR(m.data[0]) + LEN(m.data)) THEN
			Kernel32.LeaveCriticalSection(moduleCS);
			RETURN m
		ELSE
			m := m.next
		END
	END;
	Kernel32.LeaveCriticalSection(moduleCS);
	RETURN NIL
END GetMod;

(** -- Memory/Object management -- *)

(** Available - Return the size in bytes of the remaining free heap space *)

PROCEDURE Available*(): LONGINT;
	VAR i, avail: LONGINT; ptr: FreeBlockPtr;
BEGIN
	Kernel32.EnterCriticalSection(moduleCS);
	avail := 0; i := 0;
	WHILE i <= N DO
		ptr := SYSTEM.VAL(FreeBlockPtr, A[i]);
		WHILE ptr # NIL DO
			INC(avail, ptr^.size); ptr := SYSTEM.VAL(FreeBlockPtr, ptr^.next)
		END;
		INC(i)
	END;
	Kernel32.LeaveCriticalSection(moduleCS);
	RETURN avail
END Available;

(** LargestAvailable - Return the size in bytes of the largest free available memory block. Allocating objects with a size greater than this size will cause the memory allocation to fail. *)

PROCEDURE LargestAvailable*(): LONGINT;
	VAR i, max: LONGINT; ptr: FreeBlockPtr;
BEGIN
	Kernel32.EnterCriticalSection(moduleCS);
	i := N; max := 0;
	WHILE (i >= 0) & (max = 0) DO
		ptr := SYSTEM.VAL(FreeBlockPtr, A[i]);
		WHILE ptr # NIL DO
			IF ptr^.size > max THEN max := ptr^.size END;
			ptr := SYSTEM.VAL(FreeBlockPtr, ptr^.next)
		END;
		DEC(i)
	END;
	Kernel32.LeaveCriticalSection(moduleCS);
	RETURN max
END LargestAvailable;

(** Used - Return the size in bytes of the amount of memory currently in use in the heap. *)

PROCEDURE Used*(): LONGINT;
	VAR block: HeapBlock; size: LONGINT;
BEGIN
	Kernel32.EnterCriticalSection(moduleCS);
	size := 0;
	block := SYSTEM.VAL(HeapBlock, firstHeapBlock);
	WHILE block # NIL DO
		size := size + block.size;
		block := SYSTEM.VAL(HeapBlock, block.next)
	END;
	size := size - Available();
	Kernel32.LeaveCriticalSection(moduleCS);
	RETURN size
END Used;

PROCEDURE Mark(block: BlockPtr);
	TYPE Tag0 = POINTER TO RECORD (*size,*) ptroff: SET END;
		(* size skipped, because accessed via tag = actual tag + 4 *)
	VAR father, field, currElem: BlockPtr; offset: LONGINT; tag, downtag, marked: Tag0; arraybit: SET;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, block)-4, tag);
	IF ~(SubObjBit IN SYSTEM.VAL(SET, block)) THEN	(* not a subobject *)
		marked := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, tag) + mark);
		IF tag # marked THEN
			SYSTEM.PUT(SYSTEM.VAL(ADDRESS, block)-4, marked);
			SYSTEM.GET(SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, tag) - array)-4, marked);
			EXCL(SYSTEM.VAL(SET, marked), MarkBit); (* necessary to mask mark bit *)
			SYSTEM.GET(SYSTEM.VAL(ADDRESS, marked)-4, arraybit);
			INCL(arraybit, MarkBit);
			SYSTEM.PUT(SYSTEM.VAL(ADDRESS, marked)-4, arraybit);
			arraybit := SYSTEM.VAL(SET, tag) * array;
			IF arraybit # {} THEN currElem := block^.firstElem;
				tag := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, tag) - arraybit)
			ELSE currElem := block
			END;
			father := NIL;
			LOOP
				INC(SYSTEM.VAL(ADDRESS, tag), 4);	(* step through rec fields by modifying tag (locally only) *)
				offset := SYSTEM.VAL(LONGINT, tag^.ptroff - {ArrayBit});	(* strip deep copy flag *)
				IF offset < 0 THEN
					INC(SYSTEM.VAL(ADDRESS, tag), offset);
					IF (arraybit # {}) & (currElem # block^.lastElemToMark) THEN
						INC(SYSTEM.VAL(ADDRESS, currElem), SYSTEM.VAL(LONGINT, tag^.ptroff - {ArrayBit}))
					ELSE (* up *)
							(* here the tag is modified to store the state of the traversal.  bits 2- are changed *)
						SYSTEM.PUT(SYSTEM.VAL(ADDRESS, block)-4, SYSTEM.VAL(SET, tag) + arraybit + mark);
						IF father = NIL THEN EXIT END;
						SYSTEM.GET(SYSTEM.VAL(ADDRESS, father)-4, tag);
						arraybit := SYSTEM.VAL(SET, tag) * array;
						tag := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, tag) - (array + mark));
						IF arraybit # {} THEN currElem := father^.currElem
						ELSE currElem := father
						END;
						offset (*field address*) := SYSTEM.VAL(ADDRESS, currElem) + SYSTEM.VAL(LONGINT, tag^.ptroff - {ArrayBit});
						SYSTEM.GET(offset, field);
						SYSTEM.PUT(offset, block);
						block := father;
						father := field
					END
				ELSE
					offset (*field address*) := SYSTEM.VAL(ADDRESS, currElem) + offset;
					SYSTEM.GET(offset, field);
					IF field # NIL THEN
						SYSTEM.GET(SYSTEM.VAL(ADDRESS, field)-4, downtag);
						IF subobj * SYSTEM.VAL(SET, field) = {} THEN	(* not a subobject *)
							marked := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, downtag) + mark);
							IF downtag # marked THEN (* down *)
								SYSTEM.PUT(SYSTEM.VAL(ADDRESS, field)-4, marked);
									(* here the tag is modified.  bits 2- are changed *)
								SYSTEM.PUT(SYSTEM.VAL(ADDRESS, block)-4, SYSTEM.VAL(SET, tag) + arraybit + mark);
								IF arraybit # {} THEN block^.currElem:= currElem END;
								SYSTEM.GET(SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, downtag) - array)-4, marked);
								EXCL(SYSTEM.VAL(SET, marked), MarkBit); (* necessary to mask mark bit *)
								SYSTEM.GET(SYSTEM.VAL(ADDRESS, marked)-4, arraybit);
								INCL(arraybit, MarkBit);
								SYSTEM.PUT(SYSTEM.VAL(ADDRESS, marked)-4, arraybit);
								arraybit := SYSTEM.VAL(SET, downtag) * array;
								IF arraybit # {} THEN currElem := field^.firstElem ELSE currElem := field END;
								SYSTEM.PUT(offset, father);
								father := block;
								block := field;
								tag := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, downtag) - arraybit)
							END
						ELSE	(* do not mark subobject *)
							SYSTEM.GET(SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, downtag) - array)-4, marked);
							EXCL(SYSTEM.VAL(SET, marked), MarkBit);
							SYSTEM.GET(SYSTEM.VAL(ADDRESS, marked)-4, downtag);
							INCL(SYSTEM.VAL(SET, downtag), MarkBit);
							SYSTEM.PUT(SYSTEM.VAL(ADDRESS, marked)-4, downtag)
						END
					END
				END
			END
		END
	ELSE (* do not mark subobject, subobjects are not traced *)
			(* remove array bit because of array subobjects in module block *)
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, tag) - array)-4, tag);
		EXCL(SYSTEM.VAL(SET, tag), MarkBit);
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, tag)-4, arraybit);
		INCL(arraybit, MarkBit);
		SYSTEM.PUT(SYSTEM.VAL(ADDRESS, tag)-4, arraybit)
	END
END Mark;

PROCEDURE CheckFinObjs;
	VAR n: FinObj; tag: LONGINT;
BEGIN
	n := FinObjs;	(* find all checked objects that are marked *)
	WHILE n # NIL DO
		SYSTEM.GET(n.obj - 4, tag);
		n.marked := MarkBit IN SYSTEM.VAL(SET, tag);
		n := n.next
	END;
	n := FinObjs;	(* now mark all objects reachable from the unmarked checked objects *)
		(* they will be freed at the next GC, unless the checked object is ressurrected *)
	WHILE n # NIL DO
		IF ~n.marked THEN Mark(SYSTEM.VAL(BlockPtr, n.obj)) END;
		n := n.next
	END
END CheckFinObjs;

PROCEDURE Sweep;
	VAR
		p, end: Blockm4Ptr; lastp: FreeBlockPtr; tag, notmarked, tdesc: Tag; size, lastsize, i: LONGINT;
		lastA: ARRAY N+1 OF ADDRESS; block, last, next: HeapBlock;
	PROCEDURE Free();
	BEGIN
		lastp^.size := lastsize - 4;
		lastp^.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, SYSTEM.ADR(lastp^.size)) + free);
		i := lastsize DIV B;
		IF i > N THEN i := N END;
		lastp^.next := nil;
		SYSTEM.PUT(lastA[i], lastp);
		lastA[i] := SYSTEM.ADR(lastp^.next)
	END Free;
BEGIN
	i := 0; WHILE i <= N DO A[i] := nil; lastA[i] := SYSTEM.ADR(A[i]); INC(i) END;
	block := SYSTEM.VAL(HeapBlock, firstHeapBlock); last := NIL;
	WHILE block # NIL DO
		p := SYSTEM.VAL(Blockm4Ptr, block.firstBlock);
		end := SYSTEM.VAL(Blockm4Ptr, block.endBlock);
		lastsize := 0;
		WHILE p # end DO
			tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, p^.tag) - free);
			notmarked := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, tag) - mark);
			tdesc := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, notmarked) - array);
			IF notmarked # tdesc THEN (* array block *) size := p^.lastElemToMark + tdesc^.size - SYSTEM.VAL(ADDRESS, p)
			ELSE size := tdesc^.size + 4
			END;
			size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, size + B-1)-SYSTEM.VAL(SET, B-1));
			IF tag = notmarked THEN (* collect *)
				IF lastsize = 0 THEN lastp := SYSTEM.VAL(FreeBlockPtr, p) END;
				INC(lastsize, size)
			ELSE
				p^.tag := notmarked;
				IF lastsize > 0 THEN
					Free(); lastsize := 0
				END
			END;
			INC(SYSTEM.VAL(ADDRESS, p), size)
		END;
		(* last collected block: *)
		next := SYSTEM.VAL(HeapBlock, block.next);
		IF lastsize > 0 THEN
			IF (block.endBlock-block.firstBlock) = lastsize THEN
				ASSERT(block # SYSTEM.VAL(HeapBlock, SYSTEM.ADR(bootHeapBlockDesc)));
				IF last # NIL THEN
					last.next := SYSTEM.VAL(ADDRESS, next);
					IF next = NIL THEN maxHeapAdr := last.endBlock END
				ELSE
					firstHeapBlock := SYSTEM.VAL(ADDRESS, next);
					minHeapAdr := next.firstBlock
				END;
				Kernel32.VirtualFree(SYSTEM.VAL(ADDRESS, block), block.size, {Kernel32.MEMDecommit});
				Kernel32.VirtualFree(SYSTEM.VAL(ADDRESS, block), 0, {Kernel32.MEMRelease})
			ELSE
				Free(); last := block
			END
		ELSE
			last := block
		END;
		block := next
	END
END Sweep;

PROCEDURE CheckCandidates;	(* nofcand > 0 *)
	VAR i, j, h, p: LONGINT; block: Blockm4Ptr; tag, notmarked, tdesc: Tag; hblock: HeapBlock;
BEGIN
	(* first sort them in increasing order using shellsort *)
	h := 1; REPEAT h := h*3 + 1 UNTIL h > nofcand;
	REPEAT h := h DIV 3; i := h;
		WHILE i < nofcand DO p := candidates[i]; j := i;
			WHILE (j >= h) & (candidates[j-h] > p) DO
				candidates[j] := candidates[j-h]; j := j-h;
			END;
			candidates[j] := p; INC(i)
		END
	UNTIL h = 1;
	(* sweep phase *)
	hblock := SYSTEM.VAL(HeapBlock, firstHeapBlock);
	WHILE hblock # NIL DO
		block := SYSTEM.VAL(Blockm4Ptr, hblock.firstBlock);
		i := 0; p := candidates[i];
		LOOP
			IF p <= SYSTEM.VAL(ADDRESS, block) + 4 THEN
				IF p = SYSTEM.VAL(ADDRESS, block) + 4 THEN Mark(SYSTEM.VAL(BlockPtr, p)) END;
				INC(i);
				IF i = nofcand THEN EXIT END;
				p := candidates[i]
			ELSIF p <= SYSTEM.VAL(ADDRESS, block) + 28 THEN (* system block *)
				IF p = SYSTEM.VAL(ADDRESS, block) + 28 THEN Mark(SYSTEM.VAL(BlockPtr, SYSTEM.VAL(ADDRESS, block)+4)) END;
				INC(i);
				IF i = nofcand THEN EXIT END;
				p := candidates[i]
			ELSE
				tag := block^.tag;
				notmarked := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, tag) - (mark + free));
				tdesc := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, notmarked) - array);
				IF notmarked # tdesc THEN (* array block *) h := block^.lastElemToMark + tdesc^.size - SYSTEM.VAL(ADDRESS, block)
				ELSE h := tdesc^.size + 4
				END;
				INC(SYSTEM.VAL(ADDRESS, block), SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, h + B-1)-SYSTEM.VAL(SET, B-1)));
				IF block = SYSTEM.VAL(Blockm4Ptr, hblock.endBlock) THEN EXIT END
			END
		END;
		hblock := SYSTEM.VAL(HeapBlock, hblock.next)
	END;
	nofcand := 0
END CheckCandidates;

(** This must only be called from within CheckStacks up-call! *)
PROCEDURE Candidate*(p: LONGINT);
	VAR tag, tag0: LONGINT; block: HeapBlock;
BEGIN
	IF ((p MOD B) = 0) OR ((p MOD 16) = 8) & (p > minHeapAdr) & (p < maxHeapAdr) THEN
		block := SYSTEM.VAL(HeapBlock, firstHeapBlock);
		WHILE block # NIL DO
			IF (p > block.firstBlock) & (p < block.endBlock) THEN
				IF p MOD B = 0 THEN
					SYSTEM.GET(p-4, tag);
					IF tag MOD 8 IN {0, 2} THEN	(* array or record, not yet marked, not free *)
						candidates[nofcand] := p; INC(nofcand);
						IF nofcand = LEN(candidates) THEN CheckCandidates END
					END
				ELSIF p MOD 16 = 8 THEN	(* subobj *)
					SYSTEM.GET(p-4, tag);
					IF (tag MOD B = 0) & (tag > block.firstBlock) & (tag < block.endBlock) THEN
						SYSTEM.GET(tag-4, tag0);
						IF tag0 = tag THEN
							candidates[nofcand] := p; INC(nofcand);
							IF nofcand = LEN(candidates) THEN CheckCandidates END
						END
					END
				ELSE (* skip *)
				END
			END;
			block := SYSTEM.VAL(HeapBlock, block.next)
		END
	END
END Candidate;

PROCEDURE FinalizeObjs;
	VAR n, prev: FinObj;
BEGIN
	n := FinObjs;
	WHILE n # NIL DO
		IF ~n.marked THEN
			IF n = FinObjs THEN FinObjs := FinObjs.next ELSE prev.next := n.next END;
			n.fin(SYSTEM.VAL(SYSTEM.PTR, n.obj))	(* may ressurrect checked object *)
		ELSE prev := n
		END;
		n := n.next
	END
END FinalizeObjs;

(** GC - Immediately activate the garbage collector. *)

PROCEDURE ^NewSys(VAR p: ADDRESS; size: LONGINT);

PROCEDURE GC*;
	VAR m: Module; i, p, ptradr: LONGINT; ptr: BlockPtr;
BEGIN
	IF (GClevel > 0) & BeginAtomic() THEN
		m := modules;	(* ModuleDesc and ModuleBlock are marked via Kernel.modules *)
		WHILE m # NIL DO
			Mark(SYSTEM.VAL(BlockPtr, m));	(* the code, data etc. is marked via fields of m *)
			i := LEN(m.ptrTab); IF i > 0 THEN ptradr := SYSTEM.ADR(m.ptrTab[0]) END;
			WHILE i > 0 DO
				SYSTEM.GET(ptradr, p); SYSTEM.GET(p, ptr);
				IF ptr # NIL THEN Mark(ptr) END;
				DEC(i); INC(ptradr, 4)
			END;
			i := LEN(m.tdescs); IF i > 0 THEN ptradr := SYSTEM.ADR(m.tdescs[0]) END;
			WHILE i > 0 DO
				SYSTEM.GET(ptradr, ptr); Mark(ptr);
				DEC(i); INC(ptradr, 4)
			END;
			m := m^.next
		END;
			(* check stacks *)
		nofcand := 0; CheckStacks();
		IF nofcand > 0 THEN CheckCandidates END;
		CheckFinObjs;
		Sweep;
		FinalizeObjs;
		EndAtomic()
	END
END GC;

PROCEDURE NewHeapBlock(size: LONGINT);
	VAR adr: ADDRESS; alloc, s: LONGINT; block, p, q: HeapBlock; rest: FreeBlockPtr;
BEGIN
	IF size < HeapBlockSize THEN size := HeapBlockSize END;
	alloc := size + (-size MOD B) + B + 16;
	adr := Kernel32.VirtualAlloc(nil, alloc, {Kernel32.MEMCommit}, {Kernel32.PageExecuteReadWrite});
	ASSERT(adr > 0); ASSERT((adr MOD 4) = 0);
	block := SYSTEM.VAL(HeapBlock, adr);
	block.size := alloc;
	block.firstBlock := adr + 16;
	block.firstBlock := block.firstBlock + (-block.firstBlock-4) MOD B;
	ASSERT((block.firstBlock + 4) MOD B = 0);
	s := adr + alloc - block.firstBlock; s := s - s MOD B;
	block.endBlock := block.firstBlock + s;
	ASSERT((s MOD B = 0) & (s >= size));
	q := NIL; p := SYSTEM.VAL(HeapBlock, firstHeapBlock);
	WHILE (p # NIL) & (p.firstBlock < block.firstBlock) DO
		q := p; p := SYSTEM.VAL(HeapBlock, p.next)
	END;
	block.next := SYSTEM.VAL(ADDRESS, p);
	IF q # NIL THEN
		q.next := SYSTEM.VAL(ADDRESS, block);
		IF p = NIL THEN maxHeapAdr := block.endBlock END
	ELSE
		firstHeapBlock := SYSTEM.VAL(ADDRESS, block);
		minHeapAdr := block.firstBlock
	END;
	rest := SYSTEM.VAL(FreeBlockPtr, block.firstBlock);
	rest.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, SYSTEM.ADR(rest^.size)) + free);
	rest.size := block.endBlock-block.firstBlock-4;
	rest.next := A[N];
	A[N] := SYSTEM.VAL(ADDRESS, rest)
END NewHeapBlock;

PROCEDURE NewBlock(size: LONGINT): InitPtr;	(* size MOD B = 0 *)
	VAR i, rest: LONGINT; adr, AN: ADDRESS; ptr: InitPtr; restptr: FreeBlockPtr;
BEGIN
	IF size < 0 (* NEW(p, MAX(LONGINT)) *) THEN SYSTEM.HALT(14) END;
	Kernel32.EnterCriticalSection(moduleCS);
	i := size DIV B;
	IF i > N THEN i := N END;
	adr := SYSTEM.ADR(A[0]) + 4*i;
	AN := SYSTEM.ADR(A[N]);	(* constant register *)
	LOOP
		SYSTEM.GET(adr, ptr);
		IF adr = AN THEN
			LOOP
				IF ptr = NIL THEN
					IF (* (TrapHandlingLevel = 0) & *) firstTry THEN
						GC; firstTry := FALSE
					ELSE
						firstTry := TRUE;
						NewHeapBlock(size)
					END;
					ptr := NewBlock(size);
					Kernel32.LeaveCriticalSection(moduleCS);
					RETURN ptr
				END;
				IF ptr^.z0 + 4 >= size THEN EXIT END;
				adr := SYSTEM.ADR(ptr^.z1); SYSTEM.GET(adr, ptr)
			END;
			EXIT
		END;
		IF ptr # NIL THEN EXIT END;
		INC(adr, 4)
	END;
	(* ptr # NIL *)
	SYSTEM.PUT(adr, ptr^.z1);
	rest := ptr^.z0 + 4 - size;
	restptr := SYSTEM.VAL(FreeBlockPtr, SYSTEM.VAL(ADDRESS, ptr) + size);
	IF rest > 0 THEN	(* >= B >= 16 *)
		i := rest DIV B;
		IF i > N THEN i := N END;
		restptr^.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, SYSTEM.ADR(restptr^.size)) + free);
		restptr^.size := rest - 4;
		restptr^.next := A[i]; A[i] := SYSTEM.VAL(ADDRESS, restptr)
	END;
	Kernel32.LeaveCriticalSection(moduleCS);
	RETURN ptr
END NewBlock;

(* NewRec - Implementation of NEW.  Do not call directly. *)

PROCEDURE *NewRec(VAR p: ADDRESS; tag: Tag);	(* implementation of NEW(ptr) *)
	VAR size: LONGINT; ptr, init: InitPtr;
BEGIN (* tag^.size = rectyp^.size *)
	ASSERT(SYSTEM.VAL(LONGINT, tag) MOD 8 = 0);	(* no Oberon-X flags allowed *)
	IF tag = NIL THEN tag := SYSTEM.VAL(Tag, ptrElemTag) END;	(* descriptor for ARRAY * OF *)
	size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, tag^.size + (4 (*tag*) + B-1))-SYSTEM.VAL(SET, B-1));
	ptr := NewBlock(size);

	init := SYSTEM.VAL(InitPtr, SYSTEM.VAL(ADDRESS, ptr) + size - 32);
	init^.z0 := 0; init^.z1 := 0; init^.z2 := 0; init^.z3 := 0; init^.z4 := 0; init^.z5 := 0; init^.z6 := 0;
	WHILE init # ptr DO
		DEC(SYSTEM.VAL(ADDRESS, init), 32);
		init^.z0 := 0; init^.z1 := 0; init^.z2 := 0; init^.z3 := 0; init^.z4 := 0; init^.z5 := 0; init^.z6 := 0; init^.z7 := 0
	END;
	ptr^.tag := tag;
	p := SYSTEM.VAL(ADDRESS, ptr) + 4
END NewRec;

(* NewSys - Implementation of SYSTEM.NEW.  Do not call directly. *)

PROCEDURE *NewSys(VAR p: ADDRESS; size: LONGINT);
VAR ptr, init: InitPtr;
BEGIN
	size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, size + (28 + B-1))-SYSTEM.VAL(SET, B-1));
	ptr := NewBlock(size);
	init := SYSTEM.VAL(InitPtr, SYSTEM.VAL(ADDRESS, ptr) + size - 32);
	WHILE init # ptr DO
		init^.tag := NIL; init^.z0 := 0; init^.z1 := 0; init^.z2 := 0; init^.z3 := 0; init^.z4 := 0; init^.z5 := 0; init^.z6 := 0;
		DEC(SYSTEM.VAL(ADDRESS, init), 32);
	END;
	ptr^.tag := SYSTEM.VAL(Tag, SYSTEM.ADR(ptr^.z0));
	ptr^.z0 := size - 4;
	ptr^.z1 := -4;
	init^.z2 := 0;
	init^.z3 := 0;
	init^.z4 := 0;
	ptr^.z5 := SYSTEM.ADR(ptr^.z0);
	init^.z6 := 0;
	p := SYSTEM.VAL(ADDRESS, ptr) + 28
END NewSys;

(* NewArr - Implementation of NEW.  Do not call directly. *)

PROCEDURE *NewArr(VAR p: ADDRESS; eltag: Tag; nofelem, nofdim: LONGINT);
VAR size, firstElem, elSize, arrSize, vectSize: LONGINT; ptr, init: InitPtr;
BEGIN
	ASSERT(SYSTEM.VAL(LONGINT, eltag) MOD 4 = 0);
	IF eltag = NIL THEN
		eltag := SYSTEM.VAL(Tag, ptrElemTag)	(* array of pointer to *)
	END;
	elSize := eltag^.size;
	arrSize := nofelem*elSize;
	IF arrSize=0 THEN NewSys(p, nofdim*4+12); RETURN END;
	ASSERT(arrSize > 0);
	vectSize := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, 4*nofdim) + SYSTEM.VAL(SET, 4));	(* -> ADR(firstElem) MOD 8 = 0 *)
	IF eltag^.ptroff = -4 THEN (* no pointers in element type *)
		NewSys(p, arrSize + vectSize + 12);
		SYSTEM.PUT(p, SYSTEM.VAL(SET, arrSize + vectSize+15)-SYSTEM.VAL(SET, 3));
		RETURN
	END;
	size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, arrSize + vectSize + (16 + B-1))-SYSTEM.VAL(SET, B-1));
	ptr := NewBlock(size);
	init := SYSTEM.VAL(InitPtr, SYSTEM.VAL(ADDRESS, ptr) + size - 32);
	WHILE init # ptr DO
		init^.tag := NIL; init^.z0 := 0; init^.z1 := 0; init^.z2 := 0; init^.z3 := 0; init^.z4 := 0; init^.z5 := 0; init^.z6 := 0;
		DEC(SYSTEM.VAL(ADDRESS, init), 32);
	END;
	ptr^.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, eltag) + array);
	firstElem := SYSTEM.ADR(ptr^.z3) + vectSize;
	ptr^.z0 := firstElem + arrSize - elSize;
	(* ptr^.z1 is reserved for mark phase *)
	ptr^.z2 := firstElem;
	ptr^.z3 := 0; ptr^.z4 := 0; ptr^.z5 := 0; ptr^.z6 := 0;
	p := SYSTEM.VAL(ADDRESS, ptr) + 4
END NewArr;

(** RegisterObject - Register an object for finalization.  Never perform upcalls in the fin procedure! basic = FALSE *)

PROCEDURE RegisterObject*(obj: SYSTEM.PTR;  fin: Finalizer;  basic: BOOLEAN);
	VAR n: FinObj;
BEGIN
	ASSERT(obj # NIL);
	Kernel32.EnterCriticalSection(moduleCS);
	NEW(n); n.obj := SYSTEM.VAL(ADDRESS, obj); n.fin := fin;
	n.marked := FALSE; n.basic := basic;
	n.next := FinObjs; FinObjs := n;
	Kernel32.LeaveCriticalSection(moduleCS)
END RegisterObject;

(** InstallTermHandler - Install a procedure to execute when a module is freed.  Normally used to uninstall interrupt handlers or tasks and perform other cleanup duties.  Never perform upcalls in proc, because the upcalled module will no longer be in memory! *)

PROCEDURE InstallTermHandler*(h: Proc);	(* can also be used by modules below Modules, e.g. FileDir *)
	VAR codebase, handlerAdr: LONGINT; m: Module; found: BOOLEAN;
BEGIN
	Kernel32.EnterCriticalSection(moduleCS);
	m := modules; handlerAdr := SYSTEM.VAL(LONGINT, h); found := FALSE;
	WHILE (m # NIL) & ~found DO
		codebase := SYSTEM.ADR(m.code[0]);
		IF (codebase <= handlerAdr) & (handlerAdr <= codebase + LEN(m.code)) THEN found := TRUE
		ELSE m := m.next
		END
	END;
	IF found THEN m.term := h END;
	Kernel32.LeaveCriticalSection(moduleCS)
END InstallTermHandler;

(** FinalizeModule - Execute all object finalizers registered by a module, and then execute its termination handler. *)

PROCEDURE FinalizeModuleObjs(m: Module; basic: BOOLEAN);
VAR h: Proc;  beg, end: LONGINT;  n, prev: FinObj;
BEGIN
	beg := SYSTEM.ADR(m.code[0]);  end := beg + LEN(m.code);
	n := FinObjs;
	WHILE n # NIL DO
		IF (n.basic = basic) & (beg <= SYSTEM.VAL(LONGINT, n.fin)) & (SYSTEM.VAL(LONGINT, n.fin) <= end) THEN
			IF n = FinObjs THEN FinObjs := FinObjs.next ELSE prev.next := n.next END;
			n.fin(SYSTEM.VAL(SYSTEM.PTR, n.obj))
		ELSE prev := n
		END;
		n := n.next
	END
END FinalizeModuleObjs;

PROCEDURE FinalizeModule*(m: Module);
	VAR h: Proc;
BEGIN
	FinalizeModuleObjs(m, FALSE);
	IF m.term # NIL THEN
		h := m.term; m.term := NIL; h
	END;
	FinalizeModuleObjs(m, TRUE)
END FinalizeModule;

PROCEDURE InitHeap;	(* heapTop, pageheap and modules already initialized *)
	VAR
		i, t, size: LONGINT; m: Module;
		td: POINTER TO RECORD filler: ARRAY 4 OF LONGINT; name: Name END;
		low0: ADDRESS; c: CHAR; p: Blockm4Ptr; tag, tdesc: Tag;
BEGIN
	m := modules; WHILE m.name # "Kernel" DO m := m.next END;
	i := LEN(m.tdescs); ptrElemTag := 0;
	REPEAT
		DEC(i); t := m.tdescs[i]; SYSTEM.GET(t - 4, td);
		IF td.name = "PtrElemDesc" THEN ptrElemTag := t END
	UNTIL (ptrElemTag # 0);

	SYSTEM.GET(bootHeapAdr+16H, low0);	(* patched by Linker *)
	ASSERT(low0 MOD B = B-4);	(* check if linker aligned correctly *)
	bootHeapBlockDesc.firstBlock := bootHeapAdr+03CH;
	ASSERT(bootHeapBlockDesc.firstBlock > 0);
	bootHeapBlockDesc.endBlock := low0;
	ASSERT(bootHeapBlockDesc.endBlock > 0);
	bootHeapBlockDesc.size := bootHeapSize;
	bootHeapBlockDesc.next := nil;
	firstHeapBlock := SYSTEM.ADR(bootHeapBlockDesc);
	minHeapAdr := bootHeapBlockDesc.firstBlock; maxHeapAdr := bootHeapBlockDesc.endBlock;
	(* find last block in Linker-generated heap (p^.tag will be NIL because of SYSTEM.PUT(low0, LONG(LONG(0))); above) *)
	p := SYSTEM.VAL(Blockm4Ptr, bootHeapBlockDesc.firstBlock);
	WHILE p^.tag # NIL DO
		tag := p^.tag;
		initres := SYSTEM.VAL(InitPtr, SYSTEM.VAL(ADDRESS, p)+(4+24));
		tdesc := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, tag) - array - mark);
		IF array * SYSTEM.VAL(SET, tag) # {} THEN (* array block *)
			size := p^.lastElemToMark + tdesc^.size - SYSTEM.VAL(ADDRESS, p)
		ELSE
			size := tdesc^.size + 4
		END;
		size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, size + B-1)-SYSTEM.VAL(SET, B-1));
		INC(SYSTEM.VAL(ADDRESS, p), size)
	END;
	SYSTEM.GET(initres, c);  ASSERT(c = 0E8X);	(* call to first module body *)
	(* now initres points to last block, i.e. the init calls - they won't be GC'ed *)
	i := 0; WHILE i <= N DO A[i] := nil; INC(i) END;
	nofcand := 0; firstTry := TRUE; FinObjs := NIL; GClevel := 0;
	CheckStacks := NIL; BeginAtomic := NIL; EndAtomic := NIL
END InitHeap;

(** Shutdown - Terminate Oberon after executing all module terminators.  *)

PROCEDURE Shutdown*(code: LONGINT);
	VAR m: Module; block, next: HeapBlock;
BEGIN
	ASSERT(lock <= 0);
	IF lock = MIN(LONGINT) THEN RETURN END;
	lock :=  MIN(LONGINT);
	Kernel32.EnterCriticalSection(moduleCS);
	m := modules;
	WHILE m # NIL DO
		FinalizeModuleObjs(m, FALSE); m := m.next
	END;
	m := modules;
	WHILE m # NIL DO
		FinalizeModule(m); m := m.next
	END;
	GClevel := MIN(LONGINT) DIV 2;
	CheckStacks := NIL; BeginAtomic := NIL; EndAtomic := NIL;
	Kernel32.LeaveCriticalSection(moduleCS);
	Kernel32.DeleteCriticalSection(moduleCS);
Kernel32.Str("Oberon.Exit"); Kernel32.Ln();
	IF ~isEXE THEN
Kernel32.Str("Kernel.Shutdown releasing heap"); Kernel32.Ln();
		block := SYSTEM.VAL(HeapBlock, firstHeapBlock);
		WHILE block # NIL DO
			next := SYSTEM.VAL(HeapBlock, block.next);
			IF block # SYSTEM.VAL(HeapBlock, SYSTEM.ADR(bootHeapBlockDesc)) THEN
				Kernel32.VirtualFree(SYSTEM.VAL(ADDRESS, block), block.size, {Kernel32.MEMDecommit});
				Kernel32.VirtualFree(SYSTEM.VAL(ADDRESS, block), 0, {Kernel32.MEMRelease})
			END;
			block := next
		END
	ELSE
		Kernel32.ExitProcess(code)
	END
END Shutdown;

(* InitRuntime - Initialise runtime support. *)

PROCEDURE InitRuntime;
	VAR
		newRec: PROCEDURE(VAR p: ADDRESS;  tag: Tag);
		newSys: PROCEDURE(VAR p: ADDRESS;  size: LONGINT);
		newArr: PROCEDURE(VAR p: ADDRESS;  eltag: Tag;  nofelem, nofdim: LONGINT);
BEGIN
	newRec := NewRec;	(* used in Modules and Types *)
	newSys := NewSys;
	newArr := NewArr;
	runtime[0] := SYSTEM.VAL(ADDRESS, newRec);	(* 253 *)
	runtime[1] := SYSTEM.VAL(ADDRESS, newSys);	(* 252 *)
	runtime[2] := SYSTEM.VAL(ADDRESS, newArr)	(* 251 *)
END InitRuntime;

BEGIN
	Kernel32.Shutdown := Shutdown;
	Kernel32.Str("Kernel.modules "); Kernel32.Hex(SYSTEM.ADR(modules)); Kernel32.Ln();
	lock := 0;
	IF hInstance = Kernel32.NULL THEN (* from exe file *)
		hInstance := Kernel32.GetModuleHandle(NIL); isEXE := TRUE
	ELSE
		isEXE := FALSE
	END;
	version := "Win32 2.4 (14.5.2001)";
	Kernel32.InitializeCriticalSection(moduleCS);
	InitHeap; InitRuntime
END Kernel.
