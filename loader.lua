--[[
    WDYM · Key System Loader v2.0
    ═══════════════════════════════════════════════════════════════
    Features:
      • Online Key Verification (GitHub Raw / Pastebin / API)
      • Saved Key Memory (writefile/readfile - auto login)
      • Metallic Dark Grey 3D Theme matching WDYM Hub
      • "Get Key" Clipboard Copy Link
      • Smooth launch animation into WDYM VAMP Script
    ═══════════════════════════════════════════════════════════════
--]]

local CoreGui      = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local Players      = game:GetService("Players")

local lp = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
-- CONFIGURATION
-- ─────────────────────────────────────────────────────────────
local CONFIG = {
    -- 1. Online Key list URL (Unlisted Pastebin Secret Link)
    KEYS_API_URL = "https://pastebin.com/raw/v30MmTMR",
    
    -- 2. Link where users get their key (Linkvertise / Discord)
    GET_KEY_LINK = "https://discord.gg/neighborstr",
    
    -- 3. Main Script URL (Raw GitHub link to vamp.lua)
    MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/ruzzcan/Roblox-Neighbors-Script-wdym/main/vamp.lua",
    
    -- ALWAYS PROMPT KEY: If true, asks for key EVERY TIME script is executed (no auto-login)
    ALWAYS_PROMPT_KEY = true,
    
    -- Fallback local saved key file name
    KEY_FILE = "WDYM_Saved_Key.txt"
}

-- Default fallback valid keys (if HTTP fails or testing offline)
local HARDCODED_KEYS = {
    ["WDYM-KEY-2029"] = true,
    ["WDYM-VIP-8899"] = true,
    ["VAMP-KEY-FREE"] = true,
}

-- Multi-Executor Universal HTTP Fetch (Solara, Xeno, Volt, Wave, Delta, Hydrogen)
local function fetchURL(url)
    local content = nil

    -- 1. Try game:HttpGet FIRST
    pcall(function()
        content = game:HttpGet(url, true)
    end)

    -- 2. Fallback to Executor request API if game:HttpGet returned nothing or failed
    if not content or #content < 5 or content:find("<!DOCTYPE") or content:find("<html") then
        local reqFn = (type(request) == "function" and request) 
                   or (type(http_request) == "function" and http_request) 
                   or (syn and type(syn.request) == "function" and syn.request)
                   or (http and type(http.request) == "function" and http.request)
                   
        if reqFn then
            pcall(function()
                local res = reqFn({Url = url, Method = "GET"})
                if res and res.Body and #res.Body > 5 then
                    content = res.Body
                end
            end)
        end
    end

    return content
end

-- ─────────────────────────────────────────────────────────────
-- KEY VALIDATION ENGINE
-- ─────────────────────────────────────────────────────────────
local function isKeyValid(inputKey)
    if not inputKey or inputKey == "" then return false end
    inputKey = inputKey:gsub("%s+", "") -- trim whitespace

    -- Check local hardcoded keys first
    if HARDCODED_KEYS[inputKey] then return true end

    -- Check Online API / Raw Keys File via Universal HTTP Fetch
    local response = fetchURL(CONFIG.KEYS_API_URL)

    if response then
        -- Search for key line by line
        for line in response:gmatch("[^\r\n]+") do
            local cleanLine = line:gsub("%s+", "")
            if cleanLine == inputKey and cleanLine ~= "" then
                return true
            end
        end
    end

    return false
end

local function saveKey(key)
    pcall(function()
        if writefile then writefile(CONFIG.KEY_FILE, key) end
    end)
end

local function loadSavedKey()
    local saved = nil
    pcall(function()
        if readfile and isfile and isfile(CONFIG.KEY_FILE) then
            saved = readfile(CONFIG.KEY_FILE)
        end
    end)
    return saved
end

-- ─────────────────────────────────────────────────────────────
-- LAUNCH MAIN SCRIPT
-- ─────────────────────────────────────────────────────────────
local statusLbl -- forward declaration for live status updates

local function launchMainScript()
    if statusLbl then
        statusLbl.Text = "Status: Fetching WDYM Hub code..."
        statusLbl.TextColor3 = Color3.fromRGB(100, 200, 255)
    end

    local scriptContent = fetchURL(CONFIG.MAIN_SCRIPT_URL)
    if scriptContent and #scriptContent > 500 then
        if statusLbl then
            statusLbl.Text = "Status: Executing WDYM Hub..."
            statusLbl.TextColor3 = Color3.fromRGB(100, 240, 120)
        end
        task.wait(0.1)

        local func, err = loadstring(scriptContent)
        if func then
            local ok, execErr = pcall(func)
            if ok then
                return true
            else
                warn("[WDYM Engine] Runtime execution error on Xeno: " .. tostring(execErr))
                if statusLbl then
                    statusLbl.Text = "Error: Execution failed (" .. tostring(execErr):sub(1, 40) .. ")"
                    statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
            end
        else
            warn("[WDYM Engine] Loadstring syntax error on Xeno: " .. tostring(err))
            if statusLbl then
                statusLbl.Text = "Error: Syntax error (" .. tostring(err):sub(1, 40) .. ")"
                statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
            end
        end
    else
        warn("[WDYM Engine] Failed to download vamp.lua from GitHub")
        if statusLbl then
            statusLbl.Text = "Error: Could not download vamp.lua!"
            statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end

    -- Fallback if Http fetch failed
    pcall(function()
        local rawCode = readfile and isfile and isfile("vamp.lua") and readfile("vamp.lua")
        if rawCode then
            local f = loadstring(rawCode)
            if f then f(); return true end
        end
    end)
    return false
end

-- Check if saved key is valid on boot (Skipped if ALWAYS_PROMPT_KEY is true)
if not CONFIG.ALWAYS_PROMPT_KEY then
    local savedKey = loadSavedKey()
    if savedKey and isKeyValid(savedKey) then
        print("[WDYM KeySystem] Valid saved key detected! Auto-logging in...")
        launchMainScript()
        return
    end
end

-- ─────────────────────────────────────────────────────────────
-- KEY SYSTEM GUI CONSTRUCTION (Metallic Dark Grey Theme)
-- ─────────────────────────────────────────────────────────────
-- Safe cleanup (Xeno/Solara safe, no CoreGui crash)
pcall(function()
    local pg = lp:FindFirstChild("PlayerGui")
    if pg then
        local old = pg:FindFirstChild("WDYM_KeySystem_Gui")
        if old then old:Destroy() end
    end
end)
pcall(function()
    local old = CoreGui:FindFirstChild("WDYM_KeySystem_Gui")
    if old then old:Destroy() end
end)

local KeyGui = Instance.new("ScreenGui")
KeyGui.Name = "WDYM_KeySystem_Gui"
KeyGui.ResetOnSpawn = false
KeyGui.DisplayOrder = 999999
KeyGui.Enabled = true

-- PlayerGui FIRST — works on 100% of executors (Xeno, Solara, Volt, Wave, Delta)
local _keyGuiParented = false
pcall(function()
    local pg = lp:WaitForChild("PlayerGui", 3)
    if pg then
        KeyGui.Parent = pg
        _keyGuiParented = (KeyGui.Parent ~= nil)
    end
end)
if not _keyGuiParented then
    pcall(function()
        if type(gethui) == "function" then
            local hui = gethui()
            if hui then KeyGui.Parent = hui; _keyGuiParented = true end
        end
    end)
end
if not _keyGuiParented then
    pcall(function() KeyGui.Parent = CoreGui end)
end

local mainW, mainH = 400, 240
local keyFrame = Instance.new("Frame")
keyFrame.Name             = "KeyFrame"
keyFrame.Size             = UDim2.new(0, mainW, 0, mainH)
keyFrame.Position         = UDim2.new(0.5, -mainW/2, 0.5, -mainH/2)
keyFrame.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
keyFrame.BorderSizePixel  = 0
keyFrame.ClipsDescendants = true
keyFrame.Active           = true
keyFrame.Draggable        = true
keyFrame.Parent           = KeyGui

local kCorner = Instance.new("UICorner"); kCorner.CornerRadius = UDim.new(0, 8); kCorner.Parent = keyFrame
local kStroke = Instance.new("UIStroke"); kStroke.Color = Color3.fromRGB(255, 255, 255); kStroke.Thickness = 1.5; kStroke.Parent = keyFrame

-- Top White Border Accent Line
local topLine = Instance.new("Frame")
topLine.Size             = UDim2.new(1, 0, 0, 3)
topLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
topLine.BorderSizePixel  = 0
topLine.Parent           = keyFrame

-- Header
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 42)
header.Position         = UDim2.new(0, 0, 0, 3)
header.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
header.BorderSizePixel  = 0
header.Parent           = keyFrame

local titleLbl = Instance.new("TextLabel")
titleLbl.Size             = UDim2.new(1, -20, 1, 0)
titleLbl.Position         = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text             = "WDYM HUB · KEY SYSTEM"
titleLbl.TextColor3       = Color3.fromRGB(255, 255, 255)
titleLbl.Font             = Enum.Font.GothamBold
titleLbl.TextSize         = 14
titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
titleLbl.Parent           = header

local subTitle = Instance.new("TextLabel")
subTitle.Size             = UDim2.new(1, -28, 0, 18)
subTitle.Position         = UDim2.new(0, 14, 0, 52)
subTitle.BackgroundTransparency = 1
subTitle.Text             = "Please enter a valid key to access WDYM VAMP 2.0"
subTitle.TextColor3       = Color3.fromRGB(190, 195, 205)
subTitle.Font             = Enum.Font.GothamBold
subTitle.TextSize         = 10
subTitle.TextXAlignment   = Enum.TextXAlignment.Left
subTitle.Parent           = keyFrame

-- Key Input TextBox Panel
local inputPanel = Instance.new("Frame")
inputPanel.Size             = UDim2.new(1, -28, 0, 38)
inputPanel.Position         = UDim2.new(0, 14, 0, 78)
inputPanel.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
inputPanel.BorderSizePixel  = 0
inputPanel.Parent           = keyFrame
local ipCorner = Instance.new("UICorner"); ipCorner.CornerRadius = UDim.new(0, 6); ipCorner.Parent = inputPanel
local ipStroke = Instance.new("UIStroke"); ipStroke.Color = Color3.fromRGB(180, 190, 210); ipStroke.Thickness = 1; ipStroke.Parent = inputPanel

local keyInput = Instance.new("TextBox")
keyInput.Size                   = UDim2.new(1, -16, 1, 0)
keyInput.Position               = UDim2.new(0, 8, 0, 0)
keyInput.BackgroundTransparency = 1
keyInput.PlaceholderText        = "Enter Key Here... (e.g. WDYM-KEY-****)"
keyInput.PlaceholderColor3      = Color3.fromRGB(130, 135, 145)
keyInput.Text                   = ""
keyInput.TextColor3             = Color3.fromRGB(255, 255, 255)
keyInput.Font                   = Enum.Font.GothamBold
keyInput.TextSize               = 11
keyInput.ClearTextOnFocus       = false
keyInput.Parent                 = inputPanel

-- Status Message Label
local statusLbl = Instance.new("TextLabel")
statusLbl.Size             = UDim2.new(1, -28, 0, 16)
statusLbl.Position         = UDim2.new(0, 14, 0, 122)
statusLbl.BackgroundTransparency = 1
statusLbl.Text             = "Status: Waiting for key input..."
statusLbl.TextColor3       = Color3.fromRGB(190, 195, 205)
statusLbl.Font             = Enum.Font.GothamBold
statusLbl.TextSize         = 9
statusLbl.TextXAlignment   = Enum.TextXAlignment.Left
statusLbl.Parent           = keyFrame

-- Buttons Container Row
local btnRow = Instance.new("Frame")
btnRow.Size             = UDim2.new(1, -28, 0, 36)
btnRow.Position         = UDim2.new(0, 14, 0, 150)
btnRow.BackgroundTransparency = 1
btnRow.Parent           = keyFrame

-- Submit Key Button
local submitBtn = Instance.new("TextButton")
submitBtn.Size             = UDim2.new(0.48, 0, 1, 0)
submitBtn.Position         = UDim2.new(0, 0, 0, 0)
submitBtn.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
submitBtn.BorderSizePixel  = 0
submitBtn.Text             = "Submit Key"
submitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
submitBtn.Font             = Enum.Font.GothamBold
submitBtn.TextSize         = 11
submitBtn.Parent           = btnRow

local sbC = Instance.new("UICorner"); sbC.CornerRadius = UDim.new(0, 6); sbC.Parent = submitBtn
local sbS = Instance.new("UIStroke"); sbS.Color = Color3.fromRGB(180, 190, 210); sbS.Thickness = 1; sbS.Parent = submitBtn
local sbG = Instance.new("UIGradient"); sbG.Rotation = 90; sbG.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(54,60,76)), ColorSequenceKeypoint.new(1, Color3.fromRGB(24,26,34))}); sbG.Parent = submitBtn

-- Get Key Button
local getKeyBtn = Instance.new("TextButton")
getKeyBtn.Size             = UDim2.new(0.48, 0, 1, 0)
getKeyBtn.Position         = UDim2.new(0.52, 0, 0, 0)
getKeyBtn.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
getKeyBtn.BorderSizePixel  = 0
getKeyBtn.Text             = "Get Key (Copy Link)"
getKeyBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
getKeyBtn.Font             = Enum.Font.GothamBold
getKeyBtn.TextSize         = 11
getKeyBtn.Parent           = btnRow

local gkC = Instance.new("UICorner"); gkC.CornerRadius = UDim.new(0, 6); gkC.Parent = getKeyBtn
local gkS = Instance.new("UIStroke"); gkS.Color = Color3.fromRGB(180, 190, 210); gkS.Thickness = 1; gkS.Parent = getKeyBtn

-- ─────────────────────────────────────────────────────────────
-- BUTTON INTERACTION LOGIC
-- ─────────────────────────────────────────────────────────────
submitBtn.MouseButton1Click:Connect(function()
    local userKey = keyInput.Text
    statusLbl.Text = "Status: Verifying key..."
    statusLbl.TextColor3 = Color3.fromRGB(220, 220, 100)

    task.wait(0.2)

    if isKeyValid(userKey) then
        statusLbl.Text = "Status: Key Accepted! Launching Hub..."
        statusLbl.TextColor3 = Color3.fromRGB(100, 240, 120)
        saveKey(userKey)

        task.spawn(function()
            launchMainScript()
        end)
        
        TweenService:Create(keyFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -mainW/2, 0.5, -mainH/2 + 30),
            BackgroundTransparency = 1
        }):Play()
        task.wait(0.4)
        pcall(function() KeyGui:Destroy() end)
    else
        statusLbl.Text = "Status: Invalid or Expired Key!"
        statusLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        
        -- Shake effect on input box
        local origPos = inputPanel.Position
        for _, offset in ipairs({-6, 6, -4, 4, -2, 2, 0}) do
            inputPanel.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset + offset, origPos.Y.Scale, origPos.Y.Offset)
            task.wait(0.03)
        end
    end
end)

getKeyBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if setclipboard then
            setclipboard(CONFIG.GET_KEY_LINK)
            statusLbl.Text = "Status: Key Link copied to clipboard!"
            statusLbl.TextColor3 = Color3.fromRGB(100, 200, 255)
        else
            statusLbl.Text = "Status: Visit " .. CONFIG.GET_KEY_LINK
            statusLbl.TextColor3 = Color3.fromRGB(190, 195, 205)
        end
    end)
end)
