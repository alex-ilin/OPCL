(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Exceptions; (** non-portable / source: Win32.Exceptions.Mod *)	(* ejz *)
	IMPORT SYSTEM, Kernel32, Kernel, Modules, Types, Strings, Threads;

	CONST
		Ignore* = 0; Forward* = 1; Abort* = 2; CallFail = 3;

	TYPE
		Exception* = RECORD (Kernel32.Exception)
			t*: Threads.Thread
		END;

		SysException* = RECORD (Exception)
		END;

		UserException* = RECORD (Exception)
		END;

		Handler = PROCEDURE (VAR e: Exception): LONGINT;
		LocalHandler = PROCEDURE (ebp: LONGINT; VAR e: Exception): LONGINT;

		ContextPtr = POINTER TO Context;
		Context* = RECORD
			data: ARRAY 12 OF CHAR
		END;

		Bytes = POINTER TO ARRAY OF CHAR;

	VAR
		moduleCS: Threads.Mutex;
		displayTrap*: PROCEDURE (VAR e: Exception);
		theContext[UNTRACED]: ContextPtr;
		inDispatch: BOOLEAN;

	PROCEDURE GetDescription*(VAR e: Exception; VAR desc: ARRAY OF CHAR);
		VAR bp, code: LONGINT; type: Types.Type; arg: ARRAY 16 OF CHAR;
	BEGIN
		IF e IS SysException THEN
			IF e.exc.ExceptionCode = Kernel32.ExceptionGuardPage THEN
				COPY("guard page violation", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionBreakPoint THEN
				SYSTEM.GET(e.cont.Esp, code);
				Strings.IntToStr(code, desc); Strings.Append(desc, "  ");
				IF code = 1 THEN
					Strings.Append(desc, "WITH guard failed")
				ELSIF code = 2 THEN
					Strings.Append(desc, "CASE invalid")
				ELSIF code = 3 THEN
					Strings.Append(desc, "RETURN missing")
				ELSIF code = 5 THEN
					Strings.Append(desc, "Implicit type guard failed")
				ELSIF code = 6 THEN
					Strings.Append(desc, "Type guard failed")
				ELSIF code = 7 THEN
					Strings.Append(desc, "Index out of range")
				ELSIF code = 8 THEN
					Strings.Append(desc, "ASSERT failed")
				ELSIF code = 9 THEN
					Strings.Append(desc, "Array dimension error")
				ELSIF code = 13 THEN
					Strings.Append(desc, "Keyboard interrupt")
				ELSIF code = 14 THEN
					Strings.Append(desc, "Out of memory")
				ELSIF code = 23 THEN
					Strings.Append(desc, "Exceptions.Raise")
				ELSE
					Strings.Append(desc, "HALT statement")
				END
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionSingleStep THEN
				COPY("single step", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionAccessViolation THEN
				COPY("access violation", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionIllegalInstruction THEN
				COPY("illegal instruction", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionArrayBoundsExceeded THEN
				COPY("index out of range", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionFltDenormalOperand THEN
				COPY("FPU: denormal operand", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionFltDivideByZero THEN
				COPY("FPU: divide by zero", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionFltInexactResult THEN
				COPY("FPU: inexact result", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionFltInvalidOperation THEN
				COPY("FPU: invalid operation", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionFltOverflow THEN
				COPY("FPU: overflow", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionFltStackCheck THEN
				COPY("FPU: stack check", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionFltUndeflow THEN
				COPY("FPU: undeflow", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionIntDivideByZero THEN
				COPY("integer division by zero", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionIntOverflow THEN
				COPY("integer overflow", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionPrivInstruction THEN
				COPY("privileged instruction", desc)
			ELSIF e.exc.ExceptionCode = Kernel32.ExceptionStackOverflow THEN
				COPY("stack overflow", desc)
			ELSE
				Strings.IntToStr(e.exc.ExceptionCode, arg);
				COPY("exception ", desc); Strings.Append(desc, arg)
			END
		ELSE
			SYSTEM.GETREG(SYSTEM.EBP, bp); (* get type from stack *)
			SYSTEM.GET(bp+20, bp);
			SYSTEM.GET(bp-4, SYSTEM.VAL(LONGINT, type));
			COPY(type.module.name, desc);
			Strings.AppendCh(desc, ".");
			Strings.Append(desc, type.name)
		END
	END GetDescription;

	PROCEDURE GetNum(refs: Bytes; VAR i, num: LONGINT);
		VAR n, s: LONGINT; x: CHAR;
	BEGIN
		IF (i >= 0) & (i < LEN(refs^)) THEN
			s := 0; n := 0; x := refs[i]; INC(i);
			WHILE ORD(x) >= 128 DO
				INC(n, ASH(ORD(x) - 128, s)); INC(s, 7); x := refs[i]; INC(i)
			END;
			num := n + ASH(ORD(x) MOD 64 - ORD(x) DIV 64 * 64, s)
		ELSE
			num := 0
		END
	END GetNum;

	PROCEDURE FindHandler(mod: Modules.Module; pc: LONGINT; VAR handler: Handler; VAR slNeeded: BOOLEAN);
		VAR
			refs: Bytes; type: Types.Type;
			i, m, n, t, level, tdadr, proc: LONGINT; cand, sl: BOOLEAN; ch: CHAR;
	BEGIN
		handler := NIL;
		IF mod # NIL THEN
			refs := SYSTEM.VAL(Bytes, mod.refs);
			DEC(pc, SYSTEM.ADR(mod.code[0]));
			m := LEN(refs^); proc := -1; level := -1;
			i := 0; ch := refs[i]; INC(i);
			WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO	(* proc *)
				GetNum(refs, i, t);	(* pofs *)
				IF t > pc THEN	(* previous procedure was the one *)
					ch := 0X	(* stop search *)
				ELSE	(* ~found *)
					proc := t;	(* remember this pofs *)
					IF ch = 0F9X THEN
						GetNum(refs, i, n); (* n pars *)
						ch := refs[i]; INC(i); (* ret type *)
						level := ORD(refs[i]); INC(i); (* proc level *)
						ch := refs[i]; INC(i) (* sl needed *)
					ELSE
						level := -1
					END;
					REPEAT ch := refs[i]; INC(i) UNTIL ch = 0X;	(* pname *)
					IF i < m THEN
						ch := refs[i]; INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
						WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
							ch := refs[i]; INC(i);	(* type *)
							IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
								GetNum(refs, i, t)	(* dim/tdadr *)
							END;
							GetNum(refs, i, t);	(* vofs *)
							REPEAT ch := refs[i]; INC(i) UNTIL ch = 0X;	(* vname *)
							IF i < m THEN ch := refs[i]; INC(i) END	(* 1X | 3X | 0F8X | 0F9X *)
						END
					END
				END
			END;
			IF proc = -1 THEN proc := t END;
			IF (level = -1) & (proc # -1) THEN (* module body *)
				proc := MAX(LONGINT) (* any pc is ok *)
			END;
			INC(level);
			i := 0; ch := refs[i]; INC(i);
			WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO	(* proc *)
				GetNum(refs, i, pc);	(* pofs *)
				IF ch = 0F9X THEN
					GetNum(refs, i, n); (* n pars *)
					cand := n = 1;
					ch := refs[i]; INC(i); (* ret type *)
					cand := cand & (ORD(ch) = 6); (* LInt *)
					ch := refs[i]; INC(i); (* proc level *)
					cand := cand & (ORD(ch) = level);
					IF (ORD(ch) < level) & (pc < proc) THEN
						handler := NIL
					END;
					ch := refs[i]; INC(i); (* sl needed *)
					sl := ch # 0X;
					cand := cand & (pc < proc)
				ELSE
					cand := FALSE
				END;
				REPEAT ch := refs[i]; INC(i) UNTIL ch = 0X;	(* pname *)
				IF i < m THEN
					ch := refs[i]; INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
					WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
						ch := refs[i]; INC(i);	(* type *)
						IF ch >= 81X THEN
							GetNum(refs, i, t)	(* dim *)
						ELSIF (ch = 16X) OR (ch = 1DX) THEN
							GetNum(refs, i, tdadr);
							IF cand THEN
								IF (tdadr >= 0) & (tdadr <= 1024*1024) THEN
									SYSTEM.GET(mod.sb+tdadr, tdadr)
								END;
								SYSTEM.GET(tdadr-4, SYSTEM.VAL(LONGINT, type));
								IF (type.module.name = "Exceptions") & (type.name = "Exception") THEN
									handler := SYSTEM.VAL(Handler, SYSTEM.ADR(mod.code[0])+pc);
									slNeeded := sl
								END
							END
						END;
						GetNum(refs, i, t);	(* vofs *)
						REPEAT ch := refs[i]; INC(i) UNTIL ch = 0X;	(* vname *)
						IF i < m THEN ch := refs[i]; INC(i) END	(* 1X | 3X | 0F8X | 0F9X *)
					END
				END
			END
		END
	END FindHandler;

	PROCEDURE CheckContext(VAR context: Context; bp: LONGINT): BOOLEAN;
		VAR cbp: LONGINT;
	BEGIN
		SYSTEM.GET(SYSTEM.ADR(context)+4, cbp);
		WHILE (bp # cbp) & (bp # Kernel32.NULL) DO
			SYSTEM.GET(bp, bp)
		END;
		RETURN (bp # Kernel32.NULL) & (bp = cbp)
	END CheckContext;

	PROCEDURE Dispatch(VAR e: Exception): LONGINT;
		VAR
			pc, fp, lastfp, ret: LONGINT;
			mod: Modules.Module;
			handler: Handler; lHandler: LocalHandler;
			slNeeded: BOOLEAN;
	BEGIN
		theContext := NIL;
		pc := e.exc.ExceptionAddress; fp := e.cont.Ebp;
		IF pc = Kernel32.NULL THEN (* assume call of procedure variable with value NIL *)
			SYSTEM.GET(e.cont.Esp, pc) (* get return address on top of stack *)
		END;
		mod := Kernel.GetMod(pc);
		LOOP
			FindHandler(mod, pc, handler, slNeeded);
			IF handler # NIL THEN
				inDispatch := TRUE;
				IF slNeeded THEN
					lHandler := SYSTEM.VAL(LocalHandler, handler);
					ret := lHandler(fp, e)
				ELSE
					ret := handler(e)
				END;
				inDispatch := FALSE;
				IF ret = CallFail THEN
					IF (theContext = NIL) OR ~CheckContext(theContext^, e.cont.Ebp) THEN
						RETURN Abort
					ELSE
						RETURN CallFail
					END
				ELSIF ret # Forward THEN
					RETURN ret
				END
			END;
			lastfp := fp;
			SYSTEM.GET(fp+4, pc);  SYSTEM.GET(fp, fp); (* return addr from stack *)
			IF (fp < lastfp) OR (fp >= e.t.stackBottom) THEN RETURN Abort END; (* not called from stack *)
			mod := Kernel.GetMod(pc)
		END
	END Dispatch;

	PROCEDURE DisplayTrap(VAR e: Exception);
		VAR desc: ARRAY 64 OF CHAR; mod: Modules.Module; pc, fp, lastfp, stackBottom: LONGINT;
	BEGIN
		Kernel32.Str("TRAP ");
		GetDescription(e, desc); Kernel32.Str(desc);
		Kernel32.Str(" in thread ");
		IF e.t # NIL THEN
			stackBottom := e.t.stackBottom; Kernel32.Str(e.t.name)
		ELSE
			stackBottom := 1024*1024; Kernel32.Str("unknown thread")
		END;
		Kernel32.Ln();
		pc := e.exc.ExceptionAddress; fp := e.cont.Ebp;
		IF pc = Kernel32.NULL THEN (* assume call of procedure variable with value NIL *)
			SYSTEM.GET(e.cont.Esp, pc) (* get return address on top of stack *)
		END;
		mod := Kernel.GetMod(pc);
		LOOP
			IF mod # NIL THEN
				Kernel32.Str("Module: "); Kernel32.Str(mod.name); Kernel32.Str(" at ");
				Kernel32.Str("PC = "); Kernel32.Int(pc-SYSTEM.VAL(LONGINT, SYSTEM.ADR(mod.code[0])));
				Kernel32.Ln()
			END;
			lastfp := fp;
			SYSTEM.GET(fp+4, pc);  SYSTEM.GET(fp, fp); (* return addr from stack *)
			IF (fp < lastfp) OR (fp >= stackBottom) THEN EXIT END; (* not called from stack *)
			mod := Kernel.GetMod(pc)
		END;
		IF displayTrap # NIL THEN
			displayTrap(e)
		ELSE
			Kernel32.Str("Exceptions.displayTrap not set"); Kernel32.Ln()
		END
	END DisplayTrap;

	PROCEDURE -fail()
		8BH, 4DH, 8,	(* mov ecx, 8[ebp]	; address of context variable *)
		8BH, 29H,	(* mov ebp, [ecx]	; restore current SP/FP *)
		8BH, 41H, 4,	(* mov eax, 4[ecx]	; replace caller's FP by stored FP *)
		89H, 45H, 0,	(* mov [ebp], eax *)
		8BH, 41H, 8,	(* mov eax, 8[ecx]	; replace caller's return address by stored one *)
		89H, 45H, 4,	(* mov 4[ebp], eax *)
		0B0H, 1;	(* mov al, 1		; return true*)

	PROCEDURE DoCallFail0(VAR context: Context);
	BEGIN
		theContext := NIL; fail()
	END DoCallFail0;

	PROCEDURE DoCallFail();
	BEGIN
		DoCallFail0(theContext^)
	END DoCallFail;

	PROCEDURE [WINAPI] *ExcpFrmHandler(VAR excpRec: Kernel32.ExceptionRecord; excpFrame: Kernel32.ExcpFrmPtr; VAR context: Kernel32.Context; dispatch: LONGINT): LONGINT;
		VAR e: SysException; proc: Modules.Command; ret: LONGINT;
	BEGIN
		Threads.Lock(moduleCS);
		DEC(Kernel.GClevel);
		e.t := Threads.This();
		SYSTEM.MOVE(SYSTEM.ADR(excpRec), SYSTEM.ADR(e.exc), SIZE(Kernel32.ExceptionRecord));
		SYSTEM.MOVE(SYSTEM.ADR(context), SYSTEM.ADR(e.cont), SIZE(Kernel32.Context));
		ret := Dispatch(e);
		IF ret = CallFail THEN
			proc := DoCallFail;
			context.Eip := SYSTEM.VAL(LONGINT, proc);
			ret := Kernel32.ExceptionContinueSearch
		ELSE
			DisplayTrap(e);
			ret := Kernel32.ExceptionExecuteHandler
		END;
		INC(Kernel.GClevel);
		Threads.Unlock(moduleCS);
		RETURN ret
	END ExcpFrmHandler;

	PROCEDURE Raise*(VAR e: UserException);
		VAR ret: LONGINT;
	BEGIN
		ASSERT(~inDispatch); theContext := NIL;
		Threads.Lock(moduleCS);
		DEC(Kernel.GClevel);
		e.t := Threads.This();
		e.cont.ContextFlags := Kernel32.ContextFull;
		ret := Kernel32.GetThreadContext(e.t.handle, e.cont);
		e.exc.ExceptionCode := Kernel32.ExceptionBreakPoint;
		INC(e.cont.Esp, 4); SYSTEM.PUT(e.cont.Esp, 23);
		SYSTEM.GETREG(SYSTEM.EBP, e.cont.Ebp);
		SYSTEM.GET(e.cont.Ebp+4, e.cont.Eip); SYSTEM.GET(e.cont.Ebp, e.cont.Ebp); (* return addr from stack *)
		e.exc.ExceptionAddress := e.cont.Eip;
		ret := Dispatch(e);
		IF ret = CallFail THEN
			INC(Kernel.GClevel);
			Threads.Unlock(moduleCS);
			DoCallFail();
			HALT(99)
		ELSIF ret # Ignore THEN
			DisplayTrap(e);
			INC(Kernel.GClevel);
			Threads.Unlock(moduleCS);
			Threads.Abort(e.t);
			HALT(99)
		ELSE
			INC(Kernel.GClevel);
			Threads.Unlock(moduleCS)
		END
	END Raise;

	PROCEDURE -failed(): BOOLEAN
		8BH, 4DH, 8,	(* mov ecx, 8[ebp]	; address of context variable *)
		89H, 29H,	(* mov [ecx], ebp	; save current SP/FP *)
		8BH, 45H, 0,	(* mov eax, [ebp]	; save caller's FP (pushed by prolog in Failed) *)
		89H, 41H, 4,	(* mov 4[ecx], eax *)
		8BH, 45H, 4, 	(* mov eax, 4[ebp]	; save return address *)
		89H, 41H, 8,	(* mov, 8[ecx], eax *)
		0B0H, 0;	(* mov al, 0		; return false *)

	PROCEDURE Failed*(VAR context: Context): BOOLEAN;
	BEGIN
		ASSERT(~inDispatch); theContext := NIL;
		RETURN failed()
	END Failed;

	PROCEDURE ReturnFail*(VAR context: Context): LONGINT;
	BEGIN
		ASSERT(inDispatch);
		theContext := SYSTEM.VAL(ContextPtr, SYSTEM.ADR(context));
		RETURN CallFail
	END ReturnFail;

	PROCEDURE Fail*(VAR context: Context);
		VAR bp: LONGINT;
	BEGIN
		ASSERT(~inDispatch); theContext := NIL;
		SYSTEM.GETREG(SYSTEM.EBP, bp);
		ASSERT(CheckContext(context, bp));
		fail()
	END Fail;

	PROCEDURE *Shutdown();
	BEGIN
		displayTrap := NIL
	END Shutdown;

BEGIN
	Kernel32.excpFrmHandler := ExcpFrmHandler;
	NEW(moduleCS); Threads.Init(moduleCS);
	theContext := NIL; inDispatch := FALSE; displayTrap := NIL;
	Modules.InstallTermHandler(Shutdown)
END Exceptions.

(**
	TYPE
		MyException = RECORD (Exceptions.UserException)
		END;

	PROCEDURE P();
		VAR e: MyException;
		PROCEDURE Handler(VAR e: Exceptions.Exception): LONGINT;
		BEGIN
			IF e IS MyException THEN
				...
				RETURN Exceptions.Ignore / Forward / Abort
			ELSE
				RETURN Exceptions.Abort / Forward
			END
		END Handler;
	BEGIN
		...
		Exceptions.Raise(e)
		...


	PROCEDURE P();
		VAR e: MyException; context: Context;
		PROCEDURE Handler(VAR e: Exceptions.Exception): LONGINT;
		BEGIN
			IF e IS MyException THEN
				...
				RETURN Exceptions.ReturnFail(context)
			ELSE
				RETURN Exceptions.Abort / Forward
			END
		END Handler;
	BEGIN
		IF ~Exceptions.Failed(context) THEN (* no error occured *)
			...
			Exceptions.Raise(e)
			...
		ELSE (* error occured and Exceptions.ReturnFail was called *)
			...
		END


	PROCEDURE P();
		VAR context: Context;
	BEGIN
		IF ~Exceptions.Failed(context) THEN (* no error occured *)
			...
			Exceptions.Fail(context)
			...
		ELSE (* Exceptions.Fail was called *)
			...
		END
*)
