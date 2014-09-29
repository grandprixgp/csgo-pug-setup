#pragma semicolon 1
#include <cstrike>
#include <sourcemod>
#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

Handle g_hAutoKickerEnabled = INVALID_HANDLE;
Handle g_hKickMessage = INVALID_HANDLE;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: autokicker",
    author = "splewis",
    description = "Tools for setting up pugs/10mans",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public OnPluginStart() {
    g_hAutoKickerEnabled = CreateConVar("sm_pugsetup_autokicker_enabled", "0", "Whether the autokicker is enabled or not");
    g_hKickMessage = CreateConVar("sm_pugsetup_autokicker_message", "Sorry, this pug is full.", "Message to show to clients when they are kicked");
    AutoExecConfig(true, "pugsetup_autokicker.cfg", "sourcemod/pugsetup");
}

public bool OnClientConnect(int client, char rejectmsg[], int maxlen) {
    if (IsMatchLive() && GetConVarInt(g_hAutoKickerEnabled) != 0) {
        // count number of active players
        int count = 0;
        for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i)) {
                int team = GetClientTeam(i);
                if (team != CS_TEAM_NONE && team != CS_TEAM_SPECTATOR) {
                    count++;
                }
            }
        }

        if (count >= GetPugMaxPlayers()) {
            GetConVarString(g_hKickMessage, rejectmsg, maxlen);
            return false;
        }
    }

    return true;
}