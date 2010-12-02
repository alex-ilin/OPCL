(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Kernel32; (** non-portable / source: Win32.Kernel32.Mod *)	(* ejz *)
	IMPORT SYSTEM;

(** This module defines all the Win32 Kernel32 APIs used by Oberon.
	Note this module is part of the Oberon inner-core and must be linked with PELinker. *)

	CONST
		(** NIL pointer/address value *)
		NULL* = 0;

		(** BOOL values *)
		False* = NULL; True* = 1;

		(** standard handles *)
		InvalidHandleValue* = -1; STDInput* = -10; STDOutput* = -11; STDError* = -12;

		(** generic access rights *)
		GenericWrite* = 30; GenericRead* = 31;

		(** file sharing *)
		FileShareRead* = 0; FileShareWrite* = 1;

		(** file creation *)
		CreateAlways* = 2; OpenExisting* = 3;

		(** file attributes *)
		FileAttributeReadonly* = 0; FileAttributeHidden* = 1; FileAttributeSystem* = 2; FileAttributeDirectory* = 4;
		FileAttributeArchive* = 5; FileAttributeEncrypted * = 6; FileAttributeNormal* = 7; FileAttributeTemporary* = 8;
		FileAttributeSparseFILE* = 9; FileAttributeReparsePoint* = 10; FileAttributeCompressed* = 11; FileAttributeOffline* = 12;
		FileAttributeNotContentIndexed* = 13;

		(** file creation flags *)
		FileFlagRandomAccess* = 28;

		(** move method *)
		FileBegin* = 0;

		(** move file flags *)
		MoveFileReplaceExisting* = 0; MoveFileCopyAllowed* = 1;

		(* (* reason for call values *)
		DLLProcessDetach = 0; DLLProcessAttach = 1; *)

		(** allocation/free type *)
		MEMCommit* = 12; MEMReserve* = 13; MEMDecommit* = 14; MEMRelease* = 15;

		(** protect (VirtualAlloc) flags *)
		PageReadWrite* = 2; PageExecuteReadWrite* = 6;

		(** global memory flags *)
		GMemMoveable* = 1; GMemShare* = 13; GMemDDEShare* = GMemShare;

		(** maximum length of full path *)
		MaxPath* = 260;

		(** specifies the type of a drive *)
		DriveUnknown* = 0; DriveNoRootDir* = 1; DriveRemovable* = 2; DriveFixed* = 3;
		DriveRemote* = 4; DriveCDRom* = 5; DriveRamDisk* = 6;

		(** thread context and exception information *)

		SizeOf80387Registers* = 80; ExceptionMaximumParameters* = 15;

		ExceptionGuardPage* = 080000001H;
		ExceptionBreakPoint* = 080000003H;
		ExceptionSingleStep* = 080000004H;
		ExceptionAccessViolation* = 0C0000005H;
		ExceptionIllegalInstruction* = 0C000001DH;
		ExceptionArrayBoundsExceeded* = 0C000008CH;
		ExceptionFltDenormalOperand* = 0C000008DH;
		ExceptionFltDivideByZero* = 0C000008EH;
		ExceptionFltInexactResult* = 0C000008FH;
		ExceptionFltInvalidOperation* = 0C0000090H;
		ExceptionFltOverflow* = 0C0000091H;
		ExceptionFltStackCheck* = 0C0000092H;
		ExceptionFltUndeflow* = 0C0000093H;
		ExceptionIntDivideByZero* = 0C0000094H;
		ExceptionIntOverflow* = 0C0000095H;
		ExceptionPrivInstruction* = 0C0000096H;
		ExceptionStackOverflow* = 0C00000FDH;

		ContextIntel = 16;
		ContextControl* = {0, ContextIntel}; (* SS:SP, CS:IP, FLAGS, BP *)
		ContextInteger* = {1, ContextIntel}; (* AX, BX, CX, DX, SI, DI *)
		ContextSegments* = {2, ContextIntel}; (* DS, ES, FS, GS *)
		ContextFloatingPoint* = {3, ContextIntel}; (* 387 state *)
		ContextDebugRegisters* = {4, ContextIntel}; (* DB 0-3,6,7 *)
		ContextFull* = ContextControl + ContextInteger + ContextSegments;

		(** exception frame handler return values *)
		ExceptionContinueExecution* = -1; ExceptionContinueSearch* = 0; ExceptionExecuteHandler* = 1;

		(** thread priorities *)
		ThreadBasePriorityMin = -2; ThreadPriorityLowest = ThreadBasePriorityMin;
		ThreadBasePriorityMax = 2; ThreadPriorityHighest = ThreadBasePriorityMax;
		ThreadPriorityBelowNormal* = ThreadPriorityLowest+1;
		ThreadPriorityNormal* = 0;
		ThreadPriorityAboveNormal* = ThreadPriorityHighest-1;

		(** WaitForSingleObject infinite time value *)
		Infinite* = 0FFFFFFFFH;

		(** WaitForSingleObject return values *)
		WaitTimeout* = 0102H;

		(** SetErrorMode *)
		SEMFailCriticalErrors* = 0;

		(** DuplicateHandle *)
		DuplicateCloseSource* = 0; DuplicateSameAccess* = 1;

		(** StartupInfo flags *)
		StartFUseShowWindow* = 0; StartFUseSize* = 1; StartFUsePosition* = 2;

		(** OSVersionInfo dwPlatformId values *)
		VerPlatformWin32s* = 0; VerPlatformWin32Windows* = 1; VerPlatformWin32NT* = 2;

	TYPE
		OutputStringProc* = PROCEDURE (VAR str: ARRAY OF CHAR);

		BOOL* = LONGINT;

		ADDRESS* = LONGINT;
		HANDLE* = ADDRESS;
		HMODULE* = ADDRESS;
		HINSTANCE* = ADDRESS;
		ATOM* = INTEGER;
		HGLOBAL* = HANDLE;
		LPSTR* = ADDRESS;

		(** The FILETIME structure is a 64-bit value representing the number of 100-nanosecond intervals since January 1, 1601. *)
		FileTime* = RECORD [NOTAG]
			dwLowDateTime*, dwHighDateTime*: LONGINT
		END;

		(** The FindData structure describes a file found by the FindFirstFile or FindNextFile function. *)
		FindData* = RECORD [NOTAG]
			dwFileAttributes*: SET;
			ftCreationTime*, ftLastAccessTime*, ftLastWriteTime*: FileTime;
			nFileSizeHigh*, nFileSizeLow*: LONGINT;
			dwReserved0*, dwReserved1*: LONGINT;
			cFileName*: ARRAY MaxPath OF CHAR;
			cAlternateFileName*: ARRAY 14 OF CHAR
		END;

		(** The SYSTEMTIME structure represents a date and time using individual members for the month, day, year, weekday,
			hour, minute, second, and millisecond. *)
		SystemTime* = RECORD [NOTAG]
			wYear*, wMonth*, wDayOfWeek*, wDay*: INTEGER;
			wHour*, wMinute*, wSecond*, wMilliseconds*: INTEGER
		END;

		(** The SMALL_RECT structure defines the coordinates of the upper left and lower right corners of a rectangle. *)
		SmallRect* = RECORD [NOTAG]
			left*, top*, right*, bottom*: INTEGER
		END;

		(** Critical-section object. *)
		CriticalSection* = RECORD [NOTAG]
			a, b, c, d, e, f: LONGINT
		END;

		(** thread context and exception information *)

		FloatingSaveArea* = RECORD [NOTAG]
			ControlWord*, StatusWord*, TagWord*, ErrorOffset*, ErrorSelector*, DataOffset*, DataSelector*: LONGINT;
			RegisterArea*: ARRAY SizeOf80387Registers OF SYSTEM.BYTE;
			Cr0NpxState*: LONGINT
		END;

		Context* = RECORD [NOTAG]
			ContextFlags*: SET;
			Dr0*, Dr1*, Dr2*, Dr3*, Dr6*, Dr7*: LONGINT;
			FloatSave*: FloatingSaveArea;
			SegGs*, SegFs*, SegEs*, SegDs*: LONGINT;
			Edi*, Esi*, Ebx*, Edx*, Ecx*, Eax*: LONGINT;
			Ebp*, Eip*, SegCs*, EFlags*, Esp*, SegSs*: LONGINT
		END;

		ExceptionRecordPtr* = POINTER TO ExceptionRecord;
		ExceptionRecord* = RECORD [NOTAG]
			ExceptionCode*, ExceptionFlags*: LONGINT;
			nextExceptionRecord*: ExceptionRecordPtr;
			ExceptionAddress*: ADDRESS;
			NumberParameters*: LONGINT;
			ExceptionInformation*: ARRAY ExceptionMaximumParameters OF LONGINT
		END;

		ExcpFrmPtr* = ADDRESS;
		ExcpFrmHandler* = PROCEDURE [WINAPI] (VAR excpRec: ExceptionRecord; excpFrame: ExcpFrmPtr; VAR context: Context; dispatch: LONGINT): LONGINT;
		ExcpFrm* = RECORD [NOTAG]
			link*: ExcpFrmPtr;
			handler*: ExcpFrmHandler
		END;

		(** Synchronization Objects *)
		Object* = POINTER TO RECORD handle*: HANDLE END;

		(** A 64-bit signed integer value. *)
		LargeInteger* = RECORD [NOTAG]
			LowPart*, HighPart*: LONGINT
		END;

		(** A 64-bit unsigned integer value. *)
		ULargeInteger* = LargeInteger;

		(** CreateThread *)
		ThreadStartRoutine* = PROCEDURE [WINAPI] (lpThreadParameter: LONGINT): LONGINT;

		(** CreateProcess *)
		ProcessInformation* = RECORD [NOTAG]
			hProcess*, hThread*: HANDLE;
			dwProcessId*, dwThreadId*: LONGINT
		END;

		(** CreateProcess, GetStartupInfo *)
		StartupInfo* = RECORD [NOTAG]
			cb*: LONGINT;
			lpReserved*, lpDesktop*, lpTitle*: LPSTR;
			dwX*, dwY*, dwXSize*, dwYSize*: LONGINT;
			dwXCountChars*, dwYCountChars*: LONGINT;
			dwFillAttribute*: LONGINT;
			dwFlags*: SET;
			wShowWindow*, cbReserved2*: INTEGER;
			lpReserved2*: ADDRESS;
			hStdInput*, hStdOutput*, hStdError*: HANDLE
		END;

		(** The OSVersionInfo data structure contains operating system version information. *)
		OSVersionInfo* = RECORD [NOTAG]
			dwOSVersionInfoSize*,
			dwMajorVersion*, dwMinorVersion*,
			dwBuildNumber*, dwPlatformId*: LONGINT;
			szCSDVersion*: ARRAY 128 OF CHAR
		END;

		Exception* = RECORD
			exc*: ExceptionRecord;
			cont*: Context
		END;

	VAR
		(** The AllocConsole function allocates a new console for the calling process. *)
		AllocConsole-: PROCEDURE [WINAPI] (): BOOL;
		(** The CloseHandle function closes an open object handle. *)
		CloseHandle-: PROCEDURE [WINAPI] (hObject: HANDLE): BOOL;
		(** The CopyFile function copies an existing file to a new file. *)
		CopyFile-: PROCEDURE [WINAPI] (lpExistingFileName, lpNewFileName: ARRAY [NOTAG] OF CHAR; bFailIfExists: BOOL): BOOL;
		(** The CreateDirectory function creates a new directory. *)
		CreateDirectory-: PROCEDURE [WINAPI] (lpPathName: ARRAY [NOTAG] OF CHAR; lpSecurityAttributes: PTR): BOOL;
		(** The CreateEvent function creates a named or unnamed event object. *)
		CreateEvent-: PROCEDURE [WINAPI] (lpEventAttributes: PTR; bManualReset, bInitialState: BOOL; lpName: ARRAY [NOTAG] OF CHAR): HANDLE;
		(** The CreateFile function creates or opens the following objects and returns a handle that can be used to access the object:
		 files, pipes, mailslots, communications resources, disk devices (Windows NT only), consoles, directories (open only) *)
		CreateFile-: PROCEDURE [WINAPI] (lpFileName: ARRAY [NOTAG] OF CHAR; dwDesiredAccess, dwShareMode: SET; lpSecurityAttributes: PTR; dwCreationDistribution: LONGINT; dwFlagsAndAttributes: SET; hTemplateFile: HANDLE): HANDLE;
		(** The CreateProcess function creates a new process and its primary thread. The new process executes the specified
			executable file. *)
		CreateProcess-: PROCEDURE [WINAPI] (lpApplicationName, lpCommandLine: ARRAY [NOTAG] OF CHAR; lpProcessAttributes, lpThreadAttributes: PTR; bInheritHandles: BOOL; dwCreationFlags: LONGINT; lpEnvironment: PTR; lpCurrentDirectory: ARRAY [NOTAG] OF CHAR; VAR lpStartupInfo: StartupInfo; VAR lpProcessInformation: ProcessInformation): BOOL;
		(** The CreateThread function creates a thread to execute within the address space of the calling process. *)
		CreateThread-: PROCEDURE [WINAPI] (lpThreadAttributes: PTR; dwStackSize: LONGINT; lpStartAddress: ThreadStartRoutine; lpParameter, dwCrationFlags: LONGINT; VAR lpThreadId: LONGINT): HANDLE;
		(** The DeleteCriticalSection function releases all resources used by an unowned critical section object. *)
		DeleteCriticalSection-: PROCEDURE [WINAPI] (VAR lpCriticalSection: CriticalSection);
		(** The DeleteFile function deletes an existing file. *)
		DeleteFile-: PROCEDURE [WINAPI] (lpFileName: ARRAY [NOTAG] OF CHAR): BOOL;
		(** The DisableThreadLibraryCalls function disables the DLL_THREAD_ATTACH and DLL_THREAD_DETACH notifications
			for the dynamic-link library (DLL) specified by hLibModule. *)
		DisableThreadLibraryCalls-: PROCEDURE [WINAPI] (hLibModule: HMODULE): BOOL;
		(** The DuplicateHandle function duplicates an object handle. *)
		DuplicateHandle-: PROCEDURE [WINAPI] (hSourceProcessHandle, hSourceHandle, hTargetProcessHandle: HANDLE; VAR lpTargetHandle: HANDLE; dwDesiredAccess: SET; bInheritHandle: BOOL; dwOptions: SET): BOOL;
		(** The EnterCriticalSection function waits for ownership of the specified critical section object. *)
		EnterCriticalSection-: PROCEDURE [WINAPI] (VAR lpCriticalSection: CriticalSection);
		(** The ExitProcess function ends a process and all its threads. *)
		ExitProcess-: PROCEDURE [WINAPI] (uExitCode: LONGINT);
		(** The ExitThread function ends a thread. *)
		ExitThread-: PROCEDURE [WINAPI] (dwExitCode: LONGINT);
		(** The FileTimeToLocalFileTime function converts a file time based on the Coordinated Universal Time (UTC) to a
			local file time. *)
		FileTimeToLocalFileTime-: PROCEDURE [WINAPI] (lpFileTime: FileTime; VAR lpLocalFileTime: FileTime): BOOL;
		(** The FileTimeToSystemTime function converts a 64-bit file time to system time format. *)
		FileTimeToSystemTime-: PROCEDURE [WINAPI] (lpFileTime: FileTime; VAR lpSystemTime: SystemTime): BOOL;
		(** The FindClose function closes the specified search handle. *)
		FindClose-: PROCEDURE [WINAPI] (hFindFile: HANDLE): BOOL;
		(** The FindFirstFile function searches a directory for a file whose name matches the specified filename. *)
		FindFirstFile-: PROCEDURE [WINAPI] (lpFileName: ARRAY [NOTAG] OF CHAR; VAR lpFindFileDate: FindData): HANDLE;
		(** The FindNextFile function continues a file search from a previous call to the FindFirstFile function. *)
		FindNextFile-: PROCEDURE [WINAPI] (hFindFile: HANDLE; VAR lpFindFileDate: FindData): BOOL;
		(** The FlushFileBuffers function clears the buffers for the specified file and causes all buffered data to be written
			to the file. *)
		FlushFileBuffers-: PROCEDURE [WINAPI] (hFile: HANDLE): BOOL;
		(** The FreeLibrary function decrements the reference count of the loaded dynamic-link library (DLL) module.
			When the reference count reaches zero, the module is unmapped from the address space of the calling process
			and the handle is no longer valid. *)
		FreeLibrary-: PROCEDURE [WINAPI] (hLibModule: HMODULE): BOOL;
		(** The GetCommandLine function returns a pointer to the command-line string for the current process. *)
		GetCommandLine-: PROCEDURE [WINAPI] (): LPSTR;
		(** The GetComputerName function retrieves the NetBIOS name of the local computer. *)
		GetComputerName-: PROCEDURE [WINAPI] (VAR lpBuffer: ARRAY [NOTAG] OF CHAR; VAR lpnSize: LONGINT): BOOL;
		(** The GetCurrentDirectory function retrieves the current directory for the current process. *)
		GetCurrentDirectory-: PROCEDURE [WINAPI] (nBufferLength: LONGINT; VAR lpBuffer: ARRAY [NOTAG] OF CHAR): LONGINT;
		(** The GetCurrentProcess function returns a pseudohandle for the current process. *)
		GetCurrentProcess-: PROCEDURE [WINAPI] (): HANDLE;
		(** The GetCurrentProcessId function returns the process identifier of the calling process. *)
		GetCurrentProcessId-: PROCEDURE [WINAPI] (): LONGINT;
		(** The GetCurrentThread function returns a pseudohandle for the current thread. *)
		GetCurrentThread-: PROCEDURE [WINAPI] (): HANDLE;
		(** The GetCurrentThreadId function returns the thread identifier of the calling thread. *)
		GetCurrentThreadId-: PROCEDURE [WINAPI] (): LONGINT;
		(** The GetDiskFreeSpace function retrieves information about the specified disk, including the amount of
			free space on the disk. *)
		GetDiskFreeSpace-: PROCEDURE [WINAPI] (lpRootPathName: ARRAY [NOTAG] OF CHAR; VAR lpSectorsPerCluster, lpBytesPerSector, lpNumberOfFreeClusters, lpTotalNumberOfClusters: LONGINT): BOOL;
		(** The GetDriveType function determines whether a disk drive is a removable, fixed, CD-ROM, RAM disk, or
			network drive. *)
		GetDriveType-: PROCEDURE [WINAPI] (lpRootPathName: ARRAY [NOTAG] OF CHAR): LONGINT;
		(** The GetExitCodeProcess function retrieves the termination status of the specified process. *)
		GetExitCodeProcess-: PROCEDURE [WINAPI] (hProcess: HANDLE; VAR lpExitCode: LONGINT): BOOL;
		(** The GetFileAttributes function returns attributes for a specified file or directory. *)
		GetFileAttributes-: PROCEDURE [WINAPI] (lpFileName: ARRAY [NOTAG] OF CHAR): SET;
		(** The GetFileSize function retrieves the size, in bytes, of the specified file. *)
		GetFileSize-: PROCEDURE [WINAPI] (hFile: HANDLE; VAR lpFileSizeHigh: LONGINT): LONGINT;
		(** The GetFileTime function retrieves the date and time that a file was created, last accessed, and last modified. *)
		GetFileTime-: PROCEDURE [WINAPI] (hFile: HANDLE; VAR lpCreationTime, lpLastAccessTime, lpLastWriteTime: FileTime): BOOL;
		(** The GetFullPathName function retrieves the full path and filename of a specified file. *)
		GetFullPathName-: PROCEDURE [WINAPI] (lpFileName: ARRAY [NOTAG] OF CHAR; nBufferLength: LONGINT; VAR lpBuffer: ARRAY [NOTAG] OF CHAR; VAR lpFilePart: LPSTR): LONGINT;
		(** The GetLastError function returns the calling thread's last-error code value. *)
		GetLastError-: PROCEDURE [WINAPI] (): LONGINT;
		(** The GetLocalTime function retrieves the current local date and time. *)
		GetLocalTime-: PROCEDURE [WINAPI] (VAR lpSystemTime: SystemTime);
		(** The GetModuleFileName function retrieves the full path and filename for the executable file containing the
			specified module. *)
		GetModuleFileName-: PROCEDURE [WINAPI] (hModule: HMODULE; VAR lpFileName: ARRAY [NOTAG] OF CHAR; nSize: LONGINT): LONGINT;
		(** The GetModuleHandle function returns a module handle for the specified module if the file has been mapped
			into the address space of the calling process. *)
		GetModuleHandle-: PROCEDURE [WINAPI] (lpModuleName: ARRAY [NOTAG] OF CHAR): HMODULE;
		(** The GetProcAddress function returns the address of the specified exported dynamic-link library (DLL) function.
			Use the GetProcAddress Oberon wrapper. *)
		getProcAddress-: PROCEDURE [WINAPI] (hModule: LONGINT; lpProcName: ARRAY [NOTAG] OF CHAR): ADDRESS;
		(** The GetStartupInfo function retrieves the contents of the StartupInfo structure that was specified when
			the calling process was created. *)
		GetStartupInfo-: PROCEDURE [WINAPI] (VAR lpStartupInfo: StartupInfo);
		(** The GetStdHandle function returns a handle for the standard input, standard output, or standard error device. *)
		GetStdHandle-: PROCEDURE [WINAPI] (nStdHandle: LONGINT): HANDLE;
		(** The GetSystemTime function retrieves the current system date and time. The system time is expressed in
			Coordinated Universal Time (UTC). *)
		GetSystemTime-: PROCEDURE [WINAPI] (VAR lpSystemTime: SystemTime);
		(** The GetTempFileName function creates a name for a temporary file. The filename is the concatenation of
			specified path and prefix strings, a hexadecimal string formed from a specified integer, and the .TMP extension. *)
		GetTempFileName-: PROCEDURE [WINAPI] (lpPathName, lpPrefixName: ARRAY [NOTAG] OF CHAR; uUnique: LONGINT; VAR lpTempFileName: ARRAY [NOTAG] OF CHAR): LONGINT;
		(** The GetTempPath function retrieves the path of the directory designated for temporary files. *)
		GetTempPath-: PROCEDURE [WINAPI] (nBufferLength: LONGINT; VAR lpBuffer: ARRAY [NOTAG] OF CHAR): LONGINT;
		(** The GetThreadContext function retrieves the context of the specified thread. *)
		GetThreadContext-: PROCEDURE [WINAPI] (hThread: HANDLE; VAR lpContext: Context): BOOL;
		(** The GetThreadPriority function returns the priority value for the specified thread. This value, together with
			the priority class of the thread's process, determines the thread's base-priority level. *)
		GetThreadPriority-: PROCEDURE [WINAPI] (hThread: HANDLE): LONGINT;
		(** The GetTickCount function retrieves the number of milliseconds that have elapsed since the system was started. *)
		GetTickCount-: PROCEDURE [WINAPI] (): LONGINT;
		(** The GetVersion function returns the current version number of the operating system. *)
		GetVersion-: PROCEDURE [WINAPI] (): LONGINT;
		(** The GetVersionEx function obtains extended information about the version of the operating system that is
			currently running. *)
		GetVersionEx-: PROCEDURE [WINAPI] (VAR lpVersionInfo: OSVersionInfo): BOOL;
		(** The GlobalAddAtom function adds a character string to the global atom table and returns a unique value
			(an atom) identifying the string. *)
		GlobalAddAtom-: PROCEDURE [WINAPI] (lpString: ARRAY [NOTAG] OF CHAR): ATOM;
		(** The GlobalAlloc function allocates the specified number of bytes from the heap. *)
		GlobalAlloc-: PROCEDURE [WINAPI] (uFlags: SET; dwBytes: LONGINT): HGLOBAL;
		(** The GlobalDeleteAtom function decrements the reference count of a global string atom. *)
		GlobalDeleteAtom-: PROCEDURE [WINAPI] (nAtom: ATOM): ATOM;
		(** The GlobalLock function locks a global memory object and returns a pointer to the first byte of the
			object's memory block. *)
		GlobalLock-: PROCEDURE [WINAPI] (hMem: HGLOBAL): ADDRESS;
		(** The GlobalReAlloc function changes the size or attributes of a specified global memory object. *)
		GlobalReAlloc-: PROCEDURE [WINAPI] (hMem: HGLOBAL; dwBytes: LONGINT; uFlags: SET): HGLOBAL;
		(** The GlobalSize function retrieves the current size, in bytes, of the specified global memory object. *)
		GlobalSize-: PROCEDURE [WINAPI] (hMem: HGLOBAL): LONGINT;
		(** The GlobalUnlock function decrements the lock count associated with a memory object that was allocated with
			the GMEM_MOVEABLE flag. *)
		GlobalUnlock-: PROCEDURE [WINAPI] (hMem: HGLOBAL): BOOL;
		(** The InitializeCriticalSection function initializes a critical section object. *)
		InitializeCriticalSection-: PROCEDURE [WINAPI] (VAR lpCriticalSection: CriticalSection);
		(** The InterlockedDecrement function both decrements (decreases by one) the value of the specified 32-bit
			variable and checks the resulting value. *)
		InterlockedDecrement-: PROCEDURE [WINAPI] (VAR lpAddend: LONGINT): LONGINT;
		(** The InterlockedIncrement function both increments (increases by one) the value of the specified 32-bit variable
			and checks the resulting value. *)
		InterlockedIncrement-: PROCEDURE [WINAPI] (VAR lpAddend: LONGINT): LONGINT;
		(** The LeaveCriticalSection function releases ownership of the specified critical section object. *)
		LeaveCriticalSection-: PROCEDURE [WINAPI] (VAR lpCriticalSection: CriticalSection);
		(** The LoadLibrary function maps the specified executable module into the address space of the calling process. *)
		LoadLibrary-: PROCEDURE [WINAPI] (lpLibFileName: ARRAY [NOTAG] OF CHAR): HINSTANCE;
		(** The LocalFileTimeToFileTime function converts a local file time to a file time based on the Coordinated
			Universal Time (UTC). *)
		LocalFileTimeToFileTime-: PROCEDURE [WINAPI] (lpLocalFileTime: FileTime; VAR lpFileTime: FileTime): BOOL;
		(** The MoveFileEx function renames an existing file or directory. *)
		MoveFileEx-: PROCEDURE [WINAPI] (lpExistingFileName, lpNewFileName: ARRAY [NOTAG] OF CHAR; dwFlags: SET): BOOL;
		(** The OutputDebugString function sends a string to the debugger for the current application. *)
		outputDebugString-: PROCEDURE [WINAPI] (lpOutputString: ARRAY [NOTAG] OF CHAR);
		(** The QueryPerformanceCounter function retrieves the current value of the high-resolution
			performance counter, if one exists. *)
		QueryPerformanceCounter-: PROCEDURE [WINAPI] (VAR lpPerformaceCount: LargeInteger): BOOL;
		(** The QueryPerformanceFrequency function retrieves the frequency of the high-resolution
			performance counter, if one exists. *)
		QueryPerformanceFrequency-: PROCEDURE [WINAPI] (VAR lpFrequency: LargeInteger): BOOL;
		(** The ReadFile function reads data from a file, starting at the position indicated by the file pointer. *)
		ReadFile-: PROCEDURE [WINAPI] (hFile: HANDLE; VAR lpBuffer: ARRAY [NOTAG] OF SYSTEM.BYTE; nNumberOfBytesToRead: LONGINT; VAR lpNumberOfBytesRead: LONGINT; lpOverlapped: PTR): BOOL;
		(** The ReadProcessMemory function reads data from an area of memory in a specified process. *)
		ReadProcessMemory-: PROCEDURE [WINAPI] (hProcess: HANDLE; lpBaseAddress: ADDRESS; VAR lpBuffer: ARRAY [NOTAG] OF SYSTEM.BYTE; nSize: LONGINT; VAR lpNumberOfBytesRead: LONGINT): BOOL;
		(** The RemoveDirectory function deletes an existing empty directory. *)
		RemoveDirectory-: PROCEDURE [WINAPI] (lpPathName: ARRAY [NOTAG] OF CHAR): BOOL;
		(** The ResetEvent function sets the state of the specified event object to nonsignaled. *)
		ResetEvent-: PROCEDURE [WINAPI] (hEvent: HANDLE): BOOL;
		(** The ResumeThread function decrements a thread's suspend count. *)
		ResumeThread-: PROCEDURE [WINAPI] (hThread: HANDLE): LONGINT;
		(** The SearchPath function searches for the specified file. *)
		SearchPath-: PROCEDURE [WINAPI] (lpPath, lpFileName, lpExtension: ARRAY [NOTAG] OF CHAR; nBufferLength: LONGINT; VAR lpBuffer: ARRAY [NOTAG] OF CHAR; VAR lpFilePart: LPSTR): LONGINT;
		(** The SetConsoleScreenBufferSize function changes the size of the specified console screen buffer. *)
		SetConsoleScreenBufferSize-: PROCEDURE [WINAPI] (hConsoleOuput: HANDLE; dwSize: LONGINT): BOOL;
		(** The SetConsoleTitle function sets the title bar string for the current console window. *)
		SetConsoleTitle-: PROCEDURE [WINAPI] (lpConsoleTitle: ARRAY [NOTAG] OF CHAR): BOOL;
		(** The SetConsoleWindowInfo function sets the current size and position of a console screen buffer's window. *)
		SetConsoleWindowInfo-: PROCEDURE [WINAPI] (hConsoleOuput: HANDLE; bAbsolute: BOOL; lpConsoleWindow: SmallRect): BOOL;
		(** The SetCurrentDirectory function changes the current directory for the current process. *)
		SetCurrentDirectory-: PROCEDURE [WINAPI] (lpPathName: ARRAY [NOTAG] OF CHAR): BOOL;
		(** The SetErrorMode function controls whether the system will handle the specified types of serious errors,
			or whether the process will handle them. *)
		SetErrorMode-: PROCEDURE [WINAPI] (uMode: SET): SET;
		(** The SetEvent function sets the state of the specified event object to signaled. *)
		SetEvent-: PROCEDURE [WINAPI] (hEvent: HANDLE): BOOL;
		(** The SetFileAttributes function sets a file's attributes. *)
		SetFileAttributes-: PROCEDURE [WINAPI] (lpFileName: ARRAY [NOTAG] OF CHAR; dwFileAttributes: SET): BOOL;
		(** The SetFilePointer function moves the file pointer of an open file. *)
		SetFilePointer-: PROCEDURE [WINAPI] (hFile: HANDLE; lDistanceToMove: LONGINT; VAR lpDistanceToMoveHigh: LONGINT; dwMoveMethod: LONGINT): LONGINT;
		(** The SetFileTime function sets the date and time that a file was created, last accessed, or last modified. *)
		SetFileTime-: PROCEDURE [WINAPI] (hFile: HANDLE; lpCreationTime, lpLastAccessTime, lpLastWriteTime: FileTime): BOOL;
		(** The SetLocalTime function sets the current local time and date. *)
		SetLocalTime-: PROCEDURE [WINAPI] (lpSystemTime: SystemTime): BOOL;
		(** The SetThreadContext function sets the context in the specified thread. *)
		SetThreadContext-: PROCEDURE [WINAPI] (hThread: HANDLE; lpContext: Context): BOOL;
		(** The SetThreadPriority function sets the priority value for the specified thread. *)
		SetThreadPriority-: PROCEDURE [WINAPI] (hThread: HANDLE; nPriority: LONGINT): BOOL;
		(** The Sleep function suspends the execution of the current thread for a specified interval. *)
		Sleep-: PROCEDURE [WINAPI] (dwMilliseconds: LONGINT);
		(** The SuspendThread function suspends the specified thread. *)
		SuspendThread-: PROCEDURE [WINAPI] (hThread: HANDLE): LONGINT;
		(** The SystemTimeToFileTime function converts a system time to a file time. *)
		SystemTimeToFileTime-: PROCEDURE [WINAPI] (lpSystemTime: SystemTime; VAR lpFileTime: FileTime): BOOL;
		(** The TerminateThread function terminates a thread. *)
		TerminateThread-: PROCEDURE [WINAPI] (hThread: HANDLE; dwExitCode: LONGINT): BOOL;
		(** The TryEnterCriticalSection function attempts to enter a critical section without blocking. *)
		TryEnterCriticalSection-: PROCEDURE [WINAPI] (VAR lpCriticalSection: CriticalSection): BOOL;
		(** The VirtualAlloc function reserves or commits a region of pages in the virtual address space of the calling process. *)
		VirtualAlloc-: PROCEDURE [WINAPI] (lpAddress: ADDRESS; dwSize: LONGINT; flAllocationType, flProtect: SET): ADDRESS;
		(** The VirtualFree function releases or decommits (or both) a region of pages within the virtual address space of the
			calling process. *)
		VirtualFree-: PROCEDURE [WINAPI] (lpAddress: ADDRESS; dwSize: LONGINT; dwFreeType: SET): BOOL;
		(** The WaitForSingleObject function returns when one of the following occurs:
			The specified object is in the signaled state.
			The time-out interval elapses. *)
		WaitForSingleObject-: PROCEDURE [WINAPI] (hHandle: HANDLE; dwMilliseconds: LONGINT): LONGINT;
		(** The WriteFile function writes data to a file and is designed for both synchronous and asynchronous operation. *)
		WriteFile-: PROCEDURE [WINAPI] (hFile: HANDLE; VAR lpBuffer: ARRAY [NOTAG] OF SYSTEM.BYTE; nNumberOfBytesToWrite: LONGINT; VAR lpNumberOfBytesWritten: LONGINT; lpOverlapped: PTR): BOOL;
		(** Thread abort notifier, parameter is the threads id. Note this should only be used in modules which
			can't use the exception handling mechanism provided by module Exceptions. *)
		(** default exception frame handler *)
		excpFrmHandler*: ExcpFrmHandler;
		(** Method used to write text to the Console. *)
		OutputString*: OutputStringProc;
		Shutdown*: PROCEDURE (code: LONGINT);
		call: LONGINT;

	(** Wrapper for getProcAddress. *)
	PROCEDURE GetProcAddress*(hModule: HMODULE; procName: ARRAY OF CHAR; VAR adr: LONGINT);
	BEGIN
		adr := getProcAddress(hModule, procName)
	END GetProcAddress;

	(** Copy a zero-terminated string from address lpString. *)
	PROCEDURE CopyString*(lpString: LPSTR; VAR str: ARRAY OF CHAR);
		VAR i: LONGINT; ch: CHAR;
	BEGIN
		i := 0;
		IF lpString # NULL THEN
			SYSTEM.GET(lpString, ch);
			WHILE ch # 0X DO
				str[i] := ch; INC(i);
				INC(lpString); SYSTEM.GET(lpString, ch)
			END
		END;
		str[i] := 0X
	END CopyString;

	(* get the currently installed execption frame *)
	PROCEDURE - GetCur 64H, 8BH, 0DH, 0, 0, 0, 0; (* MOV ECX, FS:[0] *)
	PROCEDURE GetCurrent(): ExcpFrmPtr;
		VAR cur: ExcpFrmPtr;
	BEGIN
		GetCur;
		SYSTEM.GETREG(SYSTEM.ECX, cur); (* RETURN ECX *)
		RETURN cur
	END GetCurrent;

	(* install a new exception frame *)
	PROCEDURE - SetCur 64H, 0A3H, 0, 0, 0, 0; (* MOV FS:[0], EAX *)
	PROCEDURE SetCurrent(cur: ExcpFrmPtr);
	BEGIN
		SYSTEM.PUTREG(SYSTEM.EAX, cur); (* EAX := cur *)
		SetCur
	END SetCurrent;

	(** Installs a new new exception frame, note that the exception frame should be
		allocated on the stack of the calling thread. *)
	PROCEDURE [WINAPI] InstallExcpFrm*(VAR e: ExcpFrm);
	BEGIN (* ASSERT e is on stack of caller *)
		e.link := GetCurrent();
		SetCurrent(SYSTEM.VAL(ExcpFrmPtr, SYSTEM.ADR(e)))
	END InstallExcpFrm;

	PROCEDURE [WINAPI] *EmptyExcpFrmHandler(VAR excpRec: ExceptionRecord; excpFrame: ExcpFrmPtr; VAR context: Context; dispatch: LONGINT): LONGINT;
	BEGIN
		RETURN ExceptionContinueSearch
	END EmptyExcpFrmHandler;

	PROCEDURE OutputDebugString*(VAR str: ARRAY OF CHAR);
	BEGIN
		outputDebugString(str)
	END OutputDebugString;

	PROCEDURE Str*(s: ARRAY OF CHAR);
	BEGIN
		IF OutputString # NIL THEN OutputString(s) END
	END Str;

	PROCEDURE Ln*;
		VAR s: ARRAY 4 OF CHAR;
	BEGIN
		IF OutputString # NIL THEN
			s[0] := 0AX; s[1] := 0X; OutputString(s)
		END
	END Ln;

	PROCEDURE IntToStr(i: LONGINT; VAR s: ARRAY OF CHAR);
		VAR k, j, x0: LONGINT; a: ARRAY 10 OF CHAR;
	BEGIN
		k := 0;
		IF i < 0 THEN
			IF i = MIN(LONGINT) THEN
				COPY("-2147483648", s); RETURN
			ELSE
				x0 := -i
			END
		ELSE
			x0 := i
		END;
		REPEAT
			a[k] := CHR(x0 MOD 10 + 30H); x0 := x0 DIV 10; INC(k)
		UNTIL x0 = 0;
		IF i < 0 THEN
			s[0] := "-"; j := 1
		ELSE
			j := 0
		END;
		REPEAT DEC(k); s[j] := a[k]; INC(j) UNTIL k = 0;
		s[j] := 0X
	END IntToStr;

	PROCEDURE Int*(x: LONGINT);
		VAR s: ARRAY 16 OF CHAR;
	BEGIN
		IF OutputString # NIL THEN
			IntToStr(x, s); OutputString(s)
		END
	END Int;

	PROCEDURE Hex*(x: LONGINT);
		VAR s: ARRAY 16 OF CHAR; d, i: LONGINT;
	BEGIN
		IF OutputString # NIL THEN
			s[8] := 0X;
			FOR i := 7 TO 0 BY -1 DO
				d := x MOD 16;
				IF d < 10 THEN s[i] := CHR(d + ORD("0")) ELSE s[i] := CHR(d-10+ORD("A")) END;
				x := x DIV 16
			END;
			OutputString(s)
		END
	END Hex;

	PROCEDURE Init();
		VAR mod: HMODULE;
	BEGIN
		OutputString := OutputDebugString;
		excpFrmHandler := EmptyExcpFrmHandler;
		Shutdown := NIL;
		IF GetVersion() > 0 THEN
			mod := LoadLibrary("Kernel32.DLL");
			GetProcAddress(mod, "TryEnterCriticalSection", SYSTEM.VAL(LONGINT, TryEnterCriticalSection))
		ELSE
			TryEnterCriticalSection := NIL
		END
	END Init;

BEGIN
	IF call = 0 THEN
		INC(call); Init()
	ELSIF Shutdown # NIL THEN
		Shutdown(0)
	END
END Kernel32.
