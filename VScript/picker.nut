// I AM NOT GONNA SUGARCOAT IT
// PICKER ON!!!!
// words by great Anomidae

if (!("g_enabled" in getroottable()))
{
    ::g_enabled <- {};
    ::g_target <- {};
    ::g_manual <- {};
    ::g_targets <- {};
    ::g_targetidx <- {};
    ::g_manualtime <- {};
    ::g_lasthud <- {};
    ::g_first <- true;
}
else
{
    ::g_first <- false;
}

::MAX_DIST <- 5000.0;
::SMOOTH <- 0.15;
::MANUAL_TIMEOUT <- 3.0;

function InitPlayer(p)
{
    local id = p.GetEntityIndex().tostring();
    g_enabled[id] <- false;
    g_target[id] <- null;
    g_manual[id] <- false;
    g_targets[id] <- [];
    g_targetidx[id] <- 0;
    g_manualtime[id] <- 0.0;
    g_lasthud[id] <- 0.0;
}

function ShowHud(p, msg)
{
    local txt = SpawnEntityFromTable("game_text", {
        message = msg,
        channel = 1,
        x = -1,
        y = 0.53,
        effect = 0,
        color = "255 160 0",
        color2 = "255 160 0",
        fadein = 0.0,
        fadeout = 0.0,
        holdtime = 0.55,
        fxtime = 0,
        spawnflags = 0
    });
    
    if (txt != null)
    {
        EntFireByHandle(txt, "Display", "", 0.0, p, p);
        EntFireByHandle(txt, "Kill", "", 0.6, null, null);
    }
}

function ClearHud(p)
{
    local txt = SpawnEntityFromTable("game_text", {
        message = "",
        channel = 1,
        x = -1,
        y = 0.53,
        holdtime = 0
    });
    
    if (txt != null)
    {
        EntFireByHandle(txt, "Display", "", 0.0, p, p);
        EntFireByHandle(txt, "Kill", "", 0.01, null, null);
    }
}

function Toggle(p)
{
    local id = p.GetEntityIndex().tostring();
    
    if (!(id in g_enabled))
        InitPlayer(p);
    
    g_enabled[id] = !g_enabled[id];
    g_target[id] = null;
    g_manual[id] = false;
    g_targetidx[id] = 0;
    g_manualtime[id] = 0.0;
    g_targets[id] = [];
    
    if (!g_enabled[id])
        ClearHud(p);
}

function NextTarget(p)
{
    local id = p.GetEntityIndex().tostring();
    
    if (!(id in g_enabled) || !g_enabled[id] || !p.IsAlive())
        return;
    
    g_manual[id] = true;
    g_manualtime[id] = Time();
    g_targets[id] = BuildList(p);
    
    if (g_targets[id].len() > 0)
    {
        g_targetidx[id]++;
        if (g_targetidx[id] >= g_targets[id].len())
            g_targetidx[id] = 0;
        
        g_target[id] = g_targets[id][g_targetidx[id]];
    }
}

function BuildList(p)
{
    local list = [];
    local team = p.GetTeam();
    local pos = p.EyePosition();
    
    // enemies first
    local e = null;
    while ((e = Entities.FindByClassname(e, "player")) != null)
    {
        if (e == p || !e.IsAlive())
            continue;
        
        local t = e.GetTeam();
        if (t <= 1 || t == team)
            continue;
        
        local tpos = e.EyePosition();
        local dist = (tpos - pos).Length();
        
        if (dist > MAX_DIST || !CanSee(p, e, tpos))
            continue;
        
        list.append(e);
    }
    
    // teammates
    e = null;
    while ((e = Entities.FindByClassname(e, "player")) != null)
    {
        if (e == p || !e.IsAlive())
            continue;
        
        local t = e.GetTeam();
        if (t <= 1 || t != team)
            continue;
        
        local tpos = e.EyePosition();
        local dist = (tpos - pos).Length();
        
        if (dist > MAX_DIST || !CanSee(p, e, tpos))
            continue;
        
        list.append(e);
    }
    
    // props
    local props = ["prop_physics", "prop_physics_multiplayer", "prop_physics_override"];
    foreach (c in props)
    {
        e = null;
        while ((e = Entities.FindByClassname(e, c)) != null)
        {
            local tpos = e.GetOrigin();
            local dist = (tpos - pos).Length();
            
            if (dist > MAX_DIST || !CanSee(p, e, tpos))
                continue;
            
            list.append(e);
        }
    }
    
    return list;
}

function IsValid(p, e)
{
    if (e == null || !e.IsValid())
        return false;
    
    local c = e.GetClassname();
    if (c == "player")
    {
        if (!e.IsAlive() || e == p)
            return false;
        
        local t = e.GetTeam();
        if (t <= 1)
            return false;
        
        return CanSee(p, e, e.EyePosition());
    }
    
    return CanSee(p, e, e.GetOrigin());
}

function GetBest(p)
{
    local team = p.GetTeam();
    local pos = p.EyePosition();
    
    local bestEnemy = null;
    local bestTeam = null;
    local bestProp = null;
    local bestEDist = 999999.0;
    local bestTDist = 999999.0;
    local bestPDist = 999999.0;
    
    local e = null;
    while ((e = Entities.FindByClassname(e, "player")) != null)
    {
        if (e == p || !e.IsAlive())
            continue;
        
        local t = e.GetTeam();
        if (t <= 1)
            continue;
        
        local tpos = e.EyePosition();
        local dist = (tpos - pos).Length();
        
        if (dist > MAX_DIST || !CanSee(p, e, tpos))
            continue;
        
        if (t != team)
        {
            if (dist < bestEDist)
            {
                bestEDist = dist;
                bestEnemy = e;
            }
        }
        else
        {
            if (dist < bestTDist)
            {
                bestTDist = dist;
                bestTeam = e;
            }
        }
    }
    
    if (bestEnemy != null)
        return bestEnemy;
    
    if (bestTeam != null)
        return bestTeam;
    
    local props = ["prop_physics", "prop_physics_multiplayer", "prop_physics_override"];
    foreach (c in props)
    {
        e = null;
        while ((e = Entities.FindByClassname(e, c)) != null)
        {
            local tpos = e.GetOrigin();
            local dist = (tpos - pos).Length();
            
            if (dist > MAX_DIST || !CanSee(p, e, tpos))
                continue;
            
            if (dist < bestPDist)
            {
                bestPDist = dist;
                bestProp = e;
            }
        }
    }
    
    return bestProp;
}

function CanSee(p, t, tpos)
{
    local start = p.EyePosition();
    local trace = {
        start = start,
        end = tpos,
        ignore = p
    };
    
    TraceLineEx(trace);
    
    if ("enthit" in trace && trace.enthit == t)
        return true;
    
    if ("pos" in trace)
    {
        local d = (trace.pos - tpos).Length();
        if (d < 100.0)
            return true;
    }
    
    return false;
}

function CalcAngles(from, to)
{
    local d = to - from;
    local h = d.Length();
    
    if (h < 0.001)
        return QAngle(0, 0, 0);
    
    local pitch = asin(-d.z / h) * (180.0 / 3.14159);
    local yaw = atan2(d.y, d.x) * (180.0 / 3.14159);
    
    return QAngle(pitch, yaw, 0);
}

function NormAngle(a)
{
    while (a > 180.0) a -= 360.0;
    while (a < -180.0) a += 360.0;
    return a;
}

function Lerp(from, to, amt)
{
    local d = NormAngle(to - from);
    return from + d * amt;
}

function Aim(p, e)
{
    local ppos = p.EyePosition();
    local tpos = e.GetClassname() == "player" ? e.EyePosition() : e.GetOrigin();
    
    local want = CalcAngles(ppos, tpos);
    local cur = p.EyeAngles();
    
    local dp = NormAngle(want.x - cur.x);
    local dy = NormAngle(want.y - cur.y);
    local td = sqrt(dp * dp + dy * dy);
    
    local smooth = SMOOTH;
    if (td < 5.0) smooth *= 0.6;
    else if (td > 30.0) smooth *= 1.3;
    
    local np = Lerp(cur.x, want.x, smooth);
    local ny = Lerp(cur.y, want.y, smooth);
    
    if (np > 89.0) np = 89.0;
    if (np < -89.0) np = -89.0;
    
    while (ny > 180.0) ny -= 360.0;
    while (ny < -180.0) ny += 360.0;
    
    p.SnapEyeAngles(QAngle(np, ny, 0));
}

function Think()
{
    local t = Time();
    local p = null;
    
    while ((p = Entities.FindByClassname(p, "player")) != null)
    {
        if (!p.IsAlive())
            continue;
        
        local id = p.GetEntityIndex().tostring();
        
        if (!(id in g_enabled))
            InitPlayer(p);
        
        // hud update
        if (t - g_lasthud[id] > 0.54)
        {
            if (g_enabled[id])
                ShowHud(p, "PICKER ON");
            else
                ClearHud(p);
            
            g_lasthud[id] = t;
        }
        
        if (!g_enabled[id])
            continue;
        
        // manual timeout
        if (g_manual[id] && t - g_manualtime[id] > MANUAL_TIMEOUT)
            g_manual[id] = false;
        
        // manual mode logic
        if (g_manual[id])
        {
            if (g_target[id] == null || !IsValid(p, g_target[id]))
            {
                g_manual[id] = false;
            }
            else
            {
                local best = GetBest(p);
                if (best != null)
                {
                    local curEnemy = false;
                    local curClass = g_target[id].GetClassname();
                    
                    if (curClass == "player")
                    {
                        local ct = g_target[id].GetTeam();
                        local pt = p.GetTeam();
                        if (ct != pt && ct > 1)
                            curEnemy = true;
                    }
                    
                    local bestEnemy = false;
                    local bestClass = best.GetClassname();
                    
                    if (bestClass == "player")
                    {
                        local bt = best.GetTeam();
                        local pt = p.GetTeam();
                        if (bt != pt && bt > 1)
                            bestEnemy = true;
                    }
                    
                    // switch to enemy if current isn't
                    if (bestEnemy && !curEnemy)
                    {
                        g_manual[id] = false;
                        g_target[id] = best;
                    }
                    // switch if way closer
                    else if (bestEnemy && curEnemy)
                    {
                        local ppos = p.EyePosition();
                        local cd = (g_target[id].EyePosition() - ppos).Length();
                        local bd = (best.EyePosition() - ppos).Length();
                        
                        if (bd < cd * 0.5)
                        {
                            g_manual[id] = false;
                            g_target[id] = best;
                        }
                    }
                }
            }
        }
        else
        {
            local nt = GetBest(p);
            if (nt != null)
                g_target[id] = nt;
        }
        
        if (g_target[id] != null)
            Aim(p, g_target[id]);
    }
    
    EntFire("worldspawn", "CallScriptFunction", "Think", 0.015);
}

function OnGameEvent_round_start(params)
{
    foreach (id, _ in g_enabled)
    {
        g_target[id] = null;
        g_manual[id] = false;
        g_targetidx[id] = 0;
        g_manualtime[id] = 0.0;
        g_targets[id] = [];
    }
    
    EntFire("worldspawn", "RunScriptCode", "if(!(\"Think\" in this)) SendToConsole(\"script_execute aimbot.nut\")", 0.1);
}

__CollectGameEventCallbacks(this);

if (g_first)
    printl("picker ON - just do picker_toggle / picker_next in the console, you can bind them also");
else
    printl("picker reloaded");

SendToConsole("alias picker_toggle \"script Toggle(GetListenServerHost())\"");
SendToConsole("alias picker_next \"script NextTarget(GetListenServerHost())\"");

Think();