#pragma semicolon 1
#pragma newdecls required

#include <cstrike>
#include <sourcemod>

#include <sdktools>
#include <sdkhooks>

#include <clientprefs>

#define PLUGIN_VERSION "1.2.15"

#define CS_TT_WEAPON 0
#define CS_CT_WEAPON 1

#define CS_ITEM_ARMOR 2
#define CS_ITEM_DEFUSER 3

Handle hEnabledPlugin, hActivePlayers, hEnableCookie, hPriceCostPercentage, hFullEquipOnWarmup;
int iEnabledPlugin, iActivePlayers, iEnableCookie, iPriceCostPercentage, iFullEquipOnWarmup;

Handle hPrimaryWeapon, hPrimaryAutobuy, hSecondaryWeapon, hSecondaryAutobuy, hArmorAutobuy, hDefuserAutobuy;

bool AutoBuyState[64][4];
CSWeaponID AutoBuyWeapons[64][2];

int m_hMyWeapons;

static char Primary[][] = {
	"weapon_ak47",
	"weapon_m4a1",
	"weapon_m4a1_silencer",
	"weapon_sg556",
	"weapon_aug",
	"weapon_ssg08",
	"weapon_scar20",
	"weapon_g3sg1",
	"weapon_awp",
	"weapon_galilar",
	"weapon_famas",
	"weapon_m249",
	"weapon_negev",
	"weapon_mac10",
	"weapon_mp9",
	"weapon_ump45",
	"weapon_bizon",
	"weapon_mp7",
	"weapon_p90",
	"weapon_nova",
	"weapon_sawedoff",
	"weapon_mag7",
	"weapon_xm1014"
};

static char Secondary[][] = {
	"weapon_glock",
	"weapon_usp_silencer",
	"weapon_hkp2000",
	"weapon_p250",
	"weapon_deagle",
	"weapon_revolver",
	"weapon_fiveseven",
	"weapon_elite",
	"weapon_tec9",
	"weapon_cz75a"
};

static char Items[][] = {
	"",
	"",
	"item_assaultsuit",
	"item_defuser"
};

static char Grenades[][] = {
	"weapon_incgrenade",
	"weapon_molotov",
	"weapon_hegrenade",
	"weapon_smokegrenade",
	"weapon_flashbang",
	"weapon_decoy"
};

Menu mHeadMenu = null;
Menu mPrimaryWeapons = null;
Menu mSecondaryWeapons = null;

ConVar gcDefaultWeapons[2];
char sDefaultWeapons[2][32];
CSWeaponID cswDefaultWeapID[2];

ConVar gcGrenadeCount;
int iGrenadeCount;

stock bool IsEmptyTeamScore() {
	return (!CS_GetTeamScore(CS_TEAM_T) && !CS_GetTeamScore(CS_TEAM_CT));
}

stock bool IsWarmup() {
	return (GameRules_GetProp("m_bWarmupPeriod") == 1);
}

stock bool IsFullEquipOnWarmupCondition() {
	return (IsWarmup() && iFullEquipOnWarmup);
}

stock void StringToLU(char[] input, bool state = false) {
    int len = strlen(input);
    for (int i = 0; i <= len; ++i) {
       input[i] = !state ? CharToLower(input[i]) : CharToUpper(input[i]);
	}
}

stock void GetWeaponIDSinString(int client, char[] input, int size, int weaponclass) {
	char WeaponIdStr[4]; IntToString(view_as<int>(AutoBuyWeapons[client][weaponclass]), WeaponIdStr, sizeof(WeaponIdStr));
	strcopy(input, size, WeaponIdStr);
}

stock void GetMenuWeapons(int client, char[] input, int size, int weaponclass) {
	
	char WeaponAlias[32]; CS_WeaponIDToAlias(AutoBuyWeapons[client][weaponclass], WeaponAlias, sizeof(WeaponAlias));
	char WeaponName[32]; CS_GetTranslatedWeaponAlias(WeaponAlias, WeaponName, sizeof(WeaponName)); StringToLU(WeaponName, true);
	
	Format(input, size, "%s in autobuy", WeaponName);
}

stock void AddMenuItemsToBuyMenu(Menu menu, int weaponclass) {
	
	if(menu == null || menu == INVALID_HANDLE) {
		return;
	}
	
	for(int i=0;i < (!weaponclass ? sizeof(Primary) : sizeof(Secondary)); ++i) {
		char WeaponIdStr[4]; CSWeaponID WeaponCSID = CS_AliasToWeaponID((!weaponclass ? Primary[i] : Secondary[i]));
		IntToString(view_as<int>(WeaponCSID), WeaponIdStr, sizeof(WeaponIdStr));
		
		char WeaponName[32]; CS_GetTranslatedWeaponAlias((!weaponclass ? Primary[i] : Secondary[i]), WeaponName, sizeof(WeaponName));
		
		menu.AddItem(WeaponIdStr, WeaponName);
	}
}

stock int GetUserMoney(int client) {
    return GetEntProp(client, Prop_Send, "m_iAccount");
}

stock void SetUserMoney(int client, int money) {
    SetEntProp(client, Prop_Send, "m_iAccount", money);
} 

stock void DropExistsWeapon(int client, int slot) {
	int ent; if((ent = GetPlayerWeaponSlot(client, slot)) != -1) {
		CS_DropWeapon(client, ent, true, true);
	}
}

stock void SaveCookies(int client) {
	char sCookieValue[4]; int size = sizeof(sCookieValue);
	
	IntToString(AutoBuyState[client][CS_SLOT_PRIMARY], sCookieValue, size);
	SetClientCookie(client, hPrimaryAutobuy, sCookieValue);
	
	IntToString(AutoBuyState[client][CS_SLOT_SECONDARY], sCookieValue, size);
	SetClientCookie(client, hSecondaryAutobuy, sCookieValue);
	
	IntToString(view_as<int>(AutoBuyWeapons[client][CS_SLOT_PRIMARY]), sCookieValue, size);
	SetClientCookie(client, hPrimaryWeapon, sCookieValue);
	
	IntToString(view_as<int>(AutoBuyWeapons[client][CS_SLOT_SECONDARY]), sCookieValue, size);
	SetClientCookie(client, hSecondaryWeapon, sCookieValue);
	
	IntToString(AutoBuyState[client][CS_ITEM_ARMOR], sCookieValue, size);
	SetClientCookie(client, hArmorAutobuy, sCookieValue);
	
	IntToString(AutoBuyState[client][CS_ITEM_DEFUSER], sCookieValue, size);
	SetClientCookie(client, hDefuserAutobuy, sCookieValue);
}

stock void RetriveCookies(int client) {
	if(IsFakeClient(client)) {
		return;
	}
	
	char sCookieValue[4];
	
	GetClientCookie(client, hPrimaryAutobuy, sCookieValue, sizeof(sCookieValue));
	AutoBuyState[client][CS_SLOT_PRIMARY] = view_as<bool>(StringToInt(sCookieValue));
	
	GetClientCookie(client, hSecondaryAutobuy, sCookieValue, sizeof(sCookieValue));
	AutoBuyState[client][CS_SLOT_SECONDARY] = view_as<bool>(StringToInt(sCookieValue));
	
	GetClientCookie(client, hPrimaryWeapon, sCookieValue, sizeof(sCookieValue));
	AutoBuyWeapons[client][CS_SLOT_PRIMARY] = view_as<CSWeaponID>(StringToInt(sCookieValue));
	
	GetClientCookie(client, hSecondaryWeapon, sCookieValue, sizeof(sCookieValue));
	AutoBuyWeapons[client][CS_SLOT_SECONDARY] = view_as<CSWeaponID>(StringToInt(sCookieValue));
	
	GetClientCookie(client, hArmorAutobuy, sCookieValue, sizeof(sCookieValue));
	AutoBuyState[client][CS_ITEM_ARMOR] = view_as<bool>(StringToInt(sCookieValue));
	
	GetClientCookie(client, hDefuserAutobuy, sCookieValue, sizeof(sCookieValue));
	AutoBuyState[client][CS_ITEM_DEFUSER] = view_as<bool>(StringToInt(sCookieValue));
}

stock int GivePlayerItem2(int iClient, const char[] chItem) {
	int iTeam = GetClientTeam(iClient);
	SetEntProp(iClient, Prop_Send, "m_iTeamNum", CS_TEAM_SPECTATOR);

	int ent = GivePlayerItem(iClient, chItem);
	SetEntProp(iClient, Prop_Send, "m_iTeamNum", iTeam);

	return ent;
} 

stock void InvalidateVariables(int client) {
	for(int i = CS_SLOT_PRIMARY; i <= CS_SLOT_SECONDARY; ++i) {
		AutoBuyWeapons[client][i] = CSWeapon_NONE;
		AutoBuyState[client][i] = false;
	}
	for(int i = CS_ITEM_ARMOR; i <= CS_ITEM_DEFUSER; ++i) {
		AutoBuyState[client][i] = false;
	}
}

stock int ProcessWeapons(int client, int selected, int weaponclass) {
	if(IsPlayerAlive(client)) {
		
		int iHalfPrice = RoundToNearest(CS_GetWeaponPrice(client, AutoBuyWeapons[client][weaponclass]) * iPriceCostPercentage / 100.0); 
		int iMoney = GetUserMoney(client);
		
		if(iMoney >= iHalfPrice) {
			SetUserMoney(client, iMoney-iHalfPrice);
			int ent; if((ent = GetPlayerWeaponSlot(client, weaponclass)) != -1) {
				CS_DropWeapon(client, ent, true, true);
			}
			return GivePlayerItem2(client, (!weaponclass ? Primary[selected] : Secondary[selected]));
		}
	}
	return 0;
}

stock void EuipItems(int client) {
	for(int i = CS_ITEM_ARMOR; i <= CS_ITEM_DEFUSER; ++i) {
		
		if(!AutoBuyState[client][i]) {
			continue;
		}
		
		if(GetClientTeam(client) != CS_TEAM_CT && i == CS_ITEM_DEFUSER) {
			continue;
		}
		
		if(GetEntProp(client, Prop_Send, "m_bHasDefuser") && i == CS_ITEM_DEFUSER) {
			continue;
		}
		
		if(IsEmptyTeamScore() && !IsFullEquipOnWarmupCondition()) {
			continue;
		}
		
		int iHalfPrice = RoundToNearest((i == CS_ITEM_ARMOR ? 650 : 400) * iPriceCostPercentage / 100.0); 
		int iMoney = GetUserMoney(client);
		
		if(iMoney < iHalfPrice && !IsFullEquipOnWarmupCondition()) {
			continue;
		}
		
		GivePlayerItem(client, Items[i]);
		
		if(i == CS_ITEM_ARMOR) {
			SetEntProp(client, Prop_Send, "m_ArmorValue", 100, 1);
		}
	}
	
	if(IsFullEquipOnWarmupCondition()) {
		for(int i = 1, iEnd = sizeof(Grenades)-1; i <= iEnd, iEnd && iEnd <= iGrenadeCount; ++i) {
			GivePlayerItem(client, Grenades[(
				i == 1 ? (GetClientTeam(client) == CS_TEAM_CT ? CS_TT_WEAPON : CS_CT_WEAPON) : i
			)]);
		}
	}
}

stock void EuipTheAutobuyWeapons(int client) {
	for(int i = CS_SLOT_PRIMARY; i <= CS_SLOT_SECONDARY; ++i) {
		
		if(!AutoBuyWeapons[client][i]) {
			continue;
		}
		
		int iHalfPrice = RoundToNearest(CS_GetWeaponPrice(client, AutoBuyWeapons[client][i]) * iPriceCostPercentage / 100.0); 
		int iMoney = GetUserMoney(client);
		
		if(iMoney < iHalfPrice && !IsFullEquipOnWarmupCondition()) {
			continue;
		}
		
		int ent; if((ent = GetPlayerWeaponSlot(client, i)) != -1) {
		
			int iItemDefIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
			CSWeaponID SlotCSWID = CS_ItemDefIndexToID(iItemDefIndex);
			
			/* int iTeam = GetClientTeam(client)-2;
			PrintToServer("%N(Team: %d) => AutoBuyWeapons[client][i]: %d, LoadOut: %d:%d (sDefaultWeapons: %s)", 
				client, 
				GetClientTeam(client), 
				AutoBuyWeapons[client][i], 
				SlotCSWID,
				cswDefaultWeapID[iTeam],
				sDefaultWeapons[iTeam]
			); */
			// Alex Deroza(Team: 3) => AutoBuyWeapons[client][i]: 41, LoadOut: 61:41 (sDefaultWeapons: weapon_hkp2000)
			
			if(i == CS_SLOT_SECONDARY && SlotCSWID != AutoBuyWeapons[client][i]) {
				CS_DropWeapon(client, ent, true, true);
			}
			else {
				continue;
			}
		}
		
		SetUserMoney(client, iMoney-iHalfPrice);
		
		char sEapon[25]; 
		static char sW[32] = "weapon_"; 
		
		CS_WeaponIDToAlias(AutoBuyWeapons[client][i], sEapon, sizeof(sEapon));
		strcopy(sW[7], sizeof(sW), sEapon);
		
		GivePlayerItem2(client, sW);
	}
}

stock void WeaponMenuActions(int client, int weaponclass, int selected) {
	AutoBuyWeapons[client][weaponclass] = CS_AliasToWeaponID( !weaponclass ? Primary[selected] : Secondary[selected]);
	ProcessWeapons(client, selected, weaponclass);
}

public Plugin myinfo = {
	name = "Autobuy weapon menus",
	author = "Alex Deroza (KGB1st)",
	description = "Autobuy weapon menus",
	version = PLUGIN_VERSION,
	url = "https://ranks.moonsiber.org/"
};

public void OnPluginStart() {
	
	hEnabledPlugin = CreateConVar("sm_autobuy_wpn_enabled", "1", "Enables vip weapons menus", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	hActivePlayers = CreateConVar("sm_autobuy_accessed_players", "10", "Acess to menus", FCVAR_PROTECTED, true, 1.0, true, 64.0);
	hEnableCookie = CreateConVar("sm_autobuy_enables_cookie", "1", "Does cookie will be used", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	hPriceCostPercentage = CreateConVar("sm_price_cost_percentage", "50", "Weapon pricing cost percentage", FCVAR_PROTECTED, true, 1.0, true, 100.0);
	hFullEquipOnWarmup = CreateConVar("sm_full_equip_onwarmup", "1", "Enables fully equipment on warmup", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	iEnabledPlugin = GetConVarInt(hEnabledPlugin);
	iActivePlayers = GetConVarInt(hActivePlayers);
	iEnableCookie = GetConVarInt(hEnableCookie);
	iPriceCostPercentage = GetConVarInt(hPriceCostPercentage);
	iFullEquipOnWarmup = GetConVarInt(hFullEquipOnWarmup);
	
	HookConVarChange(hEnabledPlugin, ConvarChange_EnableedPlugin);
	HookConVarChange(hActivePlayers, ConvarChange_ActivePlayers);
	HookConVarChange(hEnableCookie, ConvarChange_UseCookie);
	HookConVarChange(hPriceCostPercentage, ConvarChange_PriceCostPercentage);
	HookConVarChange(hFullEquipOnWarmup, ConvarChange_FullEquipOnWarmup);
	
	gcDefaultWeapons[CS_TT_WEAPON] = FindConVar("mp_t_default_secondary");
	gcDefaultWeapons[CS_TT_WEAPON].GetString(sDefaultWeapons[CS_TT_WEAPON], sizeof(sDefaultWeapons[]));
	cswDefaultWeapID[CS_TT_WEAPON] = CS_AliasToWeaponID(sDefaultWeapons[CS_TT_WEAPON]);
	
	gcDefaultWeapons[CS_CT_WEAPON] = FindConVar("mp_ct_default_secondary");
	gcDefaultWeapons[CS_CT_WEAPON].GetString(sDefaultWeapons[CS_CT_WEAPON], sizeof(sDefaultWeapons[]));
	cswDefaultWeapID[CS_CT_WEAPON] = CS_AliasToWeaponID(sDefaultWeapons[CS_CT_WEAPON]);
	
	gcGrenadeCount = FindConVar("ammo_grenade_limit_total");
	char sGrenadeCount[4]; gcGrenadeCount.GetString(sGrenadeCount, sizeof(sGrenadeCount));
	iGrenadeCount = StringToInt(sGrenadeCount);
	
	RegConsoleCmd("say", Command_SayChat);
	RegConsoleCmd("say_team", Command_SayChat);	
	
	RegAdminCmd("sm_autobuy_weapons", Command_AccessViewer, ADMFLAG_GENERIC|ADMFLAG_ROOT|ADMFLAG_CUSTOM6, "Usage command sm_autobuy_weapons");
	
	if((m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons")) == -1) {
        char Error[128];
        FormatEx(Error, sizeof(Error), "FATAL ERROR m_hMyWeapons [%d]. Please contact the author.", m_hMyWeapons);
        SetFailState(Error);
    }
	
	hPrimaryWeapon = RegClientCookie("primary_weapon", "Primary Weapon", CookieAccess_Protected);
	hPrimaryAutobuy = RegClientCookie("primary_autobuy", "Primary Autobuy", CookieAccess_Protected);
	
	hSecondaryWeapon = RegClientCookie("secondary_weapon", "Secondary Weapon", CookieAccess_Protected);
	hSecondaryAutobuy = RegClientCookie("secondary_autobuy", "Secondary Autobuy", CookieAccess_Protected);
	
	hArmorAutobuy = RegClientCookie("armor_autobuy", "Armor Autobuy", CookieAccess_Protected);
	hDefuserAutobuy = RegClientCookie("defuser_autobuy", "Defuser Autobuy", CookieAccess_Protected);
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	AutoExecConfig();
}

#include "./weapon_menus/posts.c"

#include "./weapon_menus/commands.c"
#include "./weapon_menus/convars.c"

Menu Builder_HeadMenu(int client) {
	Menu menu = new Menu(HeadMenu);
	
	char WeaponIdStr[4];
	char buf[128];
	
	if(AutoBuyState[client][CS_SLOT_PRIMARY] && view_as<int>(AutoBuyWeapons[client][CS_SLOT_PRIMARY])) {
		GetWeaponIDSinString(client, WeaponIdStr, sizeof(WeaponIdStr), CS_SLOT_PRIMARY);
		GetMenuWeapons(client, buf, sizeof(buf), CS_SLOT_PRIMARY);
		
		menu.AddItem(WeaponIdStr, buf);
	}
	else {
		menu.AddItem("Select primary autobuy", "Select primary autobuy");
	}
	
	if(AutoBuyState[client][CS_SLOT_SECONDARY] && view_as<int>(AutoBuyWeapons[client][CS_SLOT_SECONDARY])) {
		GetWeaponIDSinString(client, WeaponIdStr, sizeof(WeaponIdStr), CS_SLOT_SECONDARY);
		GetMenuWeapons(client, buf, sizeof(buf), CS_SLOT_SECONDARY);
		
		menu.AddItem(WeaponIdStr, buf);
	}
	else {
		menu.AddItem("Select secondary autobuy", "Select secondary autobuy");
	}
	
	menu.AddItem("", "", ITEMDRAW_SPACER);
	
	Format(buf, sizeof(buf), "%s primary autobuy", AutoBuyState[client][CS_SLOT_PRIMARY] ? "Disable" : "Enable");
	menu.AddItem("", buf);
	
	Format(buf, sizeof(buf), "%s secondary autobuy", AutoBuyState[client][CS_SLOT_SECONDARY] ? "Disable" : "Enable");
	menu.AddItem("", buf);
	
	menu.AddItem("", "", ITEMDRAW_SPACER);
	
	Format(buf, sizeof(buf), "%s armor autobuy", AutoBuyState[client][CS_ITEM_ARMOR] ? "Disable" : "Enable");
	menu.AddItem("", buf);
	
	Format(buf, sizeof(buf), "%s defuser autobuy", AutoBuyState[client][CS_ITEM_DEFUSER] ? "Disable" : "Enable");
	menu.AddItem("", buf);
	
	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = true;
	
	menu.SetTitle("                          ");
	
	return menu;
}

Menu Builder_AutobuyMenu(int slot) {
	Menu menu = new Menu(!slot ? PrimaryWeapons : SecondaryWeapons);
	
	AddMenuItemsToBuyMenu(menu, slot);
	
	char buf[128];
	Format(buf, sizeof(buf), "%s weapon menu", !slot ? "Primary" : "Secondary");
	menu.SetTitle(buf);
	
	return menu;
}

public int HeadMenu(Menu menu, MenuAction action, int param1, int param2) {
	if(action == MenuAction_Select) {
		
		int selected = param2;
		
		switch(selected) {
			
			case 0: {
				mPrimaryWeapons = Builder_AutobuyMenu(CS_SLOT_PRIMARY);
				if(mPrimaryWeapons != INVALID_HANDLE) {
					if(mHeadMenu != INVALID_HANDLE) {
						delete mHeadMenu;
					}
					mPrimaryWeapons.Display(param1, 15);
				}
			}
			
			case 1: {
				mSecondaryWeapons = Builder_AutobuyMenu(CS_SLOT_SECONDARY);
				if(mSecondaryWeapons != INVALID_HANDLE) {
					if(mHeadMenu != INVALID_HANDLE) {
						delete mHeadMenu;
					}
					mSecondaryWeapons.Display(param1, 15);
				}
			}
			
			case 3: {
				AutoBuyState[param1][CS_SLOT_PRIMARY] = !AutoBuyState[param1][CS_SLOT_PRIMARY];
				mHeadMenu = Builder_HeadMenu(param1);
				if(mHeadMenu != INVALID_HANDLE) {
					mHeadMenu.Display(param1, 10);
				}
			}
			
			case 4: {
				AutoBuyState[param1][CS_SLOT_SECONDARY] = !AutoBuyState[param1][CS_SLOT_SECONDARY];
				mHeadMenu = Builder_HeadMenu(param1);
				if(mHeadMenu != INVALID_HANDLE) {
					mHeadMenu.Display(param1, 10);
				}
			}
			
			case 6: {
				AutoBuyState[param1][CS_ITEM_ARMOR] = !AutoBuyState[param1][CS_ITEM_ARMOR];
				mHeadMenu = Builder_HeadMenu(param1);
				if(mHeadMenu != INVALID_HANDLE) {
					mHeadMenu.Display(param1, 10);
				}
			}
			
			case 7: {
				AutoBuyState[param1][CS_ITEM_DEFUSER] = !AutoBuyState[param1][CS_ITEM_DEFUSER];
				mHeadMenu = Builder_HeadMenu(param1);
				if(mHeadMenu != INVALID_HANDLE) {
					mHeadMenu.Display(param1, 10);
				}
			}
		}
    }
}

public int PrimaryWeapons(Menu menu, MenuAction action, int param1, int param2) {
    if(action == MenuAction_Select) {
		
		int selected = param2;
		
		WeaponMenuActions(param1, CS_SLOT_PRIMARY, selected);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int SecondaryWeapons(Menu menu, MenuAction action, int param1, int param2) {
    if(action == MenuAction_Select) {
		
		int selected = param2;
		
		WeaponMenuActions(param1, CS_SLOT_SECONDARY, selected);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

#include "./weapon_menus/events.c"
#include "./weapon_menus/timers.c"

