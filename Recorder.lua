local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LP
for i = 1, 100 do
    local ok, p = pcall(function() return Players.LocalPlayer end)
    if ok and p then LP = p break end
    wait(0.1)
end
if not LP then
    for i = 1, 100 do
        local ok, p = pcall(function() return game.Players.LocalPlayer end)
        if ok and p then LP = p break end
        wait(0.1)
    end
end
if not LP then
    notify("LocalPlayer unavailable", "Recorder", 3)
    return
end
for i = 1, 100 do
    if game:IsLoaded() and workspace.CurrentCamera then break end
    wait(0.1)
end

local S = {
    rec = false, play = false, loop_ = false, ghost = false,
    pEl = 0, gEl = 0, pIdx = 1, gIdx = 1,
    t0 = 0, lastT = tick(), drawn = 0,
    lastCfT = 0, frameGaps = 0, overflow = false,
    vtick = 0, phase = 0, stamp = 0,
    colorVer = 1, rcVer = 0,
    hudShown = false, hudKey = nil, gKey = nil, bKey = nil, cached = {},
    mapShown = false, mapKey = nil, trimShown = false, trimCV = -1,
    trailShown = false,
    dTrail = false, dMap = false, dTicks = false, dMk = false,
    tr = {h = 0, t = 0, hs = 0, ts = 0},
    tcKey = nil, tcH = nil, tcT = nil,
    prevKeys = {},
    fileCombo = nil,
    lastCf = nil,
}

local C = {
    rate = 20, pSpeed = 1.0, file = "movement_rec",
    showPath = true, showHud = true, showGraph = true, showBar = true, showMap = false,
    mapSize = 180, mapX = 0, mapY = 0, mapAlpha = 0.55,
    hudX = 20, hudY = 20, hudScale = 1.0, hudAlpha = 0.5, hudCorner = 6, hudFont = 5,
    trimPreview = true, heat = false, liveTrail = false, smoothTrail = true,
    ghostColor = {r = 255, g = 120, b = 255, a = 0.9},
    accentColor = {r = 120, g = 220, b = 180, a = 1},
    pathColor = {r = 120, g = 220, b = 180, a = 1},
    headColor = {r = 255, g = 60, b = 60, a = 1},
    tailColor = {r = 60, g = 180, b = 255, a = 1},
    trimColor = {r = 255, g = 140, b = 40, a = 0.9},
}

local K = {
    MAX_SEGS = 800, MIN_DIST = 0.1, MAX_FRAMES = 18000, LIVE_BATCH = 4,
    GRAPH_PTS = 60, HROWS = 6, HEAT_BANDS = 6,
    FOLDER = "recorder", CFG = "recorder_config.json",
    VK_R = 82, VK_P = 80, VK_L = 76, VK_G = 71,
    FONTS = {
        Drawing.Fonts.UI, Drawing.Fonts.System, Drawing.Fonts.SystemBold, Drawing.Fonts.Minecraft,
        Drawing.Fonts.Monospace, Drawing.Fonts.Pixel, Drawing.Fonts.Fortnite, Drawing.Fonts.ProximaSoftBold,
    },
    BANDS = {
        Color3.fromRGB(70, 140, 255), Color3.fromRGB(70, 220, 230), Color3.fromRGB(90, 255, 130),
        Color3.fromRGB(230, 255, 80), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 70, 70),
    },
    EDGES = {{0,1},{2,3},{4,5},{6,7},{0,2},{1,3},{4,6},{5,7},{0,4},{1,5},{2,6},{3,7}},
    SX = {}, SY = {}, SZ = {},
    DIM = Color3.fromRGB(120, 120, 130),
    WARN = Color3.fromRGB(255, 180, 90),
    REC = Color3.fromRGB(255, 90, 90),
}

for i = 0, 7 do
    K.SX[i + 1] = (i % 2 == 1) and 1 or -1
    K.SY[i + 1] = (math.floor(i / 2) % 2 == 1) and 1 or -1
    K.SZ[i + 1] = (i >= 4) and 1 or -1
end

local D = {
    frames = {}, spd = {}, spdS = {}, stat = {dist = 0, maxV = 0, minV = math.huge},
    marks = {}, trail = {}, mapSegs = {}, mk = {},
    graphSegs = {}, files = {}, bounds = nil,
}

local DR = { hud = {}, map = {}, trim = {}, ghost = {} }
local RC = {}
local PC = { v = {}, o = {}, s = {} }

local function refreshColors()
    RC.accent = {c = Color3.fromRGB(C.accentColor.r, C.accentColor.g, C.accentColor.b), a = C.accentColor.a}
    RC.path = {c = Color3.fromRGB(C.pathColor.r, C.pathColor.g, C.pathColor.b), a = C.pathColor.a}
    RC.head = {c = Color3.fromRGB(C.headColor.r, C.headColor.g, C.headColor.b), a = C.headColor.a}
    RC.tail = {c = Color3.fromRGB(C.tailColor.r, C.tailColor.g, C.tailColor.b), a = C.tailColor.a}
    RC.trim = {c = Color3.fromRGB(C.trimColor.r, C.trimColor.g, C.trimColor.b), a = C.trimColor.a}
    RC.ghost = {c = Color3.fromRGB(C.ghostColor.r, C.ghostColor.g, C.ghostColor.b), a = C.ghostColor.a}
    S.rcVer = S.colorVer
end
refreshColors()

local resetTrimValues

local function setGhost(v)
    if S.ghost == v then return end
    if v then
        if #D.frames < 2 then
            notify("No recording", "Recorder", 2)
            UI.SetValue("r_ghost", false)
            return
        end
        if S.play then
            notify("Stop playback first", "Recorder", 2)
            UI.SetValue("r_ghost", false)
            return
        end
        if S.rec then
            notify("Stop recording first", "Recorder", 2)
            UI.SetValue("r_ghost", false)
            return
        end
        S.ghost = true
        S.gEl = 0
        S.gIdx = 1
    else
        S.ghost = false
        if S.gShown then
            S.gShown = false
            for i = 1, 13 do DR.ghost.l[i].Visible = false end
        end
    end
    UI.SetValue("r_ghost", v)
end

local function setLoop(v)
    if S.loop_ == v then return end
    S.loop_ = v
    UI.SetValue("r_loop", v)
end

local function heatCol(v)
    local st = D.stat
    local rng = st.maxV - st.minV
    if rng <= 0 then rng = 1 end
    local t = math.clamp((v - st.minV) / rng, 0, 1)
    local bands = K.BANDS
    local nb = #bands
    if C.smoothTrail then
        return bands[math.floor(t * (nb - 1) + 0.5) + 1]
    end
    local seg = 1 / (nb - 1)
    local idx = math.min(math.floor(t / seg) + 1, nb - 1)
    local lt = (t - (idx - 1) * seg) / seg
    local c1, c2 = bands[idx], bands[idx + 1]
    return Color3.new(c1.R + (c2.R - c1.R) * lt, c1.G + (c2.G - c1.G) * lt, c1.B + (c2.B - c1.B) * lt)
end

local function catmullRomV3(a, b, c, d, t)
    local t2 = t * t
    local t3 = t2 * t
    return Vector3.new(
        0.5 * ((2 * b.X) + (-a.X + c.X) * t + (2 * a.X - 5 * b.X + 4 * c.X - d.X) * t2 + (-a.X + 3 * b.X - 3 * c.X + d.X) * t3),
        0.5 * ((2 * b.Y) + (-a.Y + c.Y) * t + (2 * a.Y - 5 * b.Y + 4 * c.Y - d.Y) * t2 + (-a.Y + 3 * b.Y - 3 * c.Y + d.Y) * t3),
        0.5 * ((2 * b.Z) + (-a.Z + c.Z) * t + (2 * a.Z - 5 * b.Z + 4 * c.Z - d.Z) * t2 + (-a.Z + 3 * b.Z - 3 * c.Z + d.Z) * t3)
    )
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function ensureFolder()
    if not isfolder(K.FOLDER) then pcall(makefolder, K.FOLDER) end
end

local function rpath(n)
    return K.FOLDER .. "/" .. n .. ".json"
end

local function mkLine(z)
    local l = Drawing.new("Line")
    l.Thickness, l.ZIndex, l.Visible = 2, z, false
    return l
end

local function mkSq(z)
    local s = Drawing.new("Square")
    s.Filled, s.Thickness, s.ZIndex, s.Visible = false, 2, z, false
    return s
end

local function mkText(size, font, color)
    local t = Drawing.new("Text")
    t.Size, t.Font, t.Color, t.Outline, t.ZIndex, t.Visible = size, font, color, true, 902, false
    return t
end

local function mkSquare(color, trans, corner, z)
    local s = Drawing.new("Square")
    s.Filled, s.Color, s.Transparency, s.Corner, s.ZIndex, s.Visible = true, color, trans, corner or 0, z or 900, false
    return s
end

local function mkDot(sides, radius, z, color)
    local c = Drawing.new("Circle")
    c.Filled, c.NumSides, c.Radius = true, sides, radius
    c.Transparency, c.ZIndex, c.Visible = 1, z, false
    if color then c.Color = color end
    return c
end

local function findIdx(tbl, t)
    local lo, hi = 1, #tbl
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if tbl[mid].t <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end

local function splineCf(idx, alpha)
    local fr = D.frames
    local n = #fr
    if n < 4 then return nil end
    if idx - 1 < 1 or idx + 2 > n then return nil end
    local pos = catmullRomV3(fr[idx - 1].p, fr[idx].p, fr[idx + 1].p, fr[idx + 2].p, alpha)
    local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = fr[idx].cf:Lerp(fr[idx + 1].cf, alpha):GetComponents()
    return CFrame.new(pos.X, pos.Y, pos.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

local function sampleCf(t)
    local fr = D.frames
    local n = #fr
    if n == 0 then return nil, 1 end
    if n == 1 or t <= fr[1].t then return fr[1].cf, 1 end
    if t >= fr[n].t then return fr[n].cf, n end
    local i = findIdx(fr, t)
    local a, b = fr[i], fr[i + 1]
    local seg = b.t - a.t
    local al = seg > 0 and (t - a.t) / seg or 0
    local c = splineCf(i, al)
    if c then return c, i end
    return a.cf:Lerp(b.cf, al), i
end

local function proj(i)
    if PC.s[i] == S.stamp then return PC.v[i], PC.o[i] end
    local v, o = WorldToScreen(D.frames[i].p)
    PC.v[i], PC.o[i], PC.s[i] = v, o, S.stamp
    return v, o
end

local function computeTrimIndices()
    local fr = D.frames
    local n = #fr
    if n < 2 then return nil, nil end
    local tr = S.tr
    local key = n .. "|" .. tr.h .. "|" .. tr.t .. "|" .. tr.hs .. "|" .. tr.ts
    if S.tcKey == key then return S.tcH, S.tcT end
    local hi, ti = 1, n
    if tr.hs > 0 then
        local cut = fr[1].t + tr.hs
        while hi < n and fr[hi].t < cut do hi = hi + 1 end
    end
    if tr.ts > 0 then
        local cut = fr[n].t - tr.ts
        while ti > 1 and fr[ti].t > cut do ti = ti - 1 end
    end
    if tr.h > 0 then hi = math.min(hi + tr.h, n) end
    if tr.t > 0 then ti = math.max(ti - tr.t, 1) end
    if hi >= ti then hi, ti = nil, nil end
    S.tcKey, S.tcH, S.tcT = key, hi, ti
    return hi, ti
end

local function recalcStat()
    local st = D.stat
    st.dist, st.maxV, st.minV = 0, 0, math.huge
    D.spd = {}
    local fr = D.frames
    for i = 2, #fr do
        local dt = fr[i].t - fr[i - 1].t
        if dt <= 0 then dt = 1 / C.rate end
        local d = (fr[i].p - fr[i - 1].p).Magnitude
        local v = d / dt
        D.spd[i] = v
        st.dist = st.dist + d
        if v > st.maxV then st.maxV = v end
        if v < st.minV then st.minV = v end
    end
    if st.minV == math.huge then st.minV = 0 end
end

local function smoothSpd()
    D.spdS = {}
    if not C.smoothTrail then return end
    local spd, ss = D.spd, D.spdS
    local n = #D.frames
    if n < 3 then
        for i = 1, n do ss[i] = spd[i] end
        return
    end
    ss[2] = spd[2]
    for i = 3, n - 1 do
        ss[i] = (spd[i - 1] + spd[i] * 2 + spd[i + 1]) * 0.25
    end
    ss[n] = spd[n]
end

local function pushFrame(t, cf)
    local fr = D.frames
    local n = #fr
    local p = cf.Position
    fr[n + 1] = { t = t, cf = cf, p = p }
    if n >= 1 then
        local pf = fr[n]
        local dt = t - pf.t
        if dt <= 0 then dt = 1 / C.rate end
        local d = (p - pf.p).Magnitude
        local v = d / dt
        local st = D.stat
        D.spd[n + 1] = v
        st.dist = st.dist + d
        if v > st.maxV then st.maxV = v end
        if v < st.minV then st.minV = v end
    end
end

local function stepFor(n)
    if n <= K.MAX_SEGS then return 1 end
    return math.ceil(n / K.MAX_SEGS)
end

local function segColor(i, prev)
    local c = heatCol(C.smoothTrail and (D.spdS[i] or D.spd[i] or 0) or (D.spd[i] or 0))
    if C.smoothTrail and prev then
        return Color3.new((c.R + prev.R) * 0.5, (c.G + prev.G) * 0.5, (c.B + prev.B) * 0.5)
    end
    return c
end

local function addSeg(i, step, lastColor, n)
    local fr = D.frames
    if i <= 1 or i > #fr then return lastColor end
    local j = math.max(1, i - step)
    local a, b = fr[j].p, fr[i].p
    if (a - b).Magnitude < K.MIN_DIST then return lastColor end
    local l = mkLine(500)
    local hc = segColor(i, lastColor)
    D.trail[#D.trail + 1] = { l = l, i = i, j = j, hc = hc }
    return hc
end

local function clearTrail()
    local tr = D.trail
    for i = #tr, 1, -1 do
        pcall(function() tr[i].l:Remove() end)
        tr[i] = nil
    end
    S.drawn = 0
    S.trailShown = false
end

local function rebuildTrail()
    clearTrail()
    S.tcKey = nil
    recalcStat()
    smoothSpd()
    local n = #D.frames
    if n < 2 then return end
    local step = stepFor(n)
    local lastColor = nil
    for i = step + 1, n, step do lastColor = addSeg(i, step, lastColor, n) end
    S.drawn = n
end

local function computeBounds()
    local fr = D.frames
    if #fr < 2 then D.bounds = nil return end
    local minX, maxX, minZ, maxZ
    for i = 1, #fr do
        local p = fr[i].p
        if not minX then
            minX, maxX, minZ, maxZ = p.X, p.X, p.Z, p.Z
        else
            if p.X < minX then minX = p.X end
            if p.X > maxX then maxX = p.X end
            if p.Z < minZ then minZ = p.Z end
            if p.Z > maxZ then maxZ = p.Z end
        end
    end
    local span = math.max(math.max(maxX - minX, maxZ - minZ), 20)
    local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
    local half = span / 2 * 1.1
    D.bounds = { minX = cx - half, minZ = cz - half, span = half * 2 }
end

local function toMap(p)
    local b = D.bounds
    if not b then return nil end
    return (p.X - b.minX) / b.span, (p.Z - b.minZ) / b.span
end

local function clearMap()
    local ms = D.mapSegs
    for i = #ms, 1, -1 do
        pcall(function() ms[i].l:Remove() end)
        ms[i] = nil
    end
    local mm = D.mk
    for i = #mm, 1, -1 do
        pcall(function() mm[i].c:Remove() end)
        mm[i] = nil
    end
    S.mapKey = nil
end

local function rebuildMap()
    clearMap()
    computeBounds()
    local n = #D.frames
    if not D.bounds or n < 2 then return end
    local step = stepFor(n)
    for i = step + 1, n, step do
        D.mapSegs[#D.mapSegs + 1] = { l = mkLine(902), i = i, j = i - step }
    end
    for i, m in ipairs(D.marks) do
        D.mk[i] = { c = mkDot(10, 3.5, 906), p = m.p }
    end
end

local function rebuildMk()
    rebuildMap()
end

local function initDraw()
    local H = DR.hud
    H.bg = mkSquare(Color3.fromRGB(12, 12, 18), 0.5, 6, 900)
    H.border = mkSquare(Color3.fromRGB(255, 255, 255), 0.85, 6, 901)
    H.border.Filled = false
    H.border.Thickness = 1
    H.title = mkText(14, K.FONTS[C.hudFont], Color3.fromRGB(255, 255, 255))
    H.title.Text = "RECORDER"
    H.rows = {}
    for i = 1, K.HROWS do H.rows[i] = mkText(13, K.FONTS[C.hudFont], Color3.fromRGB(200, 200, 200)) end
    H.gbg = mkSquare(Color3.fromRGB(20, 20, 28), 0.5, 0, 902)
    H.bbg = mkSquare(Color3.fromRGB(38, 38, 48), 1, 0, 902)
    H.bfill = mkSquare(Color3.fromRGB(120, 220, 180), 1, 0, 903)
    H.btext = mkText(12, K.FONTS[C.hudFont], Color3.fromRGB(220, 255, 235))

    local M = DR.map
    M.bg = mkSquare(Color3.fromRGB(10, 12, 16), 0.55, 6, 900)
    M.border = mkSquare(Color3.fromRGB(255, 255, 255), 0.85, 6, 901)
    M.border.Filled = false
    M.border.Thickness = 1
    M.title = mkText(12, K.FONTS[3], Color3.fromRGB(255, 255, 255))
    M.title.Text = "ROUTE"
    M.s = mkDot(12, 4, 904, Color3.fromRGB(90, 255, 130))
    M.e = mkDot(12, 4, 904, Color3.fromRGB(255, 90, 90))
    M.c = mkDot(14, 4.5, 905, Color3.fromRGB(255, 255, 255))

    local T = DR.trim
    T.hSq, T.hX1, T.hX2 = mkSq(520), mkLine(520), mkLine(520)
    T.tSq, T.tX1, T.tX2 = mkSq(520), mkLine(520), mkLine(520)
    T.hC = mkDot(10, 5, 907)
    T.tS = Drawing.new("Square")
    T.tS.Filled, T.tS.ZIndex, T.tS.Visible = true, 907, false

    local G = DR.ghost
    G.l, G.sp, G.so, G.cv = {}, {}, {}, -1
    for i = 1, 13 do
        local l = Drawing.new("Line")
        l.Thickness = i == 13 and 2.5 or 1.5
        l.ZIndex, l.Visible = 600, false
        G.l[i] = l
    end
end

initDraw()

local function hideGhost()
    if not S.gShown then return end
    S.gShown = false
    for i = 1, 13 do DR.ghost.l[i].Visible = false end
end

local function showGhost(cf)
    local G = DR.ghost
    if G.cv ~= S.colorVer then
        local g = RC.ghost
        for i = 1, 13 do G.l[i].Color, G.l[i].Transparency = g.c, g.a end
        G.cv = S.colorVer
    end
    local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
    local gw = 1.5
    local gh = 3
    local sp, so = G.sp, G.so
    for i = 1, 8 do
        local sx, sy, sz = K.SX[i] * gw, K.SY[i] * gh, K.SZ[i] * gw
        sp[i], so[i] = WorldToScreen(Vector3.new(
            px + r00 * sx + r01 * sy + r02 * sz,
            py + r10 * sx + r11 * sy + r12 * sz,
            pz + r20 * sx + r21 * sy + r22 * sz
        ))
    end
    for k = 1, 12 do
        local a, b = K.EDGES[k][1] + 1, K.EDGES[k][2] + 1
        local l = G.l[k]
        if so[a] and so[b] then
            l.From, l.To, l.Visible = sp[a], sp[b], true
        else
            l.Visible = false
        end
    end
    local cs, con = WorldToScreen(Vector3.new(px, py, pz))
    local fs, fon = WorldToScreen(Vector3.new(px - r02 * 4, py - r12 * 4, pz - r22 * 4))
    local al = G.l[13]
    if con and fon then
        al.From, al.To, al.Visible = cs, fs, true
    else
        al.Visible = false
    end
    S.gShown = true
end

local function hideTrim()
    if not S.trimShown then return end
    S.trimShown = false
    local T = DR.trim
    T.hSq.Visible, T.hX1.Visible, T.hX2.Visible = false, false, false
    T.tSq.Visible, T.tX1.Visible, T.tX2.Visible = false, false, false
    T.hC.Visible, T.tS.Visible = false, false
end

local function updateTrimPreview()
    local tr = S.tr
    local fr = D.frames
    if not C.trimPreview or #fr < 2 or (tr.h == 0 and tr.t == 0 and tr.hs == 0 and tr.ts == 0) then
        hideTrim()
        return
    end
    local hi, ti = computeTrimIndices()
    if not hi then hideTrim() return end
    S.trimShown = true
    local T = DR.trim
    local hPos, tPos = fr[hi].p, fr[ti].p
    if S.trimCV ~= S.colorVer then
        S.trimCV = S.colorVer
        local hc, tc = RC.head, RC.tail
        for _, o in ipairs({T.hSq, T.hX1, T.hX2, T.hC}) do o.Color, o.Transparency = hc.c, hc.a end
        for _, o in ipairs({T.tSq, T.tX1, T.tX2, T.tS}) do o.Color, o.Transparency = tc.c, tc.a end
    end
    local sz = 8
    local hS, hOn = WorldToScreen(hPos)
    if hOn and hi > 1 then
        T.hSq.Position = Vector2.new(hS.X - sz, hS.Y - sz)
        T.hSq.Size = Vector2.new(sz * 2, sz * 2)
        T.hX1.From = Vector2.new(hS.X - sz, hS.Y - sz)
        T.hX1.To = Vector2.new(hS.X + sz, hS.Y + sz)
        T.hX2.From = Vector2.new(hS.X + sz, hS.Y - sz)
        T.hX2.To = Vector2.new(hS.X - sz, hS.Y + sz)
        T.hSq.Visible, T.hX1.Visible, T.hX2.Visible = true, true, true
    else
        T.hSq.Visible, T.hX1.Visible, T.hX2.Visible = false, false, false
    end
    local tS, tOn = WorldToScreen(tPos)
    if tOn and ti < #fr then
        T.tSq.Position = Vector2.new(tS.X - sz, tS.Y - sz)
        T.tSq.Size = Vector2.new(sz * 2, sz * 2)
        T.tX1.From = Vector2.new(tS.X, tS.Y - sz - 4)
        T.tX1.To = Vector2.new(tS.X, tS.Y + sz + 4)
        T.tX2.From = Vector2.new(tS.X - sz - 4, tS.Y)
        T.tX2.To = Vector2.new(tS.X + sz + 4, tS.Y)
        T.tSq.Visible, T.tX1.Visible, T.tX2.Visible = true, true, true
    else
        T.tSq.Visible, T.tX1.Visible, T.tX2.Visible = false, false, false
    end
    if C.showMap and D.bounds then
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local mx = C.mapX == 0 and (vp.X - C.mapSize) / 2 or C.mapX
        local my = C.mapY == 0 and 20 or C.mapY
        local pad, inner = 6, C.mapSize - 12
        local hx, hz = toMap(hPos)
        local tx, tz = toMap(tPos)
        if hx and hi > 1 then
            T.hC.Position = Vector2.new(mx + pad + hx * inner, my + pad + hz * inner)
            T.hC.Visible = true
        else
            T.hC.Visible = false
        end
        if tx and ti < #fr then
            T.tS.Position = Vector2.new(mx + pad + tx * inner - 4, my + pad + tz * inner - 4)
            T.tS.Size = Vector2.new(8, 8)
            T.tS.Visible = true
        else
            T.tS.Visible = false
        end
    else
        T.hC.Visible, T.tS.Visible = false, false
    end
end

local function updatePath()
    local tr = D.trail
    local nT = #tr
    if not C.showPath or nT == 0 then
        if S.trailShown then
            for i = 1, nT do
                local e = tr[i]
                if e.on then e.l.Visible, e.on = false, false end
            end
            S.trailShown = false
        end
        return
    end
    S.trailShown = true
    S.stamp = S.stamp + 1
    local headIdx, tailIdx
    if C.trimPreview then headIdx, tailIdx = computeTrimIndices() end
    local P, T = RC.path, RC.trim
    local colorVer = S.colorVer
    for i = 1, nT do
        local e = tr[i]
        local a2, aOn = proj(e.j)
        local b2, bOn
        if aOn then b2, bOn = proj(e.i) end
        if aOn and bOn then
            local ax, ay, bx, by = a2.X, a2.Y, b2.X, b2.Y
            if not e.on or e.ax ~= ax or e.ay ~= ay or e.bx ~= bx or e.by ~= by then
                e.l.From, e.l.To = a2, b2
                e.ax, e.ay, e.bx, e.by = ax, ay, bx, by
            end
            if not e.on then e.l.Visible, e.on = true, true end
            local state
            if headIdx and (e.i <= headIdx or e.j > tailIdx) then state = 1
            elseif C.heat then state = 2
            else state = 0 end
            if e.cs ~= state or e.cv ~= colorVer then
                local c, a
                if state == 1 then
                    c, a = T.c, T.a
                elseif state == 2 then
                    c, a = e.hc, P.a
                else
                    c, a = P.c, P.a
                end
                e.l.Color, e.l.Transparency = c, a
                e.cs, e.cv = state, colorVer
            end
        elseif e.on then
            e.l.Visible, e.on = false, false
        end
    end
end

local function setRow(i, txt, st)
    local k = txt .. st .. S.rcVer
    if S.cached[i] ~= k then
        local t = DR.hud.rows[i]
        t.Text = txt
        t.Color = st == 1 and RC.accent.c or (st == 2 and K.WARN or K.DIM)
        S.cached[i] = k
    end
end

local function hideHud()
    local H = DR.hud
    H.bg.Visible, H.border.Visible, H.title.Visible = false, false, false
    for _, t in ipairs(H.rows) do t.Visible = false end
    H.gbg.Visible = false
    for _, s in ipairs(D.graphSegs) do s.Visible = false end
    H.bbg.Visible, H.bfill.Visible, H.btext.Visible = false, false, false
    S.hudShown, S.hudKey, S.gKey, S.bKey = false, nil, nil, nil
end

local function updateHud()
    local H = DR.hud
    if not C.showHud then
        if S.hudShown then hideHud() end
        return
    end
    S.hudShown = true
    local fr = D.frames
    local n = #fr
    local st = D.stat
    local sc = C.hudScale
    local padX, padY = math.floor(10 * sc), math.floor(8 * sc)
    local rowH, titleH = math.floor(18 * sc), math.floor(20 * sc)
    local w = math.floor(250 * sc)
    local gH = C.showGraph and math.floor(40 * sc) or 0
    local bH = C.showBar and math.floor(26 * sc) or 0
    local nRows = K.HROWS
    local baseY = C.hudY + padY + titleH + rowH * nRows
    local gx, gy, gw, gh = C.hudX + padX, baseY, w - padX * 2, gH - 6
    local bx, by = C.hudX + padX, baseY + gH + 4
    local barW = w - padX * 2
    local barH = math.max(4, math.floor(6 * sc))

    local key = table.concat({C.hudX, C.hudY, gH, bH, S.rec and 1 or 0, sc, C.hudAlpha, C.hudCorner, C.hudFont, S.colorVer}, ",")
    if key ~= S.hudKey then
        S.hudKey = key
        local font = K.FONTS[C.hudFont] or K.FONTS[5]
        local totalH = padY * 2 + titleH + rowH * nRows + gH + bH
        local A = RC.accent
        H.bg.Position, H.bg.Size = Vector2.new(C.hudX, C.hudY), Vector2.new(w, totalH)
        H.bg.Transparency, H.bg.Corner, H.bg.Visible = C.hudAlpha, C.hudCorner, true
        H.border.Position, H.border.Size = Vector2.new(C.hudX, C.hudY), Vector2.new(w, totalH)
        H.border.Corner = C.hudCorner
        H.border.Color = S.rec and K.REC or A.c
        H.border.Visible = true
        H.title.Font, H.title.Size, H.title.Color = font, math.floor(14 * sc), A.c
        H.title.Position, H.title.Visible = Vector2.new(C.hudX + padX, C.hudY + padY), true
        for i = 1, nRows do
            local r = H.rows[i]
            r.Font, r.Size = font, math.floor(13 * sc)
            r.Position = Vector2.new(C.hudX + padX, C.hudY + padY + titleH + (i - 1) * rowH)
            r.Visible = true
        end
        S.cached = {}
        if C.showGraph then
            H.gbg.Position, H.gbg.Size, H.gbg.Visible = Vector2.new(gx, gy), Vector2.new(gw, gh), true
        else
            H.gbg.Visible = false
        end
        if C.showBar then
            H.bbg.Position, H.bbg.Size, H.bbg.Visible = Vector2.new(bx, by), Vector2.new(barW, barH), true
            H.btext.Font, H.btext.Size = font, math.floor(12 * sc)
            H.btext.Position = Vector2.new(bx, by + barH + 2)
        else
            H.bbg.Visible, H.bfill.Visible, H.btext.Visible = false, false, false
        end
        S.gKey, S.bKey = nil, nil
    end

    local idx
    if S.play then idx = math.min(S.pIdx, n)
    elseif S.ghost then idx = math.min(S.gIdx, n)
    else idx = n end
    local dur = n >= 2 and fr[n].t - fr[1].t or 0
    local recTxt = "[R] Recording"
    if S.rec then recTxt = string.format("[R] Recording  %.1fs", tick() - S.t0) end
    setRow(1, recTxt, S.rec and 1 or 0)
    local pTxt = "[P] Playing"
    if S.play then pTxt = pTxt .. "  >>" end
    setRow(2, pTxt, S.play and 1 or 0)
    setRow(3, string.format("Loop %s  Ghost %s", S.loop_ and "on" or "off", S.ghost and "on" or "off"), (S.loop_ or S.ghost) and 1 or 0)
    setRow(4, string.format("Frames %d  Time %.1fs", n, dur), n > 0 and 1 or 0)
    local avg = dur > 0 and st.dist / dur or 0
    setRow(5, string.format("Dist %.0f  Avg %.1f  Max %.1f", st.dist, avg, st.maxV), n > 1 and 1 or 0)
    local hz = "--"
    if S.rec and n > 1 and dur > 0 then hz = string.format("%.1fHz g%d", (n - 1) / dur, S.frameGaps) end
    local sp = C.smoothTrail and (D.spdS[idx] or D.spd[idx] or 0) or (D.spd[idx] or 0)
    setRow(6, string.format("Speed %.1f  Rate %s", sp, hz), (S.rec and S.frameGaps > 0) and 2 or (n > 1 and 1 or 0))

    if C.showGraph and n >= 2 then
        local gk = idx .. "," .. n .. "," .. S.colorVer .. "," .. st.maxV .. "," .. (C.smoothTrail and 1 or 0) .. "," .. gw .. "," .. gh
        if gk ~= S.gKey then
            S.gKey = gk
            local gmax = math.max(10, math.ceil(st.maxV / 10) * 10)
            local count = math.min(K.GRAPH_PTS, idx - 1)
            local start = math.max(2, idx - count + 1)
            local xs, ys, m = {}, {}, 0
            for k = 0, count - 1 do
                local i = start + k
                if i > idx then break end
                local v = C.smoothTrail and (D.spdS[i] or D.spd[i] or 0) or (D.spd[i] or 0)
                m = m + 1
                xs[m] = gx + gw * (k / math.max(1, count - 1))
                ys[m] = gy + gh - math.min(v / gmax, 1) * gh
            end
            local need = math.max(0, m - 1)
            local gs = D.graphSegs
            while #gs < need do
                local l = Drawing.new("Line")
                l.Thickness, l.ZIndex, l.Visible = 1, 903, false
                gs[#gs + 1] = l
            end
            local A = RC.accent
            for i = 1, need do
                local seg = gs[i]
                seg.From, seg.To = Vector2.new(xs[i], ys[i]), Vector2.new(xs[i + 1], ys[i + 1])
                seg.Color, seg.Transparency, seg.Visible = A.c, A.a * 0.9, true
            end
            for i = need + 1, #gs do gs[i].Visible = false end
        end
    elseif S.gKey ~= "off" then
        for _, s in ipairs(D.graphSegs) do s.Visible = false end
        S.gKey = "off"
    end

    if C.showBar then
        local progress, label = 0, nil
        local T = n >= 2 and fr[n].t or 0
        if S.play and n >= 2 then
            if T > 0 then progress = math.clamp(S.pEl / T, 0, 1) end
            label = string.format("Play %d%%  %d/%d", math.floor(progress * 100 + 0.5), math.min(S.pIdx, n), n)
        elseif S.rec and n >= 1 then
            label = string.format("Rec %.1fs  %d frames", tick() - S.t0, n)
        elseif S.ghost and n >= 2 then
            if T > 0 then progress = math.clamp(S.gEl / T, 0, 1) end
            label = string.format("Ghost %d%%", math.floor(progress * 100 + 0.5))
        else
            label = string.format("Idle  %d frames", n)
        end
        local bk = label .. "|" .. math.floor(progress * 1000) .. "|" .. S.colorVer
        if bk ~= S.bKey then
            S.bKey = bk
            H.bfill.Position, H.bfill.Size = Vector2.new(bx, by), Vector2.new(math.max(1, barW * progress), barH)
            H.bfill.Color = (S.rec and K.REC) or (S.play and RC.path.c) or (S.ghost and RC.ghost.c) or K.DIM
            H.bfill.Visible = true
            H.btext.Text = label
            H.btext.Color = RC.accent.c
            H.btext.Visible = true
        end
    end
end

local function hideMap()
    local M = DR.map
    M.bg.Visible, M.border.Visible, M.title.Visible = false, false, false
    M.s.Visible, M.e.Visible, M.c.Visible = false, false, false
    for _, s in ipairs(D.mapSegs) do s.l.Visible = false end
    for _, c in ipairs(D.mk) do c.c.Visible = false end
    S.mapShown, S.mapKey = false, nil
end

local function updateMap()
    local fr = D.frames
    local n = #fr
    local M = DR.map
    if not C.showMap or not D.bounds or n < 2 then
        if S.mapShown then hideMap() end
        return
    end
    S.mapShown = true
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local size = C.mapSize
    local mx = C.mapX == 0 and (vp.X - size) / 2 or C.mapX
    local my = C.mapY == 0 and 20 or C.mapY
    local pad, inner = 6, size - 12
    local headIdx, tailIdx
    if C.trimPreview then headIdx, tailIdx = computeTrimIndices() end
    local key = table.concat({size, C.mapX, C.mapY, vp.X, n, S.colorVer, headIdx or 0, tailIdx or 0, C.heat and 1 or 0, C.smoothTrail and 1 or 0, C.mapAlpha}, ",")
    if key ~= S.mapKey then
        S.mapKey = key
        local A, P, T = RC.accent, RC.path, RC.trim
        M.bg.Position, M.bg.Size = Vector2.new(mx, my), Vector2.new(size, size)
        M.bg.Transparency, M.bg.Visible = C.mapAlpha, true
        M.border.Position, M.border.Size = Vector2.new(mx, my), Vector2.new(size, size)
        M.border.Color, M.border.Visible = A.c, true
        M.title.Position, M.title.Color, M.title.Visible = Vector2.new(mx + pad, my + pad), A.c, true
        local ms = D.mapSegs
        for q = 1, #ms do
            local e = ms[q]
            local pa, pb = fr[e.j], fr[e.i]
            local ax, az, bx, bz
            if pa and pb then
                ax, az = toMap(pa.p)
                bx, bz = toMap(pb.p)
            end
            if ax and bx then
                e.l.From = Vector2.new(mx + pad + ax * inner, my + pad + az * inner)
                e.l.To = Vector2.new(mx + pad + bx * inner, my + pad + bz * inner)
                local col, al
                if headIdx and (e.i <= headIdx or e.j > tailIdx) then
                    col, al = T.c, T.a * 0.7
                elseif C.heat then
                    col, al = heatCol(C.smoothTrail and (D.spdS[e.i] or D.spd[e.i] or 0) or (D.spd[e.i] or 0)), P.a * 0.7
                else
                    col, al = P.c, P.a * 0.7
                end
                e.l.Color, e.l.Transparency, e.l.Visible = col, al, true
            else
                e.l.Visible = false
            end
        end
        local sx, sz = toMap(fr[1].p)
        if sx then
            M.s.Position, M.s.Visible = Vector2.new(mx + pad + sx * inner, my + pad + sz * inner), true
        end
        local ex, ez = toMap(fr[n].p)
        if ex then
            M.e.Position, M.e.Visible = Vector2.new(mx + pad + ex * inner, my + pad + ez * inner), true
        end
        for q, c in ipairs(D.mk) do
            local x, z = toMap(c.p)
            if x then
                c.c.Position = Vector2.new(mx + pad + x * inner, my + pad + z * inner)
                c.c.Color, c.c.Transparency, c.c.Visible = A.c, A.a, true
            else
                c.c.Visible = false
            end
        end
    end
    local cur = fr[math.max(1, math.min(S.play and S.pIdx or (S.ghost and S.gIdx or n), n))]
    local cx, cz = toMap(cur.p)
    if cx then
        M.c.Position = Vector2.new(mx + pad + cx * inner, my + pad + cz * inner)
        M.c.Visible = true
    end
end

resetTrimValues = function()
    local tr = S.tr
    tr.h, tr.t, tr.hs, tr.ts = 0, 0, 0, 0
    S.tcKey = nil
    UI.SetValue("r_trim_h", 0)
    UI.SetValue("r_trim_t", 0)
    UI.SetValue("r_trim_hs", 0)
    UI.SetValue("r_trim_ts", 0)
end

local function refreshList()
    D.files = {}
    if isfolder(K.FOLDER) then
        local ok, ls = pcall(listfiles, K.FOLDER)
        if ok and type(ls) == "table" then
            for _, p in ipairs(ls) do
                if isfile(p) then
                    local nm = p:match("([^/\\]+)%.json$")
                    if nm then D.files[#D.files + 1] = nm end
                end
            end
        end
    end
    table.sort(D.files)
    local fc = S.fileCombo
    if fc then
        fc:Clear()
        if #D.files == 0 then
            fc:Add("(empty)")
        else
            for _, nm in ipairs(D.files) do fc:Add(nm) end
        end
        local idx = 0
        for i, nm in ipairs(D.files) do
            if nm == C.file then idx = i - 1 break end
        end
        UI.SetValue("r_file_combo", idx)
    end
end

local function rd(v)
    return math.floor(v * 100000 + 0.5) / 100000
end

local function save()
    ensureFolder()
    local fr = D.frames
    local out = { rate = C.rate, frames = {} }
    for i = 1, #fr do
        local f = fr[i]
        local p, l = f.cf.Position, f.cf.LookVector
        out.frames[i] = { t = rd(f.t), p = { rd(p.X), rd(p.Y), rd(p.Z) }, l = { rd(l.X), rd(l.Y), rd(l.Z) } }
    end
    local ok = pcall(writefile, rpath(C.file), HttpService:JSONEncode(out))
    if ok then refreshList() end
    return ok
end

local function load()
    local path = rpath(C.file)
    if not isfile(path) then return false end
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" or type(data.frames) ~= "table" then return false end
    setPlay(false)
    if S.ghost then setGhost(false) end
    local nf = {}
    for _, f in ipairs(data.frames) do
        if type(f.p) == "table" then
            local p = f.p
            local pos = Vector3.new(p[1], p[2], p[3])
            local cf
            if type(f.l) == "table" then
                local lv = Vector3.new(f.l[1], f.l[2], f.l[3])
                cf = lv.Magnitude > 0.001 and CFrame.lookAt(pos, pos + lv) or CFrame.new(p[1], p[2], p[3])
            else
                cf = CFrame.new(p[1], p[2], p[3])
            end
            nf[#nf + 1] = { t = f.t or 0, cf = cf, p = pos }
        end
    end
    D.frames = nf
    D.marks = {}
    rebuildTrail()
    rebuildMk()
    return true
end

local function applyTrim()
    local fr = D.frames
    if #fr < 3 then
        notify("Not enough frames", "Recorder", 2)
        return
    end
    local hi, ti = computeTrimIndices()
    if not hi then
        notify("Invalid trim", "Recorder", 2)
        return
    end
    if hi == 1 and ti == #fr then
        notify("Nothing to trim", "Recorder", 2)
        return
    end
    setPlay(false)
    if S.ghost then setGhost(false) end
    local n0 = #fr
    local off = fr[hi].t
    local nf = {}
    for i = hi, ti do nf[#nf + 1] = { t = fr[i].t - off, cf = fr[i].cf, p = fr[i].p } end
    D.frames = nf
    D.marks = {}
    rebuildTrail()
    rebuildMk()
    resetTrimValues()
    notify(string.format("Trim: %d -> %d", n0, #nf), "Recorder", 2)
end

local function readColor(v, fb)
    if type(v) ~= "table" then return fb end
    return {
        r = type(v.r) == "number" and v.r or fb.r,
        g = type(v.g) == "number" and v.g or fb.g,
        b = type(v.b) == "number" and v.b or fb.b,
        a = type(v.a) == "number" and v.a or fb.a,
    }
end

local function saveCfg()
    return pcall(writefile, K.CFG, HttpService:JSONEncode(C))
end

local function loadCfg()
    if not isfile(K.CFG) then return false end
    local ok, raw = pcall(readfile, K.CFG)
    if not ok or not raw then return false end
    local ok2, d = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(d) ~= "table" then return false end
    local function n(v, fb) return type(v) == "number" and v or fb end
    local function b(v, fb) return type(v) == "boolean" and v or fb end
    local function s(v, fb) return type(v) == "string" and v ~= "" and v or fb end
    C.rate = n(d.rate, C.rate)
    C.pSpeed = n(d.pSpeed, C.pSpeed)
    C.file = s(d.file, C.file)
    C.showPath, C.showHud = b(d.showPath, C.showPath), b(d.showHud, C.showHud)
    C.showGraph, C.showBar, C.showMap = b(d.showGraph, C.showGraph), b(d.showBar, C.showBar), b(d.showMap, C.showMap)
    C.mapSize, C.mapX, C.mapY = n(d.mapSize, C.mapSize), n(d.mapX, C.mapX), n(d.mapY, C.mapY)
    C.mapAlpha = n(d.mapAlpha, C.mapAlpha)
    C.hudX, C.hudY = n(d.hudX, C.hudX), n(d.hudY, C.hudY)
    C.hudScale, C.hudAlpha = n(d.hudScale, C.hudScale), n(d.hudAlpha, C.hudAlpha)
    C.hudCorner, C.hudFont = n(d.hudCorner, C.hudCorner), n(d.hudFont, C.hudFont)
    C.trimPreview = b(d.trimPreview, C.trimPreview)
    C.heat, C.liveTrail = b(d.heat, C.heat), b(d.liveTrail, C.liveTrail)
    C.smoothTrail = b(d.smoothTrail, C.smoothTrail)
    C.ghostColor = readColor(d.ghostColor, C.ghostColor)
    C.accentColor = readColor(d.accentColor, C.accentColor)
    C.pathColor = readColor(d.pathColor, C.pathColor)
    C.headColor = readColor(d.headColor, C.headColor)
    C.tailColor = readColor(d.tailColor, C.tailColor)
    C.trimColor = readColor(d.trimColor, C.trimColor)
    S.colorVer = S.colorVer + 1
    return true
end

local function syncUI()
    for _, kv in ipairs({
        {"r_rate", C.rate}, {"r_spd", C.pSpeed},
        {"r_path", C.showPath}, {"r_heat", C.heat}, {"r_smooth", C.smoothTrail},
        {"r_live", C.liveTrail}, {"r_ghost", false},
        {"r_hud", C.showHud}, {"r_graph", C.showGraph}, {"r_bar", C.showBar},
        {"r_hud_x", C.hudX}, {"r_hud_y", C.hudY}, {"r_hud_scale", C.hudScale}, {"r_hud_alpha", C.hudAlpha},
        {"r_hud_corner", C.hudCorner}, {"r_hud_font", C.hudFont},
        {"r_map", C.showMap}, {"r_map_size", C.mapSize}, {"r_map_x", C.mapX}, {"r_map_y", C.mapY}, {"r_map_alpha", C.mapAlpha},
        {"r_name", C.file}, {"r_trim_preview", C.trimPreview},
        {"r_trim_h", 0}, {"r_trim_t", 0}, {"r_trim_hs", 0}, {"r_trim_ts", 0},
    }) do UI.SetValue(kv[1], kv[2]) end
    local idx = 0
    for i, nm in ipairs(D.files) do
        if nm == C.file then idx = i - 1 break end
    end
    UI.SetValue("r_file_combo", idx)
end

local function startRec()
    S.play = false
    if S.ghost then setGhost(false) end
    D.frames, D.spd, D.spdS = {}, {}, {}
    D.marks = {}
    D.bounds = nil
    local st = D.stat
    st.dist, st.maxV, st.minV = 0, 0, math.huge
    clearTrail()
    clearMap()
    S.t0, S.lastCf, S.lastCfT = tick(), nil, 0
    S.frameGaps, S.overflow, S.tcKey = 0, false, nil
end

local function stopRec()
    rebuildTrail()
    rebuildMk()
end

local function setRec(v)
    if S.rec == v then return end
    if v and S.play then
        S.play = false
        UI.SetValue("r_play_on", false)
    end
    S.rec = v
    UI.SetValue("r_on", v)
    if v then
        resetTrimValues()
        startRec()
    else
        stopRec()
    end
end

local function setPlay(v)
    if S.play == v then return end
    if v and S.rec then
        S.rec = false
        UI.SetValue("r_on", false)
        stopRec()
    end
    if v then
        local fr = D.frames
        if #fr < 2 then
            notify("Need 2+ frames", "Recorder", 2)
            UI.SetValue("r_play_on", false)
            return
        end
        local h = hrp()
        if not h then
            UI.SetValue("r_play_on", false)
            return
        end
        if S.ghost then setGhost(false) end
        S.pEl = 0
        S.pIdx = 1
        local cf, idx = sampleCf(0)
        S.pIdx = idx or 1
        if cf then
            h.CFrame = cf
            h.AssemblyLinearVelocity = Vector3.zero
        end
        S.play = true
    else
        S.play = false
    end
    UI.SetValue("r_play_on", v)
end

local function fullReset()
    setPlay(false)
    setRec(false)
    setGhost(false)
    D.frames, D.spd, D.spdS, D.marks = {}, {}, {}, {}
    D.bounds = nil
    local st = D.stat
    st.dist, st.maxV, st.minV = 0, 0, math.huge
    clearTrail()
    clearMap()
    for _, s in ipairs(D.graphSegs) do s.Visible = false end
    S.lastCf, S.lastCfT = nil, 0
    S.frameGaps, S.overflow, S.drawn, S.vtick, S.trimCV = 0, false, 0, 0, -1
    S.gKey, S.bKey, S.mapKey, S.hudKey = nil, nil, nil, nil
    S.cached = {}
    S.hudShown, S.mapShown, S.trimShown = false, false, false
    S.tcKey = nil
    resetTrimValues()
    notify("Recorder reset", "Recorder", 2)
end

local function stepPlay(dt)
    local h = hrp()
    local fr = D.frames
    local n = #fr
    if not h or n < 2 then
        setPlay(false)
        return
    end
    local T = fr[n].t
    S.pEl = S.pEl + dt * C.pSpeed
    if S.pEl >= T then
        if S.loop_ then
            S.pEl = S.pEl - T
        else
            S.pEl = T
            setPlay(false)
        end
    end
    local cf, idx = sampleCf(S.pEl)
    S.pIdx = idx or 1
    if cf then
        h.CFrame = cf
        h.AssemblyLinearVelocity = Vector3.zero
    end
end

local function updateGhost(dt)
    local fr = D.frames
    local n = #fr
    if n < 2 then
        setGhost(false)
        return
    end
    local T = fr[n].t
    S.gEl = S.gEl + dt * C.pSpeed
    if S.gEl >= T then
        S.gEl = T
        setGhost(false)
        return
    end
    local cf, idx = sampleCf(S.gEl)
    S.gIdx = idx or 1
    if cf then showGhost(cf) else hideGhost() end
end

local function keyDown(c)
    local ok, v = pcall(iskeypressed, c)
    return ok and (v == true or v == 1)
end

local function edge(nm, code)
    local now = keyDown(code)
    local was = S.prevKeys[nm] or false
    S.prevKeys[nm] = now
    return now and not was
end

RunService.Heartbeat:Connect(function()
    local active = true
    local ok, a = pcall(isrbxactive)
    if ok and a ~= nil then active = a end
    if active then
        if edge("R", K.VK_R) then setRec(not S.rec) end
        if edge("P", K.VK_P) then setPlay(not S.play) end
        if edge("L", K.VK_L) then setLoop(not S.loop_) end
        if edge("G", K.VK_G) then setGhost(not S.ghost) end
    else
        S.prevKeys.R = keyDown(K.VK_R)
        S.prevKeys.P = keyDown(K.VK_P)
        S.prevKeys.L = keyDown(K.VK_L)
        S.prevKeys.G = keyDown(K.VK_G)
    end

    if not S.rec or S.play then return end
    local h = hrp()
    if not h then return end
    local now = tick()
    local interval = 1 / C.rate
    local cfNow = h.CFrame

    if not S.lastCf then
        S.lastCf, S.lastCfT = cfNow, now
        pushFrame(now - S.t0, cfNow)
        S.drawn = #D.frames
        return
    end

    local elapsed = now - S.lastCfT
    if elapsed < interval then return end
    local steps = math.floor(elapsed / interval)
    if steps <= 0 then return end

    for k = 1, steps do
        local alpha = math.min(1, (k * interval) / elapsed)
        pushFrame(S.lastCfT + k * interval - S.t0, S.lastCf:Lerp(cfNow, alpha))
    end
    if steps >= 2 then S.frameGaps = S.frameGaps + (steps - 1) end

    local adv = steps * interval
    S.lastCf = S.lastCf:Lerp(cfNow, math.min(1, adv / elapsed))
    S.lastCfT = S.lastCfT + adv

    local n = #D.frames
    if C.liveTrail and not S.overflow and n - S.drawn >= K.LIVE_BATCH then
        if n <= K.MAX_SEGS then
            local tr = D.trail
            local lastColor = #tr > 0 and tr[#tr].hc or nil
            for i = S.drawn + 1, n do lastColor = addSeg(i, 1, lastColor, n) end
            S.drawn = n
        end
    end

    if not S.overflow and n >= K.MAX_FRAMES then
        S.overflow = true
        notify(string.format("Frame limit reached (%d). Auto-stopped.", K.MAX_FRAMES), "Recorder", 4)
        setRec(false)
    end
end)

RunService.RenderStepped:Connect(function()
    local now = tick()
    local dt = now - S.lastT
    S.lastT = now
    if dt > 0.1 then dt = 0.1 elseif dt < 0 then dt = 0 end

    if S.rcVer ~= S.colorVer then refreshColors() end

    if S.dTrail then S.dTrail = false rebuildTrail() rebuildMap() end

    if S.play then stepPlay(dt) end
    if S.ghost then updateGhost(dt) elseif S.gShown then hideGhost() end

    S.vtick = S.vtick + 1
    if S.vtick >= 2 then
        S.vtick = 0
        S.phase = 1 - S.phase
        updatePath()
        updateTrimPreview()
        updateHud()
        updateMap()
    end
end)

local function colorCb(field)
    return function(c, a)
        local t = C[field]
        t.r, t.g, t.b, t.a = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), a
        S.colorVer = S.colorVer + 1
    end
end

ensureFolder()
local cfgOk = loadCfg()
refreshColors()
refreshList()

UI.AddTab("Recorder", function(tab)
    local s1 = tab:Section("Recorder", "Left")
    s1:Toggle("r_on", "Recording [R]", false, function(v) setRec(v) end)
    s1:Toggle("r_play_on", "Playing [P]", false, function(v) setPlay(v) end)
    s1:Toggle("r_loop", "Loop [L]", false, function(v) setLoop(v) end)
    s1:SliderInt("r_rate", "Sample Rate", 5, 60, C.rate, function(v) C.rate = v end)
    s1:SliderFloat("r_spd", "Playback Speed", 0.1, 5.0, C.pSpeed, "%.2f", function(v) C.pSpeed = v end)
    s1:Button("Reset", 100, 20, function() fullReset() end)

    local s2 = tab:Section("Files", "Left")
    s2:InputText("r_name", "Name", C.file, function(t)
        local n = t:gsub("[^%w_%-%.]", "")
        if n ~= "" then
            C.file = n
            local idx = 0
            for i, fn in ipairs(D.files) do
                if fn == C.file then idx = i - 1 break end
            end
            UI.SetValue("r_file_combo", idx)
        end
    end)
    if not S.fileCombo then
        S.fileCombo = s2:Combo("r_file_combo", "Saved Files", (#D.files > 0) and D.files or {"(empty)"}, 0, function(i)
            if #D.files == 0 then return end
            local nm = D.files[i + 1]
            if nm then
                C.file = nm
                UI.SetValue("r_name", nm)
            end
        end)
    end
    s2:Button("Save", 100, 20, function()
        if save() then
            saveCfg()
            notify("Saved " .. C.file, "Recorder", 2)
        else
            notify("Save failed", "Recorder", 2)
        end
    end)
    s2:Button("Load", 100, 20, function()
        if load() then notify("Loaded " .. #D.frames .. " frames", "Recorder", 2)
        else notify("Not found", "Recorder", 2) end
    end)
    s2:Button("Refresh List", 100, 20, function()
        refreshList()
        notify("List: " .. #D.files, "Recorder", 2)
    end)
    s2:Button("Delete", 100, 20, function()
        local p = rpath(C.file)
        if isfile(p) then delfile(p) end
        refreshList()
        notify("Deleted " .. C.file, "Recorder", 2)
    end)

    local s3 = tab:Section("Config", "Left")
    s3:Button("Save Config", 120, 20, function()
        if saveCfg() then notify("Config saved", "Recorder", 2) else notify("Save failed", "Recorder", 2) end
    end)
    s3:Button("Load Config", 120, 20, function()
        if loadCfg() then
            syncUI()
            S.dTrail = true
            notify("Config loaded", "Recorder", 2)
        else
            notify("No config", "Recorder", 2)
        end
    end)
    s3:Button("Reset Config", 120, 20, function()
        C.rate, C.pSpeed = 20, 1.0
        C.showPath, C.showHud, C.showGraph, C.showBar, C.showMap = true, true, true, true, false
        C.mapSize, C.mapX, C.mapY = 180, 0, 0
        C.mapAlpha = 0.55
        C.hudX, C.hudY = 20, 20
        C.hudScale, C.hudAlpha = 1.0, 0.5
        C.hudCorner, C.hudFont = 6, 5
        C.trimPreview, C.heat = true, false
        C.liveTrail, C.smoothTrail = false, true
        C.ghostColor = {r = 255, g = 120, b = 255, a = 0.9}
        C.accentColor = {r = 120, g = 220, b = 180, a = 1}
        C.pathColor = {r = 120, g = 220, b = 180, a = 1}
        C.headColor = {r = 255, g = 60, b = 60, a = 1}
        C.tailColor = {r = 60, g = 180, b = 255, a = 1}
        C.trimColor = {r = 255, g = 140, b = 40, a = 0.9}
        S.colorVer = S.colorVer + 1
        resetTrimValues()
        syncUI()
        S.dTrail = true
        notify("Config reset", "Recorder", 2)
    end)
    s3:Button("Delete Config", 120, 20, function()
        if isfile(K.CFG) then delfile(K.CFG) end
        notify("Config deleted", "Recorder", 2)
    end)

    local s4 = tab:Section("Trim", "Left")
    s4:Toggle("r_trim_preview", "Show Trim Markers", C.trimPreview, function(v) C.trimPreview = v end)
    s4:ColorPicker("r_head_col", C.headColor.r / 255, C.headColor.g / 255, C.headColor.b / 255, C.headColor.a, colorCb("headColor"))
    s4:ColorPicker("r_tail_col", C.tailColor.r / 255, C.tailColor.g / 255, C.tailColor.b / 255, C.tailColor.a, colorCb("tailColor"))
    s4:ColorPicker("r_trim_col", C.trimColor.r / 255, C.trimColor.g / 255, C.trimColor.b / 255, C.trimColor.a, colorCb("trimColor"))
    s4:SliderInt("r_trim_h", "Trim Head (frames)", 0, 700, 0, function(v) S.tr.h = v end)
    s4:SliderInt("r_trim_t", "Trim Tail (frames)", 0, 700, 0, function(v) S.tr.t = v end)
    s4:SliderFloat("r_trim_hs", "Trim Head (sec)", 0, 30, 0, "%.2f", function(v) S.tr.hs = v end)
    s4:SliderFloat("r_trim_ts", "Trim Tail (sec)", 0, 30, 0, "%.2f", function(v) S.tr.ts = v end)
    s4:Button("Apply Trim", 120, 20, function() applyTrim() end)
    s4:Button("Reset Trim", 120, 20, function()
        resetTrimValues()
        notify("Trim reset", "Recorder", 2)
    end)

    local s5 = tab:Section("Path", "Right")
    s5:Toggle("r_path", "Show Trail", C.showPath, function(v) C.showPath = v end)
    s5:ColorPicker("r_path_col", C.pathColor.r / 255, C.pathColor.g / 255, C.pathColor.b / 255, C.pathColor.a, colorCb("pathColor"))
    s5:Toggle("r_heat", "Show Trail Speed", C.heat, function(v) C.heat = v S.colorVer = S.colorVer + 1 end)
    s5:Toggle("r_live", "Live Trail", C.liveTrail, function(v) C.liveTrail = v end)
    s5:Toggle("r_smooth", "Smooth Trail", C.smoothTrail, function(v) C.smoothTrail = v S.dTrail = true end)
    s5:Toggle("r_ghost", "Ghost Preview [G]", false, function(v) setGhost(v) end)
    s5:ColorPicker("r_ghost_col", C.ghostColor.r / 255, C.ghostColor.g / 255, C.ghostColor.b / 255, C.ghostColor.a, colorCb("ghostColor"))
    s5:Button("Rebuild", 120, 20, function() S.dTrail = true end)
    s5:Button("Clear Path", 120, 20, function()
        clearTrail()
        clearMap()
        D.bounds = nil
    end)

    local s6 = tab:Section("HUD", "Right")
    s6:Toggle("r_hud", "Show HUD", C.showHud, function(v) C.showHud = v end)
    s6:ColorPicker("r_acc_col", C.accentColor.r / 255, C.accentColor.g / 255, C.accentColor.b / 255, C.accentColor.a, colorCb("accentColor"))
    s6:Toggle("r_graph", "Speed Graph", C.showGraph, function(v) C.showGraph = v end)
    s6:Toggle("r_bar", "Progress Bar", C.showBar, function(v) C.showBar = v end)
    s6:SliderInt("r_hud_x", "HUD X", 0, 1920, C.hudX, function(v) C.hudX = v end)
    s6:SliderInt("r_hud_y", "HUD Y", 0, 1080, C.hudY, function(v) C.hudY = v end)
    s6:SliderFloat("r_hud_scale", "HUD Scale", 0.6, 2.0, C.hudScale, "%.2f", function(v) C.hudScale = v end)
    s6:SliderFloat("r_hud_alpha", "HUD Opacity", 0.1, 1.0, C.hudAlpha, "%.2f", function(v) C.hudAlpha = v end)
    s6:SliderInt("r_hud_corner", "HUD Corner", 0, 16, C.hudCorner, function(v) C.hudCorner = v end)
    s6:SliderInt("r_hud_font", "HUD Font 1-8", 1, 8, C.hudFont, function(v) C.hudFont = v end)
    s6:Tip("1 UI  2 System  3 SystemBold  4 Minecraft  5 Monospace  6 Pixel  7 Fortnite  8 Proxima")

    local s7 = tab:Section("Minimap", "Right")
    s7:Toggle("r_map", "Route Minimap", C.showMap, function(v) C.showMap = v end)
    s7:SliderInt("r_map_size", "Map Size", 100, 320, C.mapSize, function(v) C.mapSize = v end)
    s7:SliderInt("r_map_x", "Map X (0=auto)", 0, 1920, C.mapX, function(v) C.mapX = v end)
    s7:SliderInt("r_map_y", "Map Y (0=auto)", 0, 1080, C.mapY, function(v) C.mapY = v end)
    s7:SliderFloat("r_map_alpha", "Map Opacity", 0.1, 1.0, C.mapAlpha, "%.2f", function(v) C.mapAlpha = v end)
end)

if cfgOk then
    syncUI()
    S.dTrail = true
end
