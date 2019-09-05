#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

#pragma semicolon 1
#pragma newdecls required

#define MAX_HOST_LENGTH 256

ConVar g_hEnabled;
ConVar g_HostnameCvar;
ConVar g_MatchStarted;
ConVar g_MatchFinished;

bool g_GotHostName = false;        // keep track of it, so we only fetch it once
char g_HostName[MAX_HOST_LENGTH];  // stores the original hostname

// clang-format off
public Plugin myinfo = {
    name = "CS:GO PugSetup: hostname setter",
    author = "splewis",
    description = "Tweaks the server hostname according to the pug status",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};
// clang-format on

public void OnPluginStart() {
  LoadTranslations("pugsetup.phrases");
  g_hEnabled = CreateConVar("sm_pugsetup_hostname_enabled", "1", "Whether the plugin is enabled");
  AutoExecConfig(true, "pugsetup_hostname", "sourcemod/pugsetup");
  g_HostnameCvar = FindConVar("hostname");
  g_GotHostName = false;

  if (g_HostnameCvar == INVALID_HANDLE)
    SetFailState("Failed to find cvar \"hostname\"");

  g_MatchStarted = CreateConVar("sv_matchstarted", "0", "Whether the match is started", FCVAR_REPLICATED | FCVAR_NOTIFY);
  g_MatchFinished = CreateConVar("sv_matchfinished", "0", "Whether the match is finished", FCVAR_REPLICATED | FCVAR_NOTIFY);

  HookEvent("round_start", Event_RoundStart);
}

public void OnConfigsExecuted() {
  if (!g_GotHostName) {
    g_HostnameCvar.GetString(g_HostName, sizeof(g_HostName));
    g_GotHostName = true;
  }
}

public void PugSetup_OnReadyToStartCheck(int readyPlayers, int totalPlayers) {
  if (g_hEnabled.IntValue == 0)
    return;

  char hostname[MAX_HOST_LENGTH];
  int need = PugSetup_GetPugMaxPlayers() - totalPlayers;

  if (need >= 1) {
    Format(hostname, sizeof(hostname), "%s [NEED %d]", g_HostName, need);
  } else {
    Format(hostname, sizeof(hostname), "%s", g_HostName);
  }

  g_HostnameCvar.SetString(hostname);
}

public void PugSetup_OnGoingLive() {

  g_MatchStarted = FindConVar("sv_matchstarted");
  g_MatchStarted.SetBool(true);

  if (g_hEnabled.IntValue == 0)
    return;

  char hostname[MAX_HOST_LENGTH];
  Format(hostname, sizeof(hostname), "%s [LIVE]", g_HostName);
  g_HostnameCvar.SetString(hostname);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  if (g_hEnabled.IntValue == 0 || !PugSetup_IsMatchLive()) {
    g_MatchStarted = FindConVar("sv_matchstarted");
    g_MatchStarted.SetBool(false);
    return Plugin_Continue;
  }

  char hostname[MAX_HOST_LENGTH];
  Format(hostname, sizeof(hostname), "%s [LIVE %d-%d]", g_HostName, CS_GetTeamScore(CS_TEAM_CT),
         CS_GetTeamScore(CS_TEAM_T));
  g_HostnameCvar.SetString(hostname);

  return Plugin_Continue;
}

public void PugSetup_OnMatchOver() {
  if (GetConVarInt(g_hEnabled) == 0)
    return;

  g_MatchFinished = FindConVar("sv_matchfinished");
  g_MatchFinished.SetBool(true);

  g_HostnameCvar.SetString(g_HostName);
}