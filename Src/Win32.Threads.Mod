(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Threads; (** non-portable / source: Win32.Threads.Mod *)	(* ejz,  *)
	IMPORT SYSTEM, Kernel32, Kernel, Modules, Reals;

	CONST
(** Priority levels used by GetPriority & SetPriority *)
		Low* = Kernel32.ThreadPriorityBelowNormal;
		Normal* = Kernel32.ThreadPriorityNormal;
		High* = Kernel32.ThreadPriorityAboveNormal;
		Infinite* = Kernel32.Infinite; (** see Wait *)

	TYPE
(** Thread descriptor, used to store thread information. *)
		BodyProc* = Modules.Command; (** Thread body procedure. *)
		Thread* = POINTER TO RECORD (Kernel32.Object)
			id, prio, GCCount: LONGINT;
			stackBottom*: Kernel32.ADDRESS;
			name*: ARRAY 64 OF CHAR; (** Name of thread. *)
			proc: BodyProc;
			next: Thread;
			cont: Kernel32.Context;
			atomic, first: BOOLEAN;
			safe*: BOOLEAN (** Restart the thread after a trap. *)
		END;

		RegThread = POINTER TO RECORD (Thread)
			refCount: LONGINT
		END;

(** Threads enumerator *)
		EnumProc* = PROCEDURE (t: Thread);

(** Base type for critical section objects. *)
		Mutex* = POINTER TO RECORD
			cs: Kernel32.CriticalSection;
			next[UNTRACED]: Mutex;
			id, count-: LONGINT
		END;

(** Base type for events *)
		Event* = POINTER TO RECORD (Kernel32.Object) END;

	VAR
		threads, aliens: Thread;
		mtxs: Mutex;
		oberonLoop*: Thread; (** thread executing Oberon.Loop *)
		threaded: BOOLEAN;
		moduleCS: Kernel32.CriticalSection;
		break: ARRAY 16 OF CHAR;

(** Wait for ownership of the mutex. *)
	PROCEDURE Lock*(mtx: Mutex);
	BEGIN
		ASSERT(threaded);
		Kernel32.EnterCriticalSection(mtx.cs);
		IF mtx.count <= 0 THEN mtx.id := Kernel32.GetCurrentThreadId() END;
		INC(mtx.count)
	END Lock;

(** Release ownership of the mutex. *)
	PROCEDURE Unlock*(mtx: Mutex);
	BEGIN
		ASSERT(threaded);
		DEC(mtx.count);
		IF mtx.count <= 0 THEN mtx.id := 0 END;
		Kernel32.LeaveCriticalSection(mtx.cs)
	END Unlock;

(** Try to take ownership of the mutex without blocking. *)
	PROCEDURE TryLock*(mtx: Mutex): BOOLEAN;
		VAR id: LONGINT; ret: Kernel32.BOOL;
	BEGIN
		ASSERT(threaded);
		IF Kernel32.TryEnterCriticalSection # NIL THEN
			ret := Kernel32.TryEnterCriticalSection(mtx.cs);
			IF ret = Kernel32.False THEN RETURN FALSE END
		ELSE
			id := Kernel32.GetCurrentThreadId();
			IF (mtx.count > 0) & (mtx.id # id) THEN
				RETURN FALSE
			ELSE
				Kernel32.EnterCriticalSection(mtx.cs)
			END
		END;
		IF mtx.count <= 0 THEN mtx.id := Kernel32.GetCurrentThreadId() END;
		INC(mtx.count);
		RETURN TRUE
	END TryLock;

	PROCEDURE *FinalizeMutex(mtx: PTR);
		VAR mx: Mutex;
	BEGIN
		WITH mtx: Mutex DO
			mx := mtxs;
			WHILE (mx # NIL) & (mx.next # mtx) DO
				mx := mx.next
			END;
			IF mx # NIL THEN
				mx.next := mtx.next
			ELSIF mtx = mtxs THEN
				mtxs := mtx.next
			ELSE
				HALT(99)
			END;
			Kernel32.DeleteCriticalSection(mtx.cs)
		END
	END FinalizeMutex;

(** Initialize a new mutex. *)
	PROCEDURE Init*(mtx: Mutex);
		VAR mx: Mutex;
	BEGIN
		mx := mtxs;
		WHILE (mx # NIL) & (mx # mtx) DO
			mx := mx.next
		END;
		IF mx = NIL THEN
			Kernel32.EnterCriticalSection(moduleCS);
			mtx.next := mtxs; mtxs := mtx;
			Kernel32.LeaveCriticalSection(moduleCS);
			mtx.id := 0; mtx.count := 0;
			Kernel32.InitializeCriticalSection(mtx.cs);
			Kernel.RegisterObject(mtx, FinalizeMutex, TRUE)
		ELSE
			HALT(99)
		END
	END Init;

(** Set an event *)
	PROCEDURE Set*(event: Event);
	BEGIN
		Kernel32.SetEvent(event.handle)
	END Set;

(** Reset an event *)
	PROCEDURE Reset*(event: Event);
	BEGIN
		Kernel32.ResetEvent(event.handle)
	END Reset;

	PROCEDURE *FinalizeEvent(event: PTR);
	BEGIN
		WITH event: Event DO
			IF event.handle # Kernel32.InvalidHandleValue THEN
				Kernel32.CloseHandle(event.handle); event.handle := Kernel32.InvalidHandleValue
			END
		END
	END FinalizeEvent;

(** Initialize a new event *)
	PROCEDURE Create*(event: Event);
	BEGIN
		event.handle := Kernel32.CreateEvent(NIL, Kernel32.False, Kernel32.False, NIL);
		Kernel.RegisterObject(event, FinalizeEvent, TRUE)
	END Create;

(** Wait for an event or kernel object to be signaled for at most timeOut milliseconds. *)
	PROCEDURE Wait*(event: Kernel32.Object; timeOut: LONGINT): BOOLEAN;
	BEGIN
		 RETURN Kernel32.WaitForSingleObject(event.handle, timeOut) # Kernel32.WaitTimeout
	END Wait;

	PROCEDURE this(): Thread;
		VAR id: LONGINT; t: Thread;
	BEGIN
		id := Kernel32.GetCurrentThreadId();
		t := threads;
		WHILE (t # NIL) & (t.id # id) DO
			t := t.next
		END;
		RETURN t
	END this;

(** Get the current thread beeing processed. *)
	PROCEDURE This*(): Thread;
		VAR t: Thread;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		t := this();
		Kernel32.LeaveCriticalSection(moduleCS);
		RETURN t
	END This;

	PROCEDURE *FinalizeThread(t: PTR);
	BEGIN
		WITH t: Thread DO
			IF t.handle # Kernel32.InvalidHandleValue THEN
				Kernel32.CloseHandle(t.handle); t.handle := Kernel32.InvalidHandleValue
			END
		END
	END FinalizeThread;

	PROCEDURE FindStackBottom(t: Thread);
		VAR bp, lastbp: LONGINT;
	BEGIN
		bp := t.cont.Ebp;
		LOOP
			lastbp := bp;
			SYSTEM.GET(bp, bp); (* return addr from stack *)
			IF (bp <= lastbp) OR ((bp MOD 4) # 0) OR ((bp-lastbp) > 1024*1024) THEN (* invalid stack frame *)
				EXIT
			END
		END;
		t.stackBottom := lastbp
	END FindStackBottom;

(** Register the calling thread as non-Oberon thread. *)
	PROCEDURE Register*(name: ARRAY OF CHAR): Thread;
		VAR proc: Kernel32.HANDLE; t: Thread; r: RegThread; ret: Kernel32.BOOL;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		DEC(Kernel.GClevel);
		t := this();
		IF t = NIL THEN
			NEW(r); t := r; r.refCount := 1;
			t.id := Kernel32.GetCurrentThreadId(); t.handle := Kernel32.GetCurrentThread();
			t.prio := Kernel32.GetThreadPriority(t.handle); t.proc := NIL; (* unknown *)
			t.atomic := FALSE; t.first := FALSE; t.GCCount := 0; t.safe := FALSE;
			COPY(name, t.name);
			proc := Kernel32.GetCurrentProcess();
			ret := Kernel32.DuplicateHandle(proc, t.handle, proc, t.handle, {}, Kernel32.False, {Kernel32.DuplicateSameAccess});
			ASSERT(ret # Kernel32.False);
			t.cont.ContextFlags := Kernel32.ContextFull;
			ret := Kernel32.GetThreadContext(t.handle, t.cont); ASSERT(ret # Kernel32.False);
			FindStackBottom(t);
			t.next := threads; threads := t;
			Kernel.RegisterObject(t, FinalizeThread, TRUE)
		ELSIF t IS RegThread THEN
			r := t(RegThread); INC(r.refCount)
		END;
		INC(Kernel.GClevel);
		Kernel32.LeaveCriticalSection(moduleCS);
		RETURN t
	END Register;

(** Unregister a thread previously registered with Register. *)
	PROCEDURE Unregister*(t: Thread);
		VAR pt: Thread;
	BEGIN
		IF (t = NIL) OR ~(t IS RegThread) THEN RETURN END;
		WITH t: RegThread DO
			Kernel32.EnterCriticalSection(moduleCS);
			DEC(t.refCount);
			IF t.refCount <= 0 THEN
				pt := threads;
				WHILE (pt # NIL) & (pt.next # t) DO
					pt := pt.next
				END;
				IF pt # NIL THEN
					pt.next := t.next
				ELSIF t = threads THEN
					threads := t.next
				ELSE
					HALT(99)
				END;
				FinalizeThread(t)
			END;
			Kernel32.LeaveCriticalSection(moduleCS)
		END
	END Unregister;

	PROCEDURE Cleanup(t: Thread);
		VAR mx: Mutex;
	BEGIN
		ASSERT(t.id = Kernel32.GetCurrentThreadId());
		IF t.atomic THEN Kernel.EndAtomic() END;
		mx := mtxs;
		WHILE mx # NIL DO
			IF mx.id = t.id THEN
				WHILE mx.count > 0 DO Unlock(mx) END
			END;
			mx := mx.next
		END;
		WHILE t.GCCount > 0 DO
			DEC(t.GCCount); INC(Kernel.GClevel)
		END
	END Cleanup;

	PROCEDURE ^Start*(t: Thread; p: BodyProc; stackLen: LONGINT);

	PROCEDURE kill(t: Thread; safe: BOOLEAN);
		VAR pt: Thread;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		pt := threads;
		WHILE (pt # NIL) & (pt.next # t) DO
			pt := pt.next
		END;
		IF pt # NIL THEN
			pt.next := t.next
		ELSIF t = threads THEN
			threads := t.next
		ELSE
			HALT(99)
		END;
		IF t.id # Kernel32.GetCurrentThreadId() THEN
			Kernel32.SuspendThread(t.handle);
			t.next := aliens; aliens := t;
			Kernel32.LeaveCriticalSection(moduleCS);
			Kernel32.SetThreadContext(t.handle, t.cont);
			Kernel32.ResumeThread(t.handle)
		ELSE (* Stop(self) *)
			Cleanup(t); FinalizeThread(t);
			Kernel32.LeaveCriticalSection(moduleCS);
			IF t.safe & safe THEN Start(t, t.proc, 0) END;
			Kernel32.ExitThread(0)
		END
	END kill;

(** Stop execution of thread t. *)
	PROCEDURE Kill*(t: Thread);
	BEGIN
		kill(t, FALSE)
	END Kill;

(** Stop execution of thread t after a trap. *)
	PROCEDURE Abort*(t: Thread);
	BEGIN
		kill(t, TRUE)
	END Abort;

	PROCEDURE [WINAPI] *ExcpFrmHandler(VAR excpRec: Kernel32.ExceptionRecord; excpFrame: Kernel32.ExcpFrmPtr; VAR context: Kernel32.Context; dispatch: LONGINT): LONGINT;
		VAR t: Thread; ret: LONGINT;
	BEGIN
		DEC(Kernel.GClevel); t := this();
		ret := Kernel32.excpFrmHandler(excpRec, excpFrame, context, dispatch);
		IF ret = Kernel32.ExceptionExecuteHandler THEN
			IF t # NIL THEN
				INC(Kernel.GClevel);
				Abort(t);
				RETURN ret
			ELSE
				Kernel32.Str("Threads.ExcpFrmHandler: failing thread not found!!!"); Kernel32.Ln()
			END
		END;
		INC(Kernel.GClevel);
		RETURN ret
	END ExcpFrmHandler;

	PROCEDURE SafeForBreak(mod: Modules.Module): BOOLEAN;
	BEGIN
		Kernel32.Str("Threads.SafeForBreak: ");
		IF mod # NIL THEN
			Kernel32.Str(mod.name); Kernel32.Ln();
			IF (mod.name = "Kernel") OR (mod.name = "FileDir") OR (mod.name = "Files") OR (mod.name = "Modules") OR (mod.name = "Threads") THEN
				RETURN FALSE
			ELSE
				RETURN TRUE
			END
		ELSE
			Kernel32.Str("module not found"); Kernel32.Ln();
			RETURN FALSE
		END
	END SafeForBreak;

(** *)
	PROCEDURE Break*(t: Thread); (* not reentrant / global break code *)
		CONST MaxTry = 50;
		VAR cont: Kernel32.Context; mod: Modules.Module; try: LONGINT;
	BEGIN
		IF This() # t THEN
			Kernel32.EnterCriticalSection(moduleCS);
			try := 0;
			LOOP
				DEC(Kernel.GClevel);
				Kernel32.SuspendThread(t.handle);
				cont.ContextFlags := Kernel32.ContextControl; Kernel32.GetThreadContext(t.handle, cont);
				mod := Kernel.GetMod(cont.Eip);
				IF ~SafeForBreak(mod) THEN
					Kernel32.ResumeThread(t.handle);
					INC(Kernel.GClevel); INC(try);
					IF try > MaxTry THEN
						Kernel32.Str("Threads.Break: failed"); Kernel32.Ln();
						Kernel32.LeaveCriticalSection(moduleCS);
						RETURN
					END
				ELSE
					EXIT
				END
			END;
			(* push cont.Eip *) break[0] := 68X; SYSTEM.MOVE(SYSTEM.ADR(cont.Eip), SYSTEM.ADR(break[1]), 4);
			(* push ebp *) break[5] := 055X;
			(* mov ebp, esp *) break[6] := 08BX; break[7] := 0ECX;
			(* push 13 *) break[8] := 06AX; break[9] := 0DX;
			(* int 3 *) break[10] := 0CCX;
			(* mov esp, ebp *) break[11] := 08BX; break[12] := 0E5X;
			(* pop ebp *) break[13] := 05DX;
			(* ret *) break[14] := 0C3X;
			cont.Eip := SYSTEM.ADR(break[0]);
			Kernel32.SetThreadContext(t.handle, cont);
			Kernel32.ResumeThread(t.handle);
			INC(Kernel.GClevel);
			Kernel32.LeaveCriticalSection(moduleCS)
		ELSE
			HALT(99)
		END
	END Break;

	PROCEDURE [WINAPI] *Wrapper(par: LONGINT): LONGINT;
		VAR
			excp: Kernel32.ExcpFrm;
			pt, t: Thread;
			id: LONGINT;
			wrapper: Kernel32.ThreadStartRoutine;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		id := Kernel32.GetCurrentThreadId();
		t := threads;
		WHILE (t # NIL) & (t.id # id) DO
			t := t.next
		END;
		Kernel32.LeaveCriticalSection(moduleCS);
		IF (t # NIL) & t.first THEN
			t.first := FALSE; wrapper := Wrapper;
			SYSTEM.GETREG(SYSTEM.ESP, t.stackBottom);
			t.cont.ContextFlags := Kernel32.ContextFull;
			Kernel32.GetThreadContext(t.handle, t.cont);
			t.cont.Eip := SYSTEM.VAL(LONGINT, wrapper);
			Kernel32.SetThreadPriority(t.handle, Normal); t.prio := Normal;
			excp.handler := ExcpFrmHandler; excp.link := Kernel32.NULL;
			Kernel32.InstallExcpFrm(excp);
			Reals.SetFCR(Reals.DefaultFCR);
			t.proc(); Kill(t)
		ELSE
			ASSERT(t = NIL);
			Kernel32.EnterCriticalSection(moduleCS);
			pt := NIL; t := aliens;
			WHILE (t # NIL) & (t.id # id) DO
				pt := t; t := t.next
			END;
			ASSERT(t # NIL);
			Cleanup(t);
			IF pt # NIL THEN
				pt.next := t.next
			ELSIF aliens = t THEN
				aliens := t.next
			END;
			Kernel32.LeaveCriticalSection(moduleCS);
			Kernel32.ExitThread(0)
		END
	END Wrapper;

(** Start a new thread executing p. *)
	PROCEDURE Start*(t: Thread; p: BodyProc; stackLen: LONGINT);
		VAR pt, tt: Thread;
	BEGIN
		ASSERT(threaded & (p # NIL) & (t # NIL), 32);
		Kernel32.EnterCriticalSection(moduleCS);
		pt := NIL; tt := threads;
		WHILE (tt # NIL) & (tt # t) DO
			pt := tt; tt := tt.next
		END;
		IF tt = t THEN
			Kernel32.LeaveCriticalSection(moduleCS);
			HALT(99)
		ELSIF pt # NIL THEN
			pt.next := t
		ELSE
			threads := t
		END;
		Kernel.RegisterObject(t, FinalizeThread, TRUE);
		t.next := NIL; t.proc := p; t.handle := Kernel32.InvalidHandleValue; t.id := 0;
		t.stackBottom := Kernel32.NULL; t.atomic := FALSE; t.first := TRUE; t.GCCount := 0;
		t.handle := Kernel32.CreateThread(NIL, stackLen, Wrapper, 0, 0, t.id);
		Kernel32.LeaveCriticalSection(moduleCS);
		ASSERT(t.handle # Kernel32.InvalidHandleValue, 33)
	END Start;

(** Enumerate all threads. *)
	PROCEDURE Enumerate*(p: EnumProc);
		VAR t: Thread;
	BEGIN
		ASSERT(p # NIL);
		Kernel32.EnterCriticalSection(moduleCS);
		t := threads;
		WHILE t # NIL DO
			p(t); t := t.next
		END;
		Kernel32.LeaveCriticalSection(moduleCS)
	END Enumerate;

(** Suspend execution of thread t. *)
	PROCEDURE Suspend*(t: Thread);
	BEGIN
		 Kernel32.SuspendThread(t.handle)
	END Suspend;

(** Resume execution of thread t. *)
	PROCEDURE Resume*(t: Thread);
	BEGIN
		Kernel32.ResumeThread(t.handle)
	END Resume;

(** Change the priority of thread t to prio. *)
	PROCEDURE SetPriority*(t: Thread; prio: LONGINT);
	BEGIN
		Kernel32.SetThreadPriority(t.handle, prio); t.prio := prio
	END SetPriority;

(** Get the priority for thread t. *)
	PROCEDURE GetPriority*(t: Thread; VAR prio: LONGINT);
	BEGIN
		t.prio := Kernel32.GetThreadPriority(t.handle); prio := t.prio
	END GetPriority;

(** Set the calling thread to sleep for the specified amount of milliseconds. *)
	PROCEDURE Sleep*(ms: LONGINT);
	BEGIN
		Kernel32.Sleep(ms)
	END Sleep;

(** Pass control to the next ready thread. *)
	PROCEDURE Pass*();
	BEGIN
		Kernel32.Sleep(0)
	END Pass;

	PROCEDURE EnableGC*();
		VAR t: Thread;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		t := this();
		IF t # NIL THEN DEC(t.GCCount) END;
		INC(Kernel.GClevel);
		Kernel32.LeaveCriticalSection(moduleCS)
	END EnableGC;

	PROCEDURE DisableGC*();
		VAR t: Thread;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		t := this();
		IF t # NIL THEN INC(t.GCCount) END;
		DEC(Kernel.GClevel);
		Kernel32.LeaveCriticalSection(moduleCS)
	END DisableGC;

(** Start non-interruptable section *)
	PROCEDURE BeginAtomic*(): BOOLEAN;
		VAR t, tt: Thread;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		tt := this();
		IF tt # NIL THEN
			ASSERT(threaded & ~tt.atomic, 34);
			t := threads;
			WHILE t # NIL DO
				IF t # tt THEN
					ASSERT(~t.atomic, 35);
					Kernel32.SuspendThread(t.handle)
				END;
				t := t.next
			END;
			tt.atomic := TRUE;
			RETURN TRUE
		ELSE
			Kernel32.LeaveCriticalSection(moduleCS);
			RETURN FALSE
		END
	END BeginAtomic;

(** End non-interruptable section *)
	PROCEDURE EndAtomic*();
		VAR t, tt: Thread;
	BEGIN
		tt := this();
		ASSERT(threaded & tt.atomic, 36);
		t := threads;
		WHILE t # NIL DO
			IF t # tt THEN
				ASSERT(~t.atomic, 37);
				Kernel32.ResumeThread(t.handle)
			END;
			t := t.next
		END;
		tt.atomic := FALSE;
		Kernel32.LeaveCriticalSection(moduleCS)
	END EndAtomic;

	PROCEDURE *CheckStacks();
		VAR
			t: Thread; cont: Kernel32.Context;
			sp, p, bottom: Kernel32.ADDRESS;
	BEGIN
		t := threads;
		WHILE t # NIL DO
			cont.ContextFlags := Kernel32.ContextControl + Kernel32.ContextInteger;
			Kernel32.GetThreadContext(t.handle, cont);
			Kernel.Candidate(cont.Edi); Kernel.Candidate(cont.Esi);
			Kernel.Candidate(cont.Ebx); Kernel.Candidate(cont.Edx);
			Kernel.Candidate(cont.Ecx); Kernel.Candidate(cont.Eax);
			sp := cont.Esp;
			IF cont.Ebp > t.stackBottom THEN
				t.stackBottom := cont.Ebp
			END;
			bottom := t.stackBottom;
			WHILE sp < bottom DO
				SYSTEM.GET(sp, p);
				Kernel.Candidate(p);
				INC(sp, 4)
			END;
			t := t.next
		END
	END CheckStacks;

	PROCEDURE *Shutdown();
		VAR tt, t: Thread;
	BEGIN
		Kernel32.EnterCriticalSection(moduleCS);
		threaded := FALSE; oberonLoop := NIL;
		tt := this(); t := threads;
		WHILE t # NIL DO
			IF (t # tt) & ((t IS RegThread) OR (Kernel32.TerminateThread(t.handle, 0) # Kernel32.False)) THEN
				FinalizeThread(t)
			END;
			t := t.next
		END;
		Kernel32.LeaveCriticalSection(moduleCS);
		Kernel32.DeleteCriticalSection(moduleCS)
	END Shutdown;

	PROCEDURE init();
	BEGIN
		Kernel32.InitializeCriticalSection(moduleCS);
		Kernel32.EnterCriticalSection(moduleCS);
		threads := NIL; aliens := NIL; oberonLoop := NIL; threaded := FALSE; mtxs := NIL;
		Kernel.CheckStacks := CheckStacks; Kernel.BeginAtomic := BeginAtomic; Kernel.EndAtomic := EndAtomic;
		threaded := TRUE; INC(Kernel.GClevel); (* enable GC *)
		Modules.InstallTermHandler(Shutdown);
		Kernel32.LeaveCriticalSection(moduleCS)
	END init;

BEGIN
	init()
END Threads.
