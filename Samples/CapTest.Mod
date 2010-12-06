MODULE CapTest;

(* CAP built-in function test. (c) Alexander Iljin, 06.12.2010. *)

   IMPORT SYSTEM, Kernel32;

   PROCEDURE OutInt(i: INTEGER);
      VAR
         pos: INTEGER;
         s: ARRAY 16 OF CHAR; (* must be bigger than MAX(INTEGER) string + 2 characters *)
   BEGIN
      IF i = 0 THEN
         Kernel32.Str('0');
      ELSIF i > 0 THEN
         pos := 2; (* leave s[0] and s[1] as buffer space for output *)
         WHILE i > 0 DO
            s[pos] := CHR(i MOD 10 + ORD('0'));
            INC(pos);
            i := i DIV 10;
         END;
         s[1] := 0X; (* use s[0] and s[1] as output buffer *)
         DEC(pos);
         WHILE pos >= 0 DO
            s[0] := s[pos];
            Kernel32.Str(s);
            DEC(pos);
         END;
      ELSE
         ASSERT(i > 0, 20); (* always FALSE *)
      END
   END OutInt;

   PROCEDURE Out8Bits(i: INTEGER);
      VAR bit: INTEGER;
   BEGIN
      FOR bit := 7 TO 0 BY -1 DO
         IF bit IN SYSTEM.VAL(SET, i) THEN
            Kernel32.Str('1');
         ELSE
            Kernel32.Str('0');
         END;
      END;
   END Out8Bits;

   PROCEDURE OutChar(ch: CHAR);
      (* If ch < ' ' then output space, otherwise output ch. Surround with '"'. *)
      VAR s: ARRAY 2 OF CHAR;
   BEGIN
      Kernel32.Str('"');
      IF ch < ' ' THEN
         Kernel32.Str(' ');
      ELSE
         s[0] := ch;
         s[1] := 0X;
         Kernel32.Str(s);
      END;
      Kernel32.Str('"');
   END OutChar;

   PROCEDURE CapCheck(i: LONGINT): BOOLEAN;
      (* If result of our SET manipulation matches CAP result, return TRUE
       * otherwise return FALSE. *)
   BEGIN
      RETURN SYSTEM.VAL(SET, i) - {7, 5} = SYSTEM.VAL(SET, LONG(ORD(CAP(CHR(i)))))
   END CapCheck;

   PROCEDURE OutBool(b: BOOLEAN);
   BEGIN
      IF b THEN
         Kernel32.Str('v');
      ELSE
         Kernel32.Str('-');
      END;
   END OutBool;

   PROCEDURE Do;
      VAR i: INTEGER;
   BEGIN
      FOR i := 0 TO 255 DO
         Out8Bits(i);
         Kernel32.Str(' ');
         Out8Bits(ORD(CAP(CHR(i))));
         Kernel32.Str(' ');
         OutChar(CHR(i));
         Kernel32.Str(' ');
         OutInt(i);
         Kernel32.Str('=>');
         OutInt(ORD(CAP(CHR(i))));
         Kernel32.Str(' ');
         OutChar(CAP(CHR(i)));
         Kernel32.Str(' ');
         OutBool(CapCheck(i));
         Kernel32.Ln();
      END;
   END Do;

BEGIN
   Do;
END CapTest.
