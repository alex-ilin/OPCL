(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Fonts; (** portable / source: Win32.Fonts.Mod *)	(* ejz *)
	IMPORT SYSTEM, Modules, Objects;

	CONST
		substitute* = -1; font* = 0; metric* = 1;	(** Font types. *)

	TYPE
		Char* = POINTER TO CharDesc;
		Font* = POINTER TO FontDesc;

		CharDesc* = RECORD (Objects.ObjDesc)	(** The objects in a font library. *)
			dx*, x*, y*, w*, h*: INTEGER;	(** Character width, pattern offset (x, y), pattern size (w, h). *)
			pat*: LONGINT	(** Character raster data. *)
		END;

		FontDesc* = RECORD (Objects.LibDesc)
			type*: SHORTINT;	(** Substitute, font, or metric. *)
			height*, minX*, maxX*, minY*, maxY*: INTEGER	(** Font height, extremal values of characters in font. *)
		END;

	VAR
		FontId*: CHAR;	(** Initial character of font files (.Fnt). *)
		Default*: Font;	(** Default system screen font (typically Syntax10.Scn.Fnt). *)

	(** Return the character and data of ch in a font. *)
	PROCEDURE GetChar*(F: Font; ch: CHAR; VAR dx, x, y, w, h: INTEGER; VAR pat: LONGINT);
		VAR obj: Objects.Object;
	BEGIN
		F.GetObj(F, ORD(ch), obj);
		WITH obj: Char DO
			dx := obj.dx; x := obj.x; y := obj.y; w := obj.w; h := obj.h; pat := obj.pat
		END
	END GetChar;

	(** Load and cache a font. *)
	PROCEDURE This*(name: ARRAY OF CHAR): Font;
		VAR L: Objects.Library;
	BEGIN
		L := Objects.ThisLibrary(name);
		IF (L # NIL) & (L IS Font) THEN RETURN L(Font) ELSE RETURN NIL END
	END This;

	PROCEDURE Init();
		VAR mod: Modules.Module;
	BEGIN
		FontId := 0DBX; Default := NIL;
		(*mod := Modules.ThisMod("WinFonts")*)
	END Init;

BEGIN
	Init()
END Fonts.

(** Remarks:

1. Screen fonts and printer fonts are stored in files with extensions .Scn.Fnt and .Prx.Fnt respectively (the x refers to x00dpi printer fonts). A full font name (like Syntax12b.Scn.Fnt) has to be specified to load a font. Should the font not be available, a substitute font is created. This has the same name but the wrong character metrics (often the Syntax10 font is used instead). A file with an .Mdx.Fnt extension is a metric font containing only metric data and no raster patterns. Each printer font has an associated metric font. A metric font is used to make measurements while printing. Sometimes the font module is clever enough to simulate the presence of a metric font by reading the metric data from a printer font (the metric fonts need not necessarily be available). If you need to find out the size of a character on paper, you should always request a metric font (it is faster to load and requires less memory than the printer fonts). Some Font modules support Truetype fonts implemented in the host operating system.

2. Fonts are extensions of Libraries. Each letter of the font is a (virtual) object indexed by ASCII code. Note that to optimize garbage collection, the same object instance is returned for each call to the GetObj library method (no matter what font or character is involved). This is realized by copying the character raster and metrics from a specially compressed representation of the font data. The GetChar procedure fetches a character from the font using this mechanism. The PutObj, GenRef and Store methods of fonts have no function.

3. The pattern (raster) of a character is only as large as required. The x, y, w, h values of a character metric specify the offset of the pattern from a virtual text baseline and the width and height of the pattern. Display.CopyPattern is used to draw the character patterns of the display. Help procedures like Display3.String hides the low-level display process and allows you to display strings at a time.

4. The default font is Syntax10.Scn.Fnt. You may influence the default font by adding a DefaultFont entry to the Fonts section of the Registry. Oberon allows you to influence the fonts loaded by specifying remapping of font families and sizes in the Registry (check the User Guide for more details).
*)
