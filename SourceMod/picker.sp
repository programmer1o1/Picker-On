// woo hoo, this is some picking it rn!
#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

bool g_enabled[MAXPLAYERS + 1];
ConVar g_cvDist;
ConVar g_cvSmooth;
Handle g_hud;
int g_target[MAXPLAYERS + 1];
float g_lastang[MAXPLAYERS + 1][3];
bool g_manual[MAXPLAYERS + 1];
ArrayList g_targets[MAXPLAYERS + 1];
int g_targetidx[MAXPLAYERS + 1];
float g_manualtime[MAXPLAYERS + 1];
bool g_teamplay = false;
bool g_teamplayDetected = false;

public Plugin myinfo = {
    name = "Picker",
    author = "Sierra",
    description = "Sourcebox Aimbot from Interloper F by Anomidae",
    version = "1.0",
    url = ""
};

public void OnPluginStart() {
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");
    
    RegAdminCmd("sm_giveaimbot", Command_Give, ADMFLAG_SLAY);
    
    g_cvDist = CreateConVar("sm_aimbot_distance", "5000.0", "max distance");
    g_cvSmooth = CreateConVar("sm_aimbot_smoothing", "0.15", "smoothing amount", _, true, 0.05, true, 1.0);
    
    g_hud = CreateHudSynchronizer();
    
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_Spawn);
    
    for (int i = 1; i <= MaxClients; i++) {
        g_target[i] = -1;
        g_enabled[i] = false;
        g_manual[i] = false;
        g_targets[i] = null;
        g_targetidx[i] = 0;
        g_manualtime[i] = 0.0;
    }
}

public void OnMapStart() {
    g_teamplayDetected = false;
}

bool DetectTeamplay() {
    if (g_teamplayDetected)
        return g_teamplay;
    
    // count distinct teams with players
    int teamCounts[32];
    int numTeams = 0;
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValid(i) && IsPlayerAlive(i)) {
            int team = GetClientTeam(i);
            if (team >= 2) {
                teamCounts[team]++;
            }
        }
    }
    
    // count how many teams have players
    for (int i = 2; i < sizeof(teamCounts); i++) {
        if (teamCounts[i] > 0)
            numTeams++;
    }
    
    // if 2+ teams have players, it's teamplay
    g_teamplay = (numTeams >= 2);
    g_teamplayDetected = true;
    
    PrintToServer("[Picker] teamplay detected: %s", g_teamplay ? "true" : "false");
    
    return g_teamplay;
}

public void OnClientConnected(int client) {
    g_enabled[client] = false;
    g_target[client] = -1;
    g_manual[client] = false;
    g_targets[client] = null;
    g_targetidx[client] = 0;
    g_manualtime[client] = 0.0;
}

public void OnClientDisconnect(int client) {
    g_enabled[client] = false;
    g_target[client] = -1;
    g_manual[client] = false;
    
    if (g_targets[client] != null) {
        delete g_targets[client];
        g_targets[client] = null;
    }
    
    if (g_hud != null)
        ClearSyncHud(client, g_hud);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    g_teamplayDetected = false;
    
    for (int i = 1; i <= MaxClients; i++) {
        g_target[i] = -1;
        g_manual[i] = false;
        g_targetidx[i] = 0;
        g_manualtime[i] = 0.0;
        if (g_targets[i] != null) {
            delete g_targets[i];
            g_targets[i] = null;
        }
    }
    return Plugin_Continue;
}

public Action Event_Spawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValid(client)) {
        g_target[client] = -1;
        g_manual[client] = false;
        g_targetidx[client] = 0;
        g_manualtime[client] = 0.0;
        if (g_targets[client] != null) {
            delete g_targets[client];
            g_targets[client] = null;
        }
    }
    return Plugin_Continue;
}

public Action Command_Say(int client, const char[] command, int argc) {
    if (!IsValid(client))
        return Plugin_Continue;
    
    char txt[192];
    GetCmdArgString(txt, sizeof(txt));
    StripQuotes(txt);
    
    if (StrEqual(txt, "!aimbot", false) || StrEqual(txt, "/aimbot", false) ||
        StrEqual(txt, "!picker", false) || StrEqual(txt, "/picker", false)) {
        
        g_enabled[client] = !g_enabled[client];
        g_target[client] = -1;
        g_manual[client] = false;
        g_targetidx[client] = 0;
        g_manualtime[client] = 0.0;
        
        if (g_targets[client] != null) {
            delete g_targets[client];
            g_targets[client] = null;
        }
        
        if (g_hud != null)
            ClearSyncHud(client, g_hud);
        
        return Plugin_Handled;
    }
    
    if (StrEqual(txt, "!nexttarget", false) || StrEqual(txt, "/nexttarget", false)) {
        if (g_enabled[client] && IsPlayerAlive(client)) {
            g_manual[client] = true;
            g_manualtime[client] = GetGameTime();
            
            if (g_targets[client] != null)
                delete g_targets[client];
            
            g_targets[client] = BuildList(client);
            
            if (g_targets[client] != null && g_targets[client].Length > 0) {
                g_targetidx[client]++;
                if (g_targetidx[client] >= g_targets[client].Length)
                    g_targetidx[client] = 0;
                
                g_target[client] = g_targets[client].Get(g_targetidx[client]);
            }
        }
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

ArrayList BuildList(int client) {
    ArrayList list = new ArrayList();
    
    int team = GetClientTeam(client);
    float pos[3];
    GetClientEyePosition(client, pos);
    float maxd = g_cvDist.FloatValue;
    bool teamplay = DetectTeamplay();
    
    // enemies first
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValid(i) || !IsPlayerAlive(i) || i == client)
            continue;
        
        int t = GetClientTeam(i);
        
        if (teamplay) {
            if (t <= 1 || t == team)
                continue;
        }
        
        float tpos[3];
        GetClientEyePosition(i, tpos);
        float dist = GetVectorDistance(pos, tpos);
        
        if (dist > maxd || !CanSee(client, i, tpos))
            continue;
        
        list.Push(i);
    }
    
    // teammates (only in teamplay)
    if (teamplay) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsValid(i) || !IsPlayerAlive(i) || i == client)
                continue;
            
            int t = GetClientTeam(i);
            if (t <= 1 || t != team)
                continue;
            
            float tpos[3];
            GetClientEyePosition(i, tpos);
            float dist = GetVectorDistance(pos, tpos);
            
            if (dist > maxd || !CanSee(client, i, tpos))
                continue;
            
            list.Push(i);
        }
    }
    
    // props
    char props[][] = {
        "prop_physics",
        "prop_physics_multiplayer",
        "prop_physics_override"
    };
    
    for (int p = 0; p < sizeof(props); p++) {
        int ent = -1;
        while ((ent = FindEntityByClassname(ent, props[p])) != -1) {
            if (!IsValidEntity(ent))
                continue;
            
            float tpos[3];
            GetEntPropVector(ent, Prop_Send, "m_vecOrigin", tpos);
            float dist = GetVectorDistance(pos, tpos);
            
            if (dist > maxd || !CanSee(client, ent, tpos))
                continue;
            
            list.Push(ent);
        }
    }
    
    return list;
}

public Action Command_Give(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "[SM] usage: sm_giveaimbot <target>");
        return Plugin_Handled;
    }
    
    char arg[65];
    GetCmdArg(1, arg, sizeof(arg));
    
    int t = FindTarget(client, arg, true, false);
    if (t == -1)
        return Plugin_Handled;
    
    g_enabled[t] = true;
    
    if (g_hud != null)
        ClearSyncHud(t, g_hud);
    
    ReplyToCommand(client, "[SM] gave aimbot to %N", t);
    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2]) {
    if (!IsValid(client))
        return Plugin_Continue;
    
    if (g_enabled[client]) {
        SetHudTextParams(-1.0, 0.53, 0.55, 255, 160, 0, 255, 0, 0.0, 0.0, 0.0);
        ShowSyncHudText(client, g_hud, "PICKER ON");
        
        if (IsPlayerAlive(client)) {
            float t = GetGameTime();
            
            if (g_manual[client] && t - g_manualtime[client] > 3.0)
                g_manual[client] = false;
            
            if (g_manual[client]) {
                if (g_target[client] == -1 || !IsValidTarget(client, g_target[client])) {
                    g_manual[client] = false;
                } else {
                    int best = GetBest(client);
                    
                    if (best != -1) {
                        bool curEnemy = false;
                        bool teamplay = DetectTeamplay();
                        
                        if (g_target[client] > 0 && g_target[client] <= MaxClients) {
                            int ct = GetClientTeam(g_target[client]);
                            int pt = GetClientTeam(client);
                            
                            if (teamplay) {
                                if (ct != pt && ct > 1)
                                    curEnemy = true;
                            } else {
                                curEnemy = true;
                            }
                        }
                        
                        bool bestEnemy = false;
                        if (best > 0 && best <= MaxClients) {
                            int bt = GetClientTeam(best);
                            int pt = GetClientTeam(client);
                            
                            if (teamplay) {
                                if (bt != pt && bt > 1)
                                    bestEnemy = true;
                            } else {
                                bestEnemy = true;
                            }
                        }
                        
                        if (bestEnemy && !curEnemy) {
                            g_manual[client] = false;
                            g_target[client] = best;
                        } else if (bestEnemy && curEnemy) {
                            float ppos[3];
                            GetClientEyePosition(client, ppos);
                            
                            float cpos[3], bpos[3];
                            GetClientEyePosition(g_target[client], cpos);
                            GetClientEyePosition(best, bpos);
                            
                            float cd = GetVectorDistance(ppos, cpos);
                            float bd = GetVectorDistance(ppos, bpos);
                            
                            if (bd < cd * 0.5) {
                                g_manual[client] = false;
                                g_target[client] = best;
                            }
                        }
                    }
                }
            } else {
                int nt = GetBest(client);
                if (nt != -1)
                    g_target[client] = nt;
            }
            
            if (g_target[client] != -1)
                Aim(client, g_target[client]);
            
            GetClientEyeAngles(client, g_lastang[client]);
        }
    } else {
        if (g_hud != null)
            ClearSyncHud(client, g_hud);
    }
    
    return Plugin_Continue;
}

bool IsValidTarget(int client, int ent) {
    if (ent <= 0)
        return false;
    
    if (ent <= MaxClients) {
        if (!IsValid(ent) || !IsPlayerAlive(ent) || ent == client)
            return false;
        
        int t = GetClientTeam(ent);
        bool teamplay = DetectTeamplay();
        
        if (teamplay && t <= 1)
            return false;
        
        float tpos[3];
        GetClientEyePosition(ent, tpos);
        return CanSee(client, ent, tpos);
    }
    
    if (!IsValidEntity(ent))
        return false;
    
    float tpos[3];
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", tpos);
    return CanSee(client, ent, tpos);
}

int GetBest(int client) {
    int team = GetClientTeam(client);
    float pos[3];
    GetClientEyePosition(client, pos);
    float maxd = g_cvDist.FloatValue;
    bool teamplay = DetectTeamplay();
    
    int bestEnemy = -1;
    int bestTeam = -1;
    int bestProp = -1;
    float bestED = 999999.0;
    float bestTD = 999999.0;
    float bestPD = 999999.0;
    
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValid(i) || !IsPlayerAlive(i) || i == client)
            continue;
        
        int t = GetClientTeam(i);
        
        float tpos[3];
        GetClientEyePosition(i, tpos);
        float dist = GetVectorDistance(pos, tpos);
        
        if (dist > maxd || !CanSee(client, i, tpos))
            continue;
        
        if (teamplay) {
            if (t <= 1)
                continue;
            
            if (t != team) {
                if (dist < bestED) {
                    bestED = dist;
                    bestEnemy = i;
                }
            } else {
                if (dist < bestTD) {
                    bestTD = dist;
                    bestTeam = i;
                }
            }
        } else {
            // ffa mode - everyone is enemy
            if (dist < bestED) {
                bestED = dist;
                bestEnemy = i;
            }
        }
    }
    
    if (bestEnemy != -1)
        return bestEnemy;
    
    if (bestTeam != -1)
        return bestTeam;
    
    char props[][] = {
        "prop_physics",
        "prop_physics_multiplayer",
        "prop_physics_override"
    };
    
    for (int p = 0; p < sizeof(props); p++) {
        int ent = -1;
        while ((ent = FindEntityByClassname(ent, props[p])) != -1) {
            if (!IsValidEntity(ent))
                continue;
            
            float tpos[3];
            GetEntPropVector(ent, Prop_Send, "m_vecOrigin", tpos);
            float dist = GetVectorDistance(pos, tpos);
            
            if (dist > maxd || !CanSee(client, ent, tpos))
                continue;
            
            if (dist < bestPD) {
                bestPD = dist;
                bestProp = ent;
            }
        }
    }
    
    return bestProp;
}

bool CanSee(int client, int target, float tpos[3]) {
    float pos[3];
    GetClientEyePosition(client, pos);
    
    Handle tr = TR_TraceRayFilterEx(pos, tpos, MASK_SHOT, RayType_EndPoint, Filter, client);
    
    bool vis = false;
    
    if (TR_DidHit(tr)) {
        int hit = TR_GetEntityIndex(tr);
        
        if (hit == target) {
            vis = true;
        } else {
            float end[3];
            TR_GetEndPosition(end, tr);
            float d = GetVectorDistance(end, tpos);
            
            if (d < 100.0)
                vis = true;
        }
    } else {
        vis = true;
    }
    
    delete tr;
    return vis;
}

public bool Filter(int ent, int mask, int client) {
    return ent != client;
}

void Aim(int client, int ent) {
    float pos[3], tpos[3];
    GetClientEyePosition(client, pos);
    
    if (ent > 0 && ent <= MaxClients)
        GetClientEyePosition(ent, tpos);
    else
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", tpos);
    
    float want[3];
    MakeVectorFromPoints(pos, tpos, want);
    GetVectorAngles(want, want);
    
    float cur[3];
    GetClientEyeAngles(client, cur);
    
    float dp = NormAng(want[0] - cur[0]);
    float dy = NormAng(want[1] - cur[1]);
    float td = SquareRoot(dp*dp + dy*dy);
    
    float smooth = g_cvSmooth.FloatValue;
    
    if (td < 5.0)
        smooth *= 0.6;
    else if (td > 30.0)
        smooth *= 1.3;
    
    float newang[3];
    newang[0] = Lerp(cur[0], want[0], smooth);
    newang[1] = Lerp(cur[1], want[1], smooth);
    newang[2] = 0.0;
    
    if (newang[0] > 89.0) newang[0] = 89.0;
    if (newang[0] < -89.0) newang[0] = -89.0;
    
    while (newang[1] > 180.0) newang[1] -= 360.0;
    while (newang[1] < -180.0) newang[1] += 360.0;
    
    TeleportEntity(client, NULL_VECTOR, newang, NULL_VECTOR);
}

float Lerp(float from, float to, float amt) {
    float d = NormAng(to - from);
    return from + d * amt;
}

float NormAng(float a) {
    while (a > 180.0) a -= 360.0;
    while (a < -180.0) a += 360.0;
    return a;
}

bool IsValid(int client) {
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}