MODULE HelloGUI;
		IMPORT User32;
BEGIN
	User32.MessageBox(User32.HWNDDesktop,
					 "Hello from Oberon!",
					 "HELLO", 
					  User32.MBOk + User32.MBIconExclamation);
END HelloGUI.
