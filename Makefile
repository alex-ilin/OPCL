# This is GNU makefile. (c) Alexander Iljin (ajsoft@yandex.ru), December 2010.
# Run 'make' to make the projects.

# List of subfolders to make.
Projects := Samples Src

# Declare some phony targets for optimization.
.PHONY: clean default $(Projects)

# Build all projects by deafult.
default: $(Projects)

# To make a project, call Make in that project's folder. This rule is suitable
# for parallel execution (run 'make -j 2').
$(Projects):
	$(MAKE) -C $@

# Run 'make clean' for all projects.
clean:
	for %%P in ($(Projects)) do $(MAKE) clean -C %%P
