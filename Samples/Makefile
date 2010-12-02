# This is GNU makefile. (c) Alexander Iljin (ajsoft@yandex.ru), November 2010.
# Run 'make' to make the projects.

# Projects = space separated list of the exe-files to build
Projects := HelloCon.exe HelloGUI.exe HelloDLL.dll HelloDLL.exe
# Platform = file name prefix for the target platform modules
Platform := Win32
# Compiler name to be used
Compiler := o2ethclc.exe
# Compiler options: W = enable warnings, 2 = compile as Oberon-2 language
CompilerOptions := @W2
# Linker name to be used
Linker := o2ethcll.exe

# Declare some phony targets for optimization.
.PHONY: clean default

# First rule will be made by default. Make all projects using default commands.
default: $(Projects)

# Every exe-project will have its dependencies listed in a Make-file; include
# those files as part of this file.
include $(addsuffix .Make,$(Projects))

# The following rule will update Make-files based on the contents of the
# Link-files. For every project listed in the Projects variable there will be a
# Make-file included. When a file is included, the GNU Make tries to update it,
# and this rule is exactly for the purpose. It will generate the Make-file by
# parsing the Link-file and listing its dependencies as Obj-files, icons and
# cursors.
%.Make: %.Link
   # Output prerequisite name.
	echo $*: >$@.tmp
	$(Linker) $< /d >>$@.tmp
   # Tr removes EOL characters (\12 = LF, \15 = CR) and compresses consecutive
   # spaces.
	tr -ds \12\15 " " <$@.tmp >$@
	del $@.tmp

# There are two rules to make Obj-files. The first one simply expects a
# Mod-file of the same name. If there is no such file, the second rule is used.
%.Obj: %.Mod
	$(Compiler) $< $(CompilerOptions)

# The second rule expects a Win32.Name.Mod file, where "Win32" is the target
# platform name (the Platform variable specified above) and "Name" is the name
# of the Obj-file to be created.
%.Obj: $(Platform).%.Mod
	$(Compiler) $< $(CompilerOptions)

# To make exe- or dll-file we need the Link-file. The latter is passed to the
# Linker. The list of Obj-file dependencies specific to a project is
# automatically generated and included as Project.Make file.
%.exe: %.exe.Link
	$(Linker) $<

%.dll: %.dll.Link
	$(Linker) $<

# Run 'make clean' to remove everything but the sources.
clean:
	del *.Obj *.Make $(Projects)
