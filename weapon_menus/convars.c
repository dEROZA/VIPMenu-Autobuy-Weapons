
public void ConvarChange_EnableedPlugin(Handle cvar, const char[] oldVal, const char[] newVal) 
{
	iEnabledPlugin = GetConVarInt(hEnabledPlugin);
}

public void ConvarChange_ActivePlayers(Handle cvar, const char[] oldVal, const char[] newVal) 
{
	iActivePlayers = GetConVarInt(hActivePlayers);
}

public void ConvarChange_UseCookie(Handle cvar, const char[] oldVal, const char[] newVal) 
{
	iEnableCookie = GetConVarInt(hEnableCookie);
}

public void ConvarChange_PriceCostPercentage(Handle cvar, const char[] oldVal, const char[] newVal) 
{
	iPriceCostPercentage = GetConVarInt(hPriceCostPercentage);
}

public void ConvarChange_FullEquipOnWarmup(Handle cvar, const char[] oldVal, const char[] newVal) 
{
	iFullEquipOnWarmup = GetConVarInt(hFullEquipOnWarmup);
}
