#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

#define MAP_NAME "ze_squidzer"

bool g_bIsClientSafe[MAXPLAYERS + 1] = { false, ... };
bool g_bEnableShooting;

public Plugin myinfo = {
	name		= "VScript ze_squidzer",
	author		= "Dolly",
	description = "Movement detection for the redlight greenlight game",
	version 	= "1.0.0",
	url 		= "https://github.com/srcdslab/sm-plugin-VScript_ze_squidzer"
};

public void OnPluginStart() {
	HookEvent("round_start", Event_RoundStart);
	
	RegAdminCmd("sm_redlight", Command_RedLight, ADMFLAG_ROOT);
	RegAdminCmd("sm_greenlight", Command_GreenLight, ADMFLAG_ROOT);
	RegAdminCmd("sm_resetsafe", Command_ResetSafe, ADMFLAG_ROOT);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_bEnableShooting = false;
	
	Command_ResetSafe(0, 0);
}

Action Command_RedLight(int client, int args) {
	if(client) {
		return Plugin_Handled;
	}
	
	g_bEnableShooting = true;
	return Plugin_Handled;
}

Action Command_GreenLight(int client, int args) {
	if(client) {
		return Plugin_Handled;
	}
	
	g_bEnableShooting = false;
	return Plugin_Handled;
}

Action Command_ResetSafe(int client, int args) {
	if(client) {
		return Plugin_Handled;
	}
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		g_bIsClientSafe[i] = false;
	}
	
	return Plugin_Handled;
}

public void OnClientDisconnect(int client) {
	g_bIsClientSafe[client] = false;
}

public void OnMapStart() {
	CheckMap();
}

void CheckMap() {
	char currentMap[PLATFORM_MAX_PATH];
	if(!GetCurrentMap(currentMap, sizeof(currentMap))) {
		return;
	}
	
	if(StrContains(currentMap, MAP_NAME) == -1) {
		/* Unload the plugin if the map that was found is not the specified one */
		char pluginName[64];
		GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));
		ServerCommand("sm plugins unload %s", pluginName);
	} else {
		PrecacheSound("rm_2_gun_shot.mp3");
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if(StrContains(classname, "trigger") != -1) {
		CreateTimer(1.0, CheckEntity, EntIndexToEntRef(entity));
	}
}

Action CheckEntity(Handle timer, int ref) {
	int entity = EntRefToEntIndex(ref);
	if(ref == INVALID_ENT_REFERENCE || !IsValidEntity(entity)) {
		return Plugin_Stop;
	}
	
	char targetName[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));
	if(StrEqual(targetName, "to_safe", false) || StrContains(targetName, "to_safe", false) != -1) {
		CreateTimer(1.0, HookStartTouch_Timer, ref);
	}
	
	return Plugin_Continue;
}

Action HookStartTouch_Timer(Handle timer, int ref) {
	int entity = EntRefToEntIndex(ref);
	if(!IsValidEntity(entity)) {
		return Plugin_Stop;
	}
	
	SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
	return Plugin_Continue;
}

Action OnStartTouch(int entity, int other) {
	if(other >= 1 && other <= MaxClients && IsClientInGame(other)) {
		g_bIsClientSafe[other] = (g_bIsClientSafe[other]) ? false : true;
	}
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impluse) {
	if(!IsClientInGame(client)) {
		return Plugin_Continue;
	}
	
	if(!g_bEnableShooting) {
		return Plugin_Continue;
	}
	
	if(GetClientTeam(client) != CS_TEAM_CT || !IsPlayerAlive(client)) {
		return Plugin_Continue;
	}
	
	if(g_bIsClientSafe[client]) {
		return Plugin_Continue;
	}
	
	if(buttons & (IN_WALK | IN_JUMP | IN_FORWARD | IN_BACK | IN_RIGHT | IN_LEFT | IN_DUCK)) {
		ForcePlayerSuicide(client);
		EmitSoundToAll("rm_2_gun_shot.mp3");
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}
