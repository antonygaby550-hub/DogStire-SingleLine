-- Libraries
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
local Window = Library:CreateWindow({
    Title = 'DogStire V1',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})
-- Tabs
local Tabs = {
    Combat = Window:AddTab('Combat'),
    Visuals = Window:AddTab('Visuals'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
    World = Window:AddTab('World'), -- Nuevo tab World
}
-- =====================
-- COMBAT / SILENT AIM
-- =====================
local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer
local mouse = plr:GetMouse()
local camera = game:GetService("Workspace").CurrentCamera
-- Silent Aim Configuration
local SilentAimEnabled = false
local SilentAimFOV = 100
local HitPart = "Head" -- Can be changed to "Head", "HumanoidRootPart", etc.
-- New Aimbot Configuration
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local CircleRadius = 200
local BulletSpeed = 2200
local GRAVITY = Workspace.Gravity
local VELOCITY_MULTIPLIER = 1.12
local GRAVITY_COMPENSATION = 1.15
-- Cambiado a color rojo
local OriginalCircleColor = Color3.fromRGB(255, 0, 0)
local CircleVisible = false
local AimingEnabled = false
local RightMouseButtonHeld = false
local PredictionX = 0.7
local PredictionY = 0.7
local SmoothFactor = 1.5
local TargetPlayer = nil
local RainbowEnabled = false
-- Circle Drawing
local Circle = Drawing.new("Circle")
Circle.Visible = false -- Inicialmente invisible
Circle.Thickness = 2
Circle.NumSides = 50
Circle.Radius = CircleRadius
Circle.Filled = false
Circle.Transparency = 0.5
Circle.Color = OriginalCircleColor
-- Debug Line
local DebugLine = Drawing.new("Line")
DebugLine.Thickness = 2
DebugLine.Transparency = 0.8
DebugLine.Visible = false
-- Player Box
local PlayerBox = Drawing.new("Square")
PlayerBox.Visible = false
PlayerBox.Thickness = 2
PlayerBox.Filled = true
PlayerBox.Transparency = 1
-- Cambiado a color blanco
PlayerBox.Color = Color3.new(1, 3, 1)
-- Player Name Text
local PlayerNameText = Drawing.new("Text")
PlayerNameText.Visible = false
PlayerNameText.Center = true
PlayerNameText.Outline = true
PlayerNameText.Font = 2
PlayerNameText.Size = 16
PlayerNameText.Color = Color3.new(1, 3, 1)
-- Functions
function notBehindWall(target)
    local ray = Ray.new(plr.Character.Head.Position,
        (target.Position - plr.Character.Head.Position).Unit * 300)
    local part, position = game:GetService("Workspace"):FindPartOnRayWithIgnoreList(ray, {plr.Character}, false, true)
    if part then
        local humanoid = part.Parent:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            humanoid = part.Parent.Parent:FindFirstChildOfClass("Humanoid")
        end
        if humanoid and target and humanoid.Parent == target.Parent then
            local pos, visible = camera:WorldToScreenPoint(target.Position)
            if visible then
                return true
            end
        end
    end
end
function getPlayerClosestToMouse()
    local target = nil
    local maxDist = SilentAimFOV
    for _, v in pairs(plrs:GetPlayers()) do
        if v.Character then
            if v.Character:FindFirstChild("Humanoid") 
                and v.Character.Humanoid.Health ~= 0 
                and v.Character:FindFirstChild("HumanoidRootPart") 
                and v.TeamColor ~= plr.TeamColor then
                local pos, vis = camera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
                local dist = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(pos.X, pos.Y)).magnitude
                if dist < maxDist and vis then
                    local targetPart = v.Character:FindFirstChild(HitPart) or v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("HumanoidRootPart")
                    if notBehindWall(targetPart) then
                        target = targetPart
                    end
                    maxDist = dist
                end
            end
        end
    end
    return target
end
function getBulletSpeed()
    local weapon = LocalPlayer:FindFirstChild("CurrentSelectedObject")
    if weapon and weapon.Value then
        local data = ReplicatedStorage:FindFirstChild("GunData"):FindFirstChild(weapon.Value.Name)
        if data and data:FindFirstChild("Stats") and data.Stats:FindFirstChild("BulletSettings") then
            local speed = data.Stats.BulletSettings:FindFirstChild("BulletSpeed")
            if speed then return speed.Value end
        end
    end
    return BulletSpeed
end
function findNearestTargetToCenter()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closest, minDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("ServerColliderHead") then
            local pos = Camera:WorldToViewportPoint(player.Character.ServerColliderHead.Position)
            local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
            if dist <= CircleRadius and dist < minDist then
                minDist = dist
                closest = player
            end
        end
    end
    return closest
end
function aimAtTarget()
    if not TargetPlayer or not TargetPlayer.Character then return end
    local head = TargetPlayer.Character:FindFirstChild("ServerColliderHead")
    if not head then return end
    local bulletSpeed = getBulletSpeed()
    local distance = (head.Position - Camera.CFrame.Position).Magnitude
    local time = distance / bulletSpeed
    local prediction = head.Velocity * time * PredictionX
    local drop = Vector3.new(0, -0.5 * GRAVITY * time^2 * GRAVITY_COMPENSATION * PredictionY, 0)
    local aimPos = head.Position + prediction - drop
    local screenPos, onScreen = Camera:WorldToViewportPoint(aimPos)
    if RightMouseButtonHeld and AimingEnabled and onScreen then
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local delta = Vector2.new(screenPos.X, screenPos.Y) - center
        delta = Vector2.new(math.clamp(delta.X, -50, 50), math.clamp(delta.Y, -50, 50))
        mousemoverel(delta.X * SmoothFactor, delta.Y * SmoothFactor)
    end
end
function updateDebugLine()
    if not TargetPlayer or not TargetPlayer.Character then 
        DebugLine.Visible = false 
        return 
    end
    local head = TargetPlayer.Character:FindFirstChild("ServerColliderHead")
    if not head then 
        DebugLine.Visible = false 
        return 
    end
    local predicted = head.Position + head.Velocity * 0.1
    local screenFrom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local screenTo3D = Camera:WorldToViewportPoint(predicted)
    DebugLine.From = screenFrom
    DebugLine.To = Vector2.new(screenTo3D.X, screenTo3D.Y)
    DebugLine.Visible = true
    DebugLine.Color = Color3.fromHSV((tick() % 5) / 5, 1, 1)
end
function updatePlayerBox(player)
    local head = player and player.Character and player.Character:FindFirstChild("ServerColliderHead")
    if not head then 
        PlayerBox.Visible = false 
        PlayerNameText.Visible = false 
        return 
    end
    local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then 
        PlayerBox.Visible = false 
        PlayerNameText.Visible = false 
        return 
    end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local gap, width, height = 10, 70, 25
    local boxPos = Vector2.new(center.X - width / 2, center.Y + CircleRadius + gap)
    PlayerBox.Position = boxPos
    PlayerBox.Size = Vector2.new(width, height)
    PlayerBox.Color = Color3.new(1, 1, 1)
    PlayerBox.Visible = true
    PlayerNameText.Position = Vector2.new(center.X, boxPos.Y - 18)
    PlayerNameText.Text = player.Name
    PlayerNameText.Color = PlayerBox.Color
    PlayerNameText.Visible = true
end
function updateCirclePosition()
    local screenSize = Camera.ViewportSize
    Circle.Position = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
    
    -- Cambiar color según el modo
    if RainbowEnabled then
        Circle.Color = Color3.fromHSV((tick() % 5) / 5, 1, 1)
    else
        Circle.Color = OriginalCircleColor
    end
    
    -- El círculo siempre es visible si el aimbot está activado
    Circle.Visible = AimingEnabled and CircleVisible
end
-- Remote Hook
local gmt = getrawmetatable(game)
setreadonly(gmt, false)
local oldNamecall = gmt.__namecall
gmt.__namecall = newcclosure(function(self, ...)
    local Args = {...}
    local method = getnamecallmethod()
    
    if SilentAimEnabled and tostring(method) == "FireServer" and tostring(self) == "HitPart" then
        local target = getPlayerClosestToMouse()
        if target then
            Args[1] = target
            Args[2] = target.Position
        end
    end
    
    return oldNamecall(self, unpack(Args))
end)
setreadonly(gmt, true)
-- Input Connections
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        RightMouseButtonHeld = true
        AimingEnabled = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        RightMouseButtonHeld = false
        -- No cambiamos AimingEnabled aquí para que el círculo permanezca visible
    end
end)
-- RenderStepped Connection
RunService.RenderStepped:Connect(function()
    updateCirclePosition()
    TargetPlayer = findNearestTargetToCenter()
    updateDebugLine()
    aimAtTarget()
    updatePlayerBox(TargetPlayer)
end)
-- ======================
-- AIMBOT FUNCTIONS
-- ======================
-- ======================
-- MENU / SLIDERS / TOGGLES
-- ======================
local AimbotGroup = Tabs.Combat:AddLeftGroupbox("Aimbot Settings")
AimbotGroup:AddToggle("ToggleAimbot", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(v)
        AimingEnabled = v
        CircleVisible = v
    end
})
AimbotGroup:AddSlider("FOVSlider", {
    Text = "Aimbot FOV",
    Default = CircleRadius,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Suffix = "px",
    Callback = function(v)
        CircleRadius = v
        Circle.Radius = v
    end
})
AimbotGroup:AddSlider("CircleSizeSlider", {
    Text = "Circle Thickness",
    Default = Circle.Thickness,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Suffix = "px",
    Callback = function(v)
        Circle.Thickness = v
    end
})
AimbotGroup:AddToggle("RainbowCircleToggle", {
    Text = "Rainbow Circle",
    Default = false,
    Callback = function(v)
        RainbowEnabled = v
    end
})
AimbotGroup:AddSlider("PredictionXSlider", {
    Text = "Prediction X",
    Default = PredictionX,
    Min = 0,
    Max = 2,
    Rounding = 2,
    Callback = function(v)
        PredictionX = v
    end
})
AimbotGroup:AddSlider("PredictionYSlider", {
    Text = "Prediction Y",
    Default = PredictionY,
    Min = 0,
    Max = 2,
    Rounding = 2,
    Callback = function(v)
        PredictionY = v
    end
})
AimbotGroup:AddSlider("SmoothFactorSlider", {
    Text = "Smooth Factor",
    Default = SmoothFactor,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Callback = function(v)
        SmoothFactor = v
    end
})
AimbotGroup:AddToggle("ToggleSilentAim", {
    Text = "Enable Silent Aim",
    Default = false,
    Callback = function(v)
        SilentAimEnabled = v
    end
})
AimbotGroup:AddSlider("SilentAimFOVSlider", {
    Text = "Silent Aim FOV",
    Default = SilentAimFOV,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Suffix = "px",
    Callback = function(v)
        SilentAimFOV = v
    end
})
AimbotGroup:AddDropdown("HitPartDropdown", {
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Default = "Head",
    Text = "Target Hit Part",
    Callback = function(v)
        HitPart = v
    end
})
-- ======================
-- VISUALS / ESP
-- ======================
local VisualGroup = Tabs.Visuals:AddLeftGroupbox("ESP / Skeleton")
VisualGroup.Position = UDim2.new(0,0,0,150)
-- Inventory Viewer
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local boxWidth = 280
local lineSpacing = 20
local box = Drawing.new("Square")
box.Filled = true
box.Transparency = 0.5
box.Color = Color3.new(0, 0, 0)
box.Visible = false
box.ZIndex = 1
local textLines = {}
local maxLines = 20
for i = 1, maxLines do
    local t = Drawing.new("Text")
    t.Size = 16
    t.Color = Color3.new(1, 1, 1)
    t.Outline = true
    t.Font = 2
    t.Visible = false
    t.ZIndex = 2
    table.insert(textLines, t)
end
local function updateBoxHeight(lineCount)
    local height = lineCount * lineSpacing + 10
    box.Size = Vector2.new(boxWidth, height)
end
local dragging = false
local dragStartPos = nil
local mouseStartPos = nil
box.Position = Vector2.new(Camera.ViewportSize.X - boxWidth - 20, 20)
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = Vector2.new(Mouse.X, Mouse.Y)
        if mousePos.X >= box.Position.X and mousePos.X <= box.Position.X + box.Size.X and
           mousePos.Y >= box.Position.Y and mousePos.Y <= box.Position.Y + box.Size.Y then
            dragging = true
            dragStartPos = box.Position
            mouseStartPos = mousePos
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = Vector2.new(Mouse.X, Mouse.Y) - mouseStartPos
        local newPos = dragStartPos + delta
        box.Position = newPos
        for i, t in ipairs(textLines) do
            if t.Visible then
                t.Position = Vector2.new(newPos.X + 5, newPos.Y + 5 + (i - 1) * lineSpacing)
            end
        end
    end
end)
local function getGunInfoLines(target)
    local lines = {}
    if not target or not target:FindFirstChild("GunInventory") then
        table.insert(lines, "No target")
        return lines
    end
    table.insert(lines, target.Name .. "'s Inventory")
    local gunInventory = target:FindFirstChild("GunInventory")
    local gunObjects = gunInventory:GetChildren()
    if #gunObjects == 0 then
        table.insert(lines, "No guns")
        return lines
    end
    for _, gunObj in ipairs(gunObjects) do
        if gunObj:IsA("ObjectValue") and gunObj.Value then
            local gunName = tostring(gunObj.Value)
            local scopeText = "No scope"
            local reticleObj = gunObj:FindFirstChild("AttachmentReticle")
            if reticleObj and reticleObj:IsA("ObjectValue") and reticleObj.Value then
                scopeText = tostring(reticleObj.Value) .. "x scope"
            end
            table.insert(lines, gunName .. " - " .. scopeText)
            local mag = gunObj:FindFirstChild("BulletsInMagazine")
            local reserve = gunObj:FindFirstChild("BulletsInReserve")
            if mag and reserve and mag:IsA("IntValue") and reserve:IsA("IntValue") then
                table.insert(lines, tostring(mag.Value) .. " / " .. tostring(reserve.Value))
            end
        end
    end
    return lines
end
local function getClosestPlayerToCenter()
    local closestPlayer = nil
    local closestDist = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local screenPos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end
-- Skeleton
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local CharactersFolder = workspace:WaitForChild("Characters")
local SkeletonEnabled = false
local MinSkeletonDistance = 4
local MaxSkeletonDistance = 3000
-- Cambiado a color blanco y grosor más delgado
local function createLine()
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = Color3.new(1, 1, 1)
    line.Thickness = 1
    line.Transparency = 1
    return line
end
local R15Bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
}
local skeletonLines = {}
local function createSkeleton(character)
    local lines = {}
    for _, bone in ipairs(R15Bones) do
        local part0 = character:FindFirstChild(bone[1])
        local part1 = character:FindFirstChild(bone[2])
        if part0 and part1 then
            local line = createLine()
            table.insert(lines, {line = line, part0 = part0, part1 = part1})
        end
    end
    return lines
end
local function updateSkeleton(character, lines)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local distance = (Camera.CFrame.Position - root.Position).Magnitude
    if not SkeletonEnabled or distance < MinSkeletonDistance or distance > MaxSkeletonDistance then
        for _, data in pairs(lines) do
            data.line.Visible = false
        end
        return
    end
    for _, data in pairs(lines) do
        local pos0, onScreen0 = Camera:WorldToViewportPoint(data.part0.Position)
        local pos1, onScreen1 = Camera:WorldToViewportPoint(data.part1.Position)
        if onScreen0 and onScreen1 then
            data.line.From = Vector2.new(pos0.X, pos0.Y)
            data.line.To = Vector2.new(pos1.X, pos1.Y)
            data.line.Visible = true
        else
            data.line.Visible = false
        end
    end
end
local function clearSkeleton(lines)
    for _, data in pairs(lines) do
        data.line.Visible = false
        data.line:Remove()
    end
end
local function updateInventoryViewer()
    local target = getClosestPlayerToCenter()
    local lines = getGunInfoLines(target)
    updateBoxHeight(#lines)
    for i, t in ipairs(textLines) do
        t.Visible = false
    end
    for i, line in ipairs(lines) do
        local t = textLines[i]
        t.Text = line
        t.Visible = true
        t.Position = Vector2.new(box.Position.X + 5, box.Position.Y + 5 + (i - 1) * lineSpacing)
    end
end
-- ESP Config
local ESPConfig = {
    ESPEnabled = false,
    DistanceEnabled = true,
    BoxEnabled = true,
    NameEnabled = true,
    RefreshRate = 0.1,
    MaxDistance = 2400,
    Colors = {
        -- Cambiado a color blanco
        Box = Color3.fromRGB(255, 255, 255),
        Distance = Color3.fromRGB(0, 255, 0),
        Name = Color3.fromRGB(0, 0, 255),
        Skeleton = Color3.fromRGB(255, 255, 255)
    }
}
local ESPStorage = {}
local R15BonesESP = {
    {"Head", "UpperTorso"},{"UpperTorso", "LowerTorso"},{"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},{"LeftLowerLeg", "LeftFoot"},{"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},{"RightLowerLeg", "RightFoot"},{"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},{"LeftLowerArm", "LeftHand"},{"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},{"RightLowerArm", "RightHand"}
}
local function createLineESP()
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = ESPConfig.Colors.Skeleton
    line.Thickness = 1
    line.Transparency = 1
    return line
end
local function createESP(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local box = Drawing.new("Square"); box.Visible = false; box.Color = ESPConfig.Colors.Box; box.Thickness = 1; box.Transparency = 1; box.Filled = false
    local distance = Drawing.new("Text"); distance.Visible = false; distance.Size = 16; distance.Center = true; distance.Outline = true; distance.Color = ESPConfig.Colors.Distance
    local name = Drawing.new("Text"); name.Visible = false; name.Size = 16; name.Center = true; name.Outline = true; name.Color = ESPConfig.Colors.Name; name.Text = player.Name
    local skeletonLines = {}
    for _, bone in ipairs(R15BonesESP) do
        local part0 = char:FindFirstChild(bone[1])
        local part1 = char:FindFirstChild(bone[2])
        if part0 and part1 then
            table.insert(skeletonLines, {line = createLineESP(), part0 = part0, part1 = part1})
        end
    end
    ESPStorage[player] = {Box = box, Distance = distance, Name = name, Skeleton = skeletonLines}
end
local function removeESP(player)
    local esp = ESPStorage[player]
    if esp then
        for _, obj in pairs(esp) do
            if typeof(obj) == "table" then
                for _, l in pairs(obj) do l.line:Remove() end
            else obj:Remove() end
        end
        ESPStorage[player] = nil
    end
end
local function updateESP()
    if not ESPConfig.ESPEnabled then
        for _, player in pairs(plrs:GetPlayers()) do
            if ESPStorage[player] then
                removeESP(player)
            end
        end
        return
    end
    
    for _, player in pairs(plrs:GetPlayers()) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if player ~= LocalPlayer and char and hrp then
            local esp = ESPStorage[player]
            if not esp then createESP(player); esp = ESPStorage[player] end
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0,2.5,0))
            local distanceToPlayer = (Camera.CFrame.Position - hrp.Position).Magnitude
            if onScreen and distanceToPlayer <= ESPConfig.MaxDistance then
                local scale = 1 / (screenPos.Z * math.tan(math.rad(Camera.FieldOfView*0.5))*2)*1000
                local width,height = math.floor(4.5*scale), math.floor(6*scale)
                local x,y = math.floor(screenPos.X), math.floor(screenPos.Y)
                local xPos,yPos = math.floor(x-width*0.5), math.floor(y-height*0.5)
                if ESPConfig.BoxEnabled then 
                    esp.Box.Size = Vector2.new(width,height); 
                    esp.Box.Position = Vector2.new(xPos,yPos); 
                    esp.Box.Visible = true 
                else 
                    esp.Box.Visible = false 
                end
                if ESPConfig.DistanceEnabled then 
                    esp.Distance.Text = string.format("[ %dm ]",math.floor(distanceToPlayer)); 
                    esp.Distance.Position = Vector2.new(x,yPos+height+14); 
                    esp.Distance.Visible = true 
                else 
                    esp.Distance.Visible = false 
                end
                if ESPConfig.NameEnabled then 
                    esp.Name.Text = player.Name; 
                    esp.Name.Position = Vector2.new(x,yPos-18); 
                    esp.Name.Visible = true 
                else 
                    esp.Name.Visible = false 
                end
                if SkeletonEnabled then
                    for _, data in pairs(esp.Skeleton) do
                        local pos0,on0 = Camera:WorldToViewportPoint(data.part0.Position)
                        local pos1,on1 = Camera:WorldToViewportPoint(data.part1.Position)
                        if on0 and on1 then 
                            data.line.From = Vector2.new(pos0.X,pos0.Y); 
                            data.line.To = Vector2.new(pos1.X,pos1.Y); 
                            data.line.Visible = true 
                        else 
                            data.line.Visible = false 
                        end
                    end
                else 
                    for _, data in pairs(esp.Skeleton) do 
                        data.line.Visible = false 
                    end
                end
            else
                esp.Box.Visible=false; 
                esp.Distance.Visible=false; 
                if esp.Name then 
                    esp.Name.Visible=false 
                end; 
                for _,data in pairs(esp.Skeleton) do 
                    data.line.Visible=false 
                end
            end
        elseif ESPStorage[player] then 
            removeESP(player) 
        end
    end
end
for _,player in ipairs(plrs:GetPlayers()) do createESP(player) end
plrs.PlayerAdded:Connect(createESP)
plrs.PlayerRemoving:Connect(removeESP)
RunService.RenderStepped:Connect(function()
    if ESPConfig.ESPEnabled then 
        updateESP() 
    end
    
    if SkeletonEnabled then
        for character, lines in pairs(skeletonLines) do
            if not character:IsDescendantOf(CharactersFolder) then
                clearSkeleton(lines)
                skeletonLines[character] = nil
            else
                updateSkeleton(character, lines)
            end
        end
        for _, character in ipairs(CharactersFolder:GetChildren()) do
            if not skeletonLines[character] then
                skeletonLines[character] = createSkeleton(character)
            end
        end
    else
        for character, lines in pairs(skeletonLines) do
            clearSkeleton(lines)
        end
        skeletonLines = {}
    end
    
    updateInventoryViewer()
end)
-- Visual Toggles
VisualGroup:AddToggle('EnableESP', {Text='Enable ESP', Default=false, Callback=function(v) 
    ESPConfig.ESPEnabled = v
    if not v then
        for _, player in pairs(plrs:GetPlayers()) do
            if ESPStorage[player] then
                removeESP(player)
            end
        end
    end
end})
VisualGroup:AddToggle('EnableBox', {Text='Enable Box', Default=true, Callback=function(v) ESPConfig.BoxEnabled=v end})
VisualGroup:AddToggle('EnableName', {Text='Enable Name', Default=true, Callback=function(v) ESPConfig.NameEnabled=v end})
VisualGroup:AddToggle('EnableDistance', {Text='Enable Distance', Default=true, Callback=function(v) ESPConfig.DistanceEnabled=v end})
VisualGroup:AddToggle('EnableSkeleton', {Text='Enable Skeleton', Default=false, Callback=function(v) 
    SkeletonEnabled = v
    if not v then
        for character, lines in pairs(skeletonLines) do
            clearSkeleton(lines)
        end
        skeletonLines = {}
    end
end})
VisualGroup:AddToggle('EnableInventoryViewer', {Text='Enable Inventory Viewer', Default=false, Callback=function(v) box.Visible = v end})
-- ======================
-- WORLD SETTINGS
-- ======================
local ws = game:GetService("Workspace")
local NoLeavesEnabled = false

-- Función para eliminar hojas
local function removeLeaves()
    for _,v in ipairs(ws:GetDescendants()) do
        if v:IsA("Part") or v:IsA("MeshPart") then
            local name = v.Name:lower()
            if name:find("leaf") or name:find("leaves") or name:find("foliage") then
                v.Transparency = 1
                v.CanCollide = false
            end
        elseif v:IsA("Decal") or v:IsA("Texture") then
            local name = v.Name:lower()
            if name:find("leaf") or name:find("leaves") then
                v:Destroy()
            end
        end
    end
    print("[Tree Cleaner] hojas eliminadas.")
end

-- Función para restaurar hojas
local function restoreLeaves()
    for _,v in ipairs(ws:GetDescendants()) do
        if v:IsA("Part") or v:IsA("MeshPart") then
            local name = v.Name:lower()
            if name:find("leaf") or name:find("leaves") or name:find("foliage") then
                v.Transparency = 0
                v.CanCollide = true
            end
        end
    end
    print("[Tree Cleaner] hojas restauradas.")
end

-- Inicialmente no hacemos nada, se activará con el toggle
print("[Tree Cleaner] Modo inactivo. Usa el toggle para activar/desactivar.")

-- ======================
-- UI SETTINGS
-- ======================
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu Keybind' })
Library.ToggleKeybind = Options.MenuKeybind

-- World Toggles
local WorldGroup = Tabs.World:AddLeftGroupbox('World Settings')
WorldGroup:AddToggle('NoLeavesToggle', {
    Text = 'No Leaves',
    Default = false,
    Callback = function(v)
        NoLeavesEnabled = v
        if v then
            removeLeaves()
        else
            restoreLeaves()
        end
    end
})

-- Theme/Save managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:BuildConfigSection(Tabs['UI Settings'])
-- Notification
local StarterGui = game:GetService("StarterGui")
StarterGui:SetCore("SendNotification", {
    Title = "Sensei/Wazaaa|Aimbot Loaded",
    Text = "Hold MouseButton2 to aim",
    Duration = 5
})
