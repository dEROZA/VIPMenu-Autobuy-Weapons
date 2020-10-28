
public Action Timer_CookieCacher(Handle timer, DataPack pack) {
	
	pack.Reset(); int client = pack.ReadCell();
	
	if(!client || client > 64 || !iEnableCookie) {
		return Plugin_Stop;
	}
	if(IsFakeClient(client)) {
		return Plugin_Stop;
	}
	
	if(AreClientCookiesCached(client)) {
		RetriveCookies(client);
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action Timer_EquipWeapon(Handle timer, DataPack pack) {
	
	pack.Reset(); int client = pack.ReadCell();
	
	if(!client || client > 64) {
		return Plugin_Stop;
	}
	
	EuipTheAutobuyWeapons(client);
	EuipItems(client);
	return Plugin_Continue;
}
