
#pragma semicolon 1
#pragma tabsize 0
#define DEBUG
#define TIMER_FLAG_NO_MAPCHANGE (1<<1)   

#define PLUGIN_AUTHOR "steamId=crackersarenoice"
#define PLUGIN_VERSION "1.03"
#define PLAYERBUILTOBJECT_ID_DISPENSER 0
#define PLAYERBUILTOBJECT_ID_TELENT    1
#define PLAYERBUILTOBJECT_ID_TELEXIT   2
#define PLAYERBUILTOBJECT_ID_SENTRY    3

#define TF_CLASS_DEMOMAN		4
#define TF_CLASS_ENGINEER		9
#define TF_CLASS_HEAVY			6
#define TF_CLASS_MEDIC			5
#define TF_CLASS_PYRO				7
#define TF_CLASS_SCOUT			1
#define TF_CLASS_SNIPER			2
#define TF_CLASS_SOLDIER		3
#define TF_CLASS_SPY				8
#define TF_CLASS_UNKNOWN		0

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <clientprefs>

//Handles
new Handle:zm_tDalgasuresi = INVALID_HANDLE;
new Handle:zm_tHazirliksuresi = INVALID_HANDLE;
new Handle:zm_hTekvurus = INVALID_HANDLE;
new Handle:MusicCookie;
new Handle:g_hTimer = INVALID_HANDLE;
new Handle:g_hSTimer = INVALID_HANDLE;
//bools
new bool:g_bOyun;
new bool:getrand = false;
new bool:g_bOnlyZMaps;
//ints
new g_iSetupCount;
new g_iDalgaSuresi;
new bool:g_bKazanan;
new g_maxHealth[10] =  { 0, 125, 125, 200, 175, 150, 300, 175, 125, 125 };
new g_iMapPrefixType = 0;

public Plugin:myinfo = 
{
	name = "Zombie Escape/Survival", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		Format(error, err_max, "This plug-in only works for Team Fortress 2. // Eklenti sadece Team Fortress 2 için tasarlandı.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}
//Ayarların yüklenmesi.
public OnMapStart()
{
	zombimod();
	setuptime();
	ClearTimer(g_hTimer);
}
public OnMapEnd()
{
	getrand = false;
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
}
public OnClientPutInServer(id)
{
	SDKHook(id, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(id, SDKHook_GetMaxHealth, OnGetMaxHealth);
	if (id > 0 && IsValidClient(id) && IsClientInGame(id) && g_bOyun && TakimdakiOyuncular(3) > 0)
	{
		ChangeClientTeam(id, 3);
		CreateTimer(1.0, ClassSelection, id, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:ClassSelection(Handle:timer, any:id) {
	if (id > 0 && IsClientInGame(id) && ToplamOyuncular() > 0) {
		ShowVGUIPanel(id, GetClientTeam(id) == TFTeam_Blue ? "class_blue" : "class_red");
	} else {
		PrintToChat(id, "Lütfen [,] e basın!");
	}
}
public OnConfigsExecuted()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_GetMaxHealth, OnGetMaxHealth);
		}
	}
}
public OnPluginStart()
{
	//Konsol Komutları
	RegConsoleCmd("sm_msc", msc);
	RegConsoleCmd("sm_menu", zmenu);
	//Zamanlayıcılar
	CreateTimer(200.0, yazi1, _, TIMER_REPEAT);
	CreateTimer(220.0, yazi2, _, TIMER_REPEAT);
	CreateTimer(120.0, yazi4, _, TIMER_REPEAT);
	CreateTimer(190.0, yazi3, _, TIMER_REPEAT);
	//Convarlar
	zm_tHazirliksuresi = CreateConVar("zm_setup", "60", "Setup suresi/Hazirlik Suresi", FCVAR_NOTIFY);
	zm_tDalgasuresi = CreateConVar("zm_dalgasuresi", "225", "Setup bittikten sonraki round zamani", FCVAR_NOTIFY);
	zm_hTekvurus = CreateConVar("zm_tekvurus", "0", "Zombiler tek vurusta insanlari infekte edebilsin (1/0) 0 kapatir.", FCVAR_NOTIFY);
	//Olaylar
	HookEvent("teamplay_round_start", round);
	HookEvent("player_death", death);
	HookEvent("player_spawn", spawn);
	HookEvent("teamplay_setup_finished", setup);
	HookEvent("teamplay_point_captured", captured, EventHookMode_Post);
	HookEvent("player_hurt", HookPlayerHurt);
	HookEvent("post_inventory_application", Event_Resupply);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	//Set
	ServerCommand("mp_autoteambalance 0");
	ServerCommand("mp_scrambleteams_auto 0");
	ServerCommand("mp_teams_unbalance_limit 0");
	ServerCommand("mp_respawnwavetime 0 ");
	ServerCommand("mp_disable_respawn_times 1 ");
	ServerCommand("sm_cvar mp_waitingforplayers_time 25");
	ServerCommand("sm_cvar tf_spy_invis_time 0.5"); // Locked 
	ServerCommand("sm_cvar tf_spy_invis_unstealth_time 0.75"); // Locked 
	ServerCommand("sm_cvar tf_spy_cloak_no_attack_time 1.0");
	//Tercihler
	MusicCookie = RegClientCookie("oyuncu_mzk_ayari", "Muzik Ayarı", CookieAccess_Public);
	//Komut takibi
	AddCommandListener(hook_JoinClass, "joinclass");
	AddCommandListener(BlockedCommands, "autoteam");
	AddCommandListener(BlockedCommandsteam, "jointeam");
}
public Action:OnGetMaxHealth(client, &maxhealth)
{
	if (client > 0 && client <= MaxClients)
	{
		if (TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			maxhealth = g_maxHealth[TF2_GetPlayerClass(client)] * 2;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
public Action:Event_Resupply(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (client > 0 && client && IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) == TFTeam_Blue)
	{
		zombi(client); //Oyuncular resupply cabinete dokunduğu zaman silahlarını tekrar silmek için. (Zombilerin)
	}
	return Plugin_Continue;
}
public HookPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iUserId = GetEventInt(event, "userid");
	new client = GetClientOfUserId(iUserId);
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damagebits = GetEventInt(event, "damagebits");
	if (client > 0 && damagebits & DMG_FALL)
	{
		return;
	}
	if (client > 0 && GetEventInt(event, "death_flags") & 32)
	{
		return;
	}
	if (client > 0 && GetConVarInt(zm_hTekvurus) == 1)
	{
		if (client != attacker && attacker && TF2_GetPlayerClass(attacker) != TFClass_Scout && GetClientTeam(attacker) != 2 && GetClientTeam(attacker) != 1) //Scoutun topları tek atmamalı.
		{
			zombi(client);
		}
	}
}
public Action:captured(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = GetClientOfUserId(GetEventInt(event, "userid"));
	g_bKazanan = true;
	new capT = GetEntProp(entity, Prop_Send, "m_iOwner");
	kazanantakim(capT);
	oyunuresetle(); //Control point capture edildiği zaman resetlenme gerçekleşicek
}
public Action:zmenu(client, args)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "ZF Esas Menü");
	DrawPanelItem(panel, "Yardim");
	DrawPanelItem(panel, "Tercihler");
	DrawPanelItem(panel, "Yapımcılar");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleMain, 10);
	CloseHandle(panel);
}
public panel_HandleMain(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:
			{
				Yardim(param1);
			}
			case 2:
			{
				mzkv2(param1);
			}
			case 3:Yapimcilar(param1);
			default:return;
		}
	}
}
public mzk(Handle hMuzik, MenuAction action, client, item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 0:
			{
				MuzikAc(client);
				OyuncuMuzikAyari(client, true);
			}
			
			case 1:
			{
				MuzikDurdurma(client);
				OyuncuMuzikAyari(client, false);
			}
		}
	}
}
public Action:BlockedCommands(client, const String:command[], argc)
{
	return Plugin_Handled;
}

public Action:BlockedCommandsteam(client, const String:command[], argc)
{
	if (ToplamOyuncular() > 0 && client > 0 && g_bOyun && GetClientTeam(client) > 1) //Round başladığı halde oyuncular takım değiştirmeye çalışırsa engellensin
	{
		PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun esnasında ya da setup zamanında takım değiştirilemez!");
		return Plugin_Handled; // Engellemeyi uygula
	}
	return Plugin_Continue; // Eğer öyle bir olay yoksa da plugin çalışmaya devam edicek.
}
public Action:hook_JoinClass(client, const String:command[], argc)
{
	if (client > 0 && client <= MaxClients && g_bOyun && GetClientTeam(client) == 2) //Round başladığı halde oyuncular takım değiştirmeye çalışırsa engellensin
	{
		PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun esnasında sınıf değiştiremezsiniz!");
		return Plugin_Handled; // Engellemeyi uygula
	}
	return Plugin_Continue; // Eğer öyle bir olay yoksa da plugin çalışmaya devam edicek.
}
public Action:setup(Handle:event, const String:name[], bool:dontBroadcast)
{
	zombimod(); //Round timerin işlemesi için
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCHazırlık bitti!");
}
//----------------------MENU HANDLE------------------------------------------
public Action:msc(client, args)
{
	Menu hMuzik = new Menu(mzk);
	hMuzik.SetTitle("Müzik bölmesi");
	hMuzik.AddItem("Aç", "Aç");
	hMuzik.AddItem("Kapa", "Kapa");
	hMuzik.ExitButton = false;
	hMuzik.Display(client, 20);
	
}
public Action:round(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bOyun = false; // Setup bitmeden round başlayamaz
	g_iSetupCount = GetConVarInt(zm_tHazirliksuresi); //Setup zamanlayicisinin convarın değerini alması için
	g_iDalgaSuresi = GetConVarInt(zm_tDalgasuresi); //Round zamanlayicisinin convarın değerini alması için
	g_bKazanan = false;
	getrand = false;
	setuptime();
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	g_hTimer = CreateTimer(1.0, oyun1, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hSTimer = CreateTimer(1.0, hazirlik, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
public Action:Event_RoundEnd(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	oyunuresetle();
}
public Action:spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (TF2_GetClientTeam(client) == TFTeam_Blue)
	{
		if (!g_bOyun && g_iSetupCount > 0 && g_iSetupCount <= GetConVarInt(zm_tHazirliksuresi))
		{
			SetEntProp(client, Prop_Send, "m_lifeState", 2);
			ChangeClientTeam(client, 2);
			SetEntProp(client, Prop_Send, "m_lifeState", 0);
			TF2_RespawnPlayer(client);
			PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun Başlamadan Zombi Olamazsın!");
		}
		if (g_bOyun && g_iDalgaSuresi > 0 && g_iDalgaSuresi <= GetConVarInt(zm_tDalgasuresi))
		{
			SetEntityRenderColor(client, 0, 255, 0, 0);
			zombi(client);
		}
	} else {
		SetEntityRenderColor(client, 255, 255, 255, 0);
		discizgi();
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Spy:
			{
				TF2_RemoveWeaponSlot(client, 3);
				new slot = GetPlayerWeaponSlot(client, 4);
				if (IsValidEntity(slot))
				{
					decl String:classname[64];
					if (GetEntityClassname(slot, classname, sizeof(classname)) && StrContains(classname, "tf_weapon", false) != -1)
					{
						switch (GetEntProp(slot, Prop_Send, "m_iItemDefinitionIndex"))
						{
							case 30: {  }
							default:TF2_RemoveWeaponSlot(client, 4);
						}
					}
				}
			}
			case TFClass_Engineer:
			{
				if (sinifsayisi(TFClass_Engineer) > 2)
				{
					TF2_SetPlayerClass(client, TFClass_Scout);
					TF2_RespawnPlayer(client);
					PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCEngineer limiti aşıldı(2), Hayatta olan Engi sayisi:%d", sinifsayisi(TFClass_Engineer));
				}
			}
		}
	}
}
public Action:death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetEventInt(event, "death_flags") & 32) // Sahte ölüm
	{
		return;
	}
	if (GetClientTeam(victim) == 2 && g_bOyun)
	{
		zombi(victim);
		HUD(-1.0, 0.2, 6.0, 255, 0, 0, 2, "\n☠☠☠\n%N", victim);
	}
}
public Action:hazirlik(Handle:timer, any:client)
{
	if (ToplamOyuncular() > 0)
	{
		g_iSetupCount--;
	}
	if (g_iSetupCount <= GetConVarInt(zm_tHazirliksuresi) && g_iSetupCount > 0)
	{
		HUD(-1.0, 0.2, 6.0, 255, 255, 0, 1, "Setup:%02d:%02d", g_iSetupCount / 60, g_iSetupCount % 60);
		HUD(0.02, 0.10, 1.0, 0, 255, 0, 5, "☠Zombi☠:%d", TakimdakiOyuncular(3));
		HUD(-0.02, 0.10, 1.0, 255, 255, 255, 6, "Insan:%d", TakimdakiOyuncular(2));
		g_iDalgaSuresi = GetConVarInt(zm_tDalgasuresi);
		g_bOyun = false;
	} else {
		g_bOyun = true;
		if (TakimdakiOyuncular(3) == 0 && TakimdakiOyuncular(2) > 9 && g_bOyun && !getrand)
			zombi(rastgelezombi()), zombi(rastgelezombi());
		else if (TakimdakiOyuncular(3) == 0 && TakimdakiOyuncular(2) < 9 && !getrand)
			zombi(rastgelezombi());
		else if (TakimdakiOyuncular(3) == 0 && TakimdakiOyuncular(2) > 20 && !getrand)
			zombi(rastgelezombi()), zombi(rastgelezombi()), zombi(rastgelezombi());
	}
}
public Action:oyun1(Handle:timer, any:id)
{
	if (ToplamOyuncular() > 0)
	{
		g_iDalgaSuresi--;
	}
	if (g_iDalgaSuresi <= GetConVarInt(zm_tDalgasuresi) && g_iDalgaSuresi > 0 && g_bOyun)
	{
		izleyicikontrolu();
		HUD(-1.0, 0.2, 6.0, 255, 255, 0, 1, "Round:%02d:%02d", g_iDalgaSuresi / 60, g_iDalgaSuresi % 60);
		HUD(0.02, 0.10, 1.0, 0, 255, 0, 5, "☠Zombiler☠:%d", TakimdakiOyuncular(3));
		HUD(-0.02, 0.10, 1.0, 255, 255, 255, 6, "İnsanlar:%d", TakimdakiOyuncular(2));
		if (g_iDalgaSuresi == GetConVarInt(zm_tDalgasuresi) - 3) {
			setuptime();
		}
		if (TakimdakiOyuncular(2) == 0) //2 red 3 blue
		{
			kazanantakim(3);
			oyunuresetle();
		}
	}
	else if (g_iDalgaSuresi <= 0 && g_bOyun)
	{
		if (TakimdakiOyuncular(2) > 0)
		{
			kazanantakim(2);
			oyunuresetle();
		}
		else if (TakimdakiOyuncular(2) == 0)
		{
			kazanantakim(3);
			oyunuresetle();
		}
	}
	return Plugin_Handled;
}
stock rastgelezombi()
{
	new oyuncular[MaxClients + 1], num;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) > 1 && TF2_GetPlayerClass(i) != TFClass_Engineer && g_bOyun)
		{
			oyuncular[num++] = i;
		}
	}
	return (num == 0) ? 0 : oyuncular[GetRandomInt(0, num - 1)];
}
zombi(client)
{
	if (client > 0 && IsClientInGame(client))
	{
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		ChangeClientTeam(client, 3);
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
		SetEntityRenderColor(client, 0, 255, 0, 0);
	}
	CreateTimer(0.1, silah, client, TIMER_FLAG_NO_MAPCHANGE);
}
public Action:silah(Handle:timer, any:client)
{
	if (client > 0 && IsClientInGame(client))
	{
		for (new i = 0; i <= 5; i++)
		{
			if (client > 0 && i != 2 && TF2_GetClientTeam(client) == TFTeam_Blue)
			{
				TF2_RemoveWeaponSlot(client, i);
			}
		}
		if (client > 0 && TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			new silah1 = GetPlayerWeaponSlot(client, 2);
			if (IsValidEdict(silah1))
			{
				EquipPlayerWeapon(client, silah1);
			}
		}
	}
}
TakimdakiOyuncular(iTakim)
{
	new iSayi;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iTakim)
		{
			iSayi++;
		}
	}
	return iSayi;
}
ToplamOyuncular()
{
	new iSayi2;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			iSayi2++;
		}
	}
	return iSayi2;
}
kazanantakim(takim)
{
	new ent = FindEntityByClassname(-1, "team_control_point_master"); //game_round_win
	if (ent == -1) // < 1  ya da == -1
	{
		ent = CreateEntityByName("team_control_point_master");
		DispatchSpawn(ent);
	} else {
		SetVariantInt(takim);
		g_bKazanan = true;
		AcceptEntityInput(ent, "SetWinner");
	}
}
HUD(Float:x, Float:y, Float:Sure, r, g, b, kanal, const String:message[], any:...)
{
	SetHudTextParams(x, y, Sure, r, g, b, 255, 0, 6.0, 0.1, 0.2);
	new String:buffer[256];
	VFormat(buffer, sizeof(buffer), message, 9);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ShowHudText(i, kanal, buffer);
		}
	}
}
//Adverts
public Action:yazi1(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCHazırlık süresi 30(varsayılan) saniyedir.");
}
public Action:yazi2(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCHayatta kalmaya çalışın!");
}
public Action:yazi3(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun içi müzikleri açmak veya kapatmak için [!msc] yazabilirsiniz.");
}
public Action:yazi4(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun hakkında bilgi için [!menu] yazabilirsiniz.");
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!IsValidClient(attacker))
	{
		return Plugin_Continue;
	}
	new weaponId;
	(attacker == inflictor) ? (weaponId = ClientWeapon(attacker)) : (weaponId = inflictor); // Karsilastirma ? IfTrue : IfFalse;
	
	if (IsValidEntity(weaponId) && GetClientTeam(attacker) == 3)
	{  // weaponId != -1
		decl String:sWeapon[80];
		sWeapon[0] = '\0';
		GetEntityClassname(weaponId, sWeapon, 32);
		if (StrEqual(sWeapon, "tf_weapon_bat") || StrEqual(sWeapon, "tf_weapon_bat_fish") || 
			StrEqual(sWeapon, "tf_weapon_shovel") || StrEqual(sWeapon, "tf_weapon_katana") || StrEqual(sWeapon, "tf_weapon_fireaxe") || 
			StrEqual(sWeapon, "tf_weapon_bottle") || StrEqual(sWeapon, "tf_weapon_sword") || StrEqual(sWeapon, "tf_weapon_fists") || 
			StrEqual(sWeapon, "tf_weapon_wrench") || StrEqual(sWeapon, "tf_weapon_robot_arm") || StrEqual(sWeapon, "tf_weapon_bonesaw") || 
			StrEqual(sWeapon, "tf_weapon_club"))
		{
			//damage = 350.0;
			//return Plugin_Changed;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}
setuptime()
{
	new ent1 = FindEntityByClassname(MaxClients + 1, "team_round_timer");
	if (ent1 == -1)
	{
		ent1 = CreateEntityByName("team_round_timer");
		DispatchSpawn(ent1);
	}
	CreateTimer(1.0, Timer_SetTimeSetup, ent1, TIMER_FLAG_NO_MAPCHANGE);
}
public Action:Timer_SetTimeSetup(Handle:timer, any:ent1)
{
	if (g_iSetupCount > 0) {
		SetVariantInt(GetConVarInt(zm_tHazirliksuresi));
		AcceptEntityInput(ent1, "SetTime");
	}
	else if (g_iSetupCount < 0) {
		SetVariantInt(GetConVarInt(zm_tDalgasuresi));
		AcceptEntityInput(ent1, "SetTime");
	}
}
zombimod()
{
	g_iMapPrefixType = 0;
	decl String:mapv[32];
	GetCurrentMap(mapv, sizeof(mapv));
	if (!StrContains(mapv, "zf_", false))
		g_iMapPrefixType = 1;
	else if (!StrContains(mapv, "szf_", false))
		g_iMapPrefixType = 2;
	else if (!StrContains(mapv, "zm_", false))
		g_iMapPrefixType = 3;
	else if (!StrContains(mapv, "zom_", false))
		g_iMapPrefixType = 4;
	else if (!StrContains(mapv, "zs_", false))
		g_iMapPrefixType = 5;
	
	if (g_iMapPrefixType == 1)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZF']\n\n\n");
	else if (g_iMapPrefixType == 2)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['SZF']\n\n\n");
	else if (g_iMapPrefixType == 3)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZM']zf\n\n\n");
	else if (g_iMapPrefixType == 4)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZOM']\n\n\n");
	else if (g_iMapPrefixType == 5)
		PrintToServer("\n\n\n      Great :) Found Map Prefix ['ZS']\n\n\n");
	else if(g_iMapPrefixType > 0)
		g_bOnlyZMaps = true;
	else if (g_iMapPrefixType == 0) {
		g_bOnlyZMaps = false;
		PrintToServer("\n\n           ********WARNING!********     \n\n\n ***Zombie Map Recommended Current[MAP] = [%s]***\n\n\n", mapv);
	}
}
public Action:Timer_SetRoundTime(Handle:timer, any:ent1)
{
	SetVariantInt(GetConVarInt(zm_tDalgasuresi)); // 600 sec ~ 10min
	AcceptEntityInput(ent1, "SetTime");
}
oyunuresetle()
{
	if (g_bKazanan)
	{
		CreateTimer(15.0, res, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:res(Handle:timer, any:id)
{
	new oyuncu[MaxClients + 1], num;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3)
		{
			oyuncu[num++] = i;
			SetEntProp(i, Prop_Send, "m_lifeState", 2);
			ChangeClientTeam(i, 2);
			SetEntProp(i, Prop_Send, "m_lifeState", 0);
			TF2_RespawnPlayer(i);
		}
	}
}
MuzikDurdurma(client)
{
	PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCMüzikler durduruldu.");
}
MuzikAc(client)
{
	PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCMüzikler açıldı.");
}

OyuncuMuzikAyari(client, bool:acik)
{
	new String:strCookie[32];
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (acik)
		{
			strCookie = "1";
		} else {
			strCookie = "0";
			SetClientCookie(client, MusicCookie, strCookie);
		}
	}
	return bool:StringToInt(strCookie);
}
stock bool:IsValidClient(client, bool:nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

ClientWeapon(client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}
Yardim(client)
{
	Menu hYardim = new Menu(yrd);
	hYardim.SetTitle("ZF Yardım Bölmesi(bilgi)");
	hYardim.AddItem("ZF Hakkında", "ZF Hakkında");
	hYardim.AddItem("Kapat", "Kapat");
	hYardim.ExitButton = false;
	hYardim.Display(client, 20);
}
public yrd(Handle hYardim, MenuAction action, client, item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 0:
			{
				HakkindaK(client);
			}
			case 1:
			{
				CloseHandle(hYardim);
			}
		}
	}
}
public HakkindaK(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "ZF Hakkında");
	DrawPanelText(panel, "----------------------------------------------");
	DrawPanelText(panel, "Zombie Fortress, oyuncuları zombiler ve insanlar");
	DrawPanelText(panel, "arası ölümcül bir savaşa sokan custom moddur.");
	DrawPanelText(panel, "Insanlar bu bitmek bilmeyen salgında hayatta kalmalıdır.");
	DrawPanelText(panel, "Eğer insan infekte(ölürse) zombi olur.");
	DrawPanelText(panel, "----------------------------------------------");
	DrawPanelText(panel, "Modu Kodlayan:steamId=crackersarenoice - Deniz");
	DrawPanelItem(panel, "Yardım menüsüne geri dön.");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleOverview, 10);
	CloseHandle(panel);
}
public panel_HandleOverview(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:Yardim(param1);
			default:return;
		}
	}
}
public Yapimcilar(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "Yapimci");
	DrawPanelText(panel, "Kodlayan:steamId=crackersarenoice - Deniz");
	DrawPanelItem(panel, "Yardim Menüsüne Geri Dön");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleYapimci, 10);
	CloseHandle(panel);
}
public panel_HandleYapimci(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:Yardim(param1);
			default:return;
		}
	}
}
public mzkv2(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "Tercihler - Müzik");
	DrawPanelItem(panel, "Aç");
	DrawPanelItem(panel, "Kapa");
	DrawPanelItem(panel, "Yardım menüsüne geri dön.");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleMuzik, 10);
	CloseHandle(panel);
}
public panel_HandleMuzik(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:MuzikAc(param1), OyuncuMuzikAyari(param1, true);
			case 2:MuzikDurdurma(param1), OyuncuMuzikAyari(param1, false);
			case 3:Yardim(param1);
			default:return;
		}
	}
}
sinifsayisi(siniff)
{
	new iSinifNum;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetPlayerClass(i) == siniff && TF2_GetClientTeam(i) == TFTeam_Red)
		{
			iSinifNum++;
		}
	}
	return iSinifNum;
}
discizgi()
{
	new oyuncu[MaxClients + 1], num;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			oyuncu[num++] = i;
			SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
		}
	}
}
izleyicikontrolu()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Spectator && g_bOyun)
		{
			ChangeClientTeam(i, 3);
			TF2_SetPlayerClass(i, TFClass_Scout);
			TF2_RespawnPlayer(i);
		}
	}
}
public Action:TF2_CalcIsAttackCritical(id, weapon, String:weaponname[], &bool:result)
{
	if (StrEqual(weaponname, "tf_weapon_compound_bow", false) || StrEqual(weaponname, "tf_weapon_fists", false) || StrEqual(weaponname, "tf_weapon_crossbow", false))
	{
		result = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
stock ClearTimer(&Handle:hTimer)
{
	if (hTimer != INVALID_HANDLE)
	{
		KillTimer(hTimer);
		hTimer = INVALID_HANDLE;
	}
} 
