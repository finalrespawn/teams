#include <sourcemod>
#include <cstrike>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "Teams",
	author = "Clarkey",
	description = "Easy and effective team management.",
	version = "1.0",
	url = "http://finalrespawn.com"
};

/***************/
/** VARIABLES **/
/***************/

ConVar g_cBalanceTeams;
ConVar g_cCreateSpawns;
ConVar g_cOneTeam;
ConVar g_cSpawnIn;

bool g_BalanceTeams;
bool g_CreateSpawns;
bool g_OneTeam;
bool g_SpawnIn;

float g_SpawnPosition[3];

int g_CTCount;
int g_TCount;
int g_LimitTeams;
int g_ValidTeam;

/***********/
/** START **/
/***********/

public void OnPluginStart()
{
	g_cBalanceTeams = CreateConVar("sm_teams_balanceteams", "0", "The plugin should obey the mp_limitteams console variable.");
	g_cCreateSpawns = CreateConVar("sm_teams_createspawns", "0", "Spawns should be created up to MaxClients.");
	g_cOneTeam = CreateConVar("sm_teams_oneteam", "0", "Clients can only join the team that is first joined.");
	g_cSpawnIn = CreateConVar("sm_teams_spawnin", "1", "Should the plugin attempt to spawn players in?");
	
	AutoExecConfig();
	
	AddCommandListener(Command_JoinTeam, "jointeam");
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
}

public void OnMapStart()
{
	// Count CT spawns
	int Entity = -1;
	while ((Entity = FindEntityByClassname(Entity, "info_player_counterterrorist")) != -1)
	{
		if (g_SpawnPosition[0] == 0.0)
		{
			GetEntPropVector(Entity, Prop_Send, "m_vecOrigin", g_SpawnPosition);
		}
		
		g_CTCount++;
	}
	
	// Count T spawns
	Entity = -1;
	while ((Entity = FindEntityByClassname(Entity, "info_player_terrorist")) != -1)
	{
		if (g_SpawnPosition[0] == 0.0)
		{
			GetEntPropVector(Entity, Prop_Send, "m_vecOrigin", g_SpawnPosition);
		}
		
		g_TCount++;
	}
	
	g_ValidTeam = 0;
}

public void OnConfigsExecuted()
{
	g_BalanceTeams = g_cBalanceTeams.BoolValue;
	g_CreateSpawns = g_cCreateSpawns.BoolValue;
	g_OneTeam = g_cOneTeam.BoolValue;
	g_SpawnIn = g_cSpawnIn.BoolValue;
	
	if (g_BalanceTeams)
	{
		ConVar g_cLimitTeams = FindConVar("mp_limitteams");
		g_LimitTeams = g_cLimitTeams.IntValue;
	}
	
	if (g_CreateSpawns)
	{
		for (int i; i < (MaxClients - g_CTCount); i++)
		{
			int Entity = CreateEntityByName("info_player_counterterrorist");
			if (DispatchSpawn(Entity))
			{
				TeleportEntity(Entity, g_SpawnPosition, NULL_VECTOR, NULL_VECTOR);
			}
		}
		
		for (int i; i < (MaxClients - g_TCount); i++)
		{
			int Entity = CreateEntityByName("info_player_terrorist");
			if (DispatchSpawn(Entity))
			{
				TeleportEntity(Entity, g_SpawnPosition, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

/**************/
/** COMMANDS **/
/**************/

public Action Command_JoinTeam(int client, const char[] command, int arg)
{
	char Join[32];
	GetCmdArg(1, Join, sizeof(Join));
	int JoinTeam = StringToInt(Join);
	
	// We need a valid team, so don't interfere with the games behaviour
	if (g_OneTeam && AreTeamsEmpty())
	{
		if (g_ValidTeam == 0)
		{
			return Plugin_Continue;
		}
		else if (JoinTeam == g_ValidTeam)
		{
			ChangeTeam(client, JoinTeam);
			return Plugin_Handled;
		}
	}
	else if (JoinTeam == CS_TEAM_CT)
	{
		if (g_BalanceTeams)
		{
			if (TeamHasValidAmount(CS_TEAM_CT))
			{
				ChangeTeam(client, CS_TEAM_CT);
				return Plugin_Handled;
			}
			
		}
		else
		{
			if (!g_OneTeam)
			{
				ChangeTeam(client, CS_TEAM_CT);
				return Plugin_Handled;
			}
			else
			{
				if (g_ValidTeam == CS_TEAM_CT)
				{
					ChangeTeam(client, CS_TEAM_CT);
					return Plugin_Handled;
				}
			}
		}
	}
	else if (JoinTeam == CS_TEAM_T)
	{
		if (g_BalanceTeams)
		{
			if (TeamHasValidAmount(CS_TEAM_T))
			{
				ChangeTeam(client, CS_TEAM_T);
				return Plugin_Handled;
			}
		}
		else
		{
			if (!g_OneTeam)
			{
				ChangeTeam(client, CS_TEAM_T);
				return Plugin_Handled;
			}
			else
			{
				if (g_ValidTeam == CS_TEAM_T)
				{
					ChangeTeam(client, CS_TEAM_T);
					return Plugin_Handled;
				}
			}
		}
	}
	else if (JoinTeam == CS_TEAM_SPECTATOR)
	{
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		return Plugin_Handled;
	}
	
	return Plugin_Changed;
}

/************/
/** EVENTS **/
/************/

public Action Event_PlayerTeam(Event event, const char[] name, bool dontbroadcast)
{
	if (g_OneTeam && AreTeamsEmpty())
	{
		int Team = event.GetInt("team");
		
		switch (Team)
		{
			case CS_TEAM_CT:
			{
				g_ValidTeam = CS_TEAM_CT;
			}
			case CS_TEAM_T:
			{
				g_ValidTeam = CS_TEAM_T;
			}
		}
	}
	
	return Plugin_Handled;
}

/************/
/** STOCKS **/
/************/

int AreTeamsEmpty()
{
	if (!GetTeamClientCount(CS_TEAM_CT) && !GetTeamClientCount(CS_TEAM_T))
	{
		return true;
	}
	
	return false;
}

void ChangeTeam(int client, int team)
{
	ChangeClientTeam(client, team);
	if (g_SpawnIn)
	{
		CreateTimer(0.5, Timer_Spawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

bool TeamHasValidAmount(int team)
{
	int Difference = GetTeamClientCount(CS_TEAM_CT) - GetTeamClientCount(CS_TEAM_T);
	
	if ((Difference <= g_LimitTeams) && (Difference >= (0 - g_LimitTeams)))
	{
		return true;
	}
	
	// If the difference isn't close enough, does the team have less players?
	if (team == CS_TEAM_CT)
	{
		if (GetTeamClientCount(CS_TEAM_CT) < GetTeamClientCount(CS_TEAM_T))
		{
			return true;
		}
	}
	else if (team == CS_TEAM_T)
	{
		if (GetTeamClientCount(CS_TEAM_T) < GetTeamClientCount(CS_TEAM_CT))
		{
			return true;
		}
	}
	
	return false;
}

/************/
/** TIMERS **/
/************/

public Action Timer_Spawn(Handle timer, any data)
{
	int Client = GetClientOfUserId(data);
	if (IsClientInGame(Client) && !IsPlayerAlive(Client))
	{
		CS_RespawnPlayer(Client);
	}
	
	return Plugin_Handled;
}