const int kNumMapsToPick = 3;

bool g_IRVActive = false;
ArrayList g_MapAliveInVote;
int g_RunnerUpMapIndex = -1;
int g_SecondRunnerUpMapIndex = -2;

// Contains the votes (by map index) for each client, in the order selected.
int g_VoteStartTime;
int g_ClientMapPicks[MAXPLAYERS + 1][kNumMapsToPick];
int g_ClientMapPosition[MAXPLAYERS + 1];

// Histogram of votes where map index -> current votes for that map.
// ArrayList g_CurrentVoteTallies;

public void ResetClientVote(int client) {
  for (int i = 0; i < kNumMapsToPick; i++) {
    g_ClientMapPicks[client][i] = -1;
  }
  g_ClientMapPosition[client] = 0;
}

public void StartInstantRunoffMapVote() {
  for (int i = 1; i <= MaxClients; i++) {
    g_ClientMapPosition[i] = -1;
    if (IsPlayer(i)) {
      ResetClientVote(i);
      ShowInstantRunoffMapVote(i, 0);
    }
  }

  g_VoteStartTime = GetTime();
  g_IRVActive = true;
  CreateTimer(1.0, Timer_ShowVoteStatus, _, TIMER_REPEAT);
  //CreateTimer(g_MapVoteTimeCvar.FloatValue, Timer_CollectIRVResults);
}


public Action Timer_ShowVoteStatus(Handle timer) {
  if (g_GameState != GameState_Warmup) {
    return Plugin_Stop;
  }

  int endTime = g_VoteStartTime + g_MapVoteTimeCvar.IntValue;
  int timeLeft = endTime - GetTime();

  for (int client = 0; client < MaxClients; client++) {
      if (IsPlayer(client)) {
        for (int i = 0; i < kNumMapsToPick; i++) {
            if (g_ClientMapPicks[client][i] == -1) {
                PrintHintTextToAll("Waiting for %N to vote!", client);
                return Plugin_Continue;
            }
        }
      }
  }

  Timer_CollectIRVResults();
  return Plugin_Stop;
}

static bool HasClientPickedMap(int client, int mapIndex) {
  for (int i = 0; i < kNumMapsToPick; i++) {
    if (g_ClientMapPicks[client][i] == mapIndex) {
      return true;
    }
  }
  return false;
}

public void ShowInstantRunoffMapVote(int client, int round) {
  Menu menu = new Menu(MapSelectionHandler);
  menu.SetTitle("%T", "IRVMenuTitle", client, round + 1);
  menu.ExitButton = false;

  // Don't paginate the menu if we have 7 maps or less, as they will fit
  // on one page when we don't add the pagination options
  if (g_MapVotePool.Length <= 7) {
    menu.Pagination = MENU_NO_PAGINATION;
  }

  for (int i = 0; i < g_MapVotePool.Length; i++) {
    if (!HasClientPickedMap(client, i)) {
      AddMapIndexToMenu(menu, g_MapVotePool, i);
    }
  }

  menu.Display(client, MENU_TIME_FOREVER/*g_MapVoteTimeCvar.IntValue*/);
}

public int MapSelectionHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    if (!g_IRVActive) {
      return 0;
    }

    int client = param1;
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));

    int mapIndex = GetMenuInt(menu, param2);
    char mapName[255];
    FormatMapName(g_MapVotePool, mapIndex, mapName, sizeof(mapName));
    PugSetup_Message(client, "%t", "IRVSelectionMessage", mapName, g_ClientMapPosition[client] + 1);

    g_ClientMapPicks[client][g_ClientMapPosition[client]] = mapIndex;
    g_ClientMapPosition[client]++;

    if (g_ClientMapPosition[client] < kNumMapsToPick) {
      ShowInstantRunoffMapVote(client, g_ClientMapPosition[client]);
    }

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

static int FindLeastVotedMap() {
  ArrayList voteCounts = new ArrayList();
  for (int i = 0; i < g_MapVotePool.Length; i++) {
    voteCounts.Push(0);
  }

  for (int i = 1; i <= MaxClients; i++) {
    int pos = g_ClientMapPosition[i];
    if (pos >= 0 && pos < kNumMapsToPick) {
      int mapIndex = g_ClientMapPicks[i][pos];
      if (mapIndex >= 0) {
        voteCounts.Set(mapIndex, voteCounts.Get(mapIndex) + 1);

        char mapName[64];
        g_MapVotePool.GetString(mapIndex, mapName, sizeof(mapName));
        LogDebug("%L has active vote for %d (%s) -> %d votes now", i, mapIndex, mapName,
                 voteCounts.Get(mapIndex));
      }
    }
  }

  // TODO: break ties randomly instead of always picking the earlier entry as the loser.
  int loserIndex = 0;
  int loserVotes = -1;
  for (int i = 0; i < voteCounts.Length; i++) {
    if (!g_MapAliveInVote.Get(i)) {
      continue;
    }

    if (voteCounts.Get(i) < loserVotes || loserVotes == -1) {
      loserVotes = voteCounts.Get(i);
      loserIndex = i;
    }
  }

  delete voteCounts;
  return loserIndex;
}

static int CountMapsAlive(int& winner) {
  int count = 0;
  for (int i = 0; i < g_MapAliveInVote.Length; i++) {
    if (g_MapAliveInVote.Get(i)) {
      count++;
      winner = i;
    }
  }
  return count;
}

public Action Timer_CollectIRVResults(/*Handle timer*/) {
  g_IRVActive = false;

  if (g_GameState != GameState_Warmup) {
    return;
  }

  if (g_MapAliveInVote == null) {
    g_MapAliveInVote = new ArrayList();
  } else {
    g_MapAliveInVote.Clear();
  }
  for (int i = 0; i < g_MapVotePool.Length; i++) {
    g_MapAliveInVote.Push(true);
  }

  for (int i = 1; i <= MaxClients; i++) {
    // Reset client ballots to slot 0 (first choice).
    if (g_ClientMapPosition[i] > 0) {
      g_ClientMapPosition[i] = 0;
      for (int j = 0; j < kNumMapsToPick; j++) {
        if (g_ClientMapPicks[i][j] >= 0) {
          char mapName[64];
          g_MapVotePool.GetString(g_ClientMapPicks[i][j], mapName, sizeof(mapName));
          LogDebug("Client %L choice %d = %d (%s)", i, j, g_ClientMapPicks[j], mapName);
        }
      }
    }
  }

  int mapLoser = -1;
  int winner = 0;
  for (int mapsLeft = CountMapsAlive(winner); mapsLeft > 1; mapsLeft = CountMapsAlive(winner)) {
    mapLoser = FindLeastVotedMap();
    char loserName[64];
    g_MapVotePool.GetString(mapLoser, loserName, sizeof(loserName));
    LogDebug("Map %d (%s) is the least voted map, eliminating", mapLoser, loserName);

    if (mapsLeft == 2) {
      g_RunnerUpMapIndex = mapLoser;
    } else if (mapsLeft == 3) {
      g_SecondRunnerUpMapIndex = mapLoser;
    }

    g_MapAliveInVote.Set(mapLoser, false);
    for (int i = 1; i <= MaxClients; i++) {
      int pos = g_ClientMapPosition[i];
      if (pos >= 0 && pos < kNumMapsToPick) {
        if (g_ClientMapPicks[i][pos] == mapLoser) {
          g_ClientMapPosition[i]++;
        }
      }
    }
  }

  char map1[64];
  FormatMapName(g_MapVotePool, winner, map1, sizeof(map1));
  ChangeMap(g_MapVotePool, winner, 10.0);
  PrintHintTextToAll("%t", "MapVoteWinnerHintText", map1);

  char map2[64];
  FormatMapName(g_MapVotePool, g_RunnerUpMapIndex, map2, sizeof(map2));

  char map3[64];
  FormatMapName(g_MapVotePool, g_SecondRunnerUpMapIndex, map3, sizeof(map3));

  PugSetup_MessageToAll("%t", "IRVResultMessage", map1, map2, map3);

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      PrintIRVInfoToConsole(i);
    }
  }
}

public void PrintIRVInfoToConsole(int client) {
  PrintToConsole(client, "--------------------------------------");
  PrintToConsole(client, "Instant runoff map vote results:");
  for (int i = 1; i <= MaxClients; i++) {
    if (!IsPlayer(i)) {
      continue;
    }

    for (int j = 0; j < kNumMapsToPick; j++) {
      char mapName[255];
      int mapIndex = g_ClientMapPicks[i][j];
      if (mapIndex >= 0) {
        FormatMapName(g_MapVotePool, mapIndex, mapName, sizeof(mapName));
        PrintToConsole(client, "%L map %d: %s", i, j + 1, mapName);
      }
    }
  }
}
