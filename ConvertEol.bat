rem F = Folder, M = Module
for %%F in (Samples Src) do for %%M in (%%F\*.Mod) do sed -i -e "s/\r/\n/g" %%M
