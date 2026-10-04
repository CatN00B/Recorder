local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
while not LP do wait(0.1) LP = Players.LocalPlayer end

local S = { rec = false, play = false, loop_ = false }
local pSpeed, rate = 1.0, 20
local file, cfgFile, recFolder = "movement_rec", "recorder_config.json", "recorder"
local showPath, showHud, showGraph, showBar, showMap = true, true, true, true, false
local mapSize, mapX, mapY = 180, 0, 0
local hudX, hudY = 20, 20
local trimH, trimT, trimHS, trimTS = 0, 0, 0, 0
local showTrimPreview = true

local pathColor = {r = 120, g = 220, b = 180, a = 1}
local headColor = {r = 255, g = 60, b = 60, a = 1}
local tailColor = {r = 60, g = 180, b = 255, a = 1}
local trimColor = {r = 255, g = 140, b = 40, a = 0.9}

local MAX_SEGS = 800
local MIN_DIST = 0.1

local frames, lines, mapSegs, graphSegs = {}, {}, {}, {}
local t0, lastS, pT0, pIdx, drawnCount = 0, 0, 0, 1, 0
local prevKeys = {}
local mapBounds, fileCombo, fileList = nil, nil, {}

local lastCf, lastCfT = nil, 0
local frameGaps = 0

local hudBg, hudBorder, hudTitle, hudRows, cachedText = nil, nil, nil, {}, {}
local graphBg, barBg, barFill, barText = nil, nil, nil, nil
local barW, barH, graphMax, graphPts = 170, 6, 10, 60
local mapBg, mapBorder, mapTitle, mapDotStart, mapDotCur, mapDotEnd = nil, nil, nil, nil, nil, nil

local trimHeadSq, trimHeadX1, trimHeadX2 = nil, nil, nil
local trimTailSq, trimTailX1, trimTailX2 = nil, nil, nil
local trimHeadMapCircle, trimTailMapSquare = nil, nil

local function c3(t) return Color3.fromRGB(t.r, t.g, t.b) end
local function lerpCf(a, b, t) return a:Lerp(b, t) end

local function hrp() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function folder() if not isfolder(recFolder) then pcall(makefolder, recFolder) end end
local function rpath(n) return recFolder .. "/" .. n .. ".json" end
local function clearLines(t)
    for _, e in ipairs(t) do pcall(function() (e.line or e):Remove() end) end
    for i = #t, 1, -1 do t[i] = nil end
end
local function clearPath() clearLines(lines) drawnCount = 0 end
local function clearMap() clearLines(mapSegs) end

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

local function addSeg(i, step)
    if i <= 1 or i > #frames then return end
    local j = math.max(1, i - step)
    local a, b = frames[j].cf.Position, frames[i].cf.Position
    if (a - b).Magnitude < MIN_DIST then return end
    local l = Drawing.new("Line")
    l.Thickness, l.ZIndex, l.Visible = 2, 500, false
    table.insert(lines, { line = l, a = a, b = b, idx = i, idxA = j })
end

local function rebuild()
    clearPath()
    if #frames < 2 then return end
    local step = stepFor(#frames)
    for i = step + 1, #frames, step do addSeg(i, step) end
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

local function initTrimMarkers()
    if not trimHeadSq then
        trimHeadSq = Drawing.new("Square")
        trimHeadSq.Filled, trimHeadSq.Thickness, trimHeadSq.ZIndex, trimHeadSq.Visible = false, 2, 520, false
    end
    if not trimHeadX1 then
        trimHeadX1 = Drawing.new("Line")
        trimHeadX1.Thickness, trimHeadX1.ZIndex, trimHeadX1.Visible = 2, 520, false
    end
    if not trimHeadX2 then
        trimHeadX2 = Drawing.new("Line")
        trimHeadX2.Thickness, trimHeadX2.ZIndex, trimHeadX2.Visible = 2, 520, false
    end
    if not trimTailSq then
        trimTailSq = Drawing.new("Square")
        trimTailSq.Filled, trimTailSq.Thickness, trimTailSq.ZIndex, trimTailSq.Visible = false, 2, 520, false
    end
    if not trimTailX1 then
        trimTailX1 = Drawing.new("Line")
        trimTailX1.Thickness, trimTailX1.ZIndex, trimTailX1.Visible = 2, 520, false
    end
    if not trimTailX2 then
        trimTailX2 = Drawing.new("Line")
        trimTailX2.Thickness, trimTailX2.ZIndex, trimTailX2.Visible = 2, 520, false
    end
    if not trimHeadMapCircle then
        trimHeadMapCircle = Drawing.new("Circle")
        trimHeadMapCircle.Filled, trimHeadMapCircle.NumSides, trimHeadMapCircle.Radius = true, 10, 5
        trimHeadMapCircle.ZIndex, trimHeadMapCircle.Visible = 907, false
    end
    if not trimTailMapSquare then
        trimTailMapSquare = Drawing.new("Square")
        trimTailMapSquare.Filled, trimTailMapSquare.ZIndex, trimTailMapSquare.Visible = true, 907, false
    end
end

initTrimMarkers()

local function computeTrimIndices()
    local n = #frames
    if n < 2 then return nil, nil end
    local headIdx = 1
    local tailIdx = n

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

local function updateTrimPreview()
    if not showTrimPreview or #frames < 2 then
        trimHeadSq.Visible, trimHeadX1.Visible, trimHeadX2.Visible = false, false, false
        trimTailSq.Visible, trimTailX1.Visible, trimTailX2.Visible = false, false, false
        trimHeadMapCircle.Visible, trimTailMapSquare.Visible = false, false
        return
    end
    local headIdx, tailIdx = computeTrimIndices()
    if not headIdx then
        trimHeadSq.Visible, trimHeadX1.Visible, trimHeadX2.Visible = false, false, false
        trimTailSq.Visible, trimTailX1.Visible, trimTailX2.Visible = false, false, false
        trimHeadMapCircle.Visible, trimTailMapSquare.Visible = false, false
        return
    end

    local hPos = frames[headIdx].cf.Position
    local tPos = frames[tailIdx].cf.Position

    trimHeadSq.Color, trimHeadSq.Transparency = c3(headColor), headColor.a
    trimHeadX1.Color, trimHeadX1.Transparency = c3(headColor), headColor.a
    trimHeadX2.Color, trimHeadX2.Transparency = c3(headColor), headColor.a
    trimTailSq.Color, trimTailSq.Transparency = c3(tailColor), tailColor.a
    trimTailX1.Color, trimTailX1.Transparency = c3(tailColor), tailColor.a
    trimTailX2.Color, trimTailX2.Transparency = c3(tailColor), tailColor.a
    trimHeadMapCircle.Color, trimHeadMapCircle.Transparency = c3(headColor), headColor.a
    trimTailMapSquare.Color, trimTailMapSquare.Transparency = c3(tailColor), tailColor.a

    local hS, hOn = WorldToScreen(hPos)
    if hOn and headIdx > 1 then
        local sz = 8
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
        local sz = 8
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
    frames, mapBounds = {}, nil
    clearPath() clearMap()
    t0, lastS = tick(), 0
    lastCf, lastCfT = nil, 0
    frameGaps = 0
end

local function stopRec()
    rebuild() rebuildMap()
end

local function startPlay()
    if #frames < 2 then return false end
    if S.play then stopPlay() end
    local h = hrp()
    if not h then return false end
    pT0, pIdx = tick(), 1
    h.CFrame = frames[1].cf
    h.AssemblyLinearVelocity = Vector3.zero
    S.play = true
    return true
end

local function setRec(v) if S.rec == v then return end S.rec = v UI.SetValue("r_on", v) if v then startRec() else stopRec() end end
local function setPlay(v)
    if S.play == v then return end
    if v then
        if not startPlay() then notify("Need 2+ frames", "Recorder", 2) return end
        S.play = true
    else S.play = false end
    UI.SetValue("r_play_on", v)
end
local function setLoop(v) if S.loop_ == v then return end S.loop_ = v UI.SetValue("r_loop", v) end

local function trimHead(n)
    if n <= 0 or n >= #frames then return 0 end
    local r = 0
    for _ = 1, n do table.remove(frames, 1) r = r + 1 end
    local off = frames[1].t
    for _, f in ipairs(frames) do f.t = f.t - off end
    rebuild() rebuildMap()
    return r
end

local function trimTail(n)
    if n <= 0 or n >= #frames then return 0 end
    local r = 0
    for _ = 1, n do table.remove(frames) r = r + 1 end
    rebuild() rebuildMap()
    return r
end

local function trimSecHead(sec)
    if sec <= 0 or #frames < 2 then return 0 end
    local cut = frames[1].t + sec
    local r = 0
    while #frames > 1 and frames[1].t < cut do table.remove(frames, 1) r = r + 1 end
    local off = frames[1].t
    for _, f in ipairs(frames) do f.t = f.t - off end
    rebuild() rebuildMap()
    return r
end

local function trimSecTail(sec)
    if sec <= 0 or #frames < 2 then return 0 end
    local cut = frames[#frames].t - sec
    local r = 0
    while #frames > 1 and frames[#frames].t > cut do table.remove(frames) r = r + 1 end
    rebuild() rebuildMap()
    return r
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
    frames = {}
    for i, f in ipairs(data.frames) do
        if f.p and f.l then
            local pos = Vector3.new(f.p[1], f.p[2], f.p[3])
            local lv = Vector3.new(f.l[1], f.l[2], f.l[3])
            local cf = lv.Magnitude > 0.001 and CFrame.lookAt(pos, pos + lv) or CFrame.new(pos)
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
        trimH = trimH, trimT = trimT, trimHS = trimHS, trimTS = trimTS,
        showTrimPreview = showTrimPreview,
        pathColor = pathColor, headColor = headColor, tailColor = tailColor, trimColor = trimColor,
    }
    return pcall(writefile, cfgFile, HttpService:JSONEncode(out))
end

local function readColor(v, fb)
    if type(v) ~= "table" then return fb end
    local r = type(v.r) == "number" and v.r or fb.r
    local g = type(v.g) == "number" and v.g or fb.g
    local b = type(v.b) == "number" and v.b or fb.b
    local a = type(v.a) == "number" and v.a or fb.a
    return {r = r, g = g, b = b, a = a}
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
    trimH, trimT, trimHS, trimTS = n(d.trimH, trimH), n(d.trimT, trimT), n(d.trimHS, trimHS), n(d.trimTS, trimTS)
    showTrimPreview = b(d.showTrimPreview, showTrimPreview)
    pathColor = readColor(d.pathColor, pathColor)
    headColor = readColor(d.headColor, headColor)
    tailColor = readColor(d.tailColor, tailColor)
    trimColor = readColor(d.trimColor, trimColor)
    return true
end

local function syncUI()
    for _, kv in ipairs({
        {"r_rate", rate}, {"r_spd", pSpeed}, {"r_path", showPath}, {"r_hud", showHud},
        {"r_graph", showGraph}, {"r_bar", showBar}, {"r_hud_x", hudX}, {"r_hud_y", hudY},
        {"r_map", showMap}, {"r_map_size", mapSize}, {"r_map_x", mapX}, {"r_map_y", mapY},
        {"r_name", file}, {"r_trim_preview", showTrimPreview},
        {"r_trim_h", trimH}, {"r_trim_t", trimT}, {"r_trim_hs", trimHS}, {"r_trim_ts", trimTS},
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
    mapDotStart = Drawing.new("Circle")
    mapDotStart.Filled, mapDotStart.NumSides, mapDotStart.Radius = true, 12, 4
    mapDotStart.Transparency, mapDotStart.ZIndex, mapDotStart.Visible = 1, 904, false
    mapDotEnd = Drawing.new("Circle")
    mapDotEnd.Filled, mapDotEnd.NumSides, mapDotEnd.Radius = true, 12, 4
    mapDotEnd.Transparency, mapDotEnd.ZIndex, mapDotEnd.Visible = 1, 904, false
    mapDotCur = Drawing.new("Circle")
    mapDotCur.Filled, mapDotCur.NumSides, mapDotCur.Radius = true, 14, 4.5
    mapDotCur.Color, mapDotCur.Transparency, mapDotCur.ZIndex, mapDotCur.Visible = Color3.fromRGB(255, 255, 255), 1, 905, false
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
    else
        prevKeys.R, prevKeys.P, prevKeys.L = keyDown(0x52), keyDown(0x50), keyDown(0x4C)
    end

    if not S.rec or S.play then return end
    local h = hrp()
    if not h then return end
    local now = tick()

    local interval = 1 / rate
    local cfNow = h.CFrame

    if not lastCf then
        lastCf, lastCfT = cfNow, now
        lastS = now
        table.insert(frames, { t = now - t0, cf = cfNow })
        drawnCount = #frames
        return
    end

    local elapsed = now - lastCfT
    if elapsed < interval then return end

    local steps = math.floor(elapsed / interval)
    if steps <= 0 then return end

    for k = 1, steps do
        local alpha = (k * interval) / elapsed
        if alpha > 1 then alpha = 1 end
        local interp = lerpCf(lastCf, cfNow, alpha)
        local sampleT = lastCfT + k * interval - t0
        table.insert(frames, { t = sampleT, cf = interp })
    end

    if steps >= 2 then frameGaps = frameGaps + (steps - 1) end

    lastCf, lastCfT = cfNow, now
    lastS = now

    if #frames - drawnCount >= 3 then
        for i = drawnCount + 1, #frames do addSeg(i, 1) end
        drawnCount = #frames
        if showMap then rebuildMap() end
    end
end)

local function speeds()
    local n = #frames
    if n < 2 then return {}, 0 end
    local out, mx = {}, 0.001
    for i = 2, n do
        local dt = frames[i].t - frames[i - 1].t
        if dt <= 0 then dt = 1 / rate end
        local v = (frames[i].cf.Position - frames[i - 1].cf.Position).Magnitude / dt
        out[i] = v
        if v > mx then mx = v end
    end
    return out, mx
end

local function updatePath()
    if not showPath or #lines == 0 then
        for _, e in ipairs(lines) do e.line.Visible = false end
        return
    end

    local headIdx, tailIdx = nil, nil
    if showTrimPreview then headIdx, tailIdx = computeTrimIndices() end

    local pc = c3(pathColor)
    local pt = pathColor.a
    local tc = c3(trimColor)
    local tt = trimColor.a

    for _, e in ipairs(lines) do
        local a2, aOn = WorldToScreen(e.a)
        local b2, bOn = WorldToScreen(e.b)
        local inTrim = headIdx and (e.idx <= headIdx or e.idxA > tailIdx)
        if aOn and bOn then
            if e.lastA ~= a2 or e.lastB ~= b2 or not e.on then
                e.line.From, e.line.To, e.line.Visible = a2, b2, true
                e.lastA, e.lastB, e.on = a2, b2, true
            end
            if inTrim then
                e.line.Color, e.line.Transparency = tc, tt
            else
                e.line.Color, e.line.Transparency = pc, pt
            end
        elseif e.on ~= false then
            e.line.Visible, e.on = false, false
        end
    end
end

local function updateHud()
    if not showHud then
        hudBg.Visible, hudBorder.Visible, hudTitle.Visible = false, false, false
        for _, t in ipairs(hudRows) do t.Visible = false end
        graphBg.Visible = false
        for _, s in ipairs(graphSegs) do s.Visible = false end
        barBg.Visible, barFill.Visible, barText.Visible = false, false, false
        return
    end
    local fStr = "Frames: " .. #frames
    local rateStr
    if S.rec and #frames > 1 then
        local span = frames[#frames].t - frames[1].t
        if span > 0 then
            rateStr = string.format("Eff: %.1f Hz  gaps: %d", (#frames - 1) / span, frameGaps)
        else
            rateStr = "Eff: --"
        end
    else
        rateStr = "Eff: --"
    end
    if cachedText.frames ~= fStr then hudRows[4].Text = fStr cachedText.frames = fStr end
    if cachedText.rate ~= rateStr then hudRows[5].Text = rateStr cachedText.rate = rateStr end

    local padX, padY, rowH, w = 10, 8, 18, 230
    local gH = showGraph and 40 or 0
    local bH = showBar and 26 or 0
    local h = padY * 2 + 20 + rowH * 5 + gH + bH

    hudBg.Position, hudBg.Size = Vector2.new(hudX, hudY), Vector2.new(w, h)
    hudBg.Visible = true
    hudBorder.Position, hudBorder.Size = Vector2.new(hudX, hudY), Vector2.new(w, h)
    hudBorder.Color = S.rec and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(120, 220, 180)
    hudBorder.Visible = true
    hudTitle.Position = Vector2.new(hudX + padX, hudY + padY)
    hudTitle.Visible = true

    local rows = {
        { l = "[R]", n = "Recording", on = S.rec },
        { l = "[P]", n = "Playing", on = S.play },
        { l = "[L]", n = "Loop", on = S.loop_ },
    }
    for i = 1, 3 do
        local r = rows[i]
        local t = hudRows[i]
        local txt = string.format("%-4s %s", r.l, r.n)
        if cachedText[i] ~= txt then t.Text = txt cachedText[i] = txt end
        t.Position = Vector2.new(hudX + padX, hudY + padY + 20 + (i - 1) * rowH)
        t.Color = r.on and Color3.fromRGB(150, 255, 190) or Color3.fromRGB(120, 120, 130)
        t.Visible = true
    end
    local t4 = hudRows[4]
    t4.Position = Vector2.new(hudX + padX, hudY + padY + 20 + 3 * rowH)
    t4.Color = #frames > 0 and Color3.fromRGB(150, 255, 190) or Color3.fromRGB(120, 120, 130)
    t4.Visible = true
    local t5 = hudRows[5]
    t5.Position = Vector2.new(hudX + padX, hudY + padY + 20 + 4 * rowH)
    t5.Color = frameGaps > 0 and Color3.fromRGB(255, 180, 90) or Color3.fromRGB(150, 255, 190)
    t5.Visible = true    local cy = hudY + padY + 20 + rowH * 5
    if showGraph then
        local gx, gy, gw, gh = hudX + padX, cy, w - padX * 2, gH - 6
        graphBg.Position, graphBg.Size, graphBg.Visible = Vector2.new(gx, gy), Vector2.new(gw, gh), true
        local sp, mx = speeds()
        local total = #frames
        if total >= 2 then
            graphMax = math.max(10, math.ceil(mx / 10) * 10)
            local count = math.min(graphPts, total - 1)
            local start = math.max(2, total - count + 1)
            local pts = {}
            for k = 0, count - 1 do
                local i = start + k
                if i > total then break end
                table.insert(pts, { gx + gw * (k / math.max(1, count - 1)), gy + gh - ((sp[i] or 0) / graphMax) * gh })
            end
            local need = #pts - 1
            while #graphSegs < need do
                local l = Drawing.new("Line")
                l.Thickness, l.ZIndex, l.Visible = 1, 903, false
                table.insert(graphSegs, l)
            end
            for i = 1, need do
                local seg = graphSegs[i]
                seg.From, seg.To, seg.Visible = Vector2.new(pts[i][1], pts[i][2]), Vector2.new(pts[i + 1][1], pts[i + 1][2]), true
                seg.Color, seg.Transparency = c3(pathColor), pathColor.a * 0.9
            end
            for i = need + 1, #graphSegs do graphSegs[i].Visible = false end
        else
            for _, s in ipairs(graphSegs) do s.Visible = false end
        end
        cy = cy + gH
    else
        graphBg.Visible = false
        for _, s in ipairs(graphSegs) do s.Visible = false end
    end

    if showBar then
        local bx, by = hudX + padX, cy + 4
        local total, progress = #frames, 0
        local label
        if S.play and total >= 2 then
            local curT = (tick() - pT0) * pSpeed
            local lastT = frames[total].t
            if lastT > 0 then progress = math.clamp(curT / lastT, 0, 1) end
            label = string.format("Play %d%%  %d/%d", math.floor(progress * 100 + 0.5), math.min(pIdx, total), total)
        elseif S.rec and total >= 1 then
            label = string.format("Rec %.1fs  %d frames", tick() - t0, total)
        else
            label = string.format("Idle  %d frames", total)
        end
        barBg.Position, barBg.Size, barBg.Visible = Vector2.new(bx, by), Vector2.new(barW, barH), true
        barFill.Position, barFill.Size = Vector2.new(bx, by), Vector2.new(barW * progress, barH)
        barFill.Color = S.play and c3(pathColor) or (S.rec and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(80, 80, 90))
        barFill.Visible = true
        barText.Text = label
        barText.Position = Vector2.new(bx, by + barH + 2)
        barText.Visible = true
    else
        barBg.Visible, barFill.Visible, barText.Visible = false, false, false
    end
end

local function updateMap()
    if not showMap or not mapBounds or #frames < 2 then
        mapBg.Visible, mapBorder.Visible, mapTitle.Visible = false, false, false
        mapDotStart.Visible, mapDotEnd.Visible, mapDotCur.Visible = false, false, false
        for _, s in ipairs(mapSegs) do s.line.Visible = false end
        return
    end
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    local mx = mapX == 0 and (vp.X - mapSize) / 2 or mapX
    local my = mapY == 0 and 20 or mapY
    local pad, inner = 6, mapSize - 12

    mapBg.Position, mapBg.Size, mapBg.Visible = Vector2.new(mx, my), Vector2.new(mapSize, mapSize), true
    mapBorder.Position, mapBorder.Size, mapBorder.Visible = Vector2.new(mx, my), Vector2.new(mapSize, mapSize), true
    mapTitle.Position, mapTitle.Visible = Vector2.new(mx + pad, my + pad), true

    local headIdx, tailIdx = nil, nil
    if showTrimPreview then headIdx, tailIdx = computeTrimIndices() end

    local pc = c3(pathColor)
    local pt = pathColor.a
    local tc = c3(trimColor)
    local tt = trimColor.a

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
            if inTrim then
                l.line.Color, l.line.Transparency = tc, tt * 0.7
            else
                l.line.Color, l.line.Transparency = pc, pt * 0.7
            end
            l.line.Visible = true
        else l.line.Visible = false end
    end
    for i = idx + 1, #mapSegs do mapSegs[i].line.Visible = false end

    local sx, sz = toMap(frames[1].cf.Position)
    if sx then mapDotStart.Position = Vector2.new(mx + pad + sx * inner, my + pad + sz * inner) mapDotStart.Visible = true end
    local ex, ez = toMap(frames[#frames].cf.Position)
    if ex then mapDotEnd.Position = Vector2.new(mx + pad + ex * inner, my + pad + ez * inner) mapDotEnd.Visible = true end
    local cur = frames[math.min(pIdx, #frames)] or frames[1]
    local cx, cz = toMap(cur.cf.Position)
    if cx then mapDotCur.Position = Vector2.new(mx + pad + cx * inner, my + pad + cz * inner) mapDotCur.Visible = true end
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
                cf = a.cf:Lerp(b.cf, al)
            end
            if cf then h.CFrame = cf h.AssemblyLinearVelocity = Vector3.zero end
        end
    end
    updatePath()
    updateHud()
    updateMap()
    updateTrimPreview()
end)

folder() refreshList() local cfgOk = loadCfg()

UI.AddTab("Recorder", function(tab)
    local s1 = tab:Section("Recorder", "Left")
    s1:Toggle("r_on", "Recording [R]", false, function(v) setRec(v) end)
    s1:Toggle("r_play_on", "Playing [P]", false, function(v) setPlay(v) end)
    s1:Toggle("r_loop", "Loop [L]", false, function(v) setLoop(v) end)
    s1:SliderInt("r_rate", "Sample Rate", 5, 60, rate, function(v) rate = v end)
    s1:SliderFloat("r_spd", "Playback Speed", 0.1, 5.0, pSpeed, "%.2f", function(v) pSpeed = v end)
    s1:Button("Clear", 100, 20, function()
        setPlay(false) frames, mapBounds = {}, nil
        clearPath() clearMap()
        lastCf, lastCfT = nil, 0
        frameGaps = 0
    end)

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

    local s3 = tab:Section("Path", "Right")
    s3:Toggle("r_path", "Show Path", showPath, function(v)
        showPath = v
        if v then rebuild() end
    end)
    s3:ColorPicker("r_path_col", pathColor.r/255, pathColor.g/255, pathColor.b/255, pathColor.a, function(c, a)
        pathColor.r, pathColor.g, pathColor.b, pathColor.a = math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5), a
    end)
    s3:Toggle("r_hud", "Show HUD", showHud, function(v) showHud = v end)
    s3:Toggle("r_graph", "Speed Graph", showGraph, function(v) showGraph = v end)
    s3:Toggle("r_bar", "Progress Bar", showBar, function(v) showBar = v end)
    s3:SliderInt("r_hud_x", "HUD X", 0, 1920, hudX, function(v) hudX = v end)
    s3:SliderInt("r_hud_y", "HUD Y", 0, 1080, hudY, function(v) hudY = v end)
    s3:Button("Rebuild", 120, 20, function() rebuild() rebuildMap() end)
    s3:Button("Clear Path", 120, 20, function() clearPath() clearMap() mapBounds = nil end)

    local s4 = tab:Section("Trim", "Left")
    s4:Toggle("r_trim_preview", "Show Trim Markers", showTrimPreview, function(v) showTrimPreview = v end)
    s4:ColorPicker("r_head_col", headColor.r/255, headColor.g/255, headColor.b/255, headColor.a, function(c, a)
        headColor.r, headColor.g, headColor.b, headColor.a = math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5), a
    end)
    s4:ColorPicker("r_tail_col", tailColor.r/255, tailColor.g/255, tailColor.b/255, tailColor.a, function(c, a)
        tailColor.r, tailColor.g, tailColor.b, tailColor.a = math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5), a
    end)
    s4:ColorPicker("r_trim_col", trimColor.r/255, trimColor.g/255, trimColor.b/255, trimColor.a, function(c, a)
        trimColor.r, trimColor.g, trimColor.b, trimColor.a = math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5), a
    end)
    s4:SliderInt("r_trim_h", "Trim Head (frames)", 0, 700, trimH, function(v) trimH = v end)
    s4:SliderInt("r_trim_t", "Trim Tail (frames)", 0, 700, trimT, function(v) trimT = v end)
    s4:SliderFloat("r_trim_hs", "Trim Head (sec)", 0, 30, trimHS, "%.2f", function(v) trimHS = v end)
    s4:SliderFloat("r_trim_ts", "Trim Tail (sec)", 0, 30, trimTS, "%.2f", function(v) trimTS = v end)
    s4:Button("Apply Trim", 120, 20, function()
        if #frames < 3 then notify("Not enough frames", "Recorder", 2) return end
        local n0 = #frames
        if trimHS > 0 then trimSecHead(trimHS) end
        if trimTS > 0 then trimSecTail(trimTS) end
        if trimH > 0 and #frames > trimT + 1 then trimHead(trimH) end
        if trimT > 0 and #frames > 1 then trimTail(trimT) end
        notify(string.format("Trim: %d -> %d", n0, #frames), "Recorder", 2)
    end)
    s4:Button("Reset Trim", 120, 20, function()
        trimH, trimT, trimHS, trimTS = 0, 0, 0, 0
        syncUI() notify("Trim reset", "Recorder", 2)
    end)

    local s5 = tab:Section("Minimap", "Right")
    s5:Toggle("r_map", "Route Minimap", showMap, function(v) showMap = v if v then rebuildMap() end end)
    s5:SliderInt("r_map_size", "Map Size", 100, 320, mapSize, function(v) mapSize = v end)
    s5:SliderInt("r_map_x", "Map X (0=auto)", 0, 1920, mapX, function(v) mapX = v end)
    s5:SliderInt("r_map_y", "Map Y (0=auto)", 0, 1080, mapY, function(v) mapY = v end)
    s5:Button("Rebuild Map", 120, 20, function() rebuildMap() end)

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
        trimH, trimT, trimHS, trimTS = 0, 0, 0, 0
        showTrimPreview = true
        pathColor = {r = 120, g = 220, b = 180, a = 1}
        headColor = {r = 255, g = 60, b = 60, a = 1}
        tailColor = {r = 60, g = 180, b = 255, a = 1}
        trimColor = {r = 255, g = 140, b = 40, a = 0.9}
        syncUI() notify("Config reset", "Recorder", 2)
    end)
    s6:Button("Delete Config", 120, 20, function()
        if isfile(cfgFile) then delfile(cfgFile) end
        notify("Config deleted", "Recorder", 2)
    end)
end)

if cfgOk then syncUI() if showMap then rebuildMap() end end