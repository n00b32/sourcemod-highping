/**
 * vim: set ts=4 :
 * =============================================================================
 * High Ping Kicker - Lite Edition
 * Checks for High Ping
 *
 * SourceMod (C)2004-2007 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 */
 // some more to copycat 
 // https://forums.alliedmods.net/showthread.php?p=769939
 // 

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <emitsoundany>
#undef REQUIRE_EXTENSIONS
#include <connect>
#define REQUIRE_EXTENSIONS


#define VERSION "1.1"

#define VERSION_FLAGS FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD
#define TIMER_FLAGS TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE
#define UMIN(%1,%2) (%1 < %2 ? %2 : %1)

new Handle:g_Cvar_Enabled = INVALID_HANDLE;         // HPK Enabled?
new Handle:g_Cvar_MaxPing = INVALID_HANDLE;         // maximum ping clients are allowed
new Handle:g_Cvar_MaxChoke = INVALID_HANDLE;        // maximum choke clients are allowed
new Handle:g_Cvar_MaxLoss = INVALID_HANDLE;         // maximum loss clients are allowed
new Handle:g_Cvar_MaxChecks = INVALID_HANDLE;       // amount of times to check
new Handle:g_Cvar_StartCheck = INVALID_HANDLE;      // seconds to start checking after map start
new Handle:g_Cvar_RepeatCheck = INVALID_HANDLE;      // seconds between checks
new Handle:g_Cvar_AdminsImmune = INVALID_HANDLE;    // are admins immune to checks
new Handle:g_Cvar_MaxKickCounts = INVALID_HANDLE;
new Handle:g_Cvar_KickCountLimitBanTime = INVALID_HANDLE;
new Handle:g_Cvar_ConnectionBreakWarn = INVALID_HANDLE;
new Handle:g_Cvar_KickCountClearTime = INVALID_HANDLE;

new Handle:g_Cvar_PlayWarningSound = INVALID_HANDLE; // TODO : different sounds per action

new g_FailedChecks[MAXPLAYERS+1];                   // number of checks clients have failed
new g_Ping[MAXPLAYERS+1];                           
new g_ChokePoints[MAXPLAYERS+1];
new g_LossPoints[MAXPLAYERS+1];
new g_ConnectTime[MAXPLAYERS+1];


new Handle:g_hClientKeys = INVALID_HANDLE; // TODO !!!!!!!!!!!!! use this ! :)
new Handle:g_hClientKickCounts = INVALID_HANDLE;
new Handle:g_hClientLastKick = INVALID_HANDLE;

// TODO 
//new Handle:g_cVarMaxChokePoints = INVALID_HANDLE;
//new Handle:g_cVarMaxLossPoints = INVALID_HANDLE;


new bool:g_sndWarningAvailable = false;
new String:g_sndWarning[PLATFORM_MAX_PATH];


public Plugin:myinfo =
{
    name = "High Ping Kicker - Custom",
    author = "Liam, dubbeh, n00b",
    description = "Checks for High Ping.",
    version = VERSION,
    url = "http://www.wcugaming.org"
};

public OnPluginStart( )
{
    LoadTranslations("common.phrases");
    LoadTranslations ("hpk.phrases");
    CreateConVar("hpk_version", VERSION, "HPK Version Number", VERSION_FLAGS);

    // TODO convars caching, convars that are int but must have min max ? hmm 

    g_Cvar_Enabled = CreateConVar("sm_hpk_enabled", "1", "0 = Off | 1 = On -- HPK Enabled?");
    g_Cvar_MaxPing = CreateConVar("hpk_maxping", "150", "Max ping allowed for clients.");
    g_Cvar_MaxChecks = CreateConVar("hpk_maxchecks", "3", "Number of grace checks for high ping.");
    g_Cvar_StartCheck = CreateConVar("hpk_startcheck", "15.0", "When to start checking ping after map start or player connects (per player). (Seconds)");
    g_Cvar_RepeatCheck = CreateConVar("hpk_repeatcheck", "10.0", "How often is the check done. (Seconds)");
    g_Cvar_AdminsImmune = CreateConVar("hpk_adminsimmune", "1", "0 = Off | 1 = On -- Admins immune to High Ping?");


    g_Cvar_MaxChoke = CreateConVar ("hpk_maxchoke", "30.0", "Set the maximum choke allowed on the server", 0, true, 0.0, true, 9999.0);
    g_Cvar_MaxLoss = CreateConVar ("hpk_maxloss", "5.0", "Set the maximum loss allowed on the server", 0, true, 0.0, true, 9999.0);
    g_Cvar_MaxKickCounts = CreateConVar ("hpk_maxkickcounts", "1", "Maximum times a user can get kicked before getting banned");//, 0, true, 0, true, 25);

    g_Cvar_ConnectionBreakWarn = CreateConVar ("hpk_connectionbreakwarn", "1.0", "Warn the user for the last 10 connection limit breaks every second until kicked/& banned", 0, true, 0.0, true, 1.0);
    g_Cvar_KickCountLimitBanTime = CreateConVar ("hpk_bantime", "1", "Set the ban time a user gets for breaking the kick count limit");//, 0, true, 1, true, 1440);
    g_Cvar_KickCountClearTime = CreateConVar ("hpk_kickcountcleartime", "1", "How often to clear the kick counts array, 1 = minute");//, 0, true, 1, true, 99999);
    

    g_Cvar_PlayWarningSound = CreateConVar ("hpk_warningsound", /*""*/"highping.mp3", "Warning sound (this will be replaced with different cvars");
    LoadSounds();

//    TODO :
//    g_cVarMaxChokePoints = CreateConVar ("yghpr_maxchokepoints", "60.0", "Set the maximum choke points, updated once a second", 0, true, 1.0, true, 900.0);
//    g_cVarMaxLossPoints = CreateConVar ("yghpr_maxlosspoints", "60.0", "Set the maximum loss points, updated once a second", 0, true, 1.0, true, 900.0);



    if (
        //( (g_hClientKickCounts = CreateTrie()) == INVALID_HANDLE ) ||
        ( (g_hClientKickCounts = CreateTrie()) == INVALID_HANDLE ) ||
        ( (g_hClientLastKick = CreateTrie()) == INVALID_HANDLE )

        )
    {
        SetFailState ("[HPK] Plugin Disabled. Unable to create the kick counts/times hashmap");
        return;
    }


    //AutoExecConfig(true, "hpk");
}

public Action:Timer_Begin(Handle:Timer){
    CreateTimer(GetConVarFloat(g_Cvar_RepeatCheck), Timer_CheckPing, _, TIMER_FLAGS);
}

public OnMapStart( )
{
    CreateTimer(GetConVarFloat(g_Cvar_StartCheck), Timer_Begin);
    new maxclients = GetMaxClients( );

    if(GetConVarInt(g_Cvar_Enabled) == 1)
    {
    }

    for(new i = 1; i < maxclients; i++)
    {
        g_Ping[i] = 0;
        g_ChokePoints[i] = 0;
        g_LossPoints[i] = 0;
        g_FailedChecks[i] = 0;
        g_ConnectTime[i] = GetTime();
    }
}

public OnClientPutInServer(client)
{
    g_Ping[client] = 0;
    g_ChokePoints[client] = 0;
    g_LossPoints[client] = 0;
    g_FailedChecks[client] = 0;
    g_ConnectTime[client] = GetTime();
}

public OnClientPostAdminCheck(client)
{
    g_ConnectTime[client] = GetTime();
}




public Action:Timer_CheckPing(Handle:Timer)
{
    if(GetConVarInt(g_Cvar_Enabled) == 0)
        return Plugin_Stop;

    new maxclients = GetMaxClients( );

    for(new i = 1; i < maxclients; i++)
    {
        if(!IsClientConnected(i) || !IsClientInGame(i) // TODO check if client has steamid or is this handled here ?
            || IsFakeClient(i) || IsAdmin(i))
            continue;
        if( (GetTime() - g_ConnectTime[i]) < GetConVarFloat(g_Cvar_StartCheck))
            continue;

        UpdatePingStatus(i);
    }
    HandleHighPingers( );
    return Plugin_Continue;
}

UpdatePingStatus(client)
{
    decl String:rate[32];
    GetClientInfo(client, "cl_cmdrate", rate, sizeof(rate));
    new Float:ping = GetClientAvgLatency(client, NetFlow_Outgoing);
    new Float:tickRate = GetTickInterval( );
    new cmdRate = UMIN(StringToInt(rate), 20);

    ping -= ((0.5 / cmdRate) + (tickRate * 1.0));
    ping -= (tickRate * 0.5);
    ping *= 1000.0;

    g_Ping[client] = RoundToZero(ping);

    if(g_Ping[client] > GetConVarFloat(g_Cvar_MaxPing)){

        if(GetKickCount(client)<GetConVarInt(g_Cvar_MaxKickCounts)){
            CPrintToChat(client, "{red} %T", "High Ping Violation", client,  RoundToZero(ping), RoundToZero(GetConVarFloat(g_Cvar_MaxPing)), RoundToZero((GetConVarInt(g_Cvar_MaxChecks) - g_FailedChecks[client])*GetConVarFloat(g_Cvar_RepeatCheck)) );
            PrintCenterText(client, "%T", "High Ping Violation", client, RoundToZero(ping), RoundToZero(GetConVarFloat(g_Cvar_MaxPing)), RoundToZero((GetConVarInt(g_Cvar_MaxChecks) - g_FailedChecks[client])*GetConVarFloat(g_Cvar_RepeatCheck)) );
        }else{
            CPrintToChat(client, "{red} %T", "High Ping Violation Ban", client,  RoundToZero(ping), RoundToZero(GetConVarFloat(g_Cvar_MaxPing)), RoundToZero((GetConVarInt(g_Cvar_MaxChecks) - g_FailedChecks[client])*GetConVarFloat(g_Cvar_RepeatCheck)) );
            PrintCenterText(client, "%T", "High Ping Violation Ban", client, RoundToZero(ping), RoundToZero(GetConVarFloat(g_Cvar_MaxPing)), RoundToZero((GetConVarInt(g_Cvar_MaxChecks) - g_FailedChecks[client])*GetConVarFloat(g_Cvar_RepeatCheck)) );
        }

        //PingWarning(); // TODO : move to this function...
        PlaySoundClient(client, g_sndWarning);
        g_FailedChecks[client]++;
    }
    else
    {
        if(g_FailedChecks[client] > 0)
            g_FailedChecks[client]--;
    }
}


bool:GetSteamID(client, String:name[], maxlength)
{
    decl String:szSteamId[32];
    if(GetClientAuthId (client, AuthId_SteamID64, szSteamId, 32)){
        strcopy(name, maxlength, szSteamId);
        return true;
    }else{
        return false;
    }
}

// TODO : 64 bit timestamps.

IncreaseKickCount(client){
    new int:value;
    decl String:szSteamId[32];
    if(!GetSteamID(client, szSteamId, 32)) return false;
    //PrintToServer("increasing kick count of %s ", szSteamId);
    if(!GetTrieValue( Handle:g_hClientKickCounts, szSteamId, value )) return false;
    //PrintToServer("current value is %d", value);
    if(!SetTrieValue( Handle:g_hClientKickCounts, szSteamId, value+1, true )) return false;
    if(!SetTrieValue( Handle:g_hClientLastKick, szSteamId, GetTime(), true )) return false;
    return true;

}

GetKickCount(client){ // TODO .. those -1s ... also optimize this ? move the cooldown thingy to IncreaseKickCount ?
    new int:value;
    new int:lastKick;
    decl String:szSteamId[32];
    if(!GetSteamID(client, szSteamId, 32)) return -1;

    if(!GetTrieValue( Handle:g_hClientKickCounts, szSteamId, value )){
        if(!SetTrieValue( Handle:g_hClientKickCounts, szSteamId, 0, true )) return -1;
        if(!SetTrieValue( Handle:g_hClientLastKick, szSteamId, GetTime(), true )) return -1;
        return 0;
    }

    if(value>0){
        // check if cooldown time was achieved
        if(GetTrieValue( Handle:g_hClientLastKick, szSteamId, lastKick )){
            int timePassed = GetTime() - lastKick;
            if(timePassed>(GetConVarInt(g_Cvar_KickCountClearTime)*60)){
                if(!SetTrieValue( Handle:g_hClientKickCounts, szSteamId, 0, true )) return -1;
                return 0;
            }
        }else{
            // TODO : this should never happen.
            if(!SetTrieValue( Handle:g_hClientLastKick, szSteamId, GetTime(), true )) return -1;
        }
    }
    return value;
}


HandleHighPingers( )
{
    new maxclients = GetMaxClients( );


    for(new i = 1; i < maxclients; i++)
    {
        if(!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i))
            continue;

        if(g_FailedChecks[i] > GetConVarInt(g_Cvar_MaxChecks))
        {
            new int:Cnt = GetKickCount(i);
            // remember we kicked the client, ban him if hes naughty
            if(Cnt<GetConVarInt(g_Cvar_MaxKickCounts)){
                IncreaseKickCount(i);
                KickClient(i, "Your ping is too high. (%d) Max: (%d)\n This is your %d warning. After %d you will be banned for %d minutes.",  // TODO translations TODO last warning message
                    g_Ping[i], GetConVarInt(g_Cvar_MaxPing),
                    Cnt+1, GetConVarInt(g_Cvar_MaxKickCounts), GetConVarInt(g_Cvar_KickCountLimitBanTime)
                    );
            }else{ // the client was banned !
                new String:banReason[200];
                FormatEx(banReason, 200, "You have been banned for %d minutes due to ping violations.", GetConVarInt(g_Cvar_KickCountLimitBanTime));
                BanClient(i, GetConVarInt(g_Cvar_KickCountLimitBanTime), BANFLAG_AUTO, "PingKickLimit", // TODO : auto ? TODO : translations
                banReason,
                 _, i); 
            }
        }
    }
}




// this will only run if connect is available... or will the plugin crash oh who knows :D
// TODO should we handle blocking or defer it to a "AntiReconnect" plugin ?
/*
public bool:OnClientPreConnectEx(const String:name[], String:password[255], const String:ip[], const String:steamID[], String:rejectReason[255])
{
        char steamID3[64], steamID64[64];
        Connect_GetAuthId(AuthId_Steam3, steamID3, sizeof(steamID3));
        Connect_GetAuthId(AuthId_SteamID64, steamID64, sizeof(steamID64));
        PrintToServer("----------------\nName: %s\nPassword: %s\nIP: %s\nSteamID2: %s\nSteamID3: %s\nSteamID64: %s\n----------------", name, password, ip, steamID, steamID3, steamID64);

        new AdminId:admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamID);

        if (admin == INVALID_ADMIN_ID)
        {
                return true;
        }

        if (GetAdminFlag(admin, Admin_Root))
        {
                GetConVarString(FindConVar("sv_password"), password, 255);
        }

        return true;
}*/




bool:IsAdmin(client)
{
 //for testing
 //       return false;
    if(GetConVarInt(g_Cvar_AdminsImmune) == 0)
        return false;

    new AdminId:admin = GetUserAdmin(client);

    if(admin == INVALID_ADMIN_ID)
        return false;

    return true;
}



// sound stuff


LoadSounds(){
    // TODO : observe changes.

    GetConVarString(g_Cvar_PlayWarningSound, g_sndWarning, PLATFORM_MAX_PATH);
    if(strlen(g_sndWarning)!=0)
        g_sndWarningAvailable = mCacheSound(g_sndWarning);
}

PlaySoundClient(client, const String:soundName[]){
    EmitSoundToClientAny(client, soundName, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
    /*, 
                 entity = SOUND_FROM_PLAYER,
                 channel = SNDCHAN_AUTO,
                 level = SNDLEVEL_NORMAL,
                 flags = SND_NOFLAGS,
                 Float:volume = SNDVOL_NORMAL,
                 pitch = SNDPITCH_NORMAL,
                 speakerentity = -1,
                 const Float:origin[3] = NULL_VECTOR,
                 const Float:dir[3] = NULL_VECTOR,
                 bool:updatePos = true,
                 Float:soundtime = 0.0)*/
}

bool:mCacheSound(const String:soundName[]){
    if (PrecacheSoundAny(soundName))
    {
        decl String:downloadLocation[PLATFORM_MAX_PATH];
        Format(downloadLocation, sizeof(downloadLocation), "sound/%s", soundName);
        AddFileToDownloadsTable(downloadLocation);
        return true;
    } else {
        LogMessage("Failed to load sound: %s", soundName);
        return false;
    }
}
