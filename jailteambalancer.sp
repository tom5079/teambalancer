//Author: D rank
//
//Project:  ██╗      █████╗ ███╗   ██╗███████╗███████╗███████╗
//          ██║     ██╔══██╗████╗  ██║██╔════╝██╔════╝██╔════╝
//          ██║     ███████║██╔██╗ ██║█████╗  ███████╗███████╗
//          ██║     ██╔══██║██║╚██╗██║██╔══╝  ╚════██║╚════██║
//          ███████╗██║  ██║██║ ╚████║███████╗███████║███████║
//          ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝╚══════╝

#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdktools>

#define PREFIX "[\x05LANESS\x01]"
#define BUFSIZE 255

public Plugin myinfo = {
	name = "JailTeamBalancer",
	description = "Team balancing plugin",
	author = "D rank",
	version = "1.0",
	url = "surf.quaver.xyz"
};

stock int GetRealClientCount() {
    new nClients = 0;

    for (new i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && !IsFakeClient(i))
            nClients++;

    return nClients;
}

stock bool CheckAdmin(int client, AdminFlag flag) {
	return (GetUserAdmin(client) != INVALID_ADMIN_ID && GetAdminFlag(GetUserAdmin(client), flag, Access_Effective));
}

ConVar g_teamratio; 

public void OnPluginStart() {
	g_teamratio = CreateConVar("jailteambalancer_teamratio", "1", "T/CT Ratio", _, true, 1.0, false, 0.0);
	
	AutoExecConfig(true, "jailteambalancer");
	
	HookEvent("player_connect_full", OnPlayerConnectFull);
	HookEvent("round_end", OnRoundEnd);
	
	AddCommandListener(OnJoinTeam, "jointeam");
	AddCommandListener(OnJoinGame, "joingame");
}

public void SetClientTeam(int userid) {
	int client = GetClientOfUserId(userid);
	
	if (IsFakeClient(client))
		return;
	
	int t_count = GetTeamClientCount(CS_TEAM_T);
	int ct_count = GetTeamClientCount(CS_TEAM_CT);
	
	if (GetRealClientCount() == 1) {
		ChangeClientTeam(client, CS_TEAM_CT);
		PrintToChat(client, "%s 현재 아무도 없으므로 대테러팀에 참가합니다", PREFIX);
		return;
	}
	
	float ratio = t_count / float(ct_count);
	
	if (ratio < g_teamratio.FloatValue) {
		ChangeClientTeam(client, CS_TEAM_T);
		PrintToChat(client, "%s 대테러가 충분하므로 테러팀에 참가합니다", PREFIX);
	} else {
		ChangeClientTeam(client, CS_TEAM_CT);
		PrintToChat(client, "%s 테러가 충분하므로 대테러팀에 참가합니다", PREFIX);
	}
}

public Action OnPlayerConnectFull(Handle event, const char[] name, bool dontBroadcast) {
	RequestFrame(SetClientTeam, GetEventInt(event, "userid"));
	
	return Plugin_Continue;
}

public void RandomlyMoveTo(int team) {
	int rand = GetRandomInt(1, MaxClients);
	
	while(!IsClientInGame(rand) || IsFakeClient(rand) || GetClientTeam(rand) != (team==CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T))
		rand = GetRandomInt(1, MaxClients);
	
	ChangeClientTeam(rand, team);
	
	char buf[BUFSIZE];
	
	GetClientName(rand, buf, BUFSIZE);
	
	PrintToChatAll("%s %s 님은 자동 팀설정에 의해 %s팀이 되었습니다", PREFIX, buf, (team==CS_TEAM_T ? "죄수" : "간수"));
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast) {
	int t_count = GetTeamClientCount(CS_TEAM_T);
	int ct_count = GetTeamClientCount(CS_TEAM_CT);
	
	float ratio = t_count / float(ct_count);
	float target = g_teamratio.FloatValue;
	
	if(ct_count == 0 && t_count == 0)
		return Plugin_Continue;
	if(ct_count == 0 && t_count != 0) {
		RandomlyMoveTo(CS_TEAM_CT);
		ct_count++;
	}
	
	while(!(target-(target/ct_count) <= ratio && ratio <= target)) {
		
		if (ratio < target-(target/ct_count)) {
			RandomlyMoveTo(CS_TEAM_T);
			ct_count--;
			t_count++;
		} else {
			RandomlyMoveTo(CS_TEAM_CT);
			t_count--;
			ct_count++;
		}
		
		ratio = t_count / float(ct_count);
	}
	
	return Plugin_Continue;
}

public Action OnJoinTeam(int client, const char[] command, int argc) {
	char buf[BUFSIZE];
	
	GetCmdArg(1, buf, BUFSIZE);
	
	if (StrEqual(buf, "0"))
		PrintToChat(client, "%s 자동선택은 차단되어있습니다. 비율에 맞게 배치되었습니다", PREFIX);
	else if (StrEqual(buf, "1")) {
		if (CheckAdmin(client, Admin_Generic))
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		else
			PrintToChat(client, "%s 관전은 어드민만 가능합니다", PREFIX);
	} else if(CheckAdmin(client, Admin_Generic))
		RequestFrame(SetClientTeam, GetClientUserId(client));
	
	return Plugin_Handled;
}

public Action OnJoinGame(int client, const char[] command, int argc) {
	return Plugin_Handled;
}