Command line version of the ETH Oberon Plugin for Windows 95/98/NT/2000
release 2.4 Portable compiler and linker.

Compiler, linker and kernel by Team of the Institute for Computer Systems
of ETH Zuerich. Copyright 2000 ETH Zuerich Institut fuer Computersysteme,
ETH Zentrum, CH-8092 Zuerich. Refer to the "General ETH Oberon System
Source License" contract available at http://www.oberon.ethz.ch/

Command line wrapper and 'readme' by Eugene Shcherbatyuk

Notes on usage

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

Known bugs and limitations

HALT and ASSERT statements are not handled properly. They cause
application errors. You can see that when linker will not find
some of the nessecary files in the current directory. Note, please,
linker will report, say, 'advapi32 not found' and cause windows
application error. That is not an error indeed. That is unhandled
exception caused by issuing HALT command within linker code.
