
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsPlayerAlive(client) || IsFakeClient(client) || !iEnabledPlugin) {
		return;	
	}
	
	if(iEnableCookie) {
		if(!AreClientCookiesCached(client)) {
			return;	
		}
	}
	
	DataPack hEquipWeapon;
	CreateDataTimer(0.1, Timer_EquipWeapon, hEquipWeapon, TIMER_DATA_HNDL_CLOSE);
	hEquipWeapon.WriteCell(client);
}
