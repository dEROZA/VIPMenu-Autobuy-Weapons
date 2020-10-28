
public void OnClientPutInServer(int client) {
	if(IsFakeClient(client)) {
		return;
	}
	InvalidateVariables(client);
}

public void OnClientPostAdminCheck(int client) {
	if(IsFakeClient(client)) {
		return;
	}
	if(iEnableCookie) {
		if(AreClientCookiesCached(client)) {
			RetriveCookies(client);
		}
		else {
			DataPack hCookieCacher;
			CreateDataTimer(1.0, Timer_CookieCacher, hCookieCacher, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			hCookieCacher.WriteCell(client);
		}
	}
}

public void OnClientCookiesCached(int client) {
	if(IsFakeClient(client)) {
		return;
	}
	// At first cookie will be cahced, than each other, like putinserver, postadmincheks..
}

public void OnClientDisconnect(int client) {
	if(IsFakeClient(client)) {
		return;
	}
	if(iEnableCookie) {
		SaveCookies(client);
	}
	
	InvalidateVariables(client);
}
