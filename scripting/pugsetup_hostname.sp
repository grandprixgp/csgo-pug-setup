#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/util.sp"

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

  g_MatchStarted = CreateConVar("de_stats_match_started", "1", "Whether the match is started");
  g_MatchFinished = CreateConVar("de_stats_match_finished", "0", "Whether the match is finished");

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
  if (g_hEnabled.IntValue == 0)
    return;

  char hostname[MAX_HOST_LENGTH];
  Format(hostname, sizeof(hostname), "%s [LIVE]", g_HostName);
  g_HostnameCvar.SetString(hostname);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  if (g_hEnabled.IntValue == 0 || !PugSetup_IsMatchLive())
    return Plugin_Continue;

  char hostname[MAX_HOST_LENGTH];
  Format(hostname, sizeof(hostname), "%s [LIVE %d-%d]", g_HostName, CS_GetTeamScore(CS_TEAM_CT),
         CS_GetTeamScore(CS_TEAM_T));
  g_HostnameCvar.SetString(hostname);

  return Plugin_Continue;
}

public void PugSetup_OnMatchOver() {
  if (GetConVarInt(g_hEnabled) == 0)
    return;

  g_MatchFinished = FindConVar("de_stats_match_finished");
  g_MatchFinished.SetBool(1);
  g_HostnameCvar.SetString(g_HostName);
}
