MODULE HelloGUI;
		IMPORT User32, Kernel32;
BEGIN
	User32.MessageBox(User32.HWNDDesktop,
					 "Hello from Oberon!",
					 "HELLO", 
					  User32.MBOk + User32.MBIconExclamation);
	Kernel32.Shutdown(0);
END HelloGUI.
