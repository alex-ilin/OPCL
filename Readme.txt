Command line version of the ETH Oberon Plugin for Windows 95/98/NT/2000
release 2.4 Portable compiler and linker.

Compiler, linker and kernel by Team of the Institute for Computer Systems
of ETH Zuerich. Copyright 2000 ETH Zuerich Institut fuer Computersysteme,
ETH Zentrum, CH-8092 Zuerich. Refer to the "General ETH Oberon System
Source License" contract available at http://www.oberon.ethz.ch/

Command line wrapper and 'readme' by Eugene Shcherbatyuk.
Current maintainer: Alexander Iljin <ajsoft@yandex.ru>.
Contributors:
	Kemet (elbrusstudio —Œ¡¿ ¿ mail “Œ◊ ¿ ru)

Notes on usage

Merge Src\o2ethclc.Reg into your computer registry.
Test the work of compiler and linker using sample programs:

a) compile and link the compiler, linker and sample programs

CompileAndLink.bat

b) merge Samples\HelloCon.Reg into your computer registry

c) run programs

Samples\HelloCon.exe
Samples\HelloGUI.exe
Samples\HelloDLL.exe

d) run compiler and linker with /? switch to read brief help information.

If you have GNU Make and tr installed, then you can simply run 'make' for
compilation and linking.

Known bugs and limitations

HALT and ASSERT statements are not handled properly. They cause
application errors. You can see that when linker will not find
some of the nessecary files in the current directory. Note, please,
linker will report, say, 'advapi32 not found' and cause windows
application error. That is not an error indeed. That is unhandled
exception caused by issuing HALT command within linker code.

History

03 Dec 2010, v0.2
- Add full sources, made compiler and linker self-compilable
- Add Makefiles for GNU Make and CompileAndLink.bat files
- Add Linker '/d' option
- Add HelloDLL sample projects
- EOL converted to Windows CRLF, removed binary file headers
- Fix inline assembler (OPA.Mod) LF and comment handling
- Update documentation
- GitHub hosting: https://github.com/AlexIljin/OPCL

?? Nov 2002, v0.1
- Initial release by Eugene Shcherbatyuk.
