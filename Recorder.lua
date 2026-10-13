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
    rec = false, play = false, loop_ = false, ghost = false, scrub = false,
    pEl = 0, gEl = 0, pIdx = 1, gIdx = 1,
    t0 = 0, lastT = tick(), drawn = 0,
    lastCfT = 0, frameGaps = 0, overflow = false,
    vtick = 0, phase = 0, stamp = 0, thr = 2, fxT = 0, fxPh = 0,
    pAcc = 0, pv = 0,
    colorVer = 1, rcVer = 0,
    hudShown = false, hudKey = nil, gKey = nil, bKey = nil, cached = {},
    mapShown = false, mapKey = nil, trimShown = false, trimCV = -1,
    trailShown = false,
    dTrail = false,
    tr = {h = 0, t = 0, hs = 0, ts = 0},
    tcKey = nil, tcH = nil, tcT = nil,
    fileCombo = nil,
    lastCf = nil,
    scrubV = 0,
}

local C = {
    rate = 20, pSpeed = 1.0, file = "movement_rec",
    showPath = true, showHud = true, showGraph = true, showBar = true, showMap = false,
    mapSize = 180, mapX = 0, mapY = 0, mapAlpha = 0.55,
    hudX = 20, hudY = 20, hudScale = 1.0, hudAlpha = 0.5, hudCorner = 6, hudFont = 5,
    trimPreview = true, heat = false, liveTrail = false, smoothTrail = true,
    fxOn = true, fx = 1, fxSpeed = 1.0, trailW = 2,
    pOn = true, pType = 0, pCol = 3, pRate = 40, pSize = 2.0, pLife = 1.0, pSpread = 1.0, pMax = 200,
    ghostColor = {r = 255, g = 120, b = 255, a = 0.9},
    accentColor = {r = 120, g = 220, b = 180, a = 1},
    pathColor = {r = 120, g = 220, b = 180, a = 1},
    gradColor = {r = 255, g = 80, b = 200, a = 1},
    pColor = {r = 255, g = 200, b = 80, a = 1},
    headColor = {r = 255, g = 60, b = 60, a = 1},
    tailColor = {r = 60, g = 180, b = 255, a = 1},
    trimColor = {r = 255, g = 140, b = 40, a = 0.9},
}

local K = {
    MAX_SEGS = 800, MIN_DIST = 0.1, MAX_FRAMES = 18000, LIVE_BATCH = 4,
    GRAPH_PTS = 60, HROWS = 6, POOL_CAP = 1200, CPOOL_CAP = 600,
    FOLDER = "recorder", CFG = "recorder_config.json",
    VK_R = 82, VK_P = 80, VK_L = 76, VK_G = 71,
    FXN = {"Solid", "Comet", "Rainbow", "Pulse", "Fire", "Ice", "Gradient", "Dashed", "Neon", "Aurora", "Lava", "Chase", "Matrix"},
    FXA = {[2] = true, [3] = true, [4] = true, [5] = true, [9] = true, [10] = true, [11] = true, [12] = true},
    FXHZ = 12, FXCYC = 36,
    PN = {"Embers", "Stardust", "Bubbles", "Snow"},
    PCN = {"Path", "Accent", "Rainbow", "Fire", "Ice", "White", "Gradient", "Custom"},
    PDYN = {[2] = true, [3] = true, [4] = true, [6] = true},
    PT = {
        {kind = 2, grav = 4, sp = 2.2, up = 3.5, vyk = 0.4, drag = 0.7, life = 1.6, filled = true},
        {kind = 2, grav = 0, sp = 3.5, up = 0, vyk = 1, drag = 1.4, life = 1.8, filled = true, twinkle = true},
        {kind = 2, grav = 5, sp = 1.2, up = 2, vyk = 0.4, drag = 1.2, life = 2.0, filled = false},
        {kind = 2, grav = -2.5, sp = 2.5, up = 1, vyk = 0.2, drag = 1.0, life = 2.4, filled = true, sway = true},
    },
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
    WHITE = Color3.fromRGB(255, 255, 255),
    FR = Color3.fromRGB(255, 40, 0),
    FO = Color3.fromRGB(255, 140, 0),
    FY = Color3.fromRGB(255, 230, 80),
    IB = Color3.fromRGB(50, 130, 255),
    IW = Color3.fromRGB(210, 248, 255),
    LV0 = Color3.fromRGB(90, 5, 0),
    AU1 = Color3.fromRGB(60, 255, 160),
    AU2 = Color3.fromRGB(60, 200, 255),
    AU3 = Color3.fromRGB(170, 90, 255),
    MX1 = Color3.fromRGB(0, 70, 20),
    MX2 = Color3.fromRGB(60, 255, 100),
}

for i = 0, 7 do
    K.SX[i + 1] = (i % 2 == 1) and 1 or -1
    K.SY[i + 1] = (math.floor(i / 2) % 2 == 1) and 1 or -1
    K.SZ[i + 1] = (i >= 4) and 1 or -1
end

local D = {
    frames = {}, spd = {}, spdS = {}, stat = {dist = 0, maxV = 0, minV = math.huge},
    marks = {}, trail = {}, mapSegs = {},
    graphSegs = {}, files = {}, bounds = nil,
}

local DR = { hud = {}, map = {}, trim = {}, ghost = nil }
local RC = {}
local PC = { v = {}, o = {}, s = {} }
local PL = { free = {}, n = 0 }
local PCp = { free = {}, n = 0 }
local PS = { list = {}, eT = 0, eH = 0, hx = 0, hy = 0, hz = 0, hv = false }

local KB = { rec = nil, play = nil, loop_ = nil, ghost = nil }
local KPrev = { rec = false, play = false, loop_ = false, ghost = false }
local KBind = { rec = true, play = true, loop_ = true, ghost = true }

local function kbHeld(kb)
    if not kb then return false end
    local ok, v = pcall(function() return kb:IsEnabled() end)
    return ok and v == true
end

local function refreshColors()
    local function mk(t) return {c = Color3.fromRGB(t.r, t.g, t.b), a = t.a} end
    RC.accent = mk(C.accentColor)
    RC.path = mk(C.pathColor)
    RC.grad = mk(C.gradColor)
    RC.pcol = mk(C.pColor)
    RC.head = mk(C.headColor)
    RC.tail = mk(C.tailColor)
    RC.trim = mk(C.trimColor)
    RC.ghost = mk(C.ghostColor)
    S.rcVer = S.colorVer
end
refreshColors()

local function acquireLine(z)
    local n = PL.n
    local l
    if n > 0 then
        l = PL.free[n]
        PL.free[n] = nil
        PL.n = n - 1
        l.ZIndex = z
    else
        l = Drawing.new("Line")
        l.ZIndex = z
    end
    l.Thickness = 2
    l.Visible = false
    return l
end

local function releaseLine(l)
    pcall(function() l.Visible = false end)
    if PL.n < K.POOL_CAP then
        PL.n = PL.n + 1
        PL.free[PL.n] = l
    else
        pcall(function() l:Remove() end)
    end
end

local function acquireCircle(z)
    local n = PCp.n
    local c
    if n > 0 then
        c = PCp.free[n]
        PCp.free[n] = nil
        PCp.n = n - 1
        c.ZIndex = z
    else
        c = Drawing.new("Circle")
        c.NumSides = 12
        c.ZIndex = z
    end
    c.Transparency = 1
    c.Visible = false
    return c
end

local function releaseCircle(c)
    pcall(function() c.Visible = false end)
    if PCp.n < K.CPOOL_CAP then
        PCp.n = PCp.n + 1
        PCp.free[PCp.n] = c
    else
        pcall(function() c:Remove() end)
    end
end

local function mkLine(z)
    local l = Drawing.new("Line")
    l.Thickness = 2
    l.ZIndex = z
    l.Visible = false
    return l
end

local function mkSq(z)
    local s = Drawing.new("Square")
    s.Filled = false
    s.Thickness = 2
    s.ZIndex = z
    s.Visible = false
    return s
end

local function mkText(size, font, color)
    local t = Drawing.new("Text")
    t.Size = size
    t.Font = font
    t.Color = color
    t.Outline = true
    t.ZIndex = 902
    t.Visible = false
    return t
end

local function mkSquare(color, trans, corner, z)
    local s = Drawing.new("Square")
    s.Filled = true
    s.Color = color
    s.Transparency = trans
    s.Corner = corner or 0
    s.ZIndex = z or 900
    s.Visible = false
    return s
end

local function mkDot(sides, radius, z, color)
    local c = Drawing.new("Circle")
    c.Filled = true
    c.NumSides = sides
    c.Radius = radius
    c.Transparency = 1
    c.ZIndex = z
    c.Visible = false
    if color then c.Color = color end
    return c
end

local function mkGhost(z)
    local G = {l = {}, sp = {}, so = {}, cv = -1, shown = false}
    for i = 1, 13 do
        local l = Drawing.new("Line")
        l.Thickness = i == 13 and 2.5 or 1.5
        l.ZIndex = z
        l.Visible = false
        G.l[i] = l
    end
    return G
end

local function initDraw()
    local font = K.FONTS[C.hudFont] or K.FONTS[5]
    local H = DR.hud
    H.bg = mkSquare(Color3.fromRGB(12, 12, 18), 0.5, 6, 900)
    H.border = mkSquare(Color3.fromRGB(255, 255, 255), 0.85, 6, 901)
    H.border.Filled = false
    H.border.Thickness = 1
    H.title = mkText(14, font, Color3.fromRGB(255, 255, 255))
    H.title.Text = "RECORDER"
    H.rows = {}
    for i = 1, K.HROWS do H.rows[i] = mkText(13, font, Color3.fromRGB(200, 200, 200)) end
    H.gbg = mkSquare(Color3.fromRGB(20, 20, 28), 0.5, 0, 902)
    H.bbg = mkSquare(Color3.fromRGB(38, 38, 48), 1, 0, 902)
    H.bfill = mkSquare(Color3.fromRGB(120, 220, 180), 1, 0, 903)
    H.btext = mkText(12, font, Color3.fromRGB(220, 255, 235))

    local M = DR.map
    M.bg = mkSquare(Color3.fromRGB(10, 12, 16), 0.55, 6, 900)
    M.border = mkSquare(Color3.fromRGB(255, 255, 255), 0.85, 6, 901)
    M.border.Filled = false
    M.border.Thickness = 1
    M.title = mkText(12, K.FONTS[3] or font, Color3.fromRGB(255, 255, 255))
    M.title.Text = "ROUTE"
    M.s = mkDot(12, 4, 904, Color3.fromRGB(90, 255, 130))
    M.e = mkDot(12, 4, 904, Color3.fromRGB(255, 90, 90))
    M.c = mkDot(14, 4.5, 905, Color3.fromRGB(255, 255, 255))

    local T = DR.trim
    T.hSq = mkSq(520)
    T.hX1 = mkLine(520)
    T.hX2 = mkLine(520)
    T.tSq = mkSq(520)
    T.tX1 = mkLine(520)
    T.tX2 = mkLine(520)
    T.hC = mkDot(10, 5, 907)
    T.tS = Drawing.new("Square")
    T.tS.Filled = true
    T.tS.ZIndex = 907
    T.tS.Visible = false

    DR.ghost = mkGhost(600)
end
initDraw()

local function hideGhost(G)
    if not G.shown then return end
    G.shown = false
    for i = 1, 13 do G.l[i].Visible = false end
end

local setPlay
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
        if S.scrub then
            S.scrub = false
            UI.SetValue("r_scrub_on", false)
        end
        hideGhost(DR.ghost)
    end
    UI.SetValue("r_ghost", v)
end

local function setScrub(v)
    if S.scrub == v then return end
    S.scrub = v
    if v and not S.ghost then
        setGhost(true)
        if not S.ghost then
            S.scrub = false
            UI.SetValue("r_scrub_on", false)
        end
    end
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

local function mixC(a, b, k)
    return Color3.new(a.R + (b.R - a.R) * k, a.G + (b.G - a.G) * k, a.B + (b.B - a.B) * k)
end

local function hue(h)
    local r = math.clamp(math.abs(h * 6 - 3) - 1, 0, 1)
    local g = math.clamp(2 - math.abs(h * 6 - 2), 0, 1)
    local b = math.clamp(2 - math.abs(h * 6 - 4), 0, 1)
    return Color3.new(0.15 + r * 0.85, 0.15 + g * 0.85, 0.15 + b * 0.85)
end

local function fxApply(fx, i, nT, e, c, a, ph)
    local t = i / nT
    local p = ph / K.FXCYC
    if fx == 2 then
        return hue((t * 0.8 + p) % 1), a, 0
    elseif fx == 3 then
        local k = 0.5 + 0.5 * math.sin(6.2832 * (t * 3 - p))
        return mixC(c, K.WHITE, k * 0.75), a * (0.55 + 0.45 * k), 0
    elseif fx == 4 then
        local k = (0.5 + 0.5 * math.sin(6.2832 * (t * 7 - p * 3))) * 0.6 + (0.5 + 0.5 * math.sin(6.2832 * (t * 2.3 + p))) * 0.4
        local col
        if k < 0.5 then col = mixC(K.FR, K.FO, k * 2) else col = mixC(K.FO, K.FY, (k - 0.5) * 2) end
        return col, a * (0.55 + 0.45 * k), 0
    elseif fx == 5 then
        local k = 0.5 + 0.5 * math.sin(6.2832 * (t * 4 - p))
        return mixC(K.IB, K.IW, k), a * (0.6 + 0.4 * k), 0
    elseif fx == 6 then
        local g = RC.grad
        return mixC(c, g.c, t), a + (g.a - a) * t, 0
    elseif fx == 8 then
        return mixC(c, K.WHITE, 0.45), a, 0
    elseif fx == 9 then
        local k = 0.5 + 0.5 * math.sin(6.2832 * (t * 2.2 - p))
        local k2 = 0.5 + 0.5 * math.sin(6.2832 * (t * 1.1 + p * 2))
        return mixC(mixC(K.AU1, K.AU2, k), K.AU3, k2 * 0.8), a * (0.6 + 0.4 * k2), 0
    elseif fx == 10 then
        local v = (0.5 + 0.5 * math.sin(6.2832 * (t * 3 - p * 2))) * 0.65 + (0.5 + 0.5 * math.sin(6.2832 * (t * 7.3 - p * 3 + 0.3))) * 0.35
        local col
        if v < 0.5 then col = mixC(K.LV0, K.FR, v * 2) else col = mixC(K.FR, K.FY, (v - 0.5) * 2) end
        return col, a * (0.6 + 0.4 * v), v > 0.75 and 1 or 0
    elseif fx == 11 then
        if (i - ph) % 12 < 4 then return mixC(c, K.WHITE, 0.7), a, 1 end
        return c, a * 0.4, 0
    elseif fx == 12 then
        local q = (t * 6 - p * 6) % 1
        if q < 0.05 then return K.WHITE, a, 1 end
        return mixC(K.MX2, K.MX1, q), a * (1.05 - q * 0.7), 0
    end
    return c, a, 0
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

local function findIdx(tbl, t)
    local lo, hi = 1, #tbl
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if tbl[mid].t <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end

local function splineCf(fr, idx, alpha)
    local n = #fr
    if n < 4 then return nil end
    if idx - 1 < 1 or idx + 2 > n then return nil end
    local pos = catmullRomV3(fr[idx - 1].p, fr[idx].p, fr[idx + 1].p, fr[idx + 2].p, alpha)
    local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = fr[idx].cf:Lerp(fr[idx + 1].cf, alpha):GetComponents()
    return CFrame.new(pos.X, pos.Y, pos.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

local function sampleCf(fr, t)
    local n = #fr
    if n == 0 then return nil, 1 end
    if n == 1 or t <= fr[1].t then return fr[1].cf, 1 end
    if t >= fr[n].t then return fr[n].cf, n end
    local i = findIdx(fr, t)
    local a, b = fr[i], fr[i + 1]
    local seg = b.t - a.t
    local al = seg > 0 and (t - a.t) / seg or 0
    local c = splineCf(fr, i, al)
    if c then return c, i end
    return a.cf:Lerp(b.cf, al), i
end

local function proj(i)
    if PC.s[i] == S.stamp then return PC.v[i], PC.o[i] end
    local v, o = WorldToScreen(D.frames[i].p)
    PC.v[i] = v
    PC.o[i] = o
    PC.s[i] = S.stamp
    return v, o
end

local function trailPos(fi)
    local tr = D.trail
    local lo, hi = 1, #tr
    if hi == 0 then return 0 end
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if tr[mid].i <= fi then lo = mid else hi = mid - 1 end
    end
    return lo
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
    S.tcKey = key
    S.tcH = hi
    S.tcT = ti
    return hi, ti
end

local function recalcStat()
    local st = D.stat
    st.dist = 0
    st.maxV = 0
    st.minV = math.huge
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

local function addSeg(i, j, lastColor)
    local fr = D.frames
    if i <= 1 or i > #fr or j < 1 then return lastColor end
    local a, b = fr[j].p, fr[i].p
    if (a - b).Magnitude < K.MIN_DIST then return lastColor end
    local hc = segColor(i, lastColor)
    D.trail[#D.trail + 1] = { l = acquireLine(500), i = i, j = j, hc = hc, x = b.X, y = b.Y, z = b.Z }
    return hc
end

local function clearTrail()
    local tr = D.trail
    for i = #tr, 1, -1 do
        local e = tr[i]
        releaseLine(e.l)
        if e.g then releaseLine(e.g) end
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
    local lastColor, lastI = nil, 1
    for i = step + 1, n, step do
        lastColor = addSeg(i, i - step, lastColor)
        lastI = i
    end
    if lastI < n then addSeg(n, lastI, lastColor) end
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
        releaseLine(ms[i].l)
        ms[i] = nil
    end
    S.mapKey = nil
end

local function rebuildMap()
    clearMap()
    computeBounds()
    local n = #D.frames
    if not D.bounds or n < 2 then return end
    local step = stepFor(n)
    local lastI = 1
    for i = step + 1, n, step do
        D.mapSegs[#D.mapSegs + 1] = { l = acquireLine(902), i = i, j = i - step }
        lastI = i
    end
    if lastI < n then
        D.mapSegs[#D.mapSegs + 1] = { l = acquireLine(902), i = n, j = lastI }
    end
end

local function showGhost(G, cf)
    if G.cv ~= S.colorVer then
        local g = RC.ghost
        for i = 1, 13 do
            local l = G.l[i]
            l.Color = g.c
            l.Transparency = g.a
        end
        G.cv = S.colorVer
    end
    local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
    local sp, so = G.sp, G.so
    for i = 1, 8 do
        local sx, sy, sz = K.SX[i] * 1.5, K.SY[i] * 3, K.SZ[i] * 1.5
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
            l.From = sp[a]
            l.To = sp[b]
            l.Visible = true
        else
            l.Visible = false
        end
    end
    local cs, con = WorldToScreen(Vector3.new(px, py, pz))
    local fs, fon = WorldToScreen(Vector3.new(px - r02 * 4, py - r12 * 4, pz - r22 * 4))
    local al = G.l[13]
    if con and fon then
        al.From = cs
        al.To = fs
        al.Visible = true
    else
        al.Visible = false
    end
    G.shown = true
end

local function hideTrim()
    if not S.trimShown then return end
    S.trimShown = false
    local T = DR.trim
    T.hSq.Visible = false
    T.hX1.Visible = false
    T.hX2.Visible = false
    T.tSq.Visible = false
    T.tX1.Visible = false
    T.tX2.Visible = false
    T.hC.Visible = false
    T.tS.Visible = false
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
        for _, o in ipairs({T.hSq, T.hX1, T.hX2, T.hC}) do
            o.Color = hc.c
            o.Transparency = hc.a
        end
        for _, o in ipairs({T.tSq, T.tX1, T.tX2, T.tS}) do
            o.Color = tc.c
            o.Transparency = tc.a
        end
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
        T.hSq.Visible = true
        T.hX1.Visible = true
        T.hX2.Visible = true
    else
        T.hSq.Visible = false
        T.hX1.Visible = false
        T.hX2.Visible = false
    end
    local tS, tOn = WorldToScreen(tPos)
    if tOn and ti < #fr then
        T.tSq.Position = Vector2.new(tS.X - sz, tS.Y - sz)
        T.tSq.Size = Vector2.new(sz * 2, sz * 2)
        T.tX1.From = Vector2.new(tS.X, tS.Y - sz - 4)
        T.tX1.To = Vector2.new(tS.X, tS.Y + sz + 4)
        T.tX2.From = Vector2.new(tS.X - sz - 4, tS.Y)
        T.tX2.To = Vector2.new(tS.X + sz + 4, tS.Y)
        T.tSq.Visible = true
        T.tX1.Visible = true
        T.tX2.Visible = true
    else
        T.tSq.Visible = false
        T.tX1.Visible = false
        T.tX2.Visible = false
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
        T.hC.Visible = false
        T.tS.Visible = false
    end
end

local function updatePath()
    local tr = D.trail
    local nT = #tr
    local fx = C.fxOn and C.fx or 0
    if not C.showPath or nT == 0 then
        if S.trailShown then
            for i = 1, nT do
                local e = tr[i]
                if e.on then
                    e.l.Visible = false
                    e.on = false
                end
                if e.g then
                    e.g.Visible = false
                    e.gon = false
                end
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
    local ph = S.fxPh
    local tw = C.trailW
    local animated = K.FXA[fx]
    local dashOff = math.floor(ph / 3)
    local flowOn = fx == 1
    local head, wrap, W = 0, false, 1
    if flowOn then
        W = math.max(4, math.min(16, math.floor(nT * 0.08)))
        if S.play then
            head = trailPos(S.pIdx)
        elseif S.ghost then
            head = trailPos(S.gIdx)
        else
            head = math.floor((S.fxT % 2.5) / 2.5 * nT)
            wrap = true
        end
    end
    for i = 1, nT do
        local e = tr[i]
        local a2, aOn = proj(e.j)
        local b2, bOn
        if aOn then b2, bOn = proj(e.i) end
        if aOn and bOn then
            local state
            if headIdx and (e.i <= headIdx or e.j > tailIdx) then state = 1
            elseif C.heat then state = 2
            else state = 0 end
            local fxOn = state ~= 1
            if fx == 7 and fxOn and ((i - dashOff) % 4) >= 2 then
                if e.on then
                    e.l.Visible = false
                    e.on = false
                end
                if e.g then
                    releaseLine(e.g)
                    e.g = nil
                    e.gon = false
                end
            else
                local ax, ay, bx, by = a2.X, a2.Y, b2.X, b2.Y
                local moved = not e.on or e.ax ~= ax or e.ay ~= ay or e.bx ~= bx or e.by ~= by
                if moved then
                    e.l.From = a2
                    e.l.To = b2
                    e.ax = ax
                    e.ay = ay
                    e.bx = bx
                    e.by = by
                end
                if not e.on then
                    e.l.Visible = true
                    e.on = true
                end
                if fx == 8 and fxOn then
                    if not e.g then
                        e.g = acquireLine(499)
                        e.gon = false
                        e.cs = nil
                        moved = true
                    end
                    if moved then
                        e.g.From = a2
                        e.g.To = b2
                    end
                    if not e.gon then
                        e.g.Visible = true
                        e.gon = true
                    end
                elseif e.g then
                    releaseLine(e.g)
                    e.g = nil
                    e.gon = false
                end
                local pb = 0
                if flowOn and fxOn then
                    local k = head - i
                    if wrap and k < 0 then k = k + nT end
                    if k >= 0 and k < W then pb = 4 - math.floor(k * 4 / W) end
                end
                local ak = (fxOn and animated) and (ph + 1) or 0
                local key = state + pb * 100 + ak * 1000
                if e.cs ~= key or e.cv ~= colorVer then
                    local c, a
                    if state == 1 then
                        c, a = T.c, T.a
                    elseif state == 2 then
                        c, a = e.hc, P.a
                    else
                        c, a = P.c, P.a
                    end
                    local c0, xt = c, 0
                    if fxOn and fx >= 2 then c, a, xt = fxApply(fx, i, nT, e, c, a, ph) end
                    if pb > 0 then
                        local m = pb * 0.2
                        c = Color3.new(c.R + (1 - c.R) * m, c.G + (1 - c.G) * m, c.B + (1 - c.B) * m)
                    end
                    local th = tw + xt
                    if e.th ~= th then
                        e.l.Thickness = th
                        e.th = th
                    end
                    e.l.Color = c
                    e.l.Transparency = a
                    if e.g then
                        e.g.Thickness = th + 5
                        e.g.Color = c0
                        e.g.Transparency = a * 0.3
                    end
                    e.cs = key
                    e.cv = colorVer
                end
            end
        elseif e.on or e.g then
            if e.on then
                e.l.Visible = false
                e.on = false
            end
            if e.g then
                if fx ~= 8 then
                    releaseLine(e.g)
                    e.g = nil
                else
                    e.g.Visible = false
                end
                e.gon = false
            end
        end
    end
end

local function killP(i)
    local list = PS.list
    local p = list[i]
    releaseCircle(p.o)
    local n = #list
    list[i] = list[n]
    list[n] = nil
end

local function clearParticles()
    local list = PS.list
    for i = #list, 1, -1 do
        local p = list[i]
        releaseCircle(p.o)
        list[i] = nil
    end
    PS.eT = 0
    PS.eH = 0
    PS.hv = false
    S.pAcc = 0
end

local function pColor(p, k)
    local m = C.pCol
    if m == 0 then return RC.path.c end
    if m == 1 then return RC.accent.c end
    if m == 2 then return hue((p.seed + k * 0.6) % 1) end
    if m == 3 then
        if k < 0.5 then return mixC(K.FY, K.FO, k * 2) end
        return mixC(K.FO, K.FR, (k - 0.5) * 2)
    end
    if m == 4 then return mixC(K.IW, K.IB, k) end
    if m == 5 then return K.WHITE end
    if m == 6 then return mixC(RC.path.c, RC.grad.c, k) end
    return RC.pcol.c
end

local function emitOne(x, y, z, bx, by, bz, sm)
    local T = K.PT[C.pType + 1]
    local u = math.random() * 2 - 1
    local th = math.random() * 6.2832
    local s = math.sqrt(1 - u * u)
    local sp = T.sp * C.pSpread * sm * (0.35 + 0.65 * math.random())
    local o = acquireCircle(520)
    o.Filled = T.filled
    o.Thickness = 1
    local list = PS.list
    list[#list + 1] = {
        o = o, kind = 2,
        x = x + (math.random() - 0.5) * 0.5,
        y = y + (math.random() - 0.5) * 0.5,
        z = z + (math.random() - 0.5) * 0.5,
        vx = s * math.cos(th) * sp + bx,
        vy = u * sp * T.vyk + T.up * (0.5 + math.random()) * sm + by,
        vz = s * math.sin(th) * sp + bz,
        age = 0,
        life = C.pLife * T.life * (0.6 + 0.4 * math.random()),
        size = C.pSize * (0.6 + 0.8 * math.random()),
        seed = math.random(),
        on = false, has = false, sx = 0, sy = 0, ta = 1, ck = -1,
    }
end

local function headPos()
    if S.play or S.rec then
        local h = hrp()
        if h then
            local p = h.Position
            return p.X, p.Y, p.Z
        end
    elseif S.ghost then
        local cf = sampleCf(D.frames, S.gEl)
        if cf then
            local p = cf.Position
            return p.X, p.Y, p.Z
        end
    end
    return nil
end

local function trailPt()
    local tr = D.trail
    local nT = #tr
    if nT == 0 then return nil end
    for q = 1, 3 do
        local e = tr[math.random(nT)]
        if e.on then return e.x, e.y, e.z end
    end
    return nil
end

local function updateParticles(dt)
    local list = PS.list
    if not C.pOn then
        if #list > 0 then clearParticles() end
        return
    end
    if dt > 0.1 then dt = 0.1 elseif dt < 0.001 then dt = 0.001 end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local cp = cam.CFrame.Position
    local T = K.PT[C.pType + 1]

    local hx, hy, hz = headPos()
    local bx, by, bz = 0, 0, 0
    if hx then
        if PS.hv then
            local vx, vy, vz = (hx - PS.hx) / dt, (hy - PS.hy) / dt, (hz - PS.hz) / dt
            local m = math.sqrt(vx * vx + vy * vy + vz * vz)
            local f = -0.25
            if m > 40 then f = f * 40 / m end
            bx = vx * f
            by = vy * f
            bz = vz * f
        end
        PS.hx = hx
        PS.hy = hy
        PS.hz = hz
        PS.hv = true
    else
        PS.hv = false
    end

    while #list > C.pMax do killP(#list) end

    local room = C.pMax - #list
    if room > 0 then
        local tr = D.trail
        if C.showPath and #tr > 0 then PS.eT = PS.eT + C.pRate * dt end
        if hx then PS.eH = PS.eH + C.pRate * 1.5 * dt end
        local nt = math.floor(PS.eT)
        PS.eT = PS.eT - nt
        if nt > 10 then nt = 10 end
        for q = 1, nt do
            if room <= 0 then break end
            local x, y, z = trailPt()
            if x then
                emitOne(x, y, z, 0, 0, 0, 1)
                room = room - 1
            end
        end
        local nh = math.floor(PS.eH)
        PS.eH = PS.eH - nh
        if nh > 10 then nh = 10 end
        for q = 1, nh do
            if room <= 0 then break end
            emitOne(hx, hy, hz, bx, by, bz, 1)
            room = room - 1
        end
    end

    local colorVer = S.colorVer
    local dyn = K.PDYN[C.pCol]
    local cx, cy, cz = cp.X, cp.Y, cp.Z
    local i = 1
    local n = #list
    while i <= n do
        local p = list[i]
        local age = p.age + dt
        if age >= p.life then
            killP(i)
            n = n - 1
        else
            p.age = age
            local dr = 1 - T.drag * dt
            if dr < 0 then dr = 0 end
            local vx = p.vx * dr
            local vy = p.vy * dr + T.grav * dt
            local vz = p.vz * dr
            if T.sway then
                vx = vx + math.sin(age * 2.3 + p.seed * 6.28) * dt * 2.5
                vz = vz + math.cos(age * 1.9 + p.seed * 6.28) * dt * 2.5
            end
            p.vx = vx
            p.vy = vy
            p.vz = vz
            local x = p.x + vx * dt
            local y = p.y + vy * dt
            local z = p.z + vz * dt
            p.x = x
            p.y = y
            p.z = z
            local o = p.o
            local sp, on = WorldToScreen(Vector3.new(x, y, z))
            if on then
                local k = age / p.life
                local a = 1 - k * k
                if T.twinkle then a = a * (0.55 + 0.45 * math.sin(age * 14 + p.seed * 6.28)) end
                local ps = 40 / math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2 + (z - cz) ^ 2 + 1)
                if ps < 0.35 then ps = 0.35 elseif ps > 3 then ps = 3 end
                local r = p.size * ps
                if T.filled then r = r * (1 - k * 0.5) else r = r * (0.7 + 0.8 * k) end
                if r < 0.6 then r = 0.6 end
                o.Position = sp
                o.Radius = r
                local key = (dyn and math.floor(k * 8) or 0) + colorVer * 16
                if p.ck ~= key then
                    o.Color = pColor(p, k)
                    p.ck = key
                end
                if math.abs(p.ta - a) > 0.04 then
                    o.Transparency = a
                    p.ta = a
                end
                if not p.on then
                    o.Visible = true
                    p.on = true
                end
            else
                if p.on then
                    o.Visible = false
                    p.on = false
                end
            end
            i = i + 1
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
    H.bg.Visible = false
    H.border.Visible = false
    H.title.Visible = false
    for _, t in ipairs(H.rows) do t.Visible = false end
    H.gbg.Visible = false
    for _, s in ipairs(D.graphSegs) do s.Visible = false end
    H.bbg.Visible = false
    H.bfill.Visible = false
    H.btext.Visible = false
    S.hudShown = false
    S.hudKey = nil
    S.gKey = nil
    S.bKey = nil
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
        H.bg.Position = Vector2.new(C.hudX, C.hudY)
        H.bg.Size = Vector2.new(w, totalH)
        H.bg.Transparency = C.hudAlpha
        H.bg.Corner = C.hudCorner
        H.bg.Visible = true
        H.border.Position = Vector2.new(C.hudX, C.hudY)
        H.border.Size = Vector2.new(w, totalH)
        H.border.Corner = C.hudCorner
        H.border.Color = S.rec and K.REC or A.c
        H.border.Visible = true
        H.title.Font = font
        H.title.Size = math.floor(14 * sc)
        H.title.Color = A.c
        H.title.Position = Vector2.new(C.hudX + padX, C.hudY + padY)
        H.title.Visible = true
        for i = 1, nRows do
            local r = H.rows[i]
            r.Font = font
            r.Size = math.floor(13 * sc)
            r.Position = Vector2.new(C.hudX + padX, C.hudY + padY + titleH + (i - 1) * rowH)
            r.Visible = true
        end
        S.cached = {}
        if C.showGraph then
            H.gbg.Position = Vector2.new(gx, gy)
            H.gbg.Size = Vector2.new(gw, gh)
            H.gbg.Visible = true
        else
            H.gbg.Visible = false
        end
        if C.showBar then
            H.bbg.Position = Vector2.new(bx, by)
            H.bbg.Size = Vector2.new(barW, barH)
            H.bbg.Visible = true
            H.btext.Font = font
            H.btext.Size = math.floor(12 * sc)
            H.btext.Position = Vector2.new(bx, by + barH + 2)
        else
            H.bbg.Visible = false
            H.bfill.Visible = false
            H.btext.Visible = false
        end
        S.gKey = nil
        S.bKey = nil
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
    setRow(3, string.format("Loop %s  Ghost %s  FX %s", S.loop_ and "on" or "off", S.ghost and (S.scrub and "scrub" or "on") or "off", C.fxOn and K.FXN[C.fx + 1] or "off"), (S.loop_ or S.ghost) and 1 or 0)
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
                l.Thickness = 1
                l.ZIndex = 903
                l.Visible = false
                gs[#gs + 1] = l
            end
            local A = RC.accent
            for i = 1, need do
                local seg = gs[i]
                seg.From = Vector2.new(xs[i], ys[i])
                seg.To = Vector2.new(xs[i + 1], ys[i + 1])
                seg.Color = A.c
                seg.Transparency = A.a * 0.9
                seg.Visible = true
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
            H.bfill.Position = Vector2.new(bx, by)
            H.bfill.Size = Vector2.new(math.max(1, barW * progress), barH)
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
    M.bg.Visible = false
    M.border.Visible = false
    M.title.Visible = false
    M.s.Visible = false
    M.e.Visible = false
    M.c.Visible = false
    for _, s in ipairs(D.mapSegs) do s.l.Visible = false end
    S.mapShown = false
    S.mapKey = nil
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
        M.bg.Position = Vector2.new(mx, my)
        M.bg.Size = Vector2.new(size, size)
        M.bg.Transparency = C.mapAlpha
        M.bg.Visible = true
        M.border.Position = Vector2.new(mx, my)
        M.border.Size = Vector2.new(size, size)
        M.border.Color = A.c
        M.border.Visible = true
        M.title.Position = Vector2.new(mx + pad, my + pad)
        M.title.Color = A.c
        M.title.Visible = true
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
                e.l.Color = col
                e.l.Transparency = al
                e.l.Visible = true
            else
                e.l.Visible = false
            end
        end
        local sx, sz = toMap(fr[1].p)
        if sx then
            M.s.Position = Vector2.new(mx + pad + sx * inner, my + pad + sz * inner)
            M.s.Visible = true
        end
        local ex, ez = toMap(fr[n].p)
        if ex then
            M.e.Position = Vector2.new(mx + pad + ex * inner, my + pad + ez * inner)
            M.e.Visible = true
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
    tr.h = 0
    tr.t = 0
    tr.hs = 0
    tr.ts = 0
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

local function saveFile(name)
    ensureFolder()
    local fr = D.frames
    local out = { rate = C.rate, frames = {} }
    for i = 1, #fr do
        local f = fr[i]
        local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = f.cf:GetComponents()
        out.frames[i] = {
            t = rd(f.t),
            p = { rd(px), rd(py), rd(pz) },
            r = { rd(r00), rd(r01), rd(r02), rd(r10), rd(r11), rd(r12), rd(r20), rd(r21), rd(r22) },
        }
    end
    local ok = pcall(writefile, rpath(name), HttpService:JSONEncode(out))
    if ok then refreshList() end
    return ok
end

local function loadFile()
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
        local p = f.p
        if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" and type(p[3]) == "number" then
            local pos = Vector3.new(p[1], p[2], p[3])
            local cf
            local r = f.r
            if type(r) == "table" and #r == 9 then
                cf = CFrame.new(p[1], p[2], p[3], unpack(r))
            elseif type(f.l) == "table" then
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
    rebuildMap()
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
    local tEnd = fr[ti].t
    local nf = {}
    for i = hi, ti do nf[#nf + 1] = { t = fr[i].t - off, cf = fr[i].cf, p = fr[i].p } end
    local nmk = {}
    for _, m in ipairs(D.marks) do
        if m.t >= off and m.t <= tEnd then nmk[#nmk + 1] = { t = m.t - off, p = m.p } end
    end
    D.frames = nf
    D.marks = nmk
    rebuildTrail()
    rebuildMap()
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
    C.showPath = b(d.showPath, C.showPath)
    C.showHud = b(d.showHud, C.showHud)
    C.showGraph = b(d.showGraph, C.showGraph)
    C.showBar = b(d.showBar, C.showBar)
    C.showMap = b(d.showMap, C.showMap)
    C.mapSize = n(d.mapSize, C.mapSize)
    C.mapX = n(d.mapX, C.mapX)
    C.mapY = n(d.mapY, C.mapY)
    C.mapAlpha = n(d.mapAlpha, C.mapAlpha)
    C.hudX = n(d.hudX, C.hudX)
    C.hudY = n(d.hudY, C.hudY)
    C.hudScale = n(d.hudScale, C.hudScale)
    C.hudAlpha = n(d.hudAlpha, C.hudAlpha)
    C.hudCorner = n(d.hudCorner, C.hudCorner)
    C.hudFont = n(d.hudFont, C.hudFont)
    C.trimPreview = b(d.trimPreview, C.trimPreview)
    C.heat = b(d.heat, C.heat)
    C.liveTrail = b(d.liveTrail, C.liveTrail)
    C.smoothTrail = b(d.smoothTrail, C.smoothTrail)
    C.fxOn = b(d.fxOn, C.fxOn)
    C.fx = math.clamp(math.floor(n(d.fx, C.fx)), 0, #K.FXN - 1)
    C.fxSpeed = math.clamp(n(d.fxSpeed, C.fxSpeed), 0.2, 4)
    C.trailW = math.clamp(math.floor(n(d.trailW, C.trailW)), 1, 6)
    C.pOn = b(d.pOn, C.pOn)
    C.pType = math.clamp(math.floor(n(d.pType, C.pType)), 0, #K.PN - 1)
    C.pCol = math.clamp(math.floor(n(d.pCol, C.pCol)), 0, #K.PCN - 1)
    C.pRate = math.clamp(n(d.pRate, C.pRate), 5, 300)
    C.pSize = math.clamp(n(d.pSize, C.pSize), 0.5, 6)
    C.pLife = math.clamp(n(d.pLife, C.pLife), 0.3, 4)
    C.pSpread = math.clamp(n(d.pSpread, C.pSpread), 0.2, 3)
    C.pMax = math.clamp(math.floor(n(d.pMax, C.pMax)), 20, 500)
    C.ghostColor = readColor(d.ghostColor, C.ghostColor)
    C.accentColor = readColor(d.accentColor, C.accentColor)
    C.pathColor = readColor(d.pathColor, C.pathColor)
    C.gradColor = readColor(d.gradColor, C.gradColor)
    C.pColor = readColor(d.pColor, C.pColor)
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
        {"r_live", C.liveTrail},
        {"r_fx_on", C.fxOn}, {"r_fx", C.fx}, {"r_fx_spd", C.fxSpeed}, {"r_tw", C.trailW},
        {"r_pt_on", C.pOn}, {"r_pt_type", C.pType}, {"r_pt_col", C.pCol},
        {"r_pt_rate", C.pRate}, {"r_pt_size", C.pSize}, {"r_pt_life", C.pLife}, {"r_pt_spread", C.pSpread}, {"r_pt_max", C.pMax},
        {"r_ghost", false}, {"r_scrub_on", false},
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
    D.frames = {}
    D.spd = {}
    D.spdS = {}
    D.marks = {}
    D.bounds = nil
    local st = D.stat
    st.dist = 0
    st.maxV = 0
    st.minV = math.huge
    clearTrail()
    clearMap()
    S.t0 = tick()
    S.lastCf = nil
    S.lastCfT = 0
    S.frameGaps = 0
    S.overflow = false
    S.tcKey = nil
end

local function stopRec()
    rebuildTrail()
    rebuildMap()
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

setPlay = function(v)
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
        local cf, idx = sampleCf(fr, S.pEl)
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

local function tpTime(t)
    local h = hrp()
    local cf = sampleCf(D.frames, t)
    if h and cf then
        h.CFrame = cf
        h.AssemblyLinearVelocity = Vector3.zero
    end
end

local function fullReset()
    setPlay(false)
    setRec(false)
    setGhost(false)
    D.frames = {}
    D.spd = {}
    D.spdS = {}
    D.marks = {}
    D.bounds = nil
    local st = D.stat
    st.dist = 0
    st.maxV = 0
    st.minV = math.huge
    clearTrail()
    clearMap()
    clearParticles()
    for _, s in ipairs(D.graphSegs) do s.Visible = false end
    S.lastCf = nil
    S.lastCfT = 0
    S.frameGaps = 0
    S.overflow = false
    S.drawn = 0
    S.vtick = 0
    S.trimCV = -1
    S.gKey = nil
    S.bKey = nil
    S.mapKey = nil
    S.hudKey = nil
    S.cached = {}
    S.hudShown = false
    S.mapShown = false
    S.trimShown = false
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
    local cf, idx = sampleCf(fr, S.pEl)
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
    if S.scrub then
        S.gEl = math.clamp(S.scrubV / 1000, 0, 1) * T
    else
        S.gEl = S.gEl + dt * C.pSpeed
        if S.gEl >= T then
            S.gEl = T
            setGhost(false)
            return
        end
    end
    local cf, idx = sampleCf(fr, S.gEl)
    S.gIdx = idx or 1
    if cf then showGhost(DR.ghost, cf) else hideGhost(DR.ghost) end
end

local function bindRec()
    setRec(not S.rec)
end

local function bindPlay()
    setPlay(not S.play)
end

local function bindLoop()
    setLoop(not S.loop_)
end

local function bindGhost()
    setGhost(not S.ghost)
end

task.spawn(function()
    while true do
        local hRec = KBind.rec and kbHeld(KB.rec)
        if hRec and not KPrev.rec then pcall(bindRec) end
        KPrev.rec = hRec
        local hPlay = KBind.play and kbHeld(KB.play)
        if hPlay and not KPrev.play then pcall(bindPlay) end
        KPrev.play = hPlay
        local hLoop = KBind.loop_ and kbHeld(KB.loop_)
        if hLoop and not KPrev.loop_ then pcall(bindLoop) end
        KPrev.loop_ = hLoop
        local hGhost = KBind.ghost and kbHeld(KB.ghost)
        if hGhost and not KPrev.ghost then pcall(bindGhost) end
        KPrev.ghost = hGhost
        wait(0.02)
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.rec or S.play then return end
    local h = hrp()
    if not h then return end
    local now = tick()
    local interval = 1 / C.rate
    local cfNow = h.CFrame

    if not S.lastCf then
        S.lastCf = cfNow
        S.lastCfT = now
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
            for i = S.drawn + 1, n do lastColor = addSeg(i, i - 1, lastColor) end
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
    S.fxT = S.fxT + dt * C.fxSpeed
    S.fxPh = math.floor(S.fxT * K.FXHZ) % K.FXCYC

    if S.dTrail then
        S.dTrail = false
        rebuildTrail()
        rebuildMap()
    end

    if S.play then stepPlay(dt) end
    if S.ghost then updateGhost(dt) elseif DR.ghost.shown then hideGhost(DR.ghost) end

    S.pAcc = S.pAcc + dt
    S.pv = S.pv + 1
    if S.pv >= 1 then
        updateParticles(S.pAcc)
        S.pAcc = 0
        S.pv = 0
    end

    S.vtick = S.vtick + 1
    if S.vtick >= S.thr then
        S.vtick = 0
        S.phase = 1 - S.phase
        updatePath()
        updateTrimPreview()
        if S.phase == 0 then updateHud() else updateMap() end
    end
end)

local function colorCb(field)
    return function(c, a)
        local t = C[field]
        t.r = math.floor(c.R * 255 + 0.5)
        t.g = math.floor(c.G * 255 + 0.5)
        t.b = math.floor(c.B * 255 + 0.5)
        t.a = a
        S.colorVer = S.colorVer + 1
    end
end

ensureFolder()
local cfgOk = loadCfg()
refreshColors()
refreshList()

UI.AddTab("Recorder", function(tab)
    local s1 = tab:Section("Recorder", "Left")
    s1:Toggle("r_on", "Recording", false, function(v)
        setRec(v)
        KBind.rec = v
    end)
    KB.rec = s1:Keybind("r_kb_rec", 82, "hold")
    s1:Toggle("r_play_on", "Playing", false, function(v)
        setPlay(v)
        KBind.play = v
    end)
    KB.play = s1:Keybind("r_kb_play", 80, "hold")
    s1:Toggle("r_loop", "Loop", false, function(v)
        setLoop(v)
        KBind.loop_ = v
    end)
    KB.loop_ = s1:Keybind("r_kb_loop", 76, "hold")
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
        if saveFile(C.file) then
            saveCfg()
            notify("Saved " .. C.file, "Recorder", 2)
        else
            notify("Save failed", "Recorder", 2)
        end
    end)
    s2:Button("Load", 100, 20, function()
        if loadFile() then notify("Loaded " .. #D.frames .. " frames", "Recorder", 2)
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
            clearParticles()
            syncUI()
            S.dTrail = true
            notify("Config loaded", "Recorder", 2)
        else
            notify("No config", "Recorder", 2)
        end
    end)
    s3:Button("Reset Config", 120, 20, function()
        C.rate = 20
        C.pSpeed = 1.0
        C.showPath = true
        C.showHud = true
        C.showGraph = true
        C.showBar = true
        C.showMap = false
        C.mapSize = 180
        C.mapX = 0
        C.mapY = 0
        C.mapAlpha = 0.55
        C.hudX = 20
        C.hudY = 20
        C.hudScale = 1.0
        C.hudAlpha = 0.5
        C.hudCorner = 6
        C.hudFont = 5
        C.trimPreview = true
        C.heat = false
        C.liveTrail = false
        C.smoothTrail = true
        C.fxOn = true
        C.fx = 1
        C.fxSpeed = 1.0
        C.trailW = 2
        C.pOn = true
        C.pType = 0
        C.pCol = 3
        C.pRate = 40
        C.pSize = 2.0
        C.pLife = 1.0
        C.pSpread = 1.0
        C.pMax = 200
        C.ghostColor = {r = 255, g = 120, b = 255, a = 0.9}
        C.accentColor = {r = 120, g = 220, b = 180, a = 1}
        C.pathColor = {r = 120, g = 220, b = 180, a = 1}
        C.gradColor = {r = 255, g = 80, b = 200, a = 1}
        C.pColor = {r = 255, g = 200, b = 80, a = 1}
        C.headColor = {r = 255, g = 60, b = 60, a = 1}
        C.tailColor = {r = 60, g = 180, b = 255, a = 1}
        C.trimColor = {r = 255, g = 140, b = 40, a = 0.9}
        S.colorVer = S.colorVer + 1
        clearParticles()
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
    s5:Button("Rebuild", 120, 20, function() S.dTrail = true end)
    s5:Button("Clear Path", 120, 20, function()
        clearTrail()
        clearMap()
        D.bounds = nil
    end)

    local s10 = tab:Section("Trail FX", "Right")
    s10:Toggle("r_fx_on", "Trail Effects", C.fxOn, function(v) C.fxOn = v S.colorVer = S.colorVer + 1 end)
    s10:ColorPicker("r_grad_col", C.gradColor.r / 255, C.gradColor.g / 255, C.gradColor.b / 255, C.gradColor.a, colorCb("gradColor"))
    s10:Combo("r_fx", "Effect", K.FXN, C.fx, function(i)
        C.fx = i
        S.colorVer = S.colorVer + 1
    end)
    s10:SliderFloat("r_fx_spd", "Effect Speed", 0.2, 4.0, C.fxSpeed, "%.2f", function(v) C.fxSpeed = v end)
    s10:SliderInt("r_tw", "Trail Width", 1, 6, C.trailW, function(v) C.trailW = v S.colorVer = S.colorVer + 1 end)
    s10:Tip("Gradient: Path color -> Effect color")

    local s11 = tab:Section("Particles", "Right")
    s11:Toggle("r_pt_on", "Particles", C.pOn, function(v)
        C.pOn = v
        if not v then clearParticles() end
    end)
    s11:ColorPicker("r_pt_pick", C.pColor.r / 255, C.pColor.g / 255, C.pColor.b / 255, C.pColor.a, colorCb("pColor"))
    s11:Combo("r_pt_type", "Particle Type", K.PN, C.pType, function(i)
        C.pType = i
        clearParticles()
    end)
    s11:Combo("r_pt_col", "Particle Color", K.PCN, C.pCol, function(i)
        C.pCol = i
        S.colorVer = S.colorVer + 1
    end)
    s11:SliderInt("r_pt_rate", "Emit Rate", 5, 300, C.pRate, function(v) C.pRate = v end)
    s11:SliderFloat("r_pt_size", "Particle Size", 0.5, 6.0, C.pSize, "%.1f", function(v) C.pSize = v end)
    s11:SliderFloat("r_pt_life", "Lifetime", 0.3, 4.0, C.pLife, "%.2f", function(v) C.pLife = v end)
    s11:SliderFloat("r_pt_spread", "Spread / Speed", 0.2, 3.0, C.pSpread, "%.2f", function(v) C.pSpread = v end)
    s11:SliderInt("r_pt_max", "Max Particles", 20, 500, C.pMax, function(v) C.pMax = v end)
    s11:Button("Clear Particles", 120, 20, function() clearParticles() end)

    local s9 = tab:Section("Ghost", "Right")
    s9:Toggle("r_ghost", "Ghost Preview", false, function(v)
        setGhost(v)
        KBind.ghost = v
    end)
    KB.ghost = s9:Keybind("r_kb_ghost", 71, "hold")
    s9:Toggle("r_scrub_on", "Scrub Mode", false, function(v) setScrub(v) end)
    s9:ColorPicker("r_ghost_col", C.ghostColor.r / 255, C.ghostColor.g / 255, C.ghostColor.b / 255, C.ghostColor.a, colorCb("ghostColor"))
    s9:SliderInt("r_scrub", "Scrub Timeline", 0, 1000, 0, function(v) S.scrubV = v end)
    s9:Button("Teleport To Scrub", 140, 20, function()
        local fr = D.frames
        local n = #fr
        if n < 2 then return end
        tpTime(math.clamp(S.scrubV / 1000, 0, 1) * fr[n].t)
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
