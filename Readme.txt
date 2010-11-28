Command line version of the ETH Oberon Plugin for Windows 95/98/NT/2000
release 2.4 Portable compiler and linker.

Compiler, linker and kernel by Team of the Institute for Computer Systems
of ETH Zuerich. Copyright 2000 ETH Zuerich Institut fuer Computersysteme,
ETH Zentrum, CH-8092 Zuerich. Refer to the "General ETH Oberon System
Source License" contract available at http://www.oberon.ethz.ch/

Command line wrapper and 'readme' by Eugene Shcherbatyuk

Distribution

Length	File name
----------------------
73 266  cmdlinesrc.zip
49 606  environ.zip
41 090  kernelsrc.zip
179 969 o2ethclc.zip
93 689  o2ethcll.zip
13 312  userguide.zip

Where	o2ethclc.zip   -- compiler executable;
	o2ethcll.zip   -- linker executable;
	cmdlinesrc.zip -- ETH Oberon Plugin source files that were
			  modified to produce command line version
			  of the compiler and linker, namely:

		                 73 055 BootLink.Mod
		                    773 CmdLine.mod
		                    731 Console.Mod
		                  4 501 Fonts.Mod
		                  6 741 O2ETHCLC.Link
		                 12 803 O2ETHCLC.Mod
		                    117 O2ETHCLC.REG
		                  6 696 O2ETHCLL.Link
		                 58 725 O2ETHCLL.Mod
		                 16 327 OPM.Mod
		                 41 237 OPV.Mod

	environ.zip --  ETH Oberon Plugin files that must present in
			the directory where compiler and linker will
			reside, and two sample programs, namely:

		                  1 660 ADVAPI32.Obj
		                 10 886 FileDir.Obj
		                 14 012 Files.Obj
		                  6 485 HelloCon.Link
		                    114 HelloCon.Mod
		                    177 HelloCon.Obj
		                    105 HelloCon.reg
		                  5 762 HelloGUI.Link
		                    191 HelloGUI.mod
		                    239 HelloGUI.Obj
		                 12 197 Kernel.Obj
		                 14 507 Kernel32.Obj
		                 16 474 Modules.Obj
		                    117 O2ETHCLC.REG
		                    766 Oberon.ico
		                  8 658 OP2.Errors
		                 13 951 OPA.Data
		                  7 776 Registry.Obj
		                    128 stub.exe
		                    530 USER32.MOD
		                    425 User32.Obj

	kernel.zip  --    ETH Oberon Plugin source of the core
			  files which should be linked to the user
			  program to produce executable.
	userguide.zip --  An excerpt from ETH Oberon Plugin documentation.

Notes on usage

Unpack zip files into destination directory.
Merge o2ethclc.reg into your computer registry.
Test the work of compiler and linker using sample programs:

a) compile sample programs

o2ethclc hellocon.mod
o2ethclc user32.mod
o2ethclc hellogui.mod

b) link sample programs

o2ethcll hellocon.link
o2ethcll hellogui.link

c) merge hellocon.reg into your computer registry

d) run programs

hello.exe
hellog.exe

e) run compiler and linker with /? switch to read breaf help information.

Documentation

Please read

- General ETH Oberon System Source License (not included)
- ETH Oberon Plugin for Windows User Guide (included)
- ETH Oberon Plugin for Windows documentation (not included)
- Source code of core files will help as well. (included)

Known bugs and limitations

HALT and ASSERT statements are not handled properly. They cause
application errors. You can see that when linker will not find
some of the nessecary files in the current directory. Note, please,
linker will report, say, 'advapi32 not found' and cause windows
application error. That is not an error indeed. That is unhandled
exception caused by issuing HALT command within linker code.

