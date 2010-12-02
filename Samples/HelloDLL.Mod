MODULE HelloDLL;
		IMPORT User32;

	PROCEDURE Do;
	BEGIN
		User32.MessageBox(User32.HWNDDesktop,
					 "Hello from Oberon!",
					 "HELLO",
					  User32.MBOk + User32.MBIconExclamation);
	END Do;

END HelloDLL.
