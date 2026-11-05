--[[
    QOL HUD | spotify + monitor performance

    F6           = next theme
    F7           = show/hide album image
    RightControl = show/hide hud
    [ = last | ] = next | \ = play/pause

    position, theme and album stay @ QOLHudSettings.json
    (your executor will need readfile/writefile). the album image needs writefile + getcustomasset

    getgenv().QOL_HUD() -> to remove
]]

local CONFIG = {
    CLIENT_ID     = "[redacted]",
    CLIENT_SECRET = "[redacted]",
    REFRESH_TOKEN = "[redacted]",
    POLL_INTERVAL = 3,

    THEME    = "minimal",  -- "minimal", "simple" or "modern"
    SHOW_ART = true,       -- album image (F7 turns on or off)

    -- initial position
    POSITION = UDim2.new(0.5, -250, 0, 16),

    ACCENT    = Color3.fromRGB(30, 215, 96),   -- green spotify 
    GS_ACCENT = Color3.fromRGB(159, 202, 43),  -- green gamesense
    TEXT      = Color3.fromRGB(235, 237, 242),
    DIM       = Color3.fromRGB(137, 143, 154),
    ICON      = "♪",
    MAX_TITLE = 38,
    BAR_BACKGROUND = Color3.fromRGB(65, 69, 78),

    SHOW = { ping = true, fps = true, frame = true, mem = false },

    KEY_TOGGLE = Enum.KeyCode.RightControl,
    KEY_PREV   = Enum.KeyCode.LeftBracket,
    KEY_NEXT   = Enum.KeyCode.RightBracket,
    KEY_PLAY   = Enum.KeyCode.BackSlash,
    KEY_THEME  = Enum.KeyCode.F6,
    KEY_ART    = Enum.KeyCode.F7,
}

-- setup --

local RunService  = game:GetService("RunService")
local Stats       = game:GetService("Stats")
local UIS         = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local env = (getgenv and getgenv()) or _G
if env.QOL_HUD then pcall(env.QOL_HUD) end

local requestFn = request or http_request or (syn and syn.request) or (http and http.request)
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
local canArt    = (requestFn and writefile and getcustomasset) ~= nil
local conns, alive = {}, true

local SETTINGS_FILE = "QOLHudSettings.json"
local THEME_ORDER = { "minimal", "simple", "modern" }
local THEME_NAMES = { minimal = "MIN", simple = "SIMPLE", modern = "GS" }

-- saved state. x/y r always in coords of Position --
local state = { x = nil, y = nil, theme = CONFIG.THEME, art = CONFIG.SHOW_ART }
if not THEME_NAMES[state.theme] then state.theme = "minimal" end

if readfile then
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(SETTINGS_FILE))
    end)
    if ok and type(data) == "table" then
        if THEME_NAMES[data.theme] then state.theme = data.theme end
        if type(data.art) == "boolean" then state.art = data.art end
        if type(data.x) == "number" and type(data.y) == "number" then
            state.x, state.y = data.x, data.y
        end
    end
end

local function saveSettings()
    if not writefile or not state.x or not state.y then return end
    pcall(function()
        writefile(SETTINGS_FILE, HttpService:JSONEncode({
            x = math.floor(state.x + 0.5),
            y = math.floor(state.y + 0.5),
            theme = state.theme,
            art = state.art,
        }))
    end)
end

local function b64(data)
    local fn = (crypt and crypt.base64encode) or base64encode or base64_encode
    if fn then return fn(data) end
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return ((data:gsub(".", function(x)
        local r, b = "", x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
        return r
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
        if #x < 6 then return "" end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
        return chars:sub(c + 1, c + 1)
    end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

-- ui --

local BLACK = Color3.new(0, 0, 0)

local gui = Instance.new("ScreenGui")
gui.Name = "QOLHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent

local holder = Instance.new("Frame")
holder.Name = "HUD"
holder.BorderSizePixel = 0
holder.Active = true
holder.Size = UDim2.fromOffset(500, 58)
holder.Parent = gui

local holderCorner = Instance.new("UICorner")
holderCorner.Parent = holder

local holderStroke = Instance.new("UIStroke")
holderStroke.Thickness = 1
holderStroke.Transparency = 1
holderStroke.Parent = holder

local mBorder = Instance.new("Frame")
mBorder.Name = "GSBorder"
mBorder.BorderSizePixel = 0
mBorder.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
mBorder.Position = UDim2.fromOffset(1, 1)
mBorder.Size = UDim2.new(1, -2, 1, -2)
mBorder.ZIndex = 1
mBorder.Visible = false
mBorder.Parent = holder

local mInner = Instance.new("Frame")
mInner.Name = "GSInner"
mInner.BorderSizePixel = 0
mInner.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
mInner.Position = UDim2.fromOffset(2, 2)
mInner.Size = UDim2.new(1, -4, 1, -4)
mInner.ZIndex = 2
mInner.Visible = false
mInner.Parent = holder

local topLine = Instance.new("Frame")
topLine.Name = "GSGradient"
topLine.BorderSizePixel = 0
topLine.BackgroundColor3 = Color3.new(1, 1, 1)
topLine.Position = UDim2.fromOffset(2, 2)
topLine.Size = UDim2.new(1, -4, 0, 2)
topLine.ZIndex = 3
topLine.Visible = false
topLine.Parent = holder

local topGradient = Instance.new("UIGradient")
topGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(59, 175, 222)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(202, 70, 205)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(201, 227, 58)),
})
topGradient.Parent = topLine

-- album image --
local art = Instance.new("ImageLabel")
art.Name = "Art"
art.BorderSizePixel = 0
art.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
art.Image = ""
art.ScaleType = Enum.ScaleType.Crop
art.ZIndex = 5
art.Active = true
art.Visible = false
art.Parent = holder

local artCorner = Instance.new("UICorner")
artCorner.CornerRadius = UDim.new(0, 4)
artCorner.Parent = art

local artStroke = Instance.new("UIStroke")
artStroke.Thickness = 1
artStroke.Color = Color3.fromRGB(60, 60, 60)
artStroke.Transparency = 1
artStroke.Parent = art

local function makeLabel(name)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.BackgroundTransparency = 1
    l.TextColor3 = CONFIG.TEXT
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.TextStrokeColor3 = BLACK
    l.RichText = true
    l.TextWrapped = false
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Text = ""
    l.ZIndex = 5
    l.Active = true
    l.Parent = holder
    return l
end
local statsLabel = makeLabel("Stats")
local musicLabel = makeLabel("Music")

local barBack = Instance.new("Frame")
barBack.Name = "ProgressBackground"
barBack.BorderSizePixel = 0
barBack.BackgroundColor3 = CONFIG.BAR_BACKGROUND
barBack.ZIndex = 5
barBack.Active = true
barBack.Visible = false
barBack.Parent = holder

local barBackCorner = Instance.new("UICorner")
barBackCorner.CornerRadius = UDim.new(1, 0)
barBackCorner.Parent = barBack

local barStroke = Instance.new("UIStroke")
barStroke.Thickness = 1
barStroke.Color = BLACK
barStroke.Transparency = 1
barStroke.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Name = "Progress"
barFill.BorderSizePixel = 0
barFill.BackgroundColor3 = CONFIG.ACCENT
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.ZIndex = 6
barFill.Parent = barBack

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(1, 0)
barFillCorner.Parent = barFill

local themeButton = Instance.new("TextButton")
themeButton.Name = "ThemeSelector"
themeButton.AutoButtonColor = false
themeButton.BorderSizePixel = 0
themeButton.Font = Enum.Font.Code
themeButton.TextSize = 10
themeButton.Text = "MIN"
themeButton.ZIndex = 7
themeButton.Parent = holder

local themeButtonCorner = Instance.new("UICorner")
themeButtonCorner.CornerRadius = UDim.new(0, 3)
themeButtonCorner.Parent = themeButton

local artButton = Instance.new("TextButton")
artButton.Name = "ArtToggle"
artButton.AutoButtonColor = false
artButton.BorderSizePixel = 0
artButton.Font = Enum.Font.Code
artButton.TextSize = 10
artButton.Text = "ART"
artButton.ZIndex = 7
artButton.Visible = false
artButton.Parent = holder

local artButtonCorner = Instance.new("UICorner")
artButtonCorner.CornerRadius = UDim.new(0, 3)
artButtonCorner.Parent = artButton

-- position --

local holderSize = Vector2.new(500, 58)

local function screenSize()
    local s = gui.AbsoluteSize
    if s.X > 0 and s.Y > 0 then return s end
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

local function setPos(x, y)
    local s = screenSize()
    state.x = math.clamp(x, 0, math.max(0, s.X - holderSize.X))
    state.y = math.clamp(y, 0, math.max(0, s.Y - holderSize.Y))
    holder.Position = UDim2.fromOffset(state.x, state.y)
end

local function artEnabled()
    return state.art and canArt
end

-- helpers --

local function paint(value, color)
    return string.format('<font color="#%s">%s</font>', color:ToHex(), value)
end
local function esc(value)
    return (tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function trunc(value, n)
    value = tostring(value or "")
    local len = utf8.len(value)
    if len and len > n then
        local cut = utf8.offset(value, n + 1) or (#value + 1)
        return value:sub(1, cut - 1) .. "..."
    end
    return value
end
local function fmt(ms)
    local s = math.floor(ms / 1000)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local GOOD, MID, BAD = Color3.fromRGB(90, 225, 130), Color3.fromRGB(250, 205, 80), Color3.fromRGB(240, 90, 90)
local function lowIsGood(v, a, b) return v <= a and GOOD or (v <= b and MID or BAD) end
local function highIsGood(v, a, b) return v >= a and GOOD or (v >= b and MID or BAD) end

local function accentColor()
    return state.theme == "modern" and CONFIG.GS_ACCENT or CONFIG.ACCENT
end

-- spotify --

local hasCreds = requestFn
    and CONFIG.CLIENT_ID ~= "" and CONFIG.CLIENT_SECRET ~= "" and CONFIG.REFRESH_TOKEN ~= ""

local token, tokenExpiry = nil, 0
local sp = { id = nil, title = "", artist = "", imageUrl = nil, playing = false, progress = 0, duration = 0, sync = 0 }

local artFile = nil
local function clearArtFile()
    if artFile and delfile then pcall(delfile, artFile) end
    artFile = nil
end

local function loadArt()
    art.Image = ""
    if not (artEnabled() and sp.id and sp.imageUrl) then return end

    local trackId, url = sp.id, sp.imageUrl
    task.spawn(function()
        local ok, res = pcall(requestFn, { Url = url, Method = "GET" })
        if not (ok and res and res.StatusCode == 200 and res.Body) then return end
        if sp.id ~= trackId or not artEnabled() then return end

        local path = "qolhud_art_" .. trackId .. ".jpg"
        if not pcall(writefile, path, res.Body) then return end

        local okAsset, asset = pcall(getcustomasset, path)
        if okAsset and sp.id == trackId then
            art.Image = asset
            local old = artFile
            artFile = path
            if old and old ~= path and delfile then pcall(delfile, old) end
        elseif delfile then
            pcall(delfile, path)
        end
    end)
end

local function refreshToken()
    local response = requestFn({
        Url = "https://accounts.spotify.com/api/token",
        Method = "POST",
        Headers = {
            ["Authorization"] = "Basic " .. b64(CONFIG.CLIENT_ID .. ":" .. CONFIG.CLIENT_SECRET),
            ["Content-Type"] = "application/x-www-form-urlencoded",
        },
        Body = "grant_type=refresh_token&refresh_token=" .. HttpService:UrlEncode(CONFIG.REFRESH_TOKEN),
    })
    if response and response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)
        token = data.access_token
        tokenExpiry = os.clock() + (data.expires_in or 3600) - 60
    else
        token = nil
    end
end

local function spotifyRequest(method, path)
    if not hasCreds then return nil end
    if not token or os.clock() >= tokenExpiry then refreshToken() end
    if not token then return nil end
    return requestFn({
        Url = "https://api.spotify.com/v1" .. path,
        Method = method,
        Headers = { ["Authorization"] = "Bearer " .. token, ["Content-Type"] = "application/json" },
        Body = (method ~= "GET") and "" or nil,
    })
end

local function poll()
    local response = spotifyRequest("GET", "/me/player/currently-playing")
    if not response then return end

    if response.StatusCode == 200 and response.Body ~= "" then
        local data = HttpService:JSONDecode(response.Body)
        local item = data.item
        if not item then
            sp.id, sp.playing = nil, false
            return
        end

        local artists = {}
        for _, a in ipairs(item.artists or {}) do artists[#artists + 1] = a.name end

        local images = item.album and item.album.images
        local image = images and (images[2] or images[1])

        local changed = item.id ~= sp.id
        sp.id = item.id
        sp.title = item.name or "?"
        sp.artist = table.concat(artists, ", ")
        sp.imageUrl = image and image.url or nil
        sp.playing = data.is_playing
        sp.progress = data.progress_ms or 0
        sp.duration = item.duration_ms or 0
        sp.sync = os.clock()

        if changed then loadArt() end

    elseif response.StatusCode == 204 then
        sp.id, sp.playing, sp.progress, sp.duration = nil, false, 0, 0
        art.Image = ""
    elseif response.StatusCode == 401 then
        token = nil
    elseif response.StatusCode == 429 then
        task.wait(10)
    end
end

local function control(method, path)
    task.spawn(function()
        pcall(spotifyRequest, method, path)
        task.wait(0.4)
        pcall(poll)
    end)
end

if hasCreds then
    task.spawn(function()
        while alive do
            pcall(poll)
            task.wait(CONFIG.POLL_INTERVAL)
        end
    end)
end

-- render --

local stat = { ping = nil, fps = 0, frame = 0, mem = nil }

local function currentProgress()
    if not sp.id or sp.duration <= 0 then return 0 end
    local p = sp.progress
    if sp.playing then p = p + (os.clock() - sp.sync) * 1000 end
    return math.clamp(p, 0, sp.duration)
end

local function renderStats()
    local theme = state.theme
    local sep
    if theme == "minimal" then
        sep = paint("  ·  ", CONFIG.DIM)
    elseif theme == "simple" then
        sep = "    "
    else
        sep = paint("  |  ", Color3.fromRGB(85, 85, 85))
    end

    local parts = {}
    if theme == "modern" then
        parts[#parts + 1] = paint("<b>qol</b>", Color3.new(1, 1, 1)) .. paint("<b>hud</b>", CONFIG.GS_ACCENT)
    end
    if CONFIG.SHOW.ping and stat.ping then
        parts[#parts + 1] = paint(tostring(math.floor(stat.ping + 0.5)), lowIsGood(stat.ping, 80, 150)) .. paint(" ms", CONFIG.DIM)
    end
    if CONFIG.SHOW.fps then
        parts[#parts + 1] = paint(tostring(math.floor(stat.fps + 0.5)), highIsGood(stat.fps, 55, 30)) .. paint(" fps", CONFIG.DIM)
    end
    if CONFIG.SHOW.frame then
        parts[#parts + 1] = paint(string.format("%.1f", stat.frame), lowIsGood(stat.frame, 18, 33)) .. paint(" ms frame", CONFIG.DIM)
    end
    if CONFIG.SHOW.mem and stat.mem then
        parts[#parts + 1] = paint(tostring(math.floor(stat.mem + 0.5)), CONFIG.TEXT) .. paint(" MB", CONFIG.DIM)
    end

    statsLabel.Text = table.concat(parts, sep)
end

local function renderMusic()
    if not hasCreds then
        musicLabel.Text = ""
        return
    end
    if not sp.id then
        musicLabel.Text = paint(CONFIG.ICON .. " nada tocando", CONFIG.DIM)
        return
    end

    musicLabel.Text = paint(CONFIG.ICON, accentColor()) .. " "
        .. paint(esc(trunc(sp.title, CONFIG.MAX_TITLE)), CONFIG.TEXT)
        .. paint(" — " .. esc(trunc(sp.artist, 24)), CONFIG.DIM)
        .. "   " .. paint(fmt(currentProgress()) .. " / " .. fmt(sp.duration), CONFIG.DIM)
        .. (sp.playing and "" or paint("   PAUSADO", Color3.fromRGB(225, 185, 95)))
end

local function render()
    renderStats()
    renderMusic()
end

-- layout per theme --

local function place(obj, x, y, w, h)
    obj.Position = UDim2.fromOffset(x, y)
    obj.Size = UDim2.fromOffset(w, h)
end

local function styleText(font, size, strokeTransparency, align)
    for _, l in ipairs({ statsLabel, musicLabel }) do
        l.Font = font
        l.TextSize = size
        l.TextStrokeTransparency = strokeTransparency
        l.TextXAlignment = align
    end
end

local function applyLayout()
    local theme = state.theme
    local showArt = artEnabled()
    local modern = theme == "modern"
    local w, h

    art.Visible = showArt
    mBorder.Visible = modern
    mInner.Visible = modern
    topLine.Visible = modern
    themeButton.Text = THEME_NAMES[theme]
    artButton.Visible = canArt
    artButton.TextColor3 = state.art and accentColor() or Color3.fromRGB(95, 95, 95)
    artButtonCorner.CornerRadius = modern and UDim.new(0, 0) or UDim.new(0, 3)

    -- Estilos que mudam entre "GS" e os demais
    barBack.BackgroundColor3 = modern and Color3.fromRGB(32, 32, 32) or CONFIG.BAR_BACKGROUND
    barBack.BackgroundTransparency = modern and 0 or 0.1
    barStroke.Transparency = modern and 0 or 1
    barBackCorner.CornerRadius = modern and UDim.new(0, 0) or UDim.new(1, 0)
    barFillCorner.CornerRadius = barBackCorner.CornerRadius
    barFill.BackgroundColor3 = accentColor()
    artStroke.Transparency = modern and 0 or 1
    artCorner.CornerRadius = modern and UDim.new(0, 0) or UDim.new(0, 4)
    themeButtonCorner.CornerRadius = modern and UDim.new(0, 0) or UDim.new(0, 3)

    if theme == "minimal" then
        local A, G, CW = 42, 10, 500
        local cx = showArt and (A + G) or 0
        w, h = cx + CW, 58

        holder.BackgroundTransparency = 1
        holderStroke.Transparency = 1
        holderCorner.CornerRadius = UDim.new(0, 0)

        local align = showArt and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
        styleText(Enum.Font.GothamMedium, 13, 0.75, align)

        place(art, 0, 8, A, A)
        place(statsLabel, cx, 2, CW - 100, 18)
        place(musicLabel, cx, 22, CW, 20)
        local bw = 300
        place(barBack, showArt and cx or (cx + (CW - bw) / 2), 48, bw, 2)

        themeButton.BackgroundColor3 = Color3.fromRGB(34, 38, 46)
        themeButton.BackgroundTransparency = 0.35
        themeButton.TextColor3 = Color3.fromRGB(150, 156, 168)
        place(themeButton, w - 52, 1, 50, 17)
        artButton.BackgroundColor3 = Color3.fromRGB(34, 38, 46)
        artButton.BackgroundTransparency = 0.35
        place(artButton, w - 52 - 4 - 34, 1, 34, 17)

    elseif theme == "simple" then
        local A, G, P, CW = 52, 10, 12, 396
        local cx = P + (showArt and (A + G) or 0)
        w, h = cx + CW + P, 76

        holder.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
        holder.BackgroundTransparency = 0.08
        holderStroke.Color = Color3.fromRGB(45, 49, 58)
        holderStroke.Transparency = 0.25
        holderCorner.CornerRadius = UDim.new(0, 5)

        styleText(Enum.Font.GothamMedium, 12, 1, Enum.TextXAlignment.Left)

        place(art, P, 12, A, A)
        place(statsLabel, cx, 8, CW - 104, 18)
        place(musicLabel, cx, 30, CW, 18)
        place(barBack, cx, 58, CW, 3)

        themeButton.BackgroundColor3 = Color3.fromRGB(34, 38, 46)
        themeButton.BackgroundTransparency = 0
        themeButton.TextColor3 = Color3.fromRGB(184, 190, 201)
        place(themeButton, w - P - 54, 7, 54, 18)
        artButton.BackgroundColor3 = Color3.fromRGB(34, 38, 46)
        artButton.BackgroundTransparency = 0
        place(artButton, w - P - 54 - 4 - 34, 7, 34, 18)

    else
        local A, G, P, CW = 54, 8, 10, 380
        local cx = P + (showArt and (A + G) or 0)
        w, h = cx + CW + P, showArt and 72 or 64

        holder.BackgroundColor3 = BLACK
        holder.BackgroundTransparency = 0
        holderStroke.Transparency = 1
        holderCorner.CornerRadius = UDim.new(0, 0)

        styleText(Enum.Font.Arial, 12, 0.35, Enum.TextXAlignment.Left)

        place(art, P, 9, A, A)
        place(statsLabel, cx, 8, CW - 86, 16)
        place(musicLabel, cx, 27, CW, 16)
        place(barBack, cx, 49, CW, 4)

        themeButton.BackgroundTransparency = 1
        themeButton.TextColor3 = Color3.fromRGB(125, 125, 125)
        place(themeButton, w - P - 40, 8, 40, 16)
        artButton.BackgroundTransparency = 1
        place(artButton, w - P - 40 - 4 - 30, 8, 30, 16)
    end

    holderSize = Vector2.new(w, h)
    holder.Size = UDim2.fromOffset(w, h)
    setPos(state.x, state.y) -- only corrects if get out of the screen
    render()
end

local function cycleTheme()
    local index = 1
    for i, name in ipairs(THEME_ORDER) do
        if name == state.theme then index = i break end
    end
    state.theme = THEME_ORDER[(index % #THEME_ORDER) + 1]
    applyLayout()
    saveSettings()
end

local function toggleArt()
    if not canArt then
        warn("[QOL HUD] capa indisponível: o executor precisa de request, writefile e getcustomasset")
        return
    end
    state.art = not state.art
    applyLayout()
    if state.art then
        loadArt()
    else
        art.Image = ""
        clearArtFile()
    end
    saveSettings()
end

conns[#conns + 1] = themeButton.Activated:Connect(cycleTheme)
conns[#conns + 1] = artButton.Activated:Connect(toggleArt)

-- drag --

local drag = { active = false, inputType = nil, touchInput = nil, startPointer = nil, startX = 0, startY = 0, moveConn = nil }
local updateDrag 

local function beginDrag(input)
    local t = input.UserInputType
    if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
    drag.active = true
    drag.inputType = t
    drag.touchInput = (t == Enum.UserInputType.Touch) and input or nil
    drag.startPointer = input.Position
    drag.startX, drag.startY = state.x, state.y
    if drag.moveConn then drag.moveConn:Disconnect() end
    drag.moveConn = UIS.InputChanged:Connect(updateDrag)
end

updateDrag = function(input)
    if not drag.active then return end
    local mouseMove = drag.inputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement
    local touchMove = drag.inputType == Enum.UserInputType.Touch and input == drag.touchInput
    if not mouseMove and not touchMove then return end

    local delta = input.Position - drag.startPointer
    setPos(drag.startX + delta.X, drag.startY + delta.Y)
end

local function endDrag(input)
    if not drag.active then return end
    local mouseUp = drag.inputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1
    local touchUp = drag.inputType == Enum.UserInputType.Touch and input == drag.touchInput
    if mouseUp or touchUp then
        drag.active = false
        drag.inputType, drag.touchInput = nil, nil
        if drag.moveConn then drag.moveConn:Disconnect() drag.moveConn = nil end
        saveSettings()
    end
end

for _, obj in ipairs({ holder, statsLabel, musicLabel, barBack, art }) do
    obj.Active = true
    conns[#conns + 1] = obj.InputBegan:Connect(beginDrag)
end
conns[#conns + 1] = UIS.InputEnded:Connect(endDrag)

-- loop stats and progress --

local frames, acc, barAcc = 0, 0, 0
conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
    if not alive then return end
    frames += 1
    acc += dt
    barAcc += dt

    if acc >= 0.5 then
        stat.fps = frames / acc
        stat.frame = 1000 / math.max(stat.fps, 1)
        frames, acc = 0, 0

        local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        stat.ping = ok and v or nil

        if CONFIG.SHOW.mem then
            local ok2, m = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
            stat.mem = ok2 and m or nil
        end

        render()
    end

    if barAcc >= 0.2 then
        barAcc = 0
        if hasCreds and sp.id and sp.duration > 0 then
            barBack.Visible = true
            barFill.Size = UDim2.new(currentProgress() / sp.duration, 0, 1, 0)
        else
            barBack.Visible = false
        end
    end
end)

-- keys --

conns[#conns + 1] = UIS.InputBegan:Connect(function(input, gameProcessed)
    local key = input.KeyCode
    if UIS:GetFocusedTextBox() then return end

    -- works if roblox says it is "processed"?  
    if key == CONFIG.KEY_TOGGLE then
        holder.Visible = not holder.Visible
        return
    elseif key == CONFIG.KEY_THEME then
        cycleTheme()
        return
    elseif key == CONFIG.KEY_ART then
        toggleArt()
        return
    end

    if gameProcessed then return end

    if hasCreds and key == CONFIG.KEY_PREV then
        control("POST", "/me/player/previous")
    elseif hasCreds and key == CONFIG.KEY_NEXT then
        control("POST", "/me/player/next")
    elseif hasCreds and key == CONFIG.KEY_PLAY then
        local was = sp.playing
        if was then sp.progress = currentProgress() end
        sp.sync, sp.playing = os.clock(), not was
        control("PUT", was and "/me/player/pause" or "/me/player/play")
    end
end)

-- ignore --

env.QOL_HUD = function()
    alive = false
    saveSettings()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if drag.moveConn then pcall(function() drag.moveConn:Disconnect() end) end
    gui:Destroy()
    clearArtFile()
end

-- start --

if not state.x or not state.y then
    local s = screenSize()
    state.x = CONFIG.POSITION.X.Scale * s.X + CONFIG.POSITION.X.Offset
    state.y = CONFIG.POSITION.Y.Scale * s.Y + CONFIG.POSITION.Y.Offset
end
applyLayout()