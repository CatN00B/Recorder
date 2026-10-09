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

local S = { rec = false, play = false, loop_ = false }
local pSpeed, rate = 1.0, 20
local file, cfgFile, recFolder = "movement_rec", "recorder_config.json", "recorder"
local showPath, showHud, showGraph, showBar, showMap = true, true, true, true, false
local mapSize, mapX, mapY = 180, 0, 0
local hudX, hudY = 20, 20
local trimH, trimT, trimHS, trimTS = 0, 0, 0, 0
local showTrimPreview = true
local heat, liveTrail, smoothTrail = false, false, true
local ghostOn, ghostT0 = false, 0
local ghostColor = {r = 255, g = 120, b = 255, a = 0.9}

local pathColor = {r = 120, g = 220, b = 180, a = 1}
local headColor = {r = 255, g = 60, b = 60, a = 1}
local tailColor = {r = 60, g = 180, b = 255, a = 1}
local trimColor = {r = 255, g = 140, b = 40, a = 0.9}

local MAX_SEGS = 800
local MIN_DIST = 0.1
local MAX_FRAMES = 18000
local VISUAL_THROTTLE = 2
local LIVE_BATCH = 4
local HEAT_BANDS = 6

local frames, lines, mapSegs, graphSegs = {}, {}, {}, {}
local spd, spdS, stat = {}, {}, { dist = 0, maxV = 0, minV = math.huge }
local t0, lastS, pT0, pIdx, drawnCount = 0, 0, 0, 1, 0
local prevKeys = {}
local mapBounds, fileCombo, fileList = nil, nil, {}
local colorVer = 0

local lastCf, lastCfT = nil, 0
local frameGaps = 0
local frameOverflow = false
local visualTick = 0

local hudBg, hudBorder, hudTitle, hudRows, cachedText = nil, nil, nil, {}, {}
local graphBg, barBg, barFill, barText = nil, nil, nil, nil
local barW, barH, graphMax, graphPts = 170, 6, 10, 60
local mapBg, mapBorder, mapTitle, mapDotStart, mapDotCur, mapDotEnd = nil, nil, nil, nil, nil, nil
local hudShown, hudLayoutKey, lastGraphKey, lastBarKey = false, nil, nil, nil
local mapShown, lastMapKey = false, nil
local trimShown, trimCV = false, -1

local trimHeadSq, trimHeadX1, trimHeadX2 = nil, nil, nil
local trimTailSq, trimTailX1, trimTailX2 = nil, nil, nil
local trimHeadMapCircle, trimTailMapSquare = nil, nil

local ghostLines = {}
local ghostShown = false
local ghostCV, ghostCA = -1, -1

local EDGES = {{0,1},{2,3},{4,5},{6,7},{0,2},{1,3},{4,6},{5,7},{0,4},{1,5},{2,6},{3,7}}
local SX, SY, SZ = {}, {}, {}
for i = 0, 7 do
    SX[i + 1] = (i % 2 == 1) and 1 or -1
    SY[i + 1] = (math.floor(i / 2) % 2 == 1) and 1 or -1
    SZ[i + 1] = (i >= 4) and 1 or -1
end
local GHX, GHY, GHZ = 1.5, 3, 1.5
local gsp, gso = {}, {}

for i = 1, 13 do
    local l = Drawing.new("Line")
    l.Thickness = i == 13 and 2.5 or 1.5
    l.ZIndex, l.Visible = 600, false
    ghostLines[i] = l
end

local BANDS = {
    {Color3.fromRGB(70, 140, 255)},
    {Color3.fromRGB(70, 220, 230)},
    {Color3.fromRGB(90, 255, 130)},
    {Color3.fromRGB(230, 255, 80)},
    {Color3.fromRGB(255, 170, 60)},
    {Color3.fromRGB(255, 70, 70)},
}

local function c3(t) return Color3.fromRGB(t.r, t.g, t.b) end
local function lerpCf(a, b, t) return a:Lerp(b, t) end

local function heatCol(v)
    local rng = stat.maxV - stat.minV
    if rng <= 0 then rng = 1 end
    local t = math.clamp((v - stat.minV) / rng, 0, 1)
    if smoothTrail then
        local idx = math.floor(t * (HEAT_BANDS - 1) + 0.5) + 1
        return BANDS[idx][1]
    end
    local seg = 1 / (HEAT_BANDS - 1)
    local idx = math.min(math.floor(t / seg) + 1, HEAT_BANDS - 1)
    local lt = (t - (idx - 1) * seg) / seg
    local c1, c2 = BANDS[idx][1], BANDS[idx + 1][1]
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

local function splineCf(idx, alpha)
    local n = #frames
    if n < 4 then return nil end
    local i0, i1, i2, i3 = idx - 1, idx, idx + 1, idx + 2
    if i0 < 1 or i3 > n then return nil end
    local p0 = frames[i0].cf.Position
    local p1 = frames[i1].cf.Position
    local p2 = frames[i2].cf.Position
    local p3 = frames[i3].cf.Position
    local posSpline = catmullRomV3(p0, p1, p2, p3, alpha)
    local rotInterp = frames[i1].cf:Lerp(frames[i2].cf, alpha)
    local rx, ry, rz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rotInterp:GetComponents()
    return CFrame.new(posSpline.X, posSpline.Y, posSpline.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

local function findIdx(tbl, t)
    local lo, hi = 1, #tbl
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if tbl[mid].t <= t then lo = mid else hi = mid - 1 end
    end
    return lo
end

local function sampleCf(tbl, t, spline)
    local n = #tbl
    if n == 0 then return nil end
    if n == 1 or t <= tbl[1].t then return tbl[1].cf end
    if t >= tbl[n].t then return tbl[n].cf end
    local i = findIdx(tbl, t)
    local a, b = tbl[i], tbl[i + 1]
    local seg = b.t - a.t
    local al = seg > 0 and (t - a.t) / seg or 0
    if spline and tbl == frames then
        local c = splineCf(i, al)
        if c then return c end
    end
    return a.cf:Lerp(b.cf, al)
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function folder() if not isfolder(recFolder) then pcall(makefolder, recFolder) end end
local function rpath(n) return recFolder .. "/" .. n .. ".json" end
local function clearLines(t)
    for _, e in ipairs(t) do pcall(function() (e.line or e):Remove() end) end
    for i = #t, 1, -1 do t[i] = nil end
end
local function clearPath() clearLines(lines) drawnCount = 0 end
local function clearMap() clearLines(mapSegs) lastMapKey = nil end

local function hideGhost()
    if not ghostShown then return end
    ghostShown = false
    for _, l in ipairs(ghostLines) do l.Visible = false end
end

local function showGhost(cf)
    if ghostCV ~= colorVer or ghostCA ~= ghostColor.a then
        local c = c3(ghostColor)
        for _, l in ipairs(ghostLines) do l.Color, l.Transparency = c, ghostColor.a end
        ghostCV, ghostCA = colorVer, ghostColor.a
    end
    local c = { cf:GetComponents() }
    local px, py, pz = c[1], c[2], c[3]
    local rx, ry, rz = c[4], c[7], c[10]
    local ux, uy, uz = c[5], c[8], c[11]
    local bx, by, bz = c[6], c[9], c[12]
    for i = 1, 8 do
        local sx, sy, sz = SX[i] * GHX, SY[i] * GHY, SZ[i] * GHZ
        gsp[i], gso[i] = WorldToScreen(Vector3.new(
            px + rx * sx + ux * sy + bx * sz,
            py + ry * sx + uy * sy + by * sz,
            pz + rz * sx + uz * sy + bz * sz
        ))
    end
    for k = 1, 12 do
        local a, b = EDGES[k][1] + 1, EDGES[k][2] + 1
        local l = ghostLines[k]
        if gso[a] and gso[b] then
            l.From, l.To, l.Visible = gsp[a], gsp[b], true
        else
            l.Visible = false
        end
    end
    local cs, con = WorldToScreen(Vector3.new(px, py, pz))
    local fs, fon = WorldToScreen(Vector3.new(px - bx * 4, py - by * 4, pz - bz * 4))
    local al = ghostLines[13]
    if con and fon then
        al.From, al.To, al.Visible = cs, fs, true
    else
        al.Visible = false
    end
    ghostShown = true
end

local function setGhost(v)
    if ghostOn == v then return end
    if v then
        if #frames < 2 then
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
        ghostOn = true
        ghostT0 = tick()
    else
        ghostOn = false
        hideGhost()
    end
    UI.SetValue("r_ghost", v)
end

local function smoothSpd()
    if not smoothTrail then return end
    spdS = {}
    local n = #spd
    if n < 3 then
        for i = 1, n do spdS[i] = spd[i] end
        return
    end
    spdS[2] = spd[2]
    for i = 3, n - 1 do
        spdS[i] = (spd[i - 1] + spd[i] * 2 + spd[i + 1]) * 0.25
    end
    spdS[n] = spd[n]
end

local function recalcStat()
    stat.dist, stat.maxV, stat.minV = 0, 0, math.huge
    spd = {}
    for i = 2, #frames do
        local dt = frames[i].t - frames[i - 1].t
        if dt <= 0 then dt = 1 / rate end
        local d = (frames[i].cf.Position - frames[i - 1].cf.Position).Magnitude
        local v = d / dt
        spd[i] = v
        stat.dist = stat.dist + d
        if v > stat.maxV then stat.maxV = v end
        if v < stat.minV then stat.minV = v end
    end
    if stat.minV == math.huge then stat.minV = 0 end
end

local function pushFrame(t, cf)
    local n = #frames
    frames[n + 1] = { t = t, cf = cf }
    if n >= 1 then
        local pf = frames[n]
        local dt = t - pf.t
        if dt <= 0 then dt = 1 / rate end
        local d = (cf.Position - pf.cf.Position).Magnitude
        local v = d / dt
        spd[n + 1] = v
        stat.dist = stat.dist + d
        if v > stat.maxV then stat.maxV = v end
        if v < stat.minV then stat.minV = v end
    end
end

local function refreshList()
    fileList = {}
    if not isfolder(recFolder) then return end
    local ok, ls = pcall(listfiles, recFolder)
    if ok and type(ls) == "table" then
        for _, p in ipairs(ls) do
            if isfile(p) then
                local n = p:match("([^/\\]+)%.json$")
                if n then table.insert(fileList, n) end
            end
        end
    end
    table.sort(fileList)
    if fileCombo then
        fileCombo:Clear()
        if #fileList == 0 then fileCombo:Add("(empty)")
        else for _, n in ipairs(fileList) do fileCombo:Add(n) end end
        UI.SetValue("r_file_combo", 0)
        if #fileList > 0 then file = fileList[1] UI.SetValue("r_name", file) end
    end
end

local function stepFor(n)
    if n <= MAX_SEGS then return 1 end
    return math.ceil(n / MAX_SEGS)
end

local function segColor(i, prevColor)
    local c = heatCol(smoothTrail and (spdS[i] or spd[i] or 0) or (spd[i] or 0))
    if smoothTrail and prevColor then
        return Color3.new((c.R + prevColor.R) * 0.5, (c.G + prevColor.G) * 0.5, (c.B + prevColor.B) * 0.5)
    end
    return c
end

local function addSeg(i, step, lastColor)
    if i <= 1 or i > #frames then return lastColor end
    local j = math.max(1, i - step)
    local a, b = frames[j].cf.Position, frames[i].cf.Position
    if (a - b).Magnitude < MIN_DIST then return lastColor end
    local l = Drawing.new("Line")
    l.Thickness, l.ZIndex, l.Visible = 2, 500, false
    local hc = segColor(i, lastColor)
    table.insert(lines, { line = l, a = a, b = b, idx = i, idxA = j, hc = hc })
    return hc
end

local function rebuild()
    clearPath()
    smoothSpd()
    recalcStat()
    if #frames < 2 then return end
    local step = stepFor(#frames)
    local lastColor = nil
    for i = step + 1, #frames, step do lastColor = addSeg(i, step, lastColor) end
    drawnCount = #frames
end

local function bounds()
    if #frames < 2 then mapBounds = nil return end
    local minX, maxX, minZ, maxZ
    for _, f in ipairs(frames) do
        local p = f.cf.Position
        if not minX then minX, maxX, minZ, maxZ = p.X, p.X, p.Z, p.Z
        else
            minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
            minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
        end
    end
    local span = math.max(math.max(maxX - minX, maxZ - minZ), 20)
    local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
    local half = span / 2 * 1.1
    mapBounds = { minX = cx - half, minZ = cz - half, span = half * 2 }
end

local function toMap(p)
    if not mapBounds then return nil end
    return (p.X - mapBounds.minX) / mapBounds.span, (p.Z - mapBounds.minZ) / mapBounds.span
end

local function rebuildMap()
    clearMap()
    bounds()
    if not mapBounds or #frames < 2 then return end
    local step = stepFor(#frames)
    for i = step + 1, #frames, step do
        local l = Drawing.new("Line")
        l.Thickness, l.ZIndex, l.Visible = 1, 902, false
        table.insert(mapSegs, { line = l, idx = i, idxA = i - step })
    end
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

trimHeadSq, trimHeadX1, trimHeadX2 = mkSq(520), mkLine(520), mkLine(520)
trimTailSq, trimTailX1, trimTailX2 = mkSq(520), mkLine(520), mkLine(520)
trimHeadMapCircle = Drawing.new("Circle")
trimHeadMapCircle.Filled, trimHeadMapCircle.NumSides, trimHeadMapCircle.Radius = true, 10, 5
trimHeadMapCircle.ZIndex, trimHeadMapCircle.Visible = 907, false
trimTailMapSquare = Drawing.new("Square")
trimTailMapSquare.Filled, trimTailMapSquare.ZIndex, trimTailMapSquare.Visible = true, 907, false

local function computeTrimIndices()
    local n = #frames
    if n < 2 then return nil, nil end
    local headIdx, tailIdx = 1, n
    if trimHS > 0 then
        local cut = frames[1].t + trimHS
        while headIdx < n and frames[headIdx].t < cut do headIdx = headIdx + 1 end
    end
    if trimTS > 0 then
        local cut = frames[n].t - trimTS
        while tailIdx > 1 and frames[tailIdx].t > cut do tailIdx = tailIdx - 1 end
    end
    if trimH > 0 then headIdx = math.min(headIdx + trimH, n) end
    if trimT > 0 then tailIdx = math.max(tailIdx - trimT, 1) end
    if headIdx >= tailIdx then return nil, nil end
    return headIdx, tailIdx
end

local function hideTrim()
    if not trimShown then return end
    trimShown = false
    trimHeadSq.Visible, trimHeadX1.Visible, trimHeadX2.Visible = false, false, false
    trimTailSq.Visible, trimTailX1.Visible, trimTailX2.Visible = false, false, false
    trimHeadMapCircle.Visible, trimTailMapSquare.Visible = false, false
end

local function updateTrimPreview()
    if not showTrimPreview or #frames < 2 or (trimH == 0 and trimT == 0 and trimHS == 0 and trimTS == 0) then
        hideTrim()
        return
    end
    local headIdx, tailIdx = computeTrimIndices()
    if not headIdx then hideTrim() return end
    trimShown = true

    local hPos = frames[headIdx].cf.Position
    local tPos = frames[tailIdx].cf.Position

    if trimCV ~= colorVer then
        trimCV = colorVer
        local hc, tc = c3(headColor), c3(tailColor)
        trimHeadSq.Color, trimHeadSq.Transparency = hc, headColor.a
        trimHeadX1.Color, trimHeadX1.Transparency = hc, headColor.a
        trimHeadX2.Color, trimHeadX2.Transparency = hc, headColor.a
        trimTailSq.Color, trimTailSq.Transparency = tc, tailColor.a
        trimTailX1.Color, trimTailX1.Transparency = tc, tailColor.a
        trimTailX2.Color, trimTailX2.Transparency = tc, tailColor.a
        trimHeadMapCircle.Color, trimHeadMapCircle.Transparency = hc, headColor.a
        trimTailMapSquare.Color, trimTailMapSquare.Transparency = tc, tailColor.a
    end

    local sz = 8
    local hS, hOn = WorldToScreen(hPos)
    if hOn and headIdx > 1 then
        trimHeadSq.Position = Vector2.new(hS.X - sz, hS.Y - sz)
        trimHeadSq.Size = Vector2.new(sz * 2, sz * 2)
        trimHeadX1.From = Vector2.new(hS.X - sz, hS.Y - sz)
        trimHeadX1.To = Vector2.new(hS.X + sz, hS.Y + sz)
        trimHeadX2.From = Vector2.new(hS.X + sz, hS.Y - sz)
        trimHeadX2.To = Vector2.new(hS.X - sz, hS.Y + sz)
        trimHeadSq.Visible, trimHeadX1.Visible, trimHeadX2.Visible = true, true, true
    else
        trimHeadSq.Visible, trimHeadX1.Visible, trimHeadX2.Visible = false, false, false
    end

    local tS, tOn = WorldToScreen(tPos)
    if tOn and tailIdx < #frames then
        trimTailSq.Position = Vector2.new(tS.X - sz, tS.Y - sz)
        trimTailSq.Size = Vector2.new(sz * 2, sz * 2)
        trimTailX1.From = Vector2.new(tS.X, tS.Y - sz - 4)
        trimTailX1.To = Vector2.new(tS.X, tS.Y + sz + 4)
        trimTailX2.From = Vector2.new(tS.X - sz - 4, tS.Y)
        trimTailX2.To = Vector2.new(tS.X + sz + 4, tS.Y)
        trimTailSq.Visible, trimTailX1.Visible, trimTailX2.Visible = true, true, true
    else
        trimTailSq.Visible, trimTailX1.Visible, trimTailX2.Visible = false, false, false
    end

    if showMap and mapBounds then
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        local mx = mapX == 0 and (vp.X - mapSize) / 2 or mapX
        local my = mapY == 0 and 20 or mapY
        local pad, inner = 6, mapSize - 12
        local hx, hz = toMap(hPos)
        local tx, tz = toMap(tPos)
        if hx and headIdx > 1 then
            trimHeadMapCircle.Position = Vector2.new(mx + pad + hx * inner, my + pad + hz * inner)
            trimHeadMapCircle.Visible = true
        else
            trimHeadMapCircle.Visible = false
        end
        if tx and tailIdx < #frames then
            trimTailMapSquare.Position = Vector2.new(mx + pad + tx * inner - 4, my + pad + tz * inner - 4)
            trimTailMapSquare.Size = Vector2.new(8, 8)
            trimTailMapSquare.Visible = true
        else
            trimTailMapSquare.Visible = false
        end
    else
        trimHeadMapCircle.Visible, trimTailMapSquare.Visible = false, false
    end
end

local function stopPlay()
    if not S.play then return end
    S.play = false
end

local function startRec()
    if S.play then stopPlay() end
    if ghostOn then setGhost(false) end
    frames, mapBounds, spd, spdS = {}, nil, {}, {}
    stat.dist, stat.maxV, stat.minV = 0, 0, math.huge
    clearPath() clearMap()
    t0, lastS = tick(), 0
    lastCf, lastCfT = nil, 0
    frameGaps = 0
    frameOverflow = false
end

local function stopRec()
    rebuild() rebuildMap()
end

local function startPlay()
    if #frames < 2 then return false end
    if S.play then stopPlay() end
    if ghostOn then setGhost(false) end
    local h = hrp()
    if not h then return false end
    pT0, pIdx = tick(), 1
    h.CFrame = frames[1].cf
    h.AssemblyLinearVelocity = Vector3.zero
    S.play = true
    return true
end

local function resetTrimValues()
    trimH, trimT, trimHS, trimTS = 0, 0, 0, 0
    UI.SetValue("r_trim_h", 0)
    UI.SetValue("r_trim_t", 0)
    UI.SetValue("r_trim_hs", 0)
    UI.SetValue("r_trim_ts", 0)
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
        if not startPlay() then
            notify("Need 2+ frames", "Recorder", 2)
            UI.SetValue("r_play_on", false)
            return
        end
        S.play = true
    else
        S.play = false
    end
    UI.SetValue("r_play_on", v)
end

local function setLoop(v) if S.loop_ == v then return end S.loop_ = v UI.SetValue("r_loop", v) end

local function applyTrim()
    if #frames < 3 then
        notify("Not enough frames", "Recorder", 2)
        return
    end
    local hi, ti = computeTrimIndices()
    if not hi then
        notify("Invalid trim", "Recorder", 2)
        return
    end
    if hi == 1 and ti == #frames then
        notify("Nothing to trim", "Recorder", 2)
        return
    end
    setPlay(false)
    local n0 = #frames
    local nf = {}
    local off = frames[hi].t
    for i = hi, ti do nf[#nf + 1] = { t = frames[i].t - off, cf = frames[i].cf } end
    frames = nf
    rebuild() rebuildMap()
    resetTrimValues()
    notify(string.format("Trim: %d -> %d", n0, #frames), "Recorder", 2)
end

local function save()
    folder()
    local out = { rate = rate, frames = {} }
    for i, f in ipairs(frames) do
        local p, l = f.cf.Position, f.cf.LookVector
        out.frames[i] = { t = f.t, p = { p.X, p.Y, p.Z }, l = { l.X, l.Y, l.Z } }
    end
    local ok = pcall(writefile, rpath(file), HttpService:JSONEncode(out))
    if ok then refreshList() end
    return ok
end

local function load()
    local path = rpath(file)
    if not isfile(path) then return false end
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" or type(data.frames) ~= "table" then return false end
    setPlay(false)
    if ghostOn then setGhost(false) end
    frames = {}
    for i, f in ipairs(data.frames) do
        if f.p and f.l then
            local pos = Vector3.new(f.p[1], f.p[2], f.p[3])
            local lv = Vector3.new(f.l[1], f.l[2], f.l[3])
            local cf = lv.Magnitude > 0.001 and CFrame.lookAt(pos, pos + lv) or CFrame.new(pos.X, pos.Y, pos.Z)
            frames[i] = { t = f.t or 0, cf = cf }
        end
    end
    rebuild() rebuildMap()
    return true
end

local function saveCfg()
    local out = {
        pSpeed = pSpeed, rate = rate, file = file,
        showPath = showPath, showHud = showHud, showGraph = showGraph, showBar = showBar, showMap = showMap,
        mapSize = mapSize, mapX = mapX, mapY = mapY, hudX = hudX, hudY = hudY,
        showTrimPreview = showTrimPreview, heat = heat, liveTrail = liveTrail, smoothTrail = smoothTrail,
        pathColor = pathColor, headColor = headColor, tailColor = tailColor, trimColor = trimColor,
        ghostColor = ghostColor,
    }
    return pcall(writefile, cfgFile, HttpService:JSONEncode(out))
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

local function loadCfg()
    if not isfile(cfgFile) then return false end
    local ok, raw = pcall(readfile, cfgFile)
    if not ok or not raw then return false end
    local ok2, d = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(d) ~= "table" then return false end
    local function n(v, fb) return type(v) == "number" and v or fb end
    local function b(v, fb) return type(v) == "boolean" and v or fb end
    local function s(v, fb) return type(v) == "string" and v ~= "" and v or fb end
    pSpeed, rate = n(d.pSpeed, pSpeed), n(d.rate, rate)
    file = s(d.file, file)
    showPath, showHud = b(d.showPath, showPath), b(d.showHud, showHud)
    showGraph, showBar, showMap = b(d.showGraph, showGraph), b(d.showBar, showBar), b(d.showMap, showMap)
    mapSize, mapX, mapY = n(d.mapSize, mapSize), n(d.mapX, mapX), n(d.mapY, mapY)
    hudX, hudY = n(d.hudX, hudX), n(d.hudY, hudY)
    showTrimPreview = b(d.showTrimPreview, showTrimPreview)
    heat, liveTrail = b(d.heat, heat), b(d.liveTrail, liveTrail)
    smoothTrail = b(d.smoothTrail, smoothTrail)
    pathColor = readColor(d.pathColor, pathColor)
    headColor = readColor(d.headColor, headColor)
    tailColor = readColor(d.tailColor, tailColor)
    trimColor = readColor(d.trimColor, trimColor)
    ghostColor = readColor(d.ghostColor, ghostColor)
    colorVer = colorVer + 1
    return true
end

local function syncUI()
    for _, kv in ipairs({
        {"r_rate", rate}, {"r_spd", pSpeed}, {"r_path", showPath}, {"r_hud", showHud},
        {"r_graph", showGraph}, {"r_bar", showBar}, {"r_hud_x", hudX}, {"r_hud_y", hudY},
        {"r_map", showMap}, {"r_map_size", mapSize}, {"r_map_x", mapX}, {"r_map_y", mapY},
        {"r_name", file}, {"r_trim_preview", showTrimPreview},
        {"r_heat", heat}, {"r_live", liveTrail}, {"r_smooth", smoothTrail},
        {"r_trim_h", 0}, {"r_trim_t", 0}, {"r_trim_hs", 0}, {"r_trim_ts", 0},
    }) do UI.SetValue(kv[1], kv[2]) end
    local idx = 0
    for i, nm in ipairs(fileList) do if nm == file then idx = i - 1 break end end
    UI.SetValue("r_file_combo", idx)
end

local function keyDown(c) local ok, v = pcall(iskeypressed, c) return ok and (v == true or v == 1) end
local function edge(n, c) local now = keyDown(c) local was = prevKeys[n] or false prevKeys[n] = now return now and not was end

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

local function initHud()
    hudBg = mkSquare(Color3.fromRGB(12, 12, 18), 0.5, 6, 900)
    hudBorder = mkSquare(Color3.fromRGB(120, 220, 180), 0.85, 6, 901)
    hudBorder.Filled = false
    hudBorder.Thickness = 1
    hudTitle = mkText(14, Drawing.Fonts.SystemBold, Color3.fromRGB(180, 255, 220))
    hudTitle.Text = "RECORDER"
    for i = 1, 5 do hudRows[i] = mkText(13, Drawing.Fonts.Monospace, Color3.fromRGB(200, 200, 200)) end
    graphBg = mkSquare(Color3.fromRGB(20, 20, 28), 0.5, 0, 902)
    barBg = mkSquare(Color3.fromRGB(38, 38, 48), 1, 0, 902)
    barFill = mkSquare(Color3.fromRGB(120, 220, 180), 1, 0, 903)
    barText = mkText(12, Drawing.Fonts.Monospace, Color3.fromRGB(220, 255, 235))
    mapBg = mkSquare(Color3.fromRGB(10, 12, 16), 0.55, 6, 900)
    mapBorder = mkSquare(Color3.fromRGB(120, 220, 180), 0.85, 6, 901)
    mapBorder.Filled = false
    mapBorder.Thickness = 1
    mapTitle = mkText(12, Drawing.Fonts.SystemBold, Color3.fromRGB(180, 255, 220))
    mapTitle.Text = "ROUTE"
    mapDotStart = mkDot(12, 4, 904, Color3.fromRGB(90, 255, 130))
    mapDotEnd = mkDot(12, 4, 904, Color3.fromRGB(255, 90, 90))
    mapDotCur = mkDot(14, 4.5, 905, Color3.fromRGB(255, 255, 255))
end

initHud()

RunService.Heartbeat:Connect(function()
    local active = true
    local ok, a = pcall(isrbxactive)
    if ok and a ~= nil then active = a end
    if active then
        if edge("R", 0x52) then setRec(not S.rec) end
        if edge("P", 0x50) then setPlay(not S.play) end
        if edge("L", 0x4C) then setLoop(not S.loop_) end
        if edge("G", 0x47) then setGhost(not ghostOn) end
    else
        prevKeys.R, prevKeys.P, prevKeys.L, prevKeys.G = keyDown(0x52), keyDown(0x50), keyDown(0x4C), keyDown(0x47)
    end

    if not S.rec or S.play then return end
    local h = hrp()
    if not h then return end
    local now = tick()
    local interval = 1 / rate
    local cfNow = h.CFrame

    if not lastCf then
        lastCf, lastCfT = cfNow, now
        pushFrame(now - t0, cfNow)
        drawnCount = #frames
        return
    end

    local elapsed = now - lastCfT
    if elapsed < interval then return end
    local steps = math.floor(elapsed / interval)
    if steps <= 0 then return end

    for k = 1, steps do
        local alpha = math.min(1, (k * interval) / elapsed)
        pushFrame(lastCfT + k * interval - t0, lerpCf(lastCf, cfNow, alpha))
    end

    if steps >= 2 then frameGaps = frameGaps + (steps - 1) end

    local adv = steps * interval
    lastCf = lerpCf(lastCf, cfNow, math.min(1, adv / elapsed))
    lastCfT = lastCfT + adv

    if liveTrail and not frameOverflow and #frames - drawnCount >= LIVE_BATCH then
        if #frames <= MAX_SEGS then
            local lastColor = #lines > 0 and lines[#lines].hc or nil
            for i = drawnCount + 1, #frames do lastColor = addSeg(i, 1, lastColor) end
        else
            rebuild()
            rebuildMap()
        end
        drawnCount = #frames
    end

    if not frameOverflow and #frames >= MAX_FRAMES then
        frameOverflow = true
        notify(string.format("Frame limit reached (%d). Auto-stopped.", MAX_FRAMES), "Recorder", 4)
        setRec(false)
    end
end)

local function updatePath()
    if not showPath or #lines == 0 then
        for _, e in ipairs(lines) do
            if e.on ~= false then e.line.Visible, e.on = false, false end
        end
        return
    end

    local headIdx, tailIdx = nil, nil
    if showTrimPreview then headIdx, tailIdx = computeTrimIndices() end

    local pc, pt = c3(pathColor), pathColor.a
    local tc, tt = c3(trimColor), trimColor.a

    for _, e in ipairs(lines) do
        local a2, aOn = WorldToScreen(e.a)
        local b2, bOn = WorldToScreen(e.b)
        local inTrim = headIdx and (e.idx <= headIdx or e.idxA > tailIdx)
        if aOn and bOn then
            if e.lastA ~= a2 or e.lastB ~= b2 or not e.on then
                e.line.From, e.line.To, e.line.Visible = a2, b2, true
                e.lastA, e.lastB, e.on = a2, b2, true
            end
            local state = inTrim and 1 or (heat and 2 or 0)
            if e.cs ~= state or e.cv ~= colorVer then
                if state == 1 then e.line.Color, e.line.Transparency = tc, tt
                elseif state == 2 then e.line.Color, e.line.Transparency = e.hc, pt
                else e.line.Color, e.line.Transparency = pc, pt end
                e.cs, e.cv = state, colorVer
            end
        elseif e.on ~= false then
            e.line.Visible, e.on = false, false
        end
    end
end

local rowCols = {
    [0] = Color3.fromRGB(120, 120, 130),
    [1] = Color3.fromRGB(150, 255, 190),
    [2] = Color3.fromRGB(255, 180, 90),
}

local function setRow(i, txt, st)
    local k = txt .. st
    if cachedText[i] ~= k then
        local t = hudRows[i]
        t.Text, t.Color = txt, rowCols[st]
        cachedText[i] = k
    end
end

local function hideHud()
    hudBg.Visible, hudBorder.Visible, hudTitle.Visible = false, false, false
    for _, t in ipairs(hudRows) do t.Visible = false end
    graphBg.Visible = false
    for _, s in ipairs(graphSegs) do s.Visible = false end
    barBg.Visible, barFill.Visible, barText.Visible = false, false, false
    hudShown, hudLayoutKey, lastGraphKey, lastBarKey = false, nil, nil, nil
end

local function updateHud()
    if not showHud then
        if hudShown then hideHud() end
        return
    end
    hudShown = true
    local n = #frames
    local dur = n >= 2 and frames[n].t - frames[1].t or 0

    setRow(1, "[R]  Recording", S.rec and 1 or 0)
    setRow(2, "[P]  Playing", S.play and 1 or 0)
    setRow(3, "[L] Loop  [G] Ghost", (S.loop_ or ghostOn) and 1 or 0)
    setRow(4, string.format("Frames: %d  Ghost: %s", n, ghostOn and "on" or "off"), n > 0 and 1 or 0)
    if S.rec and n > 1 and dur > 0 then
        setRow(5, string.format("Eff: %.1f Hz  gaps: %d", (n - 1) / dur, frameGaps), frameGaps > 0 and 2 or 1)
    else
        setRow(5, "Eff: --", 0)
    end

    local padX, padY, rowH, w = 10, 8, 18, 250
    local gH = showGraph and 40 or 0
    local bH = showBar and 26 or 0
    local baseY = hudY + padY + 20 + rowH * 5
    local gx, gy, gw, gh = hudX + padX, baseY, w - padX * 2, gH - 6
    local bx, by = hudX + padX, baseY + gH + 4

    local key = hudX .. "," .. hudY .. "," .. gH .. "," .. bH .. "," .. (S.rec and 1 or 0)
    if key ~= hudLayoutKey then
        hudLayoutKey = key
        local h = padY * 2 + 20 + rowH * 5 + gH + bH
        hudBg.Position, hudBg.Size, hudBg.Visible = Vector2.new(hudX, hudY), Vector2.new(w, h), true
        hudBorder.Position, hudBorder.Size = Vector2.new(hudX, hudY), Vector2.new(w, h)
        hudBorder.Color = S.rec and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(120, 220, 180)
        hudBorder.Visible = true
        hudTitle.Position, hudTitle.Visible = Vector2.new(hudX + padX, hudY + padY), true
        for i = 1, 5 do
            hudRows[i].Position = Vector2.new(hudX + padX, hudY + padY + 20 + (i - 1) * rowH)
            hudRows[i].Visible = true
        end
        if showGraph then
            graphBg.Position, graphBg.Size, graphBg.Visible = Vector2.new(gx, gy), Vector2.new(gw, gh), true
        else
            graphBg.Visible = false
        end
        if showBar then
            barBg.Position, barBg.Size, barBg.Visible = Vector2.new(bx, by), Vector2.new(barW, barH), true
            barText.Position = Vector2.new(bx, by + barH + 2)
        else
            barBg.Visible, barFill.Visible, barText.Visible = false, false, false
        end
        lastGraphKey, lastBarKey = nil, nil
    end

    if showGraph and n >= 2 then
        local endIdx = S.play and math.min(pIdx, n) or n
        local gk = endIdx .. "," .. n .. "," .. colorVer .. "," .. stat.maxV .. "," .. (smoothTrail and 1 or 0)
        if gk ~= lastGraphKey then
            lastGraphKey = gk
            graphMax = math.max(10, math.ceil(stat.maxV / 10) * 10)
            local count = math.min(graphPts, endIdx - 1)
            local start = math.max(2, endIdx - count + 1)
            local pts = {}
            for k = 0, count - 1 do
                local i = start + k
                if i > endIdx then break end
                local v = smoothTrail and (spdS[i] or spd[i] or 0) or (spd[i] or 0)
                table.insert(pts, { gx + gw * (k / math.max(1, count - 1)), gy + gh - (v / graphMax) * gh })
            end
            local need = math.max(0, #pts - 1)
            while #graphSegs < need do
                local l = Drawing.new("Line")
                l.Thickness, l.ZIndex, l.Visible = 1, 903, false
                table.insert(graphSegs, l)
            end
            local gc = c3(pathColor)
            for i = 1, need do
                local seg = graphSegs[i]
                seg.From, seg.To, seg.Visible = Vector2.new(pts[i][1], pts[i][2]), Vector2.new(pts[i + 1][1], pts[i + 1][2]), true
                seg.Color, seg.Transparency = gc, pathColor.a * 0.9
            end
            for i = need + 1, #graphSegs do graphSegs[i].Visible = false end
        end
    elseif lastGraphKey ~= "off" then
        for _, s in ipairs(graphSegs) do s.Visible = false end
        lastGraphKey = "off"
    end

    if showBar then
        local progress, label = 0, nil
        if S.play and n >= 2 then
            local curT = (tick() - pT0) * pSpeed
            local lastT = frames[n].t
            if lastT > 0 then progress = math.clamp(curT / lastT, 0, 1) end
            label = string.format("Play %d%%  %d/%d", math.floor(progress * 100 + 0.5), math.min(pIdx, n), n)
        elseif S.rec and n >= 1 then
            label = string.format("Rec %.1fs  %d frames", tick() - t0, n)
        elseif ghostOn and n >= 2 then
            local el = (tick() - ghostT0) * pSpeed
            local lastT = frames[n].t
            if lastT > 0 then progress = math.clamp(el / lastT, 0, 1) end
            label = string.format("Ghost %d%%", math.floor(progress * 100 + 0.5))
        else
            label = string.format("Idle  %d frames", n)
        end
        local bk = label .. "|" .. math.floor(progress * 1000) .. colorVer
        if bk ~= lastBarKey then
            lastBarKey = bk
            barFill.Position, barFill.Size = Vector2.new(bx, by), Vector2.new(barW * progress, barH)
            barFill.Color = S.play and c3(pathColor) or (S.rec and Color3.fromRGB(255, 90, 90) or (ghostOn and c3(ghostColor) or Color3.fromRGB(80, 80, 90)))
            barFill.Visible = true
            barText.Text = label
            barText.Visible = true
        end
    end
end

local function hideMap()
    mapBg.Visible, mapBorder.Visible, mapTitle.Visible = false, false, false
    mapDotStart.Visible, mapDotEnd.Visible, mapDotCur.Visible = false, false, false
    for _, s in ipairs(mapSegs) do s.line.Visible = false end
    mapShown, lastMapKey = false, nil
end

local function updateMap()
    if not showMap or not mapBounds or #frames < 2 then
        if mapShown then hideMap() end
        return
    end
    mapShown = true
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    local mx = mapX == 0 and (vp.X - mapSize) / 2 or mapX
    local my = mapY == 0 and 20 or mapY
    local pad, inner = 6, mapSize - 12

    local headIdx, tailIdx = nil, nil
    if showTrimPreview then headIdx, tailIdx = computeTrimIndices() end

    local key = table.concat({ mapSize, mapX, mapY, vp.X, #frames, colorVer, headIdx or 0, tailIdx or 0, heat and 1 or 0, smoothTrail and 1 or 0 }, ",")
    if key ~= lastMapKey then
        lastMapKey = key
        mapBg.Position, mapBg.Size, mapBg.Visible = Vector2.new(mx, my), Vector2.new(mapSize, mapSize), true
        mapBorder.Position, mapBorder.Size, mapBorder.Visible = Vector2.new(mx, my), Vector2.new(mapSize, mapSize), true
        mapTitle.Position, mapTitle.Visible = Vector2.new(mx + pad, my + pad), true

        local pc, pt = c3(pathColor), pathColor.a
        local tc, tt = c3(trimColor), trimColor.a
        local step = stepFor(#frames)
        local idx = 0
        for i = step + 1, #frames, step do
            idx = idx + 1
            local l = mapSegs[idx]
            if not l then break end
            local ax, az = toMap(frames[i - step].cf.Position)
            local bx, bz = toMap(frames[i].cf.Position)
            local inTrim = headIdx and (i <= headIdx or (i - step) > tailIdx)
            if ax then
                l.line.From = Vector2.new(mx + pad + ax * inner, my + pad + az * inner)
                l.line.To = Vector2.new(mx + pad + bx * inner, my + pad + bz * inner)
                if inTrim then l.line.Color, l.line.Transparency = tc, tt * 0.7
                elseif heat then
                    local v = smoothTrail and (spdS[i] or spd[i] or 0) or (spd[i] or 0)
                    l.line.Color, l.line.Transparency = heatCol(v), pt * 0.7
                else l.line.Color, l.line.Transparency = pc, pt * 0.7 end
                l.line.Visible = true
            else
                l.line.Visible = false
            end
        end
        for i = idx + 1, #mapSegs do mapSegs[i].line.Visible = false end

        local sx, sz = toMap(frames[1].cf.Position)
        if sx then mapDotStart.Position = Vector2.new(mx + pad + sx * inner, my + pad + sz * inner) mapDotStart.Visible = true end
        local ex, ez = toMap(frames[#frames].cf.Position)
        if ex then mapDotEnd.Position = Vector2.new(mx + pad + ex * inner, my + pad + ez * inner) mapDotEnd.Visible = true end
    end

    local cur = frames[math.min(pIdx, #frames)] or frames[1]
    local cx, cz = toMap(cur.cf.Position)
    if cx then
        mapDotCur.Position = Vector2.new(mx + pad + cx * inner, my + pad + cz * inner)
        mapDotCur.Visible = true
    end
end

local function updateGhost()
    if not ghostOn then
        if ghostShown then hideGhost() end
        return
    end
    local n = #frames
    if n < 2 then
        setGhost(false)
        return
    end
    local T = frames[n].t
    local el = (tick() - ghostT0) * pSpeed
    if el >= T then
        setGhost(false)
        return
    end
    local cf = sampleCf(frames, el, true)
    if cf then showGhost(cf) else hideGhost() end
end

RunService.RenderStepped:Connect(function()
    if S.play then
        local h = hrp()
        if not h then setPlay(false)
        else
            local el = (tick() - pT0) * pSpeed
            while pIdx < #frames and frames[pIdx + 1].t <= el do pIdx = pIdx + 1 end
            local cf
            if pIdx >= #frames then
                cf = frames[#frames].cf
                if S.loop_ then
                    pT0, pIdx = tick(), 1
                    cf = frames[1].cf
                else setPlay(false) end
            else
                local a, b = frames[pIdx], frames[pIdx + 1]
                local seg = b.t - a.t
                local al = math.clamp(seg > 0 and (el - a.t) / seg or 0, 0, 1)
                cf = splineCf(pIdx, al) or a.cf:Lerp(b.cf, al)
            end
            if cf then h.CFrame = cf h.AssemblyLinearVelocity = Vector3.zero end
        end
    end

    updateGhost()

    visualTick = visualTick + 1
    if visualTick >= VISUAL_THROTTLE then
        visualTick = 0
        updatePath()
        updateHud()
        updateMap()
        updateTrimPreview()
    end
end)

folder() refreshList() local cfgOk = loadCfg()

local function colorCb(t)
    return function(c, a)
        t.r, t.g, t.b, t.a = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), a
        colorVer = colorVer + 1
    end
end

local function fullReset()
    setPlay(false)
    setRec(false)
    setGhost(false)
    frames, mapBounds, spd, spdS = {}, nil, {}, {}
    stat.dist, stat.maxV, stat.minV = 0, 0, math.huge
    clearPath()
    clearMap()
    clearLines(graphSegs)
    lastCf, lastCfT = nil, 0
    frameGaps = 0
    frameOverflow = false
    drawnCount = 0
    visualTick = 0
    trimCV = -1
    lastGraphKey, lastBarKey, lastMapKey = nil, nil, nil
    cachedText = {}
    hudShown, mapShown, trimShown = false, false, false
    hudLayoutKey = nil
    resetTrimValues()
    notify("Recorder reset", "Recorder", 2)
end

UI.AddTab("Recorder", function(tab)
    local s1 = tab:Section("Recorder", "Left")
    s1:Toggle("r_on", "Recording [R]", false, function(v) setRec(v) end)
    s1:Toggle("r_play_on", "Playing [P]", false, function(v) setPlay(v) end)
    s1:Toggle("r_loop", "Loop [L]", false, function(v) setLoop(v) end)
    s1:SliderInt("r_rate", "Sample Rate", 5, 60, rate, function(v) rate = v end)
    s1:SliderFloat("r_spd", "Playback Speed", 0.1, 5.0, pSpeed, "%.2f", function(v) pSpeed = v end)
    s1:Button("Reset", 100, 20, function() fullReset() end)

    local s2 = tab:Section("Files", "Left")
    s2:InputText("r_name", "Name", file, function(t)
        local n = t:gsub("[^%w_%-%.]", "")
        if n ~= "" then
            file = n
            local idx = 0
            for i, fn in ipairs(fileList) do if fn == file then idx = i - 1 break end end
            UI.SetValue("r_file_combo", idx)
        end
    end)
    if not fileCombo then
        fileCombo = s2:Combo("r_file_combo", "Saved Files", (#fileList > 0) and fileList or {"(empty)"}, 0, function(i)
            if #fileList == 0 then return end
            if fileList[i + 1] then file = fileList[i + 1] UI.SetValue("r_name", file) end
        end)
    end
    s2:Button("Save", 100, 20, function() save() saveCfg() notify("Saved " .. file, "Recorder", 2) end)
    s2:Button("Load", 100, 20, function()
        if load() then notify("Loaded " .. #frames .. " frames", "Recorder", 2)
        else notify("Not found", "Recorder", 2) end
    end)
    s2:Button("Refresh List", 100, 20, function() refreshList() notify("List: " .. #fileList, "Recorder", 2) end)
    s2:Button("Delete", 100, 20, function()
        local p = rpath(file)
        if isfile(p) then delfile(p) end
        refreshList() notify("Deleted " .. file, "Recorder", 2)
    end)

    local s6 = tab:Section("Config", "Left")
    s6:Button("Save Config", 120, 20, function()
        if saveCfg() then notify("Config saved", "Recorder", 2) else notify("Save failed", "Recorder", 2) end
    end)
    s6:Button("Load Config", 120, 20, function()
        if loadCfg() then syncUI() if showMap then rebuildMap() end notify("Config loaded", "Recorder", 2)
        else notify("No config", "Recorder", 2) end
    end)
    s6:Button("Reset Config", 120, 20, function()
        pSpeed, rate = 1.0, 20
        showPath, showHud, showGraph, showBar, showMap = true, true, true, true, false
        mapSize, mapX, mapY = 180, 0, 0
        hudX, hudY = 20, 20
        showTrimPreview = true
        heat, liveTrail, smoothTrail = false, false, true
        pathColor = {r = 120, g = 220, b = 180, a = 1}
        headColor = {r = 255, g = 60, b = 60, a = 1}
        tailColor = {r = 60, g = 180, b = 255, a = 1}
        trimColor = {r = 255, g = 140, b = 40, a = 0.9}
        ghostColor = {r = 255, g = 120, b = 255, a = 0.9}
        colorVer = colorVer + 1
        resetTrimValues()
        syncUI() notify("Config reset", "Recorder", 2)
    end)
    s6:Button("Delete Config", 120, 20, function()
        if isfile(cfgFile) then delfile(cfgFile) end
        notify("Config deleted", "Recorder", 2)
    end)

    local s3 = tab:Section("Path", "Right")
    s3:Toggle("r_path", "Show Trail", showPath, function(v)
        showPath = v
        if v then rebuild() end
    end)
    s3:ColorPicker("r_path_col", pathColor.r / 255, pathColor.g / 255, pathColor.b / 255, pathColor.a, colorCb(pathColor))
    s3:Toggle("r_heat", "Show Trail Speed", heat, function(v) heat = v colorVer = colorVer + 1 end)
    s3:Toggle("r_live", "Live Trail", liveTrail, function(v) liveTrail = v end)
    s3:Toggle("r_smooth", "Smooth Trail", smoothTrail, function(v) smoothTrail = v rebuild() end)
    s3:Toggle("r_ghost", "Ghost Preview [G]", false, function(v) setGhost(v) end)
    s3:ColorPicker("r_ghost_col", ghostColor.r / 255, ghostColor.g / 255, ghostColor.b / 255, ghostColor.a, colorCb(ghostColor))
    s3:Toggle("r_hud", "Show HUD", showHud, function(v) showHud = v end)
    s3:Toggle("r_graph", "Speed Graph", showGraph, function(v) showGraph = v end)
    s3:Toggle("r_bar", "Progress Bar", showBar, function(v) showBar = v end)
    s3:SliderInt("r_hud_x", "HUD X", 0, 1920, hudX, function(v) hudX = v end)
    s3:SliderInt("r_hud_y", "HUD Y", 0, 1080, hudY, function(v) hudY = v end)
    s3:Button("Rebuild", 120, 20, function() rebuild() rebuildMap() end)
    s3:Button("Clear Path", 120, 20, function() clearPath() clearMap() mapBounds = nil end)

    local s4 = tab:Section("Trim", "Left")
    s4:Toggle("r_trim_preview", "Show Trim Markers", showTrimPreview, function(v) showTrimPreview = v end)
    s4:ColorPicker("r_head_col", headColor.r / 255, headColor.g / 255, headColor.b / 255, headColor.a, colorCb(headColor))
    s4:ColorPicker("r_tail_col", tailColor.r / 255, tailColor.g / 255, tailColor.b / 255, tailColor.a, colorCb(tailColor))
    s4:ColorPicker("r_trim_col", trimColor.r / 255, trimColor.g / 255, trimColor.b / 255, trimColor.a, colorCb(trimColor))
    s4:SliderInt("r_trim_h", "Trim Head (frames)", 0, 700, 0, function(v) trimH = v end)
    s4:SliderInt("r_trim_t", "Trim Tail (frames)", 0, 700, 0, function(v) trimT = v end)
    s4:SliderFloat("r_trim_hs", "Trim Head (sec)", 0, 30, 0, "%.2f", function(v) trimHS = v end)
    s4:SliderFloat("r_trim_ts", "Trim Tail (sec)", 0, 30, 0, "%.2f", function(v) trimTS = v end)
    s4:Button("Apply Trim", 120, 20, function() applyTrim() end)
    s4:Button("Reset Trim", 120, 20, function()
        resetTrimValues()
        notify("Trim reset", "Recorder", 2)
    end)

    local s5 = tab:Section("Minimap", "Right")
    s5:Toggle("r_map", "Route Minimap", showMap, function(v) showMap = v if v then rebuildMap() end end)
    s5:SliderInt("r_map_size", "Map Size", 100, 320, mapSize, function(v) mapSize = v end)
    s5:SliderInt("r_map_x", "Map X (0=auto)", 0, 1920, mapX, function(v) mapX = v end)
    s5:SliderInt("r_map_y", "Map Y (0=auto)", 0, 1080, mapY, function(v) mapY = v end)
    s5:Button("Rebuild Map", 120, 20, function() rebuildMap() end)
end)

if cfgOk then syncUI() if showMap then rebuildMap() end end
