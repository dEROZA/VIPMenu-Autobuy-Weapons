
public Action Command_AccessViewer(int client, int args) {
	if(client == 0) {
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Command_SayChat(int client, int args) {
	char text[256];
	GetCmdArgString(text, sizeof(text));
	
	if((StrContains(text,"!buy",false) < 0) && (StrContains(text,"!weapons",false) < 0)) {
		return Plugin_Continue;
	}
	
	mHeadMenu = Builder_HeadMenu(client);
	if(mHeadMenu != INVALID_HANDLE) {
		mHeadMenu.Display(client, 10);
	}
	
	return Plugin_Continue;
}
