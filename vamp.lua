--[[
    WDYM · Premium Utility Script · v2.0
    ═══════════════════════════════════════════════
    v2.0 Changes:
      • Complete UI Redesign: Landscape rectangle, vertical sidebar tabs
      • Ctrl+O to toggle hide/show (no X button minimize behavior)
      • View tab → renamed "Watch" → "Teleport", added world loading fix on TP
      • Utility tab → Ghost Mode, Anti-TP, Noclip, Immune (prevent power usage on us)
      • Player tab → Walk Speed, Jump Power sliders + Build Mode item equip hack
      • World Loading: Best-effort ReplicationFocus nudging (true solution requires server)
      • All text in English, no emojis
    ═══════════════════════════════════════════════
--]]

-- ─────────────────────────────────────────────────────────────
-- SERVICES
-- ─────────────────────────────────────────────────────────────
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInput       = game:GetService("UserInputService")
local TweenSvc        = game:GetService("TweenService")
local CoreGui         = game:GetService("CoreGui")
local SoundSvc        = game:GetService("SoundService")
local Debris          = game:GetService("Debris")
local StarterGui      = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local VIM             = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
-- FORCE SHOW CHAT
-- ─────────────────────────────────────────────────────────────
local function forceShowChat()
    -- 1. Enable standard Roblox CoreGui Chat
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
    end)

    -- 2. Enable TextChatService (Modern Chat System)
    pcall(function()
        if TextChatService.ChatWindowConfiguration then
            TextChatService.ChatWindowConfiguration.Enabled = true
        end
        if TextChatService.ChatInputBarConfiguration then
            TextChatService.ChatInputBarConfiguration.Enabled = true
        end
    end)

    -- 3. Unhide any Chat ScreenGuis or Frames in PlayerGui
    pcall(function()
        local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 3)
        if pg then
            for _, obj in ipairs(pg:GetDescendants()) do
                local name = obj.Name:lower()
                if name:find("chat") then
                    if obj:IsA("ScreenGui") then
                        obj.Enabled = true
                    elseif obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                        obj.Visible = true
                    end
                end
            end
        end
    end)
end

-- Auto force show chat on script launch
task.spawn(function()
    forceShowChat()
    task.wait(1.5)
    forceShowChat()
end)

-- ─────────────────────────────────────────────────────────────
-- CONFIG
-- ─────────────────────────────────────────────────────────────
local CFG = {
    ghost       = false,
    noclip      = false,
    antiTP      = false,
    immune      = false,  -- prevent others using powers/tools on us
    tpThreshold = 40,
    -- ESP Settings
    espAll      = false,  -- Master toggle: ESP for all players
    espName     = true,   -- Show DisplayName/Name
    espBox      = true,   -- Show Box / Chams Highlight
    espDistance = true,   -- Show Distance [XXm]
    espTarget   = nil,    -- Specific targeted player for ESP
}

-- ─────────────────────────────────────────────────────────────
-- STATE & CACHE
-- ─────────────────────────────────────────────────────────────
local lastCF       = nil
local isReverting  = false
local stalkTarget  = nil
local stalkActive  = false
local fakeBody     = nil
local fakeBodyConn = nil
local returnCF     = nil

local myHRPInstance = nil
local noclipParts   = {}

-- ═════════════════════════════════════════════════════════════
-- ESP ENGINE SYSTEM
-- ═════════════════════════════════════════════════════════════
local ESP_FOLDER = Instance.new("Folder")
ESP_FOLDER.Name = "WDYM_ESP_Folder"
pcall(function()
    local g = (gethui and gethui()) or CoreGui
    ESP_FOLDER.Parent = g
end)

local espObjects = {} -- player -> { highlight, billboard, nameLbl, distLbl }

local function removePlayerESP(plr)
    if espObjects[plr] then
        pcall(function()
            if espObjects[plr].highlight then espObjects[plr].highlight:Destroy() end
            if espObjects[plr].billboard then espObjects[plr].billboard:Destroy() end
        end)
        espObjects[plr] = nil
    end
end

local function createPlayerESP(plr)
    removePlayerESP(plr)
    if plr == lp then return end
    
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not (head and hrp) then return end

    -- Highlight Box / Chams
    local hl = Instance.new("Highlight")
    hl.Name = "ESPHighlight"
    hl.FillColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(160, 165, 180)
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Enabled = false
    hl.Parent = ESP_FOLDER

    -- BillboardGui (Name & Distance)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPBillboard"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 160, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2.6, 0)
    bb.AlwaysOnTop = true
    bb.Enabled = false
    bb.Parent = ESP_FOLDER

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 18)
    nameLbl.Position = UDim2.new(0, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.DisplayName ~= "" and plr.DisplayName or plr.Name
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLbl.TextStrokeTransparency = 0.2
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, 14)
    distLbl.Position = UDim2.new(0, 0, 0, 18)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "[0m]"
    distLbl.TextColor3 = Color3.fromRGB(200, 205, 220)
    distLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLbl.TextStrokeTransparency = 0.3
    distLbl.Font = Enum.Font.GothamBold
    distLbl.TextSize = 10
    distLbl.Parent = bb

    espObjects[plr] = {
        highlight = hl,
        billboard = bb,
        nameLbl = nameLbl,
        distLbl = distLbl,
        player = plr
    }
end

local function updateESP()
    local myChar = lp.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            local isTargeted = (CFG.espTarget == p)
            local isAllowed = (CFG.espAll or isTargeted)
            
            if isAllowed and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if not espObjects[p] or espObjects[p].player.Character ~= p.Character then
                    createPlayerESP(p)
                end
                local data = espObjects[p]
                if data then
                    data.highlight.Enabled = CFG.espBox
                    
                    local showBB = CFG.espName or CFG.espDistance
                    data.billboard.Enabled = showBB
                    data.nameLbl.Visible = CFG.espName
                    data.distLbl.Visible = CFG.espDistance
                    
                    if CFG.espDistance and myHRP and p.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = math.floor((myHRP.Position - p.Character.HumanoidRootPart.Position).Magnitude * 0.28)
                        data.distLbl.Text = "[" .. dist .. "m]"
                    end
                end
            else
                removePlayerESP(p)
            end
        end
    end
end

RunService.Heartbeat:Connect(updateESP)
Players.PlayerRemoving:Connect(removePlayerESP)

-- ─────────────────────────────────────────────────────────────
-- CACHE HELPERS
-- ─────────────────────────────────────────────────────────────
local function getChar() return lp.Character end

local function updateCache(char)
    myHRPInstance = char:WaitForChild("HumanoidRootPart", 5)
    table.clear(noclipParts)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            table.insert(noclipParts, p)
        end
    end
end

local function applyNoclip()
    for i = 1, #noclipParts do
        local p = noclipParts[i]
        if p and p.Parent then p.CanCollide = false end
    end
end

-- ─────────────────────────────────────────────────────────────
-- GHOST FAKE BODY
-- ─────────────────────────────────────────────────────────────
local function destroyFakeBody()
    if fakeBodyConn then fakeBodyConn:Disconnect(); fakeBodyConn = nil end
    if fakeBody     then fakeBody:Destroy();        fakeBody = nil end
end

local function createFakeBody(targetCF)
    destroyFakeBody()
    local ch = getChar()
    if not ch then return end
    task.spawn(function()
        local ok, dummy = pcall(function() return ch:Clone() end)
        if not ok or not dummy then return end
        dummy.Name = "WDYM_Ghost"
        for _, obj in ipairs(dummy:GetDescendants()) do
            if obj:IsA("BaseScript") or obj:IsA("Humanoid") or obj:IsA("Animator")
            or obj:IsA("HumanoidDescription") or obj:IsA("BodyPosition")
            or obj:IsA("BodyVelocity") or obj:IsA("BodyGyro")
            or obj:IsA("AlignPosition") or obj:IsA("AlignOrientation") then
                pcall(obj.Destroy, obj)
            end
        end
        for _, part in ipairs(dummy:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored   = true
                part.CanCollide = false
                part.CanTouch   = false
                part.AssemblyLinearVelocity  = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        dummy.Parent = workspace
        pcall(function() dummy:PivotTo(targetCF) end)
        fakeBody = dummy
        fakeBodyConn = ch.ChildAdded:Connect(function(child)
            if not fakeBody then return end
            task.defer(function()
                if fakeBody and (child:IsA("Accessory") or child:IsA("Hat")) then
                    pcall(function() child:Clone().Parent = fakeBody end)
                end
            end)
        end)
    end)
end

-- ─────────────────────────────────────────────────────────────
-- SOUNDS
-- ─────────────────────────────────────────────────────────────
local function playClick()
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://6324790483"; s.Volume = 0.4; s.Parent = SoundSvc; s:Play()
    Debris:AddItem(s, 2)
end
local function playHover()
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://12222247"; s.Volume = 0.15; s.Parent = SoundSvc; s:Play()
    Debris:AddItem(s, 2)
end

-- ─────────────────────────────────────────────────────────────
-- METAMETHOD HOOKS
-- ─────────────────────────────────────────────────────────────
local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(t, k)
    if myHRPInstance and rawequal(t, myHRPInstance) and not checkcaller() then
        if k == "Velocity" or k == "AssemblyLinearVelocity" or k == "AssemblyAngularVelocity" then
            return Vector3.zero
        end
    end
    return oldIndex(t, k)
end))

local oldNewindex
oldNewindex = hookmetamethod(game, "__newindex", newcclosure(function(t, k, v)
    -- Anti-TP: block server-forced teleports on our character
    if (k == "CFrame" or k == "Position") and CFG.antiTP and not (checkcaller() or isReverting or CFG.ghost) then
        local ch = getChar()
        if ch and t:IsDescendantOf(ch) then
            local np = (k == "CFrame") and v.Position or v
            if lastCF and (np - lastCF.Position).Magnitude > CFG.tpThreshold then return end
        end
    end
    -- Immune: if someone writes WalkSpeed/JumpPower/Anchored onto OUR humanoid/HRP, block it
    if CFG.immune and not checkcaller() then
        local ch = getChar()
        if ch then
            local myHum = ch:FindFirstChildOfClass("Humanoid")
            if myHum and rawequal(t, myHum) then
                if k == "WalkSpeed" and v < 2 then return end   -- block freeze/slow
                if k == "JumpPower" and v < 1 then return end
                if k == "JumpHeight" and v < 1 then return end
            end
            local myHRP2 = ch:FindFirstChild("HumanoidRootPart")
            if myHRP2 and rawequal(t, myHRP2) then
                if k == "Anchored" and v == true then return end -- block anchor-freeze
            end
        end
    end
    return oldNewindex(t, k, v)
end))

local ZONE_KEYWORDS = {
    "zonexit","zoneexit","zone_exit","areaexit","area_exit","leavezone","leave_zone",
    "exitzone","exit_zone","boundary","checkpointexit","checkpoint_exit",
    "playerleave","player_leave","lefthouse","left_house","removeplayer","remove_player","playerout",
}
local function isZoneRemote(name)
    local l = name:lower():gsub("[%s%-_]+","")
    for _, kw in ipairs(ZONE_KEYWORDS) do
        if l:find(kw,1,true) then return true end
    end
    return false
end

-- Immune: block ALL power/effect RemoteEvent FireServer calls that target OUR character
-- Strategy: block by keyword AND also self-repair humanoid stats every Heartbeat
local IMMUNE_BLOCK_KEYWORDS = {
    -- freeze / stun / slow
    "freeze","frozen","stun","stunned","slow","slowed","stop","stopped",
    -- damage / knockback
    "damage","dmg","hurt","hit","knockback","knock","push","launch","ragdoll",
    -- vampire-specific
    "bite","drain","leech","suck","bleed","poison","curse","debuff","weaken",
    -- generic power
    "force","power","ability","skill","effect","status",
    -- anchor / physics
    "anchor","disable","root","lock","bind",
}
local function isImmuneBound(name)
    if not CFG.immune then return false end
    local l = name:lower():gsub("[%s%-_]+","")
    for _, kw in ipairs(IMMUNE_BLOCK_KEYWORDS) do
        if l:find(kw,1,true) then return true end
    end
    return false
end

-- Saved normal stats for immune restoration
local immuneSavedSpeed  = 16
local immuneSavedJump   = 50

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local m = getnamecallmethod()
    if checkcaller() or isReverting then return oldNamecall(self, ...) end

    if m == "FireServer" or m == "InvokeServer" then
        if CFG.ghost then
            local ok, rn = pcall(function() return self.Name end)
            if ok and rn and isZoneRemote(rn) then return end
        end
        if CFG.immune then
            local ok, rn = pcall(function() return self.Name end)
            if ok and rn and isImmuneBound(rn) then return end
        end
    elseif CFG.antiTP and (m == "PivotTo" or m == "SetPrimaryPartCFrame" or m=="MoveTo") and not CFG.ghost then
        local ch = getChar()
        if ch and (rawequal(self, ch) or self:IsDescendantOf(ch)) then return end
    end
    return oldNamecall(self, ...)
end))

-- ─────────────────────────────────────────────────────────────
-- GAME LOOP
-- ─────────────────────────────────────────────────────────────
RunService.Stepped:Connect(function()
    if CFG.noclip then applyNoclip() end
end)

RunService.Heartbeat:Connect(function()
    if CFG.noclip then applyNoclip() end
    local hrp = myHRPInstance
    if not hrp or not hrp.Parent then return end
    local realCF = hrp.CFrame
    if CFG.ghost then lastCF = realCF; return end
    if CFG.antiTP and lastCF then
        if (realCF.Position - lastCF.Position).Magnitude > CFG.tpThreshold then
            isReverting = true; hrp.CFrame = lastCF; isReverting = false; return
        end
    end
    lastCF = realCF

    -- Immune: continuously restore humanoid stats if someone altered them
    if CFG.immune then
        local ch = getChar()
        if ch then
            local hum = ch:FindFirstChildOfClass("Humanoid")
            if hum then
                -- Restore WalkSpeed if frozen/slowed
                if hum.WalkSpeed < immuneSavedSpeed - 1 then
                    pcall(function() hum.WalkSpeed = immuneSavedSpeed end)
                end
                -- Restore JumpPower if blocked
                if hum.JumpPower < immuneSavedJump - 1 then
                    pcall(function() hum.JumpPower = immuneSavedJump end)
                end
            end
            -- Unanchor HRP if anchored externally
            local myhrp2 = ch:FindFirstChild("HumanoidRootPart")
            if myhrp2 and myhrp2.Anchored then
                pcall(function() myhrp2.Anchored = false end)
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────
-- WORLD LOADING: best-effort ReplicationFocus sweep
-- NOTE: Neighbors uses StreamingEnabled server-side. The real fix is the server
-- calling Player:RequestStreamAroundAsync(). Client-side we can only nudge the
-- ReplicationFocus so the engine requests adjacent chunks from the server.
-- ─────────────────────────────────────────────────────────────
-- waitForCharacterVisible: polls until the given player's HRP is in workspace with a parent
local function waitForCharacterVisible(player, timeout)
    local t0 = tick()
    while tick() - t0 < timeout do
        local ch = player.Character
        if ch then
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Parent then
                local head = ch:FindFirstChild("Head")
                -- Confirm the part actually exists in workspace hierarchy (streamed in)
                if hrp:IsDescendantOf(workspace) then
                    -- Extra: check LocalTransparencyModifier < 1 (fully visible)
                    if head then
                        local lt = 1
                        pcall(function() lt = head.LocalTransparencyModifier end)
                        if lt < 0.9 then return true end
                    else
                        return true
                    end
                end
            end
        end
        task.wait(0.1)
    end
    return false
end

local function nudgeStreamingFocus(targetCF)
    task.spawn(function()
        local part = Instance.new("Part")
        part.Size = Vector3.new(1,1,1)
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Parent = workspace

        local oldFocus = lp.ReplicationFocus
        lp.ReplicationFocus = part

        -- Step 1: Sweep a 3x3 grid of 64-stud offsets around the target
        local offsets = {
            Vector3.new(0,0,0),
            Vector3.new(64,0,0),  Vector3.new(-64,0,0),
            Vector3.new(0,0,64),  Vector3.new(0,0,-64),
            Vector3.new(64,0,64), Vector3.new(-64,0,64),
            Vector3.new(64,0,-64),Vector3.new(-64,0,-64),
        }
        for _, off in ipairs(offsets) do
            part.CFrame = CFrame.new(targetCF.Position + off)
            task.wait(0.15)
        end

        -- Step 2: Visit every online player's HRP to trigger their area to stream in
        -- (this is what makes remote characters' chat bubbles appear)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local ch = p.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp and hrp:IsDescendantOf(workspace) then
                    part.CFrame = hrp.CFrame
                    task.wait(0.15)
                end
            end
        end

        lp.ReplicationFocus = oldFocus
        part:Destroy()

        -- Step 3: TouchTransmitter sweep — fires plot-entry scripts that games use
        -- to dynamically load house/area content (common in Neighbors)
        local nearParts = workspace:GetPartBoundsInBox(
            CFrame.new(targetCF.Position),
            Vector3.new(300, 300, 300)
        )
        for _, p in ipairs(nearParts) do
            if p:FindFirstChildWhichIsA("TouchTransmitter") and firetouchinterest then
                local myHRP = myHRPInstance
                if myHRP and myHRP.Parent then
                    pcall(firetouchinterest, myHRP, p, 0)
                    task.wait(0.008)
                    pcall(firetouchinterest, myHRP, p, 1)
                end
            end
        end
    end)
end

-- Auto-sweep on spawn
local function runPreloadSequence()
    task.spawn(function()
        task.wait(2)
        local plrs = Players:GetPlayers()
        local tempPart = Instance.new("Part")
        tempPart.Size = Vector3.new(1,1,1); tempPart.Anchored = true
        tempPart.CanCollide = false; tempPart.Transparency = 1; tempPart.Parent = workspace
        local oldFocus = lp.ReplicationFocus
        lp.ReplicationFocus = tempPart
        for _, p in ipairs(plrs) do
            if p ~= lp then
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hrp then
                    tempPart.CFrame = hrp.CFrame
                    task.wait(0.2)
                end
            end
        end
        lp.ReplicationFocus = oldFocus
        tempPart:Destroy()
    end)
end

-- ─────────────────────────────────────────────────────────────
-- BUILD MODE HACK
-- ─────────────────────────────────────────────────────────────
local buildModeActive = false
local function setBuildMode(state)
    buildModeActive = state
    if state then
        -- Try to fire the build mode toggle remote in Neighbors
        local ch = getChar()
        if not ch then return end
        -- Common remote names in housing games for build mode
        local remoteNames = {"StartBuild","OpenBuild","BuildMode","EnterBuild","ToggleBuild","Build"}
        for _, rn in ipairs(remoteNames) do
            local remote = game:GetService("ReplicatedStorage"):FindFirstChild(rn, true)
            if not remote then
                remote = workspace:FindFirstChild(rn, true)
            end
            if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                pcall(function()
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer()
                    else
                        remote:InvokeServer()
                    end
                end)
            end
        end
        -- Also manipulate local StarterGui / PlayerGui to force build mode open
        local pg = lp:FindFirstChild("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetDescendants()) do
                if gui:IsA("Frame") or gui:IsA("ScreenGui") then
                    local ln = gui.Name:lower()
                    if ln:find("build") or ln:find("construct") or ln:find("place") then
                        pcall(function() gui.Enabled = true end)
                        pcall(function() gui.Visible = true end)
                    end
                end
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- PLAYER STATS
-- ─────────────────────────────────────────────────────────────
local function setWalkSpeed(val)
    immuneSavedSpeed = val  -- keep immune baseline in sync
    local ch = getChar()
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = val end
end

local function setJumpPower(val)
    immuneSavedJump = val   -- keep immune baseline in sync
    local ch = getChar()
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum:GetPropertyChangedSignal("UseJumpPower") then
            hum.UseJumpPower = true
        end
        hum.JumpPower = val
        hum.JumpHeight = val * 0.5
    end
end

-- ─────────────────────────────────────────────────────────────
-- WING / FLY SYSTEM (with back-attachment and animation)
-- ─────────────────────────────────────────────────────────────
local wingsActive   = false
local flyBodyGyro   = nil
local flyBodyVel    = nil
local flyConn       = nil
local wingFlapTrack = nil  -- AnimationTrack for wing flap
local wingBackWeld  = nil  -- Weld that moves handle to back

-- Known wing-flap animation IDs (generic Roblox wing anims)
local WING_ANIM_IDS = {
    "rbxassetid://616158929",  -- classic wing flap
    "rbxassetid://616161736",  -- superhero hover
    "rbxassetid://885367079",  -- angel wings idle
}

local function stopWingAnim()
    if wingFlapTrack then
        pcall(function() wingFlapTrack:Stop() end)
        wingFlapTrack = nil
    end
end

-- Attach the tool's Handle to the character's back via a Weld
local function attachHandleToBack(tool)
    local ch = getChar(); if not ch then return end
    local handle = tool:FindFirstChild("Handle"); if not handle then return end

    -- Torso reference (supports both R6 and R15)
    local torso = ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
    if not torso then return end

    -- Remove the auto-created hand grip motor so the item is no longer in-hand
    local function clearHandGrip()
        for _, c in ipairs(ch:GetDescendants()) do
            if c:IsA("Motor6D") and c.Name == "RightGrip" then
                pcall(function() c.Part1 = nil end)  -- detach without destroying
            end
        end
    end
    task.delay(0.05, clearHandGrip)  -- slight delay so Roblox creates it first

    -- Weld handle to the back of the torso
    local w = Instance.new("Weld")
    w.Name  = "WingBackWeld"
    w.Part0 = torso
    w.Part1 = handle
    -- Offset: center-back, rotated 180° so wings face outward
    w.C0 = CFrame.new(0, 0.4, 1.1) * CFrame.Angles(0, math.pi, 0)
    w.Parent = torso
    wingBackWeld = w
end

local visualWingModel = nil

local function create3DWings()
    detachWingsFromBack()
    if visualWingModel then pcall(function() visualWingModel:Destroy() end) visualWingModel = nil end
    local ch = getChar(); if not ch then return end
    local torso = ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
    if not torso then return end

    local model = Instance.new("Model")
    model.Name = "WDYM_3DWings"

    -- Left Wing Part
    local wLeft = Instance.new("Part")
    wLeft.Name = "LeftWing"
    wLeft.Size = Vector3.new(0.2, 3.2, 2.4)
    wLeft.Color = Color3.fromRGB(180, 0, 0)
    wLeft.Material = Enum.Material.Neon
    wLeft.CanCollide = false
    wLeft.Parent = model

    local mLeft = Instance.new("SpecialMesh")
    mLeft.MeshType = Enum.MeshType.Wedge
    mLeft.Scale = Vector3.new(0.2, 1.2, 1.2)
    mLeft.Parent = wLeft

    local wL = Instance.new("WeldConstraint")
    wLeft.CFrame = torso.CFrame * CFrame.new(-1.8, 0.6, 0.8) * CFrame.Angles(0, math.rad(-25), math.rad(25))
    wL.Part0 = torso; wL.Part1 = wLeft; wL.Parent = wLeft

    -- Right Wing Part
    local wRight = Instance.new("Part")
    wRight.Name = "RightWing"
    wRight.Size = Vector3.new(0.2, 3.2, 2.4)
    wRight.Color = Color3.fromRGB(180, 0, 0)
    wRight.Material = Enum.Material.Neon
    wRight.CanCollide = false
    wRight.Parent = model

    local mRight = Instance.new("SpecialMesh")
    mRight.MeshType = Enum.MeshType.Wedge
    mRight.Scale = Vector3.new(0.2, 1.2, 1.2)
    mRight.Parent = wRight

    local wR = Instance.new("WeldConstraint")
    wRight.CFrame = torso.CFrame * CFrame.new(1.8, 0.6, 0.8) * CFrame.Angles(0, math.rad(25), math.rad(-25))
    wR.Part0 = torso; wR.Part1 = wRight; wR.Parent = wRight

    model.Parent = ch
    visualWingModel = model
end

local function detachWingsFromBack()
    if wingBackWeld and wingBackWeld.Parent then
        wingBackWeld:Destroy()
        wingBackWeld = nil
    end
    if visualWingModel then
        pcall(function() visualWingModel:Destroy() end)
        visualWingModel = nil
    end
end

-- Play wing animation: first try tool's own animations, then fallback IDs
local function playWingAnimation(tool)
    local ch = getChar(); if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end

    local foundAnimId = nil
    if tool then
        for _, obj in ipairs(tool:GetDescendants()) do
            if obj:IsA("Animation") or obj:IsA("StringValue") then
                local id = ""
                pcall(function()
                    id = obj:IsA("Animation") and obj.AnimationId or obj.Value
                end)
                if id and id:find("rbxassetid") then
                    foundAnimId = id; break
                end
            end
        end
    end

    local ids = {}
    if foundAnimId then table.insert(ids, foundAnimId) end
    for _, id in ipairs(WING_ANIM_IDS) do table.insert(ids, id) end
    table.insert(ids, "rbxassetid://616163682") -- superhero fly pose fallback

    for _, animId in ipairs(ids) do
        local ok, track = pcall(function()
            local anim = Instance.new("Animation")
            anim.AnimationId = animId
            local t = animator:LoadAnimation(anim)
            t.Priority = Enum.AnimationPriority.Action4
            t.Looped = true
            t:Play()
            return t
        end)
        if ok and track then
            wingFlapTrack = track
            return
        end
    end
end

local flyLinearVel = nil
local flyAlignOrient = nil

local function stopFly()
    wingsActive = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBodyGyro and flyBodyGyro.Parent then flyBodyGyro:Destroy() end
    if flyBodyVel  and flyBodyVel.Parent  then flyBodyVel:Destroy()  end
    if flyLinearVel and flyLinearVel.Parent then flyLinearVel:Destroy() end
    if flyAlignOrient and flyAlignOrient.Parent then flyAlignOrient:Destroy() end
    flyBodyGyro = nil; flyBodyVel = nil; flyLinearVel = nil; flyAlignOrient = nil
    stopWingAnim()
    detachWingsFromBack()
    local ch = getChar()
    if ch then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.PlatformStand = false end) end
    end
end

local function startFly(tool)
    local ch = getChar()
    if not ch then return end
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    stopFly()
    wingsActive = true

    -- Attach tool or 3D visual wings to back
    if tool and isWingTool(tool) then
        attachHandleToBack(tool)
    else
        create3DWings()
    end

    -- Play flying animation
    task.spawn(playWingAnimation, tool)

    -- BodyGyro / BodyVelocity (Universal compatibility)
    local bg = Instance.new("BodyGyro")
    bg.D = 9999; bg.P = 200000; bg.MaxTorque = Vector3.new(1e8,1e8,1e8)
    bg.CFrame = hrp.CFrame; bg.Parent = hrp
    flyBodyGyro = bg

    local bv = Instance.new("BodyVelocity")
    bv.Velocity  = Vector3.zero
    bv.MaxForce  = Vector3.new(1e8, 1e8, 1e8)
    bv.P = 50000; bv.Parent = hrp
    flyBodyVel = bv

    local SPEED = 45

    flyConn = RunService.Heartbeat:Connect(function()
        if not wingsActive then stopFly(); return end
        local cam = workspace.CurrentCamera
        if not (cam and hrp and hrp.Parent and hum and hum.Parent) then stopFly(); return end

        local cf  = cam.CFrame
        local vel = Vector3.zero
        if UserInput:IsKeyDown(Enum.KeyCode.W) then vel = vel + cf.LookVector end
        if UserInput:IsKeyDown(Enum.KeyCode.S) then vel = vel - cf.LookVector end
        if UserInput:IsKeyDown(Enum.KeyCode.A) then vel = vel - cf.RightVector end
        if UserInput:IsKeyDown(Enum.KeyCode.D) then vel = vel + cf.RightVector end
        if UserInput:IsKeyDown(Enum.KeyCode.Space)      then vel = vel + Vector3.new(0,1,0) end
        if UserInput:IsKeyDown(Enum.KeyCode.LeftShift)  then vel = vel - Vector3.new(0,1,0) end

        if vel.Magnitude > 0 then
            vel = vel.Unit * SPEED
        end

        bv.Velocity = vel
        bg.CFrame   = cf
        pcall(function() hum.PlatformStand = true end)
    end)
end

-- Detect if the currently held tool is a wing-type item
local function isWingTool(tool)
    if not tool then return false end
    local n = tool.Name:lower()
    return n:find("wing") or n:find("kanat") or n:find("fly") or n:find("feather") or n:find("angel")
end

-- Watch character for tool equip to auto-enable wings
local function hookCharWings(ch)
    ch.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and isWingTool(child) then
            task.wait(0.3)
            if not wingsActive then startFly(child) end
        end
    end)
    ch.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and isWingTool(child) then
            if wingsActive then stopFly() end
        end
    end)
end

lp.CharacterAdded:Connect(hookCharWings)
if lp.Character then hookCharWings(lp.Character) end

-- ─────────────────────────────────────────────────────────────
-- CHARACTER SETUP
-- ─────────────────────────────────────────────────────────────
local function setupCharacter(char)
    lastCF = nil; isReverting = false
    task.wait(1)
    updateCache(char)
    char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then table.insert(noclipParts, d) end
    end)
end

lp.CharacterAdded:Connect(function(char)
    setupCharacter(char)
    runPreloadSequence()
end)
if lp.Character then
    task.spawn(setupCharacter, lp.Character)
    task.spawn(runPreloadSequence)
end

-- ─────────────────────────────────────────────────────────────
-- TELEPORT SYSTEM
-- ─────────────────────────────────────────────────────────────
local syncUI

local function stopStalk()
    stalkActive = false; stalkTarget = nil
    lp.ReplicationFocus = nil
    if returnCF then
        local myHRP = myHRPInstance
        if myHRP and myHRP.Parent then
            isReverting = true; myHRP.CFrame = returnCF; isReverting = false
            lastCF = returnCF
            task.spawn(nudgeStreamingFocus, returnCF)
        end
        returnCF = nil
    end
    if syncUI then syncUI() end
end

local function startStalk(player)
    stopStalk()
    stalkTarget = player; stalkActive = true
    if syncUI then syncUI() end

    local myHRP = myHRPInstance
    if not (myHRP and myHRP.Parent) then return end
    if not returnCF then returnCF = myHRP.CFrame end

    local tc = player.Character
    local tHRP = tc and tc:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    -- Instant CFrame Teleport
    local targetCF = tHRP.CFrame * CFrame.new(3, 0, 0)
    isReverting = true
    myHRP.CFrame = targetCF
    isReverting = false
    lastCF = targetCF

    -- Replication Focus & Chunk sweep
    lp.ReplicationFocus = tHRP
    task.spawn(nudgeStreamingFocus, targetCF)
end

-- ═════════════════════════════════════════════════════════════
-- UI CONSTRUCTION (Landscape Rectangle, Left Sidebar Tabs)
-- THEME: Vampire — Blood Red & Deep Black
-- ═════════════════════════════════════════════════════════════
local P = {
    -- Backgrounds (3D Metallic Dark Grey & Silver White Theme)
    bg      = Color3.fromRGB(16, 17, 22),   -- dark metallic grey
    panel   = Color3.fromRGB(22, 24, 30),   -- dark slate panel
    sidebar = Color3.fromRGB(18, 20, 26),   -- deep charcoal sidebar
    header  = Color3.fromRGB(28, 30, 38),   -- sleek dark grey header
    btn     = Color3.fromRGB(34, 37, 46),   -- button base grey
    -- Accent (3D Metallic Slate & Crisp Contrast)
    accent  = Color3.fromRGB(42, 47, 60),   -- dark 3D metallic slate (high contrast for white text)
    accent2 = Color3.fromRGB(60, 68, 86),   -- lighter 3D metallic hover slate
    accentD = Color3.fromRGB(28, 32, 42),   -- deep metallic slate
    -- Text (Crisp Pure White & Light Silver)
    text    = Color3.fromRGB(255, 255, 255),-- pure white text
    sub     = Color3.fromRGB(190, 195, 205),-- light silver text
    -- States
    on      = Color3.fromRGB(60, 120, 210), -- toggle ON = sleek 3D neon blue/silver
    off     = Color3.fromRGB(45,  48,  60),  -- toggle OFF = dark grey
    -- Borders (Pure White & Silver Borders)
    stroke  = Color3.fromRGB(255, 255, 255),-- WHITE border lines
    strokeD = Color3.fromRGB(180, 185, 200),-- WHITE/GREY border
    -- Scrollbar
    scrollC = Color3.fromRGB(240, 240, 245),
}

pcall(function()
    for _, n in ipairs({"WDYM_VAMP_UI"}) do
        local o = CoreGui:FindFirstChild(n)
        if o then o:Destroy() end
    end
end)

local function getIcon22()
    local asset = nil
    pcall(function()
        if getcustomasset then asset = getcustomasset("icon22.png")
        elseif getsynasset then asset = getsynasset("icon22.png") end
    end)
    return asset
end

local GUI = Instance.new("ScreenGui")
GUI.Name = "WDYM_VAMP_UI"; GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local guiParent = (gethui and gethui()) or CoreGui
pcall(function() GUI.Parent = guiParent end)
if not GUI.Parent then GUI.Parent = lp:WaitForChild("PlayerGui") end

local function tw(obj, t, props) TweenSvc:Create(obj,t,props):Play() end
local TI   = TweenInfo.new
local FAST = TI(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local MED  = TI(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- Ultra-Smooth Premium button press & hover animation helper
local function makePremiumButton(btn)
    local origSize = btn.Size
    local origBg = btn.BackgroundColor3
    
    btn.MouseEnter:Connect(function()
        playHover()
        tw(btn, FAST, {
            BackgroundTransparency = 0,
            BorderSizePixel = 0
        })
    end)

    btn.MouseButton1Down:Connect(function()
        tw(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(origSize.X.Scale * 0.96, origSize.X.Offset * 0.96, origSize.Y.Scale * 0.94, origSize.Y.Offset * 0.94)
        })
    end)
    
    local function restore()
        tw(btn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = origSize
        })
    end
    btn.MouseButton1Up:Connect(restore)
    btn.MouseLeave:Connect(restore)
end

-- Landscape: wide & shorter
local W, H    = 520, 310
local SIDEW   = 100  -- left sidebar width

-- ── MAIN FRAME ────────────────────────────────────────────────
local mainFrame = Instance.new("Frame")
mainFrame.Name             = "MainFrame"
mainFrame.Size             = UDim2.new(0, W, 0, H)
mainFrame.Position         = UDim2.new(0.5, -W/2, 0.5, -H/2)
mainFrame.BackgroundColor3 = P.bg
mainFrame.BorderSizePixel  = 0
mainFrame.ClipsDescendants = true
mainFrame.Active           = true
mainFrame.Draggable        = true
mainFrame.ZIndex           = 2
mainFrame.Parent           = GUI

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = P.stroke; mainStroke.Thickness = 1.5; mainStroke.Parent = mainFrame

-- White line at top
local topLine = Instance.new("Frame")
topLine.Size             = UDim2.new(1, 0, 0, 2)
topLine.BackgroundColor3 = P.stroke
topLine.BorderSizePixel  = 0
topLine.ZIndex           = 10
topLine.Parent           = mainFrame

-- Grey/Silver Watermark
local watermark = Instance.new("TextLabel")
watermark.Size             = UDim2.new(0.7, 0, 0.6, 0)
watermark.Position         = UDim2.new(0.5, 0, 0.5, 0)
watermark.AnchorPoint      = Vector2.new(0.5, 0.5)
watermark.BackgroundTransparency = 1
watermark.Text             = "WDYM"
watermark.TextColor3       = Color3.fromRGB(200, 200, 220)
watermark.TextTransparency = 0.92
watermark.Font             = Enum.Font.GothamBold
watermark.TextSize         = 84
watermark.ZIndex           = 3
watermark.Parent           = mainFrame

-- ── HEADER ────────────────────────────────────────────────────
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 38)
header.BackgroundColor3 = P.header
header.BorderSizePixel  = 0
header.ZIndex           = 5
header.Parent           = mainFrame

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = P.stroke; headerStroke.Thickness = 0; headerStroke.Parent = header

-- White bottom border on header
local headerLine = Instance.new("Frame")
headerLine.Size             = UDim2.new(1, 0, 0, 1)
headerLine.Position         = UDim2.new(0, 0, 1, -1)
headerLine.BackgroundColor3 = P.stroke
headerLine.BorderSizePixel  = 0
headerLine.ZIndex           = 6
headerLine.Parent           = header

local hTitle = Instance.new("TextLabel")
hTitle.Size             = UDim2.new(1, -60, 1, 0)
hTitle.Position         = UDim2.new(0, 14, 0, 0)
hTitle.BackgroundTransparency = 1
hTitle.Text             = "WDYM"
hTitle.TextColor3       = Color3.fromRGB(255, 255, 255)
hTitle.Font             = Enum.Font.GothamBold
hTitle.TextSize         = 16
hTitle.TextXAlignment   = Enum.TextXAlignment.Left
hTitle.ZIndex           = 6
hTitle.Parent           = header

-- ── LEFT SIDEBAR ──────────────────────────────────────────────
local sidebar = Instance.new("Frame")
sidebar.Size             = UDim2.new(0, SIDEW, 1, -38)
sidebar.Position         = UDim2.new(0, 0, 0, 38)
sidebar.BackgroundColor3 = P.sidebar
sidebar.BorderSizePixel  = 0
sidebar.ZIndex           = 5
sidebar.Parent           = mainFrame

-- Red right-border: parented to mainFrame so UIListLayout ignores it
local sideBorderLine = Instance.new("Frame")
sideBorderLine.Size             = UDim2.new(0, 1, 1, -38)
sideBorderLine.Position         = UDim2.new(0, SIDEW, 0, 38)
sideBorderLine.BackgroundColor3 = P.strokeD
sideBorderLine.BorderSizePixel  = 0
sideBorderLine.ZIndex           = 8
sideBorderLine.Parent           = mainFrame

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 4); sidePad.PaddingBottom = UDim.new(0, 4)
sidePad.PaddingLeft = UDim.new(0, 6); sidePad.PaddingRight = UDim.new(0, 6)
sidePad.Parent = sidebar

local sideLayout = Instance.new("UIListLayout")
sideLayout.FillDirection = Enum.FillDirection.Vertical
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Padding = UDim.new(0, 4)
sideLayout.Parent = sidebar

-- ── CONTENT AREA ──────────────────────────────────────────────
local contentArea = Instance.new("Frame")
contentArea.Size             = UDim2.new(1, -SIDEW, 1, -38)
contentArea.Position         = UDim2.new(0, SIDEW, 0, 38)
contentArea.BackgroundColor3 = P.panel
contentArea.BorderSizePixel  = 0
contentArea.ClipsDescendants = true
contentArea.ZIndex           = 5
contentArea.Parent           = mainFrame

-- ── TAB SYSTEM ────────────────────────────────────────────────
local TABS = {}
local activeTab = nil

local function switchTab(name)
    if activeTab == name then return end
    activeTab = name
    playClick()
    for n, d in pairs(TABS) do
        local on = (n == name)
        tw(d.btn, FAST, {
            BackgroundColor3       = on and P.btn or P.bg,
            TextColor3             = on and Color3.fromRGB(255, 255, 255) or P.sub,
        })
        -- active tab gets a left indicator line
        if d.indicator then
            tw(d.indicator, FAST, { BackgroundTransparency = on and 0 or 1 })
        end
        
        -- Smooth sliding transitions when selecting category
        if on then
            d.content.Position = UDim2.new(0, 30, 0, 0) -- slightly offset to the right
            d.content.Visible = true
            tw(d.content, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, 0)
            })
        else
            d.content.Visible = false
        end
    end
end

local function makeTab(label, isScrollable)
    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3       = P.bg
    btn.BackgroundTransparency = 0
    btn.BorderSizePixel        = 0
    btn.Text                   = label
    btn.TextColor3             = P.sub
    btn.Font                   = Enum.Font.GothamBold
    btn.TextSize               = 11
    btn.ZIndex                 = 6
    btn.Parent                 = sidebar

    -- Left indicator bar (white/silver line showing active tab)
    local indicator = Instance.new("Frame")
    indicator.Size             = UDim2.new(0, 3, 1, 0)
    indicator.BackgroundColor3 = P.accent
    indicator.BackgroundTransparency = 1  -- hidden by default
    indicator.BorderSizePixel  = 0
    indicator.ZIndex           = 7
    indicator.Parent           = btn

    local content
    if isScrollable then
        content = Instance.new("ScrollingFrame")
        content.Size                   = UDim2.new(1, 0, 1, 0)
        content.BackgroundTransparency = 1
        content.BorderSizePixel        = 0
        content.ScrollBarThickness     = 3
        content.ScrollBarImageColor3   = P.scrollC
        content.CanvasSize             = UDim2.new(0, 0, 0, 0)
        content.AutomaticCanvasSize    = Enum.AutomaticSize.Y
        content.Visible                = false
        content.ZIndex                 = 6
        content.Parent                 = contentArea
    else
        content = Instance.new("Frame")
        content.Size                   = UDim2.new(1, 0, 1, 0)
        content.BackgroundTransparency = 1
        content.BorderSizePixel        = 0
        content.Visible                = false
        content.ZIndex                 = 6
        content.Parent                 = contentArea
    end

    TABS[label] = { btn = btn, content = content, indicator = indicator }
    makePremiumButton(btn) -- apply premium button compression
    
    btn.MouseButton1Click:Connect(function() switchTab(label) end)
    btn.MouseEnter:Connect(function()
        playHover()
        if activeTab ~= label then
            tw(btn, FAST, { BackgroundColor3 = Color3.fromRGB(28, 30, 38), TextColor3 = Color3.fromRGB(255, 255, 255) })
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= label then
            tw(btn, FAST, { BackgroundColor3 = P.bg, TextColor3 = P.sub })
        end
    end)
    return content
end

-- ─────────────────────────────────────────────────────────────
-- VIEW TAB
-- ─────────────────────────────────────────────────────────────
local viewContent = makeTab("View")

local vPad = Instance.new("UIPadding")
vPad.PaddingTop = UDim.new(0,6); vPad.PaddingLeft = UDim.new(0,6); vPad.PaddingRight = UDim.new(0,6)
vPad.Parent = viewContent

local searchBox = Instance.new("TextBox")
searchBox.Size                   = UDim2.new(1, 0, 0, 26)
searchBox.BackgroundColor3       = P.btn
searchBox.BorderSizePixel        = 0
searchBox.PlaceholderText        = "Search player..."
searchBox.PlaceholderColor3      = P.sub
searchBox.Text                   = ""
searchBox.TextColor3             = P.text
searchBox.Font                   = Enum.Font.Gotham
searchBox.TextSize               = 11
searchBox.ZIndex                 = 7
searchBox.Parent                 = viewContent
local sbS = Instance.new("UIStroke"); sbS.Color = P.stroke; sbS.Thickness = 1; sbS.Parent = searchBox

local watchStatus = Instance.new("TextLabel")
watchStatus.Size                   = UDim2.new(1, 0, 0, 16)
watchStatus.Position               = UDim2.new(0, 0, 0, 32)
watchStatus.BackgroundTransparency = 1
watchStatus.Text                   = "Status: Idle"
watchStatus.TextColor3             = P.sub
watchStatus.Font                   = Enum.Font.Code
watchStatus.TextSize               = 10
watchStatus.TextXAlignment         = Enum.TextXAlignment.Left
watchStatus.ZIndex                 = 7
watchStatus.Parent                 = viewContent

local viewScroll = Instance.new("ScrollingFrame")
viewScroll.Size                  = UDim2.new(1, 0, 1, -80)
viewScroll.Position              = UDim2.new(0, 0, 0, 52)
viewScroll.BackgroundColor3      = P.panel
viewScroll.BorderSizePixel       = 0
viewScroll.ScrollBarThickness    = 3
viewScroll.ScrollBarImageColor3  = P.scrollC
viewScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
viewScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
viewScroll.ZIndex                = 7
viewScroll.Parent                = viewContent
local vll = Instance.new("UIListLayout"); vll.Padding = UDim.new(0,3); vll.Parent = viewScroll
local vp2 = Instance.new("UIPadding")
vp2.PaddingTop = UDim.new(0,3); vp2.PaddingLeft = UDim.new(0,2); vp2.PaddingRight = UDim.new(0,2)
vp2.Parent = viewScroll

local releaseBtn = Instance.new("TextButton")
releaseBtn.Size             = UDim2.new(1, 0, 0, 22)
releaseBtn.Position         = UDim2.new(0, 0, 1, -22)
releaseBtn.BackgroundColor3 = P.off
releaseBtn.BorderSizePixel  = 0
releaseBtn.Text             = "Release / Return"
releaseBtn.TextColor3       = P.text
releaseBtn.Font             = Enum.Font.GothamSemibold
releaseBtn.TextSize         = 10
releaseBtn.Visible          = false
releaseBtn.ZIndex           = 7
releaseBtn.Parent           = viewContent
makePremiumButton(releaseBtn) -- apply premium button compression

local function makeViewRow(player)
    local row = Instance.new("Frame")
    row.Name             = player.Name
    row.Size             = UDim2.new(1, -2, 0, 36)
    row.BackgroundColor3 = P.btn
    row.BorderSizePixel  = 0
    row.ZIndex           = 8
    row.Parent           = viewScroll

    local nl = Instance.new("TextLabel")
    nl.Size                   = UDim2.new(1, -90, 1, 0)
    nl.Position               = UDim2.new(0, 8, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Text                   = player.Name
    nl.TextColor3             = P.text
    nl.Font                   = Enum.Font.GothamSemibold
    nl.TextSize               = 11
    nl.TextXAlignment         = Enum.TextXAlignment.Left
    nl.TextTruncate           = Enum.TextTruncate.AtEnd
    nl.ZIndex                 = 9
    nl.Parent                 = row

    local wb = Instance.new("TextButton")
    wb.Size             = UDim2.new(0, 72, 0, 24)
    wb.Position         = UDim2.new(1, -78, 0.5, -12)
    wb.BackgroundColor3 = P.accent
    wb.BorderSizePixel  = 0
    wb.Text             = "Teleport"
    wb.TextColor3       = Color3.new(0,0,0)
    wb.Font             = Enum.Font.GothamBold
    wb.TextSize         = 10
    wb.ZIndex           = 9
    wb.Parent           = row
    makePremiumButton(wb) -- apply premium button compression

    wb.MouseButton1Click:Connect(function()
        playClick()
        startStalk(player)
        watchStatus.Text       = "Watching: " .. player.Name
        watchStatus.TextColor3 = P.accent
        releaseBtn.Visible     = true
    end)
    wb.MouseEnter:Connect(function()
        playHover()
        tw(wb, FAST, { BackgroundColor3 = P.accent2, TextColor3 = P.text })
    end)
    wb.MouseLeave:Connect(function()
        tw(wb, FAST, { BackgroundColor3 = P.accent, TextColor3 = Color3.new(0,0,0) })
    end)
    row.MouseEnter:Connect(function() tw(row, FAST, { BackgroundColor3 = Color3.fromRGB(22,22,22) }) end)
    row.MouseLeave:Connect(function() tw(row, FAST, { BackgroundColor3 = P.btn }) end)
end

local function refreshViewList()
    for _, c in ipairs(viewScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local q = searchBox.Text:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and (q == "" or p.Name:lower():find(q, 1, true)) then
            makeViewRow(p)
        end
    end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(refreshViewList)
Players.PlayerAdded:Connect(function() task.defer(refreshViewList) end)
Players.PlayerRemoving:Connect(function() task.defer(refreshViewList) end)
releaseBtn.MouseButton1Click:Connect(function()
    playClick(); stopStalk()
    watchStatus.Text = "Status: Idle"; watchStatus.TextColor3 = P.sub
    releaseBtn.Visible = false
end)

-- ─────────────────────────────────────────────────────────────
-- UTILITY TAB
-- ─────────────────────────────────────────────────────────────
local utilityContent = makeTab("Utility", true)
local toggleRefs = {}

local uPad = Instance.new("UIPadding")
uPad.PaddingTop = UDim.new(0,6); uPad.PaddingLeft = UDim.new(0,6); uPad.PaddingRight = UDim.new(0,6)
uPad.Parent = utilityContent
local uLayout = Instance.new("UIListLayout"); uLayout.Padding = UDim.new(0,4); uLayout.Parent = utilityContent

local function makeToggle(parent, label, defaultVal, callback)
    local wrap = Instance.new("Frame")
    wrap.Size             = UDim2.new(1, 0, 0, 38)
    wrap.BackgroundColor3 = P.btn
    wrap.BorderSizePixel  = 0
    wrap.ZIndex           = 7
    wrap.Parent           = parent
    local ws = Instance.new("UIStroke"); ws.Color = P.stroke; ws.Thickness = 0.8; ws.Parent = wrap

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, -68, 1, 0)
    lbl.Position         = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = P.text
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 11
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 8
    lbl.Parent           = wrap

    local pillBg = Instance.new("Frame")
    pillBg.Size             = UDim2.new(0, 44, 0, 22)
    pillBg.Position         = UDim2.new(1, -54, 0.5, -11)
    pillBg.BackgroundColor3 = defaultVal and P.on or P.off
    pillBg.BorderSizePixel  = 0
    pillBg.ZIndex           = 8
    pillBg.Parent           = wrap

    local pill = Instance.new("Frame")
    pill.Size             = UDim2.new(0, 16, 0, 16)
    pill.Position         = defaultVal and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    pill.BackgroundColor3 = Color3.fromRGB(0,0,0)
    pill.BorderSizePixel  = 0
    pill.ZIndex           = 9
    pill.Parent           = pillBg

    local valState = defaultVal
    local function sync()
        tw(pillBg, FAST, { BackgroundColor3 = valState and P.on or P.off })
        tw(pill, FAST, { Position = valState and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8) })
    end

    local cz = Instance.new("TextButton")
    cz.Size = UDim2.new(1,0,1,0); cz.BackgroundTransparency = 1; cz.Text = ""; cz.ZIndex = 10
    cz.Parent = wrap
    cz.MouseEnter:Connect(playHover)
    cz.MouseButton1Click:Connect(function()
        playClick()
        valState = not valState
        sync()
        tw(pillBg, TI(0.07), { Size = UDim2.new(0,48,0,24) })
        task.delay(0.07, function() tw(pillBg, TI(0.1), { Size = UDim2.new(0,44,0,22) }) end)
        if callback then callback(valState) end
    end)
end

local function makePill(parent, label, key)
    local wrap = Instance.new("Frame")
    wrap.Size             = UDim2.new(1, 0, 0, 40)
    wrap.BackgroundColor3 = P.btn
    wrap.BorderSizePixel  = 0
    wrap.ZIndex           = 7
    wrap.Parent           = parent
    local ws = Instance.new("UIStroke"); ws.Color = P.stroke; ws.Thickness = 0.8; ws.Parent = wrap

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, -68, 1, 0)
    lbl.Position         = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = P.text
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 11
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 8
    lbl.Parent           = wrap

    local pillBg = Instance.new("Frame")
    pillBg.Size             = UDim2.new(0, 44, 0, 22)
    pillBg.Position         = UDim2.new(1, -54, 0.5, -11)
    pillBg.BackgroundColor3 = CFG[key] and P.on or P.off
    pillBg.BorderSizePixel  = 0
    pillBg.ZIndex           = 8
    pillBg.Parent           = wrap

    local pill = Instance.new("Frame")
    pill.Size             = UDim2.new(0, 16, 0, 16)
    pill.Position         = CFG[key] and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    pill.BackgroundColor3 = Color3.new(0,0,0)
    pill.BorderSizePixel  = 0
    pill.ZIndex           = 9
    pill.Parent           = pillBg

    local function sync()
        tw(pillBg, FAST, { BackgroundColor3 = CFG[key] and P.on or P.off })
        tw(pill, FAST, { Position = CFG[key] and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8) })
    end
    toggleRefs[key] = { sync = sync }

    local cz = Instance.new("TextButton")
    cz.Size = UDim2.new(1,0,1,0); cz.BackgroundTransparency = 1; cz.Text = ""; cz.ZIndex = 10
    cz.Parent = wrap
    cz.MouseEnter:Connect(playHover)
    cz.MouseButton1Click:Connect(function()
        playClick()
        CFG[key] = not CFG[key]
        sync()
        tw(pillBg, TI(0.07), { Size = UDim2.new(0,48,0,24) })
        task.delay(0.07, function() tw(pillBg, TI(0.1), { Size = UDim2.new(0,44,0,22) }) end)
        if key == "ghost" then
            if CFG.ghost then
                local hrp = myHRPInstance
                if hrp then lastCF = hrp.CFrame; createFakeBody(hrp.CFrame); CFG.noclip = true; if toggleRefs["noclip"] then toggleRefs["noclip"].sync() end end
            else
                destroyFakeBody()
                local hrp = myHRPInstance; if hrp then lastCF = hrp.CFrame end
            end
        end
    end)
end

makePill(utilityContent, "Ghost Mode",          "ghost")
makePill(utilityContent, "Anti-TP Protection",  "antiTP")
makePill(utilityContent, "Noclip",              "noclip")
makePill(utilityContent, "Immune (Block Powers)","immune")

-- ─────────────────────────────────────────────────────────────
-- PLAYER TAB
-- ─────────────────────────────────────────────────────────────
local playerContent = makeTab("Player", true)

local ppPad = Instance.new("UIPadding")
ppPad.PaddingTop = UDim.new(0,8); ppPad.PaddingLeft = UDim.new(0,8); ppPad.PaddingRight = UDim.new(0,8)
ppPad.Parent = playerContent
local ppLayout = Instance.new("UIListLayout"); ppLayout.Padding = UDim.new(0,6); ppLayout.Parent = playerContent

local function makeSlider(parent, label, defaultVal, minVal, maxVal, applyFn)
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(1, 0, 0, 52)
    container.BackgroundColor3 = P.btn
    container.BorderSizePixel  = 0
    container.ZIndex           = 7
    container.Parent           = parent
    local cs = Instance.new("UIStroke"); cs.Color = P.stroke; cs.Thickness = 0.8; cs.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(0.6, 0, 0, 20)
    lbl.Position         = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = P.text
    lbl.Font             = Enum.Font.GothamSemibold
    lbl.TextSize         = 11
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 8
    lbl.Parent           = container

    local valLbl = Instance.new("TextLabel")
    valLbl.Size             = UDim2.new(0.4, -10, 0, 20)
    valLbl.Position         = UDim2.new(0.6, 0, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text             = tostring(defaultVal)
    valLbl.TextColor3       = P.accent
    valLbl.Font             = Enum.Font.GothamBold
    valLbl.TextSize         = 11
    valLbl.TextXAlignment   = Enum.TextXAlignment.Right
    valLbl.ZIndex           = 8
    valLbl.Parent           = container

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -20, 0, 6)
    track.Position         = UDim2.new(0, 10, 0, 32)
    track.BackgroundColor3 = P.off
    track.BorderSizePixel  = 0
    track.ZIndex           = 8
    track.Parent           = container

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((defaultVal - minVal)/(maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = P.accent
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 9
    fill.Parent           = track

    local knob = Instance.new("TextButton")
    knob.Size             = UDim2.new(0, 12, 0, 12)
    knob.AnchorPoint      = Vector2.new(0.5, 0.5)
    knob.Position         = UDim2.new((defaultVal - minVal)/(maxVal - minVal), 0, 0.5, 0)
    knob.BackgroundColor3 = P.text
    knob.BorderSizePixel  = 0
    knob.Text             = ""
    knob.ZIndex           = 10
    knob.Parent           = track

    local dragging = false
    local curVal = defaultVal

    knob.MouseButton1Down:Connect(function()
        dragging = true
        playClick()
    end)
    UserInput.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInput.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local trackPos = track.AbsolutePosition
        local trackSize = track.AbsoluteSize
        local rel = math.clamp((inp.Position.X - trackPos.X) / trackSize.X, 0, 1)
        curVal = math.floor(minVal + rel * (maxVal - minVal))
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text = tostring(curVal)
        applyFn(curVal)
    end)
end

-- Invisibility System
local invisConn = nil
local function setInvisibility(enable)
    CFG.invis = enable
    if invisConn then invisConn:Disconnect(); invisConn = nil end

    if enable then
        invisConn = RunService.Heartbeat:Connect(function()
            if not CFG.invis then return end
            local myChar = getChar()
            if myChar then
                for _, p in ipairs(myChar:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.LocalTransparencyModifier = 1
                    elseif p:IsA("Decal") or p:IsA("Texture") then
                        p.Transparency = 1
                    end
                end
            end
        end)
    else
        local myChar = getChar()
        if myChar then
            for _, p in ipairs(myChar:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.LocalTransparencyModifier = 0
                elseif p:IsA("Decal") or p:IsA("Texture") then
                    p.Transparency = 0
                end
            end
        end
    end
end

-- Invisibility Toggle
makeToggle(playerContent, "Invisibility", CFG.invis or false, function(val)
    setInvisibility(val)
end)

-- Speed slider: 16 default, 2-200
makeSlider(playerContent, "Walk Speed", 16, 2, 200, setWalkSpeed)
-- Jump slider: 50 default, 10-300
makeSlider(playerContent, "Jump Power", 50, 10, 300, setJumpPower)

-- ═══════════════════════════════════════════════════════════════
-- WEAPON / ITEM SYSTEM  (Equip · Drop · Wings)
-- ═══════════════════════════════════════════════════════════════
local activeToolRef = nil  -- currently equipped Tool reference

-- Helper: find best tool (backpack first, then character)
local function findBestTool()
    local ch = getChar(); if not ch then return nil end
    local bp = lp:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then return t end end
    end
    for _, t in ipairs(ch:GetChildren()) do if t:IsA("Tool") then return t end end
    return nil
end

-- Helper: equip a specific tool into character
local function doEquip(tool)
    local ch = getChar(); if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum then return false end
    pcall(function() tool.Parent = ch end)
    pcall(function() hum:EquipTool(tool) end)
    activeToolRef = tool
    return true
end

-- ── DIRECT ITEM SELECTOR ─────────────────────────────────────
local itemPanel = Instance.new("Frame")
itemPanel.Size             = UDim2.new(1, 0, 0, 110)
itemPanel.BackgroundColor3 = P.btn
itemPanel.BorderSizePixel  = 0
itemPanel.ZIndex           = 7
itemPanel.Parent           = playerContent
local ips = Instance.new("UIStroke"); ips.Color = P.stroke; ips.Thickness = 0.8; ips.Parent = itemPanel

local itemLbl = Instance.new("TextLabel")
itemLbl.Size             = UDim2.new(1, -10, 0, 18)
itemLbl.Position         = UDim2.new(0, 10, 0, 4)
itemLbl.BackgroundTransparency = 1
itemLbl.Text             = "Item Selector (Click Item to Equip)"
itemLbl.TextColor3       = P.text
itemLbl.Font             = Enum.Font.GothamBold
itemLbl.TextSize         = 11
itemLbl.TextXAlignment   = Enum.TextXAlignment.Left
itemLbl.ZIndex           = 8
itemLbl.Parent           = itemPanel

local itemStatusLbl = Instance.new("TextLabel")
itemStatusLbl.Size             = UDim2.new(1, -10, 0, 14)
itemStatusLbl.Position         = UDim2.new(0, 10, 0, 20)
itemStatusLbl.BackgroundTransparency = 1
itemStatusLbl.Text             = "Scanning Backpack..."
itemStatusLbl.TextColor3       = P.sub
itemStatusLbl.Font             = Enum.Font.GothamBold
itemStatusLbl.TextSize         = 9
itemStatusLbl.TextXAlignment   = Enum.TextXAlignment.Left
itemStatusLbl.ZIndex           = 8
itemStatusLbl.Parent           = itemPanel

-- Scroll container for direct item buttons
local itemScroll = Instance.new("ScrollingFrame")
itemScroll.Size                  = UDim2.new(1, -16, 0, 42)
itemScroll.Position              = UDim2.new(0, 8, 0, 36)
itemScroll.BackgroundTransparency= 1
itemScroll.BorderSizePixel       = 0
itemScroll.ScrollBarThickness    = 3
itemScroll.ScrollBarImageColor3  = P.scrollC
itemScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
itemScroll.AutomaticCanvasSize   = Enum.AutomaticSize.X
itemScroll.ZIndex                = 8
itemScroll.Parent                = itemPanel

local isl = Instance.new("UIListLayout")
isl.FillDirection = Enum.FillDirection.Horizontal
isl.Padding = UDim.new(0, 6)
isl.Parent = itemScroll

-- Single Drop Button
local dropBtn = Instance.new("TextButton")
dropBtn.Size             = UDim2.new(1, -16, 0, 22)
dropBtn.Position         = UDim2.new(0, 8, 0, 82)
dropBtn.BackgroundColor3 = P.off
dropBtn.BorderSizePixel  = 0
dropBtn.Text             = "Drop Active Item"
dropBtn.TextColor3       = P.text
dropBtn.Font             = Enum.Font.GothamBold
dropBtn.TextSize         = 10
dropBtn.ZIndex           = 9
dropBtn.Parent           = itemPanel
makePremiumButton(dropBtn)

local function refreshItemList()
    for _, c in ipairs(itemScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    
    local foundTools = {}
    local bp = lp:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then table.insert(foundTools, t) end
        end
    end
    local ch = getChar()
    if ch then
        for _, t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") then table.insert(foundTools, t) end
        end
    end

    if #foundTools == 0 then
        itemStatusLbl.Text = "No items in inventory"
    else
        itemStatusLbl.Text = #foundTools .. " items ready - Click to equip"
    end

    for _, tool in ipairs(foundTools) do
        local ibtn = Instance.new("TextButton")
        ibtn.Size             = UDim2.new(0, 110, 1, 0)
        ibtn.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
        ibtn.BorderSizePixel  = 0
        ibtn.Text             = tool.Name
        ibtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        ibtn.Font             = Enum.Font.GothamBold
        ibtn.TextSize         = 10
        ibtn.ZIndex           = 9
        ibtn.Parent           = itemScroll

        local ibCorner = Instance.new("UICorner")
        ibCorner.CornerRadius = UDim.new(0, 4)
        ibCorner.Parent = ibtn

        local ibStroke = Instance.new("UIStroke")
        ibStroke.Color = Color3.fromRGB(180, 190, 210)
        ibStroke.Thickness = 1
        ibStroke.Parent = ibtn

        local ibGrad = Instance.new("UIGradient")
        ibGrad.Rotation = 90
        ibGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 60, 76)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 26, 34))
        })
        ibGrad.Parent = ibtn

        makePremiumButton(ibtn)

        ibtn.MouseButton1Click:Connect(function()
            playClick()
            if doEquip(tool) then
                itemStatusLbl.Text = "Equipped: " .. tool.Name
                if isWingTool(tool) and not wingsActive then
                    startFly(tool)
                end
            end
        end)
    end
end

-- Auto refresh inventory buttons
pcall(function()
    local bp = lp:WaitForChild("Backpack", 3)
    if bp then
        bp.ChildAdded:Connect(function() task.defer(refreshItemList) end)
        bp.ChildRemoved:Connect(function() task.defer(refreshItemList) end)
    end
end)
task.spawn(function() task.wait(1); refreshItemList() end)

-- Drop functionality
dropBtn.MouseButton1Click:Connect(function()
    playClick()
    local ch = getChar(); if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")

    local dropped = false
    for _, t in ipairs(ch:GetChildren()) do
        if t:IsA("Tool") then
            if isWingTool(t) and wingsActive then stopFly() end
            pcall(function()
                if hum then hum:UnequipTools() end
                t.Parent = lp:FindFirstChildOfClass("Backpack") or lp
            end)
            itemStatusLbl.Text = "Dropped: " .. t.Name
            activeToolRef = nil
            dropped = true
        end
    end
    if not dropped then itemStatusLbl.Text = "Nothing to drop" end
    task.defer(refreshItemList)
end)

-- High-Priority ContextActionService tool override to guarantee item clicks/actions replicate and work
pcall(function()
    local CAS = game:GetService("ContextActionService")
    CAS:BindActionAtPriority("WDYM_ToolOverride", function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            local ch = getChar()
            local held = ch and ch:FindFirstChildOfClass("Tool")
            if held then
                -- Activate the tool
                pcall(function() held:Activate() end)
                
                -- Fire any tool remotes (lick/use/eat)
                for _, child in ipairs(held:GetDescendants()) do
                    if child:IsA("RemoteEvent") then
                        pcall(function() child:FireServer() end)
                        pcall(function() child:FireServer(true) end)
                        pcall(function() child:FireServer("Lick") end)
                        pcall(function() child:FireServer("Eat") end)
                        pcall(function() child:FireServer("Use") end)
                    elseif child:IsA("BindableEvent") then
                        pcall(function() child:Fire() end)
                    end
                end
                return Enum.ContextActionResult.Sink -- Sink the click input so the game knows it was used on item
            end
        end
        return Enum.ContextActionResult.Pass
    end, false, 999999, Enum.UserInputType.MouseButton1)
end)

-- Wings toggle row
local wingsWrap = Instance.new("Frame")
wingsWrap.Size             = UDim2.new(1, 0, 0, 40)
wingsWrap.BackgroundColor3 = P.btn
wingsWrap.BorderSizePixel  = 0
wingsWrap.ZIndex           = 7
wingsWrap.Parent           = playerContent
local wwss = Instance.new("UIStroke"); wwss.Color = P.stroke; wwss.Thickness = 0.8; wwss.Parent = wingsWrap

local wingsLbl = Instance.new("TextLabel")
wingsLbl.Size             = UDim2.new(1, -120, 1, 0)
wingsLbl.Position         = UDim2.new(0, 12, 0, 0)
wingsLbl.BackgroundTransparency = 1
wingsLbl.Text             = "Force Fly (Wings)"
wingsLbl.TextColor3       = P.text
wingsLbl.Font             = Enum.Font.GothamBold
wingsLbl.TextSize         = 11
wingsLbl.TextXAlignment   = Enum.TextXAlignment.Left
wingsLbl.ZIndex           = 8
wingsLbl.Parent           = wingsWrap

local wingsBtn = Instance.new("TextButton")
wingsBtn.Size             = UDim2.new(0, 88, 0, 24)
wingsBtn.Position         = UDim2.new(1, -96, 0.5, -12)
wingsBtn.BackgroundColor3 = P.off
wingsBtn.BorderSizePixel  = 0
wingsBtn.Text             = "Fly OFF"
wingsBtn.TextColor3       = P.text
wingsBtn.Font             = Enum.Font.GothamBold
wingsBtn.TextSize         = 10
wingsBtn.ZIndex           = 9
wingsBtn.Parent           = wingsWrap
wingsBtn.MouseEnter:Connect(playHover)
makePremiumButton(wingsBtn) -- apply premium button compression

wingsBtn.MouseButton1Click:Connect(function()
    playClick()
    if wingsActive then
        stopFly()
        tw(wingsBtn, FAST, { BackgroundColor3 = P.off, TextColor3 = P.text })
        wingsBtn.Text = "Fly OFF"
    else
        startFly()
        tw(wingsBtn, FAST, { BackgroundColor3 = P.accent, TextColor3 = P.text })
        wingsBtn.Text = "Fly ON"
    end
end)

-- ─────────────────────────────────────────────────────────────
-- ESP TAB
-- ─────────────────────────────────────────────────────────────
local espContent = makeTab("ESP", true)

local espPad = Instance.new("UIPadding")
espPad.PaddingTop = UDim.new(0,6); espPad.PaddingLeft = UDim.new(0,6); espPad.PaddingRight = UDim.new(0,6); espPad.PaddingBottom = UDim.new(0,6)
espPad.Parent = espContent

local espList = Instance.new("UIListLayout")
espList.FillDirection = Enum.FillDirection.Vertical
espList.Padding = UDim.new(0, 6)
espList.Parent = espContent

-- Master Toggles
makeToggle(espContent, "All Players ESP", CFG.espAll, function(val)
    CFG.espAll = val
end)

makeToggle(espContent, "Name ESP", CFG.espName, function(val)
    CFG.espName = val
end)

makeToggle(espContent, "Box / Chams ESP", CFG.espBox, function(val)
    CFG.espBox = val
end)

makeToggle(espContent, "Distance ESP", CFG.espDistance, function(val)
    CFG.espDistance = val
end)

-- Targeted Player ESP Panel
local espTargetPanel = Instance.new("Frame")
espTargetPanel.Size             = UDim2.new(1, 0, 0, 95)
espTargetPanel.BackgroundColor3 = P.btn
espTargetPanel.BorderSizePixel  = 0
espTargetPanel.ZIndex           = 7
espTargetPanel.Parent           = espContent
local etps = Instance.new("UIStroke"); etps.Color = P.stroke; etps.Thickness = 0.8; etps.Parent = espTargetPanel

local espTargetLbl = Instance.new("TextLabel")
espTargetLbl.Size             = UDim2.new(1, -10, 0, 18)
espTargetLbl.Position         = UDim2.new(0, 10, 0, 4)
espTargetLbl.BackgroundTransparency = 1
espTargetLbl.Text             = "Target Specific Player ESP"
espTargetLbl.TextColor3       = P.text
espTargetLbl.Font             = Enum.Font.GothamBold
espTargetLbl.TextSize         = 11
espTargetLbl.TextXAlignment   = Enum.TextXAlignment.Left
espTargetLbl.ZIndex           = 8
espTargetLbl.Parent           = espTargetPanel

local espTargetStatus = Instance.new("TextLabel")
espTargetStatus.Size             = UDim2.new(1, -10, 0, 14)
espTargetStatus.Position         = UDim2.new(0, 10, 0, 20)
espTargetStatus.BackgroundTransparency = 1
espTargetStatus.Text             = CFG.espTarget and ("Targeting: " .. CFG.espTarget.Name) or "Target: None (Click below)"
espTargetStatus.TextColor3       = P.sub
espTargetStatus.Font             = Enum.Font.GothamBold
espTargetStatus.TextSize         = 9
espTargetStatus.TextXAlignment   = Enum.TextXAlignment.Left
espTargetStatus.ZIndex           = 8
espTargetStatus.Parent           = espTargetPanel

local espPlayerScroll = Instance.new("ScrollingFrame")
espPlayerScroll.Size                  = UDim2.new(1, -16, 0, 42)
espPlayerScroll.Position              = UDim2.new(0, 8, 0, 36)
espPlayerScroll.BackgroundTransparency= 1
espPlayerScroll.BorderSizePixel       = 0
espPlayerScroll.ScrollBarThickness    = 3
espPlayerScroll.ScrollBarImageColor3  = P.scrollC
espPlayerScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
espPlayerScroll.AutomaticCanvasSize   = Enum.AutomaticSize.X
espPlayerScroll.ZIndex                = 8
espPlayerScroll.Parent                = espTargetPanel

local epsl = Instance.new("UIListLayout")
epsl.FillDirection = Enum.FillDirection.Horizontal
epsl.Padding = UDim.new(0, 6)
epsl.Parent = espPlayerScroll

local function refreshESPPlayerList()
    for _, c in ipairs(espPlayerScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size             = UDim2.new(0, 70, 1, 0)
    clearBtn.BackgroundColor3 = P.off
    clearBtn.BorderSizePixel  = 0
    clearBtn.Text             = "Clear Target"
    clearBtn.TextColor3       = P.text
    clearBtn.Font             = Enum.Font.GothamBold
    clearBtn.TextSize         = 10
    clearBtn.ZIndex           = 9
    clearBtn.Parent           = espPlayerScroll
    makePremiumButton(clearBtn)
    clearBtn.MouseButton1Click:Connect(function()
        playClick()
        CFG.espTarget = nil
        espTargetStatus.Text = "Target: None (Click below)"
        refreshESPPlayerList()
    end)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            local isSel = (CFG.espTarget == p)
            local pbtn = Instance.new("TextButton")
            pbtn.Size             = UDim2.new(0, 100, 1, 0)
            pbtn.BackgroundColor3 = isSel and P.accent or P.btn
            pbtn.BorderSizePixel  = 0
            pbtn.Text             = p.Name
            pbtn.TextColor3       = isSel and Color3.new(0,0,0) or P.text
            pbtn.Font             = Enum.Font.GothamBold
            pbtn.TextSize         = 10
            pbtn.ZIndex           = 9
            pbtn.Parent           = espPlayerScroll
            makePremiumButton(pbtn)

            pbtn.MouseButton1Click:Connect(function()
                playClick()
                CFG.espTarget = p
                espTargetStatus.Text = "Targeting: " .. p.Name
                refreshESPPlayerList()
            end)
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- PIANO TAB & ENGINE SYSTEM
-- ─────────────────────────────────────────────────────────────
local pianoContent = makeTab("Piano", true)

local pianoPad = Instance.new("UIPadding")
pianoPad.PaddingTop = UDim.new(0,6); pianoPad.PaddingLeft = UDim.new(0,6); pianoPad.PaddingRight = UDim.new(0,6); pianoPad.PaddingBottom = UDim.new(0,6)
pianoPad.Parent = pianoContent

local pianoList = Instance.new("UIListLayout")
pianoList.FillDirection = Enum.FillDirection.Vertical
pianoList.Padding = UDim.new(0, 6)
pianoList.Parent = pianoContent

local charToKeyCode = {
    ['a'] = Enum.KeyCode.A, ['b'] = Enum.KeyCode.B, ['c'] = Enum.KeyCode.C, ['d'] = Enum.KeyCode.D,
    ['e'] = Enum.KeyCode.E, ['f'] = Enum.KeyCode.F, ['g'] = Enum.KeyCode.G, ['h'] = Enum.KeyCode.H,
    ['i'] = Enum.KeyCode.I, ['j'] = Enum.KeyCode.J, ['k'] = Enum.KeyCode.K, ['l'] = Enum.KeyCode.L,
    ['m'] = Enum.KeyCode.M, ['n'] = Enum.KeyCode.N, ['o'] = Enum.KeyCode.O, ['p'] = Enum.KeyCode.P,
    ['q'] = Enum.KeyCode.Q, ['r'] = Enum.KeyCode.R, ['s'] = Enum.KeyCode.S, ['t'] = Enum.KeyCode.T,
    ['u'] = Enum.KeyCode.U, ['v'] = Enum.KeyCode.V, ['w'] = Enum.KeyCode.W, ['x'] = Enum.KeyCode.X,
    ['y'] = Enum.KeyCode.Y, ['z'] = Enum.KeyCode.Z,
    ['0'] = Enum.KeyCode.Zero, ['1'] = Enum.KeyCode.One, ['2'] = Enum.KeyCode.Two, ['3'] = Enum.KeyCode.Three,
    ['4'] = Enum.KeyCode.Four, ['5'] = Enum.KeyCode.Five, ['6'] = Enum.KeyCode.Six, ['7'] = Enum.KeyCode.Seven,
    ['8'] = Enum.KeyCode.Eight, ['9'] = Enum.KeyCode.Nine,
    ['!'] = Enum.KeyCode.One, ['@'] = Enum.KeyCode.Two, ['#'] = Enum.KeyCode.Three, ['$'] = Enum.KeyCode.Four,
    ['%'] = Enum.KeyCode.Five, ['^'] = Enum.KeyCode.Six, ['&'] = Enum.KeyCode.Seven, ['*'] = Enum.KeyCode.Eight,
    ['('] = Enum.KeyCode.Nine, [')'] = Enum.KeyCode.Zero,
}

local pianoPlaying     = false
local pianoSpeed       = 1.0
local currentPianoSong = "Golden Hour"
local currentPianoSheet= "[et] u o p [et] u o p [wt] u o p [wt] u o p [qt] u o p [qt] u o p [0t] u o p [0t] u o p [et] u o p [et] u o p [wt] u o p [wt] u o p"
local autoPlayOnSeat   = true

local function pressPianoKeyDirect(char)
    local isUpper = (char:match("%A") == nil) and (char == char:upper()) and (char:lower() ~= char:upper())
    local isShiftSymbol = (char:match("[%!%@%#%$%%%^%&%*%(%)]") ~= nil)
    local needShift = isUpper or isShiftSymbol
    local lowerChar = char:lower()
    local kc = charToKeyCode[lowerChar]

    if kc then
        pcall(function()
            if needShift then VIM:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game) end
            VIM:SendKeyEvent(true, kc, false, game)
            VIM:SendKeyEvent(false, kc, false, game)
            if needShift then VIM:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game) end
        end)
    end
end

local function playChordDirect(chordStr)
    for cIdx = 1, #chordStr do
        local note = chordStr:sub(cIdx, cIdx)
        pressPianoKeyDirect(note)
    end
end

local function stopPianoSheet()
    pianoPlaying = false
end

-- Controls panel
local pianoStatusLbl = Instance.new("TextLabel")
pianoStatusLbl.Size             = UDim2.new(1, 0, 0, 16)
pianoStatusLbl.BackgroundTransparency = 1
pianoStatusLbl.Text             = "Status: Ready · Song: " .. currentPianoSong
pianoStatusLbl.TextColor3       = P.sub
pianoStatusLbl.Font             = Enum.Font.GothamBold
pianoStatusLbl.TextSize         = 9
pianoStatusLbl.TextXAlignment   = Enum.TextXAlignment.Left
pianoStatusLbl.ZIndex           = 7
pianoStatusLbl.Parent           = pianoContent

local function playPianoSheet(sheet)
    stopPianoSheet()
    task.wait(0.05)
    pianoPlaying = true
    pianoStatusLbl.Text = "Status: Playing... (" .. currentPianoSong .. ")"
    pianoStatusLbl.TextColor3 = Color3.fromRGB(100, 220, 120)
    
    local i = 1
    local len = #sheet
    local baseDelay = 0.08 / pianoSpeed

    while i <= len and pianoPlaying do
        local ch = sheet:sub(i, i)
        if ch == "[" or ch == "(" then
            local closingChar = (ch == "[") and "]" or ")"
            local closeIdx = sheet:find(closingChar, i + 1, true)
            if closeIdx then
                local chordStr = sheet:sub(i + 1, closeIdx - 1)
                playChordDirect(chordStr)
                i = closeIdx + 1
                task.wait(baseDelay * 1.1)
            else
                i = i + 1
            end
        elseif ch == " " or ch == "|" then
            task.wait(baseDelay * 0.8)
            i = i + 1
        elseif ch == "-" then
            task.wait(baseDelay * 1.2)
            i = i + 1
        elseif ch == "\n" or ch == "\r" then
            task.wait(baseDelay * 1.5)
            i = i + 1
        else
            pressPianoKeyDirect(ch)
            task.wait(baseDelay)
            i = i + 1
        end
    end
    pianoPlaying = false
    pianoStatusLbl.Text = "Status: Finished / Stopped"
    pianoStatusLbl.TextColor3 = P.sub
end

-- Auto-Play toggle
makeToggle(pianoContent, "Auto-Play On Piano Seat", autoPlayOnSeat, function(val)
    autoPlayOnSeat = val
end)

-- Piano Playback Speed Slider
makeSlider(pianoContent, "Piano Speed %", 100, 40, 300, function(val)
    pianoSpeed = val / 100
end)

-- Play / Stop Row
local pBtnRow = Instance.new("Frame")
pBtnRow.Size             = UDim2.new(1, 0, 0, 32)
pBtnRow.BackgroundTransparency = 1
pBtnRow.ZIndex           = 7
pBtnRow.Parent           = pianoContent

local pPlayBtn = Instance.new("TextButton")
pPlayBtn.Size             = UDim2.new(0.48, 0, 1, 0)
pPlayBtn.Position         = UDim2.new(0, 0, 0, 0)
pPlayBtn.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
pPlayBtn.BorderSizePixel  = 0
pPlayBtn.Text             = "Play Song"
pPlayBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
pPlayBtn.Font             = Enum.Font.GothamBold
pPlayBtn.TextSize         = 10
pPlayBtn.ZIndex           = 8
pPlayBtn.Parent           = pBtnRow
local ppbC = Instance.new("UICorner"); ppbC.CornerRadius = UDim.new(0,4); ppbC.Parent = pPlayBtn
local ppbS = Instance.new("UIStroke"); ppbS.Color = Color3.fromRGB(180, 190, 210); ppbS.Thickness = 1; ppbS.Parent = pPlayBtn
local ppbG = Instance.new("UIGradient"); ppbG.Rotation = 90; ppbG.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(54,60,76)), ColorSequenceKeypoint.new(1, Color3.fromRGB(24,26,34))}); ppbG.Parent = pPlayBtn
makePremiumButton(pPlayBtn)

pPlayBtn.MouseButton1Click:Connect(function()
    playClick()
    task.spawn(playPianoSheet, currentPianoSheet)
end)

local pStopBtn = Instance.new("TextButton")
pStopBtn.Size             = UDim2.new(0.48, 0, 1, 0)
pStopBtn.Position         = UDim2.new(0.52, 0, 0, 0)
pStopBtn.BackgroundColor3 = P.off
pStopBtn.BorderSizePixel  = 0
pStopBtn.Text             = "Stop Song"
pStopBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
pStopBtn.Font             = Enum.Font.GothamBold
pStopBtn.TextSize         = 10
pStopBtn.ZIndex           = 8
pStopBtn.Parent           = pBtnRow
local psbC = Instance.new("UICorner"); psbC.CornerRadius = UDim.new(0,4); psbC.Parent = pStopBtn
makePremiumButton(pStopBtn)

pStopBtn.MouseButton1Click:Connect(function()
    playClick()
    stopPianoSheet()
end)

-- Custom Piano Sheet Input Box
local sheetInputPanel = Instance.new("Frame")
sheetInputPanel.Size             = UDim2.new(1, 0, 0, 50)
sheetInputPanel.BackgroundColor3 = P.btn
sheetInputPanel.BorderSizePixel  = 0
sheetInputPanel.ZIndex           = 7
sheetInputPanel.Parent           = pianoContent
local sips = Instance.new("UIStroke"); sips.Color = P.stroke; sips.Thickness = 0.8; sips.Parent = sheetInputPanel

local sheetInputLbl = Instance.new("TextLabel")
sheetInputLbl.Size             = UDim2.new(1, -10, 0, 14)
sheetInputLbl.Position         = UDim2.new(0, 10, 0, 4)
sheetInputLbl.BackgroundTransparency = 1
sheetInputLbl.Text             = "Custom Sheet (Paste your own piano notes):"
sheetInputLbl.TextColor3       = P.text
sheetInputLbl.Font             = Enum.Font.GothamBold
sheetInputLbl.TextSize         = 10
sheetInputLbl.TextXAlignment   = Enum.TextXAlignment.Left
sheetInputLbl.ZIndex           = 8
sheetInputLbl.Parent           = sheetInputPanel

local sheetBox = Instance.new("TextBox")
sheetBox.Size                   = UDim2.new(1, -16, 0, 24)
sheetBox.Position               = UDim2.new(0, 8, 0, 20)
sheetBox.BackgroundColor3       = Color3.fromRGB(16, 18, 24)
sheetBox.BorderSizePixel        = 0
sheetBox.PlaceholderText        = "Type/Paste piano sheet (e.g. [et] u o p ...)"
sheetBox.PlaceholderColor3      = P.sub
sheetBox.Text                   = currentPianoSheet
sheetBox.TextColor3             = Color3.fromRGB(255, 255, 255)
sheetBox.Font                   = Enum.Font.GothamBold
sheetBox.TextSize               = 9
sheetBox.ClearTextOnFocus       = false
sheetBox.ZIndex                 = 8
sheetBox.Parent                 = sheetInputPanel
local sbStroke = Instance.new("UIStroke"); sbStroke.Color = P.stroke; sbStroke.Thickness = 0.8; sbStroke.Parent = sheetBox

sheetBox:GetPropertyChangedSignal("Text"):Connect(function()
    currentPianoSheet = sheetBox.Text
    currentPianoSong  = "Custom Sheet"
end)

-- Preset Popular Songs List
local PRESET_SONGS = {
    {
        name = "Golden Hour (JVKE)",
        sheet = "[et] u o p [et] u o p [wt] u o p [wt] u o p [qt] u o p [qt] u o p [0t] u o p [0t] u o p [et] u o p [et] u o p [wt] u o p [wt] u o p"
    },
    {
        name = "Rush E (Meme Fast)",
        sheet = "[uO] [uO] [uO] [uO] [uO] [uO] [uO] [uO] u i o p a s d f g h j k l z x c v b n m u i o p a s d f g h j k l"
    },
    {
        name = "Interstellar Theme",
        sheet = "[uo] p a [uo] p a [uo] p a [uo] p a [yoi] p a [yoi] p a [yoi] p a [uo] p a [uo] p a"
    },
    {
        name = "Fur Elise (Beethoven)",
        sheet = "e W e W e 0 d s a [80a] u o p [70a] y o a [60a] u o p e W e W e 0 d s a [80a] u o p [70a] y o a"
    },
    {
        name = "He's a Pirate",
        sheet = "a s d d d f g g g f d s a s d d d f g g g f d s a s d d d f g g g f d s"
    },
    {
        name = "River Flows In You",
        sheet = "[3o] o o [7o] o o [6o] p a [5o] o o [4o] o o [3o] p a [3o] o o [7o] o o [6o] p a"
    },
}

local songHeader = Instance.new("TextLabel")
songHeader.Size             = UDim2.new(1, 0, 0, 14)
songHeader.BackgroundTransparency = 1
songHeader.Text             = "Select Preset Popular Song:"
songHeader.TextColor3       = P.text
songHeader.Font             = Enum.Font.GothamBold
songHeader.TextSize         = 10
songHeader.TextXAlignment   = Enum.TextXAlignment.Left
songHeader.ZIndex           = 7
songHeader.Parent           = pianoContent

for _, sData in ipairs(PRESET_SONGS) do
    local sBtn = Instance.new("TextButton")
    sBtn.Size             = UDim2.new(1, 0, 0, 30)
    sBtn.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
    sBtn.BorderSizePixel  = 0
    sBtn.Text             = sData.name
    sBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    sBtn.Font             = Enum.Font.GothamBold
    sBtn.TextSize         = 10
    sBtn.ZIndex           = 8
    sBtn.Parent           = pianoContent

    local sCorner = Instance.new("UICorner"); sCorner.CornerRadius = UDim.new(0, 4); sCorner.Parent = sBtn
    local sStroke = Instance.new("UIStroke"); sStroke.Color = Color3.fromRGB(180, 190, 210); sStroke.Thickness = 1; sStroke.Parent = sBtn
    local sGrad   = Instance.new("UIGradient"); sGrad.Rotation = 90
    sGrad.Color   = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(54,60,76)), ColorSequenceKeypoint.new(1, Color3.fromRGB(24,26,34))})
    sGrad.Parent  = sBtn

    makePremiumButton(sBtn)

    sBtn.MouseButton1Click:Connect(function()
        playClick()
        currentPianoSong  = sData.name
        currentPianoSheet = sData.sheet
        sheetBox.Text     = sData.sheet
        task.spawn(playPianoSheet, currentPianoSheet)
    end)
end

-- Hook Humanoid Seated Event to auto-play when player sits on Piano
local function hookPianoSeat(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Seated:Connect(function(isSeated, seat)
            if isSeated and autoPlayOnSeat then
                local seatName = seat and seat.Name:lower() or ""
                if seatName:find("piano") or seatName:find("bench") or seatName:find("seat") or seatName:find("chair") then
                    if currentPianoSheet ~= "" and not pianoPlaying then
                        task.wait(0.6)
                        task.spawn(playPianoSheet, currentPianoSheet)
                    end
                end
            end
        end)
    end
end

lp.CharacterAdded:Connect(hookPianoSeat)
if lp.Character then task.spawn(hookPianoSeat, lp.Character) end

-- ─────────────────────────────────────────────────────────────
-- EMOTES TAB
-- ─────────────────────────────────────────────────────────────
local emoteContent = makeTab("Emotes")

local ePad = Instance.new("UIPadding")
ePad.PaddingTop = UDim.new(0,6); ePad.PaddingLeft = UDim.new(0,6); ePad.PaddingRight = UDim.new(0,6)
ePad.Parent = emoteContent

local emoteStatus = Instance.new("TextLabel")
emoteStatus.Size                   = UDim2.new(1, 0, 0, 14)
emoteStatus.BackgroundTransparency = 1
emoteStatus.Text                   = "Click an emote to play it"
emoteStatus.TextColor3             = P.sub
emoteStatus.Font                   = Enum.Font.Code
emoteStatus.TextSize               = 9
emoteStatus.TextXAlignment         = Enum.TextXAlignment.Left
emoteStatus.ZIndex                 = 7
emoteStatus.Parent                 = emoteContent

local emoteScroll = Instance.new("ScrollingFrame")
emoteScroll.Size                  = UDim2.new(1, 0, 1, -20)
emoteScroll.Position              = UDim2.new(0, 0, 0, 18)
emoteScroll.BackgroundTransparency= 1
emoteScroll.BorderSizePixel       = 0
emoteScroll.ScrollBarThickness    = 3
emoteScroll.ScrollBarImageColor3  = P.scrollC
emoteScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
emoteScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
emoteScroll.ZIndex                = 7
emoteScroll.Parent                = emoteContent

-- 2-column grid for clean text buttons
local emoteGrid = Instance.new("UIGridLayout")
emoteGrid.CellSize               = UDim2.new(0.5, -4, 0, 36)
emoteGrid.CellPadding            = UDim2.new(0, 4, 0, 4)
emoteGrid.SortOrder              = Enum.SortOrder.LayoutOrder
emoteGrid.Parent                 = emoteScroll

-- Current playing emote track
local currentEmoteTrack = nil
local function stopCurrentEmote()
    if currentEmoteTrack then
        pcall(function() currentEmoteTrack:Stop(0.2) end)
        currentEmoteTrack = nil
    end
end

local function playEmote(animId, name)
    local ch = getChar(); if not ch then emoteStatus.Text = "No character"; return end
    local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then animator = Instance.new("Animator"); animator.Parent = hum end

    stopCurrentEmote()

    local ok, track = pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = animId
        local t = animator:LoadAnimation(anim)
        t.Priority = Enum.AnimationPriority.Action4  -- Highest priority to override animations
        t:Play()
        return t
    end)
    if ok and track then
        currentEmoteTrack = track
        emoteStatus.Text = "Playing: " .. name
        
        -- Fire any emote RemoteEvents in ReplicatedStorage to tell the server/others we're dancing
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            for _, child in ipairs(rs:GetDescendants()) do
                if child:IsA("RemoteEvent") then
                    local ln = child.Name:lower()
                    if ln:find("emote") or ln:find("dance") or ln:find("animation") or ln:find("play") then
                        child:FireServer(name)
                        child:FireServer(animId)
                    end
                end
            end
        end)

        -- Auto-stop after the animation finishes (for non-looping ones)
        track.Stopped:Connect(function()
            if currentEmoteTrack == track then
                currentEmoteTrack = nil
                emoteStatus.Text = "Click an emote to play it"
            end
        end)
    else
        emoteStatus.Text = "Failed: " .. name
    end
end

-- Palette of colors for emote cards (cycles through)
local EMOTE_COLORS = {
    Color3.fromRGB(24,24,24), Color3.fromRGB(18,18,18),
    Color3.fromRGB(14,14,14), Color3.fromRGB(28,28,28),
}

local function makeEmoteCard(name, animId, icon, layoutOrder)
    local card = Instance.new("TextButton")
    card.Size             = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3 = P.btn
    card.BorderSizePixel  = 0
    card.Text             = name
    card.TextColor3       = Color3.fromRGB(255, 255, 255)
    card.Font             = Enum.Font.GothamBold
    card.TextSize         = 10
    card.TextWrapped      = true
    card.ZIndex           = 8
    card.LayoutOrder      = layoutOrder
    card.Parent           = emoteScroll
    
    local cs = Instance.new("UIStroke")
    cs.Color = P.stroke -- White border line
    cs.Thickness = 0.8
    cs.Parent = card

    makePremiumButton(card) -- apply premium button compression

    card.MouseEnter:Connect(function()
        playHover()
        tw(card, FAST, { BackgroundColor3 = Color3.fromRGB(35, 35, 35) })
    end)
    card.MouseLeave:Connect(function()
        tw(card, FAST, { BackgroundColor3 = P.btn })
    end)
    card.MouseButton1Click:Connect(function()
        playClick()
        if currentEmoteTrack and emoteStatus.Text == "Playing: " .. name then
            stopCurrentEmote()
            emoteStatus.Text = "Stopped: " .. name
        else
            playEmote(animId, name)
        end
    end)
end

-- Seed list of known Neighbors Shop Emotes
local SHOP_EMOTES = {
    { name = "MopAction",      id = "rbxassetid://10714340543" },
    { name = "IdleToSit",      id = "rbxassetid://2506281703" },
    { name = "Sleep",          id = "rbxassetid://2506281703" },
    { name = "WakingUp",       id = "rbxassetid://10714341000" },
    { name = "Petting",        id = "rbxassetid://10714341500" },
    { name = "PushUps",        id = "rbxassetid://3381587039" },
    { name = "DoubleWave",     id = "rbxassetid://507770239" },
    { name = "SideLay",        id = "rbxassetid://3365925086" },
    { name = "Dab",            id = "rbxassetid://3061489905" },
    { name = "Barbell",        id = "rbxassetid://616163682" },
    { name = "BowDown",        id = "rbxassetid://3435765323" },
    { name = "CircleDance",    id = "rbxassetid://507771019" },
    { name = "Hug",            id = "rbxassetid://616159208" },
    { name = "Sit",            id = "rbxassetid://2506281703" },
}

-- ── Scan game for Neighbors animations & Shop Emotes ───────────
local function scanGameEmotes()
    local found = {}
    local seenNames = {}
    local seenIds = {}

    local function addEmote(name, id)
        if not seenNames[name] and not seenIds[id] then
            seenNames[name] = true
            seenIds[id] = true
            table.insert(found, { name = name, id = id })
        end
    end

    -- Seed known Shop Emotes first
    for _, se in ipairs(SHOP_EMOTES) do
        addEmote(se.name, se.id)
    end

    local function checkAnim(obj, sourceName)
        if not (obj:IsA("Animation") or (obj:IsA("StringValue") and obj.Name:lower():find("anim"))) then return end
        local id = ""
        pcall(function()
            id = obj:IsA("Animation") and (obj.AnimationId ~= "" and obj.AnimationId or obj) or obj.Value
        end)
        local name = (obj.Name ~= "" and obj.Name ~= "Animation") and obj.Name or (sourceName or "Emote")
        local ln = name:lower()
        local isDefaultCore = (ln == "walk" or ln == "run" or ln == "idle" or ln == "jump" or 
                               ln == "fall" or ln == "climb" or ln == "swim" or ln == "toolnone")
        if not isDefaultCore then
            addEmote(name, id ~= "" and id or obj)
        end
    end

    -- Look in ReplicatedStorage (Shop, Emotes, Items, Animations)
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        for _, obj in ipairs(rs:GetDescendants()) do
            checkAnim(obj, obj.Parent and obj.Parent.Name)
        end
    end)

    -- Look in PlayerGui / StarterPlayer
    pcall(function()
        local sp = game:GetService("StarterPlayer")
        for _, obj in ipairs(sp:GetDescendants()) do
            checkAnim(obj, obj.Parent and obj.Parent.Name)
        end
    end)

    -- Look in Character
    pcall(function()
        local ch = getChar()
        if ch then
            for _, obj in ipairs(ch:GetDescendants()) do
                checkAnim(obj, obj.Parent and obj.Parent.Name)
            end
        end
    end)

    return found
end

-- Append game-specific emotes
task.spawn(function()
    task.wait(2)  -- wait for game assets to fully replicate
    local gameEmotes = scanGameEmotes()
    for i, e in ipairs(gameEmotes) do
        makeEmoteCard(e.name, e.id, e.icon, i)
    end
    if #gameEmotes > 0 then
        emoteStatus.Text = "Neighbors Emotes loaded: " .. #gameEmotes
    else
        emoteStatus.Text = "No custom emotes found in game storage"
    end
end)

-- Apply premium press animations to all emote cards
-- (Integrated directly into makeEmoteCard via makePremiumButton)

-- ─────────────────────────────────────────────────────────────
-- syncUI
-- ─────────────────────────────────────────────────────────────
syncUI = function()
    for _, ref in pairs(toggleRefs) do
        if ref.sync then ref.sync() end
    end
end

-- ─────────────────────────────────────────────────────────────
-- SHOW/HIDE TOGGLE (Alt Keys)
-- ─────────────────────────────────────────────────────────────
local uiVisible = true

local function toggleUI()
    playClick()
    uiVisible = not uiVisible
    mainFrame.Visible = uiVisible
end

-- Keybind toggle: Right Alt / Left Alt
UserInput.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightAlt or inp.KeyCode == Enum.KeyCode.LeftAlt then
        toggleUI()
    end
end)

-- ── ACTIVATE DEFAULT TAB ─────────────────────────────────────
activeTab = "View"
TABS["View"].btn.BackgroundColor3       = P.accent
TABS["View"].btn.BackgroundTransparency = 0
TABS["View"].btn.TextColor3             = P.text
TABS["View"].content.Visible            = true
if TABS["View"].indicator then TABS["View"].indicator.BackgroundTransparency = 0 end
refreshViewList()

mainFrame.Visible = true
