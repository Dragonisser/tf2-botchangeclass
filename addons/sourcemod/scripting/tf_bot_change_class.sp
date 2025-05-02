#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_NAME	   "TFBots Change Class"
#define PLUGIN_AUTHOR  "EfeDursun125, Dragonissa"
#define PLUGIN_DESC    "Bots now change classes intelligently."
#define PLUGIN_VERSION "1.5"
#define PLUGIN_URL	   "https://github.com/Dragonisser/tf2-botchangeclass"
#define PLUGIN_PREFIX  "[TF2BCC]"


public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
};

ConVar g_Cvar_BotChangeClassChance;
float g_fNextRemoveCheck[MAXPLAYERS + 1];

public void OnPluginStart() {
    HookEvent("player_spawn", Event_BotSpawn, EventHookMode_Post);
    g_Cvar_BotChangeClassChance = CreateConVar("tf_bot_change_class_chance", "40", "Chance for a bot to change class on spawn (0–100)", FCVAR_NONE, true, 0.0, true, 100.0);

    // Initialize timers
    for (int i = 1; i <= MaxClients; i++) {
        g_fNextRemoveCheck[i] = 0.0;
    }
}

public void OnMapStart() {
    ServerCommand("sm_cvar tf_bot_reevaluate_class_in_spawnroom 0");
    ServerCommand("sm_cvar tf_bot_keep_class_after_death 1");
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3]) {
    if (!IsValidClient(client) || !IsFakeClient(client) || !IsPlayerAlive(client)) {
        return Plugin_Continue;
    }

    if (TF2_GetPlayerClass(client) != TFClass_Engineer) {
        float currentTime = GetGameTime();
        if (g_fNextRemoveCheck[client] < currentTime) {
            RemoveBotBuildings(client);
            g_fNextRemoveCheck[client] = currentTime + 5.0;
        }
    }

    return Plugin_Continue;
}

public Action Event_BotSpawn(Handle event, const char[] name, bool dontBroadcast) {
    int botid = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsValidClient(botid) || !IsFakeClient(botid) || !IsPlayerAlive(botid)) {
        return Plugin_Continue;
    }

    // Prevent class switching if Engineer has buildings
    if (TF2_GetPlayerClass(botid) == TFClass_Engineer && BotHasEngineerBuildings(botid)) {
        return Plugin_Continue;
    }

    int chance = GetRandomInt(1, 100);
    if (chance > GetConVarInt(g_Cvar_BotChangeClassChance)) {
        return Plugin_Continue;
    }

    int team = GetClientTeam(botid);

    if (GameRules_GetProp("m_bPlayingMannVsMachine") && team == 2) {
        int newClass = GetRandomInt(1, 6); // Only 6 classes for MvM
        switch (newClass) {
            case 1: TF2_SetPlayerClass(botid, TFClass_Scout);
            case 2: TF2_SetPlayerClass(botid, TFClass_Soldier);
            case 3: TF2_SetPlayerClass(botid, TFClass_Pyro);
            case 4: TF2_SetPlayerClass(botid, TFClass_DemoMan);
            case 5: TF2_SetPlayerClass(botid, TFClass_Heavy);
            case 6: TF2_SetPlayerClass(botid, TFClass_Medic);
        }

        TF2_RespawnPlayer(botid);
    } else {
        int newClass = GetRandomInt(1, 9);
        switch (newClass) {
            case 1: TF2_SetPlayerClass(botid, TFClass_Scout);
            case 2: TF2_SetPlayerClass(botid, TFClass_Soldier);
            case 3: TF2_SetPlayerClass(botid, TFClass_Pyro);
            case 4: TF2_SetPlayerClass(botid, TFClass_DemoMan);
            case 5: TF2_SetPlayerClass(botid, TFClass_Heavy);
            case 6: TF2_SetPlayerClass(botid, TFClass_Engineer);
            case 7: TF2_SetPlayerClass(botid, TFClass_Medic);
            case 8: TF2_SetPlayerClass(botid, TFClass_Sniper);
            case 9: TF2_SetPlayerClass(botid, TFClass_Spy);
        }

        TF2_RespawnPlayer(botid);
    }

    return Plugin_Continue;
}

void RemoveBotBuildings(int client) {
    int sentry = TF2_GetObject(client, TFObject_Sentry, TFObjectMode_None);
    int dispenser = TF2_GetObject(client, TFObject_Dispenser, TFObjectMode_None);
    int teleEnter = TF2_GetObject(client, TFObject_Teleporter, TFObjectMode_Entrance);
    int teleExit = TF2_GetObject(client, TFObject_Teleporter, TFObjectMode_Exit);

    if (IsValidEntity(sentry)) {
        RemoveEdict(sentry);
    }
    if (IsValidEntity(dispenser)) {
        RemoveEdict(dispenser);
    }
    if (IsValidEntity(teleEnter)) {
        RemoveEdict(teleEnter);
    }
    if (IsValidEntity(teleExit)) {
        RemoveEdict(teleExit);
    }
}

bool BotHasEngineerBuildings(int client) {
    if (TF2_GetPlayerClass(client) != TFClass_Engineer) {
        return false;
    }

    int sentry = TF2_GetObject(client, TFObject_Sentry, TFObjectMode_None);
    int dispenser = TF2_GetObject(client, TFObject_Dispenser, TFObjectMode_None);
    int teleEnter = TF2_GetObject(client, TFObject_Teleporter, TFObjectMode_Entrance);
    int teleExit = TF2_GetObject(client, TFObject_Teleporter, TFObjectMode_Exit);

    return (IsValidEntity(sentry) || IsValidEntity(dispenser) || IsValidEntity(teleEnter) || IsValidEntity(teleExit));
}

stock int TF2_GetObject(int client, TFObjectType type, TFObjectMode mode) {
    int iObject = INVALID_ENT_REFERENCE;
    while ((iObject = FindEntityByClassname(iObject, "obj_*")) != -1) {
        if (GetEntPropEnt(iObject, Prop_Send, "m_hBuilder") != client) {
            continue;
        }

        if (TF2_GetObjectType(iObject) != type || TF2_GetObjectMode(iObject) != mode) {
            continue;
        }

        if (GetEntProp(iObject, Prop_Send, "m_bPlacing")) {
            continue;
        }

        if (GetEntProp(iObject, Prop_Send, "m_bDisposableBuilding")) {
            continue;
        }

        return iObject;
    }

    return INVALID_ENT_REFERENCE;
}

bool IsValidClient(int client) {
    return (1 <= client <= MaxClients) && IsClientInGame(client);
}
