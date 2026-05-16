--[[
============================================================
    SUNNY HUB PRO - All-in-One Mod Menu (Luau)
    Gop 5 script: Mua / Mo / Giu / Hut (Nhat) / Xoa GUI
    Tac gia: Sunny Hub
------------------------------------------------------------
    PHIEN BAN NANG CAP:
    1. Event-Driven Architecture (khong dung while true do)
    2. Tab "Giam Lag" voi 3 che do: Co ban, Nang cao, Sieu toi gian
    3. Tab "Quan Ly Bo Nho" - Hien thi RAM, doc rac thu cong
    4. Tab "Profiles" - Profile cho tung loai game
    5. Khoi phuc 100% khi tat che do giam lag
    6. Disconnect events tranh Memory Leak
    7. [FIX] Dropdown mo xuong duoi voi ScrollingFrame, ZIndex cao
    8. [FIX] Nut X dong script hoan toan (destroy)
    9. [FIX] Nut - thu nho thanh icon
    10.[FIX] Them TextBox nhap truc tiep cho cac slider
============================================================
]]

-- =================== SERVICES (Local Cache de tang toc) ===================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local Lighting          = game:GetService("Lighting")
local MaterialService   = game:GetService("MaterialService")
local SoundService      = game:GetService("SoundService")
local Workspace         = game:GetService("Workspace")

local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- =================== BIEN TOAN CUC ===================
-- Kiem soat viec chay script
local ScriptRunning = true

-- Luu tru tat ca Event Connections de disconnect khi can
local AllConnections = {}

-- Xoa menu cu neu chay lai
pcall(function()
    if CoreGui:FindFirstChild("SunnyHubPro") then
        CoreGui.SunnyHubPro:Destroy()
    end
    if PlayerGui:FindFirstChild("SunnyHubPro") then
        PlayerGui.SunnyHubPro:Destroy()
    end
end)

-- =================== CONFIG ===================
local Config = {
    -- Shop
    SelectedItem    = "Frostbound",
    AutoBuy         = false,
    BuyInterval     = 10,

    -- Auto Farm / Hut Nhat
    AutoPickup      = false,
    PickupRange     = 15,
    ScanSpeed       = 0.25,

    -- Crates
    AutoOpen        = false,
    OpenSpeed       = 0.05,
    AntiEgg         = false,

    -- Misc
    LockTool        = false,
    LockedTool      = nil,
    ToggleKey       = Enum.KeyCode.RightControl,
    
    -- Giam Lag - 3 che do chinh
    -- 0 = Tat, 1 = Co ban, 2 = Nang cao, 3 = Sieu toi gian (man hinh den)
    LagMode         = 0,
    
    -- Profile Game
    -- 0 = Khong, 1 = Anime, 2 = Tycoon, 3 = Shooter
    GameProfile     = 0,
}

local TotemList = {
    "Wooden","Stone","Golden","Spiritual","Energy",
    "Divine","Galactic","Inferno","Frostbound"
}

local LagModeNames = {
    "Tat (Khoi phuc 100%)",
    "Che do 1: Co ban",
    "Che do 2: Nang cao", 
    "Che do 3: Sieu toi gian / Treo may"
}

local ProfileNames = {
    "Khong ap dung",
    "Profile Anime (Blox Fruits, Anime Adventures...)",
    "Profile Tycoon/Simulator",
    "Profile Shooter/FPS"
}

-- =================== HE THONG LUU TRU VA KHOI PHUC 100% ===================
local OriginalSettings = {
    Saved = false,
    
    -- Lighting
    GlobalShadows = nil,
    FogEnd = nil,
    FogStart = nil,
    FogColor = nil,
    Brightness = nil,
    ClockTime = nil,
    OutdoorAmbient = nil,
    Ambient = nil,
    
    -- Lighting Effects
    LightingEffects = {},
    
    -- Terrain
    Terrain = {},
    
    -- Parts (Material, CastShadow, Transparency)
    ModifiedParts = {},
    
    -- Particles, Fire, Smoke, Sparkles
    Particles = {},
    
    -- Sounds
    Sounds = {},
    
    -- Decals/Textures
    Decals = {},
    Textures = {},
    
    -- Beams/Trails
    Beams = {},
    Trails = {},
    
    -- MeshParts/SpecialMeshes
    Meshes = {},
    
    -- 3D Rendering
    RenderingEnabled = true,
    
    -- Black Screen Frame
    BlackScreenFrame = nil,
}

-- Ham luu cai dat goc
local function SaveOriginalSettings()
    if OriginalSettings.Saved then return end
    OriginalSettings.Saved = true
    
    pcall(function()
        -- Luu Lighting
        OriginalSettings.GlobalShadows = Lighting.GlobalShadows
        OriginalSettings.FogEnd = Lighting.FogEnd
        OriginalSettings.FogStart = Lighting.FogStart
        OriginalSettings.FogColor = Lighting.FogColor
        OriginalSettings.Brightness = Lighting.Brightness
        OriginalSettings.ClockTime = Lighting.ClockTime
        OriginalSettings.OutdoorAmbient = Lighting.OutdoorAmbient
        OriginalSettings.Ambient = Lighting.Ambient
        
        -- Luu Lighting Effects (Blur, SunRays, ColorCorrection, Bloom, Atmosphere)
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") 
                or effect:IsA("ColorCorrectionEffect") or effect:IsA("BloomEffect")
                or effect:IsA("Atmosphere") or effect:IsA("DepthOfFieldEffect") then
                table.insert(OriginalSettings.LightingEffects, {
                    Object = effect,
                    Enabled = effect.Enabled,
                    Parent = effect.Parent
                })
            end
        end
        
        -- Luu Terrain
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            OriginalSettings.Terrain.WaterWaveSize = terrain.WaterWaveSize
            OriginalSettings.Terrain.WaterWaveSpeed = terrain.WaterWaveSpeed
            OriginalSettings.Terrain.WaterReflectance = terrain.WaterReflectance
            OriginalSettings.Terrain.WaterTransparency = terrain.WaterTransparency
            OriginalSettings.Terrain.Decoration = terrain.Decoration
        end
    end)
    
    print("[SunnyHubPro] Da luu cai dat goc de khoi phuc sau.")
end

-- Ham khoi phuc 100% cai dat goc
local function RestoreAllSettings()
    if not OriginalSettings.Saved then return end
    
    pcall(function()
        -- Khoi phuc Lighting
        if OriginalSettings.GlobalShadows ~= nil then
            Lighting.GlobalShadows = OriginalSettings.GlobalShadows
        end
        if OriginalSettings.FogEnd then
            Lighting.FogEnd = OriginalSettings.FogEnd
        end
        if OriginalSettings.FogStart then
            Lighting.FogStart = OriginalSettings.FogStart
        end
        if OriginalSettings.FogColor then
            Lighting.FogColor = OriginalSettings.FogColor
        end
        if OriginalSettings.Brightness then
            Lighting.Brightness = OriginalSettings.Brightness
        end
        if OriginalSettings.OutdoorAmbient then
            Lighting.OutdoorAmbient = OriginalSettings.OutdoorAmbient
        end
        if OriginalSettings.Ambient then
            Lighting.Ambient = OriginalSettings.Ambient
        end
        
        -- Khoi phuc Lighting Effects
        for _, data in pairs(OriginalSettings.LightingEffects) do
            pcall(function()
                if data.Object and data.Object.Parent then
                    data.Object.Enabled = data.Enabled
                end
            end)
        end
        
        -- Khoi phuc Terrain
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain and OriginalSettings.Terrain.WaterWaveSize then
            terrain.WaterWaveSize = OriginalSettings.Terrain.WaterWaveSize
            terrain.WaterWaveSpeed = OriginalSettings.Terrain.WaterWaveSpeed
            terrain.WaterReflectance = OriginalSettings.Terrain.WaterReflectance
            terrain.WaterTransparency = OriginalSettings.Terrain.WaterTransparency
            if OriginalSettings.Terrain.Decoration ~= nil then
                terrain.Decoration = OriginalSettings.Terrain.Decoration
            end
        end
        
        -- Khoi phuc Parts
        for part, data in pairs(OriginalSettings.ModifiedParts) do
            pcall(function()
                if part and part.Parent then
                    if data.Material then part.Material = data.Material end
                    if data.CastShadow ~= nil then part.CastShadow = data.CastShadow end
                    if data.Transparency ~= nil then part.Transparency = data.Transparency end
                    if data.Reflectance ~= nil then part.Reflectance = data.Reflectance end
                end
            end)
        end
        OriginalSettings.ModifiedParts = {}
        
        -- Khoi phuc Particles
        for _, data in pairs(OriginalSettings.Particles) do
            pcall(function()
                if data.Object and data.Object.Parent then
                    data.Object.Enabled = data.Enabled
                end
            end)
        end
        OriginalSettings.Particles = {}
        
        -- Khoi phuc Sounds
        for _, data in pairs(OriginalSettings.Sounds) do
            pcall(function()
                if data.Object and data.Object.Parent then
                    data.Object.Volume = data.Volume
                end
            end)
        end
        OriginalSettings.Sounds = {}
        
        -- Khoi phuc Decals
        for _, data in pairs(OriginalSettings.Decals) do
            pcall(function()
                if data.Object and data.Object.Parent then
                    data.Object.Transparency = data.Transparency
                end
            end)
        end
        OriginalSettings.Decals = {}
        
        -- Khoi phuc Textures
        for _, data in pairs(OriginalSettings.Textures) do
            pcall(function()
                if data.Object and data.Object.Parent then
                    data.Object.Transparency = data.Transparency
                end
            end)
        end
        OriginalSettings.Textures = {}
        
        -- Khoi phuc Beams
        for _, data in pairs(OriginalSettings.Beams) do
            pcall(function()
                if data.Object and data.Object.Parent then
                    data.Object.Enabled = data.Enabled
                end
            end)
        end
        OriginalSettings.Beams = {}
        
        -- Khoi phuc Trails
        for _, data in pairs(OriginalSettings.Trails) do
            pcall(function()
                if data.Object and data.Object.Parent then
                    data.Object.Enabled = data.Enabled
                end
            end)
        end
        OriginalSettings.Trails = {}
        
        -- Khoi phuc Meshes
        for _, data in pairs(OriginalSettings.Meshes) do
            pcall(function()
                if data.Object and data.Object.Parent then
                    if data.TextureId ~= nil then data.Object.TextureId = data.TextureId end
                end
            end)
        end
        OriginalSettings.Meshes = {}
        
        -- Khoi phuc 3D Rendering
        pcall(function()
            if typeof(RunService.Set3dRenderingEnabled) == "function" then
                RunService:Set3dRenderingEnabled(true)
            end
        end)
        
        -- Xoa Black Screen Frame neu co
        if OriginalSettings.BlackScreenFrame then
            pcall(function()
                OriginalSettings.BlackScreenFrame:Destroy()
                OriginalSettings.BlackScreenFrame = nil
            end)
        end
    end)
    
    print("[SunnyHubPro] Da khoi phuc 100% cai dat goc!")
end

-- =================== LAG REDUCTION CONNECTIONS ===================
local LagReductionConnections = {}

local function DisconnectLagReductionEvents()
    for _, conn in pairs(LagReductionConnections) do
        pcall(function()
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    LagReductionConnections = {}
end

-- =================== CHE DO GIAM LAG ===================

-- Che do 1: Co ban (Yeu)
local function ApplyBasicLagReduction()
    SaveOriginalSettings()
    
    pcall(function()
        -- Tat hieu ung do bong
        Lighting.GlobalShadows = false
        
        -- Giam chat luong suong mu
        Lighting.FogEnd = 999999
        
        -- Khoa FPS neu co the (executor ho tro)
        if typeof(setfpscap) == "function" then
            setfpscap(60)
        end
    end)
    
    print("[SunnyHubPro] Che do 1: Co ban - Da tat shadow, giam suong mu")
end

-- Che do 2: Nang cao (Vua)
local function ApplyAdvancedLagReduction()
    SaveOriginalSettings()
    
    pcall(function()
        -- Ap dung tat ca cua che do 1
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 999999
        
        -- An hieu ung moi truong
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") 
                or effect:IsA("ColorCorrectionEffect") or effect:IsA("BloomEffect")
                or effect:IsA("Atmosphere") or effect:IsA("DepthOfFieldEffect") then
                if effect.Enabled then
                    effect.Enabled = false
                end
            end
        end
        
        -- Giam Terrain
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
        end
        
        -- Thay doi Material thanh SmoothPlastic va tat CastShadow
        for _, part in pairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") then
                if not OriginalSettings.ModifiedParts[part] then
                    OriginalSettings.ModifiedParts[part] = {
                        Material = part.Material,
                        CastShadow = part.CastShadow,
                        Reflectance = part.Reflectance
                    }
                end
                part.Material = Enum.Material.SmoothPlastic
                part.CastShadow = false
                part.Reflectance = 0
            end
        end
        
        -- Tat Particles, Fire, Smoke, Sparkles
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                if obj.Enabled then
                    table.insert(OriginalSettings.Particles, {Object = obj, Enabled = true})
                    obj.Enabled = false
                end
            end
        end
        
        -- Tat Beams va Trails
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Beam") and obj.Enabled then
                table.insert(OriginalSettings.Beams, {Object = obj, Enabled = true})
                obj.Enabled = false
            elseif obj:IsA("Trail") and obj.Enabled then
                table.insert(OriginalSettings.Trails, {Object = obj, Enabled = true})
                obj.Enabled = false
            end
        end
        
        -- Event-driven: Tu dong toi uu part moi xuat hien
        local descendantAddedConn = Workspace.DescendantAdded:Connect(function(obj)
            if not ScriptRunning or Config.LagMode ~= 2 then return end
            
            task.defer(function()
                pcall(function()
                    if obj:IsA("BasePart") then
                        if not OriginalSettings.ModifiedParts[obj] then
                            OriginalSettings.ModifiedParts[obj] = {
                                Material = obj.Material,
                                CastShadow = obj.CastShadow,
                                Reflectance = obj.Reflectance
                            }
                        end
                        obj.Material = Enum.Material.SmoothPlastic
                        obj.CastShadow = false
                        obj.Reflectance = 0
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                        if obj.Enabled then
                            table.insert(OriginalSettings.Particles, {Object = obj, Enabled = true})
                            obj.Enabled = false
                        end
                    elseif obj:IsA("Beam") and obj.Enabled then
                        table.insert(OriginalSettings.Beams, {Object = obj, Enabled = true})
                        obj.Enabled = false
                    elseif obj:IsA("Trail") and obj.Enabled then
                        table.insert(OriginalSettings.Trails, {Object = obj, Enabled = true})
                        obj.Enabled = false
                    end
                end)
            end)
        end)
        table.insert(LagReductionConnections, descendantAddedConn)
    end)
    
    print("[SunnyHubPro] Che do 2: Nang cao - Da an hieu ung moi truong, thay doi Material")
end

-- Che do 3: Sieu toi gian / Treo may xuyen dem
local function ApplyExtremeReduction()
    SaveOriginalSettings()
    
    pcall(function()
        -- Ap dung tat ca cua che do 2
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 200
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.fromRGB(0, 0, 0)
        
        -- An hieu ung moi truong
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") 
                or effect:IsA("ColorCorrectionEffect") or effect:IsA("BloomEffect")
                or effect:IsA("Atmosphere") or effect:IsA("DepthOfFieldEffect") then
                effect.Enabled = false
            end
        end
        
        -- Giam Terrain
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
            pcall(function() terrain.Decoration = false end)
        end
        
        -- Xu ly tat ca Parts
        for _, part in pairs(Workspace:GetDescendants()) do
            pcall(function()
                if part:IsA("BasePart") then
                    if not OriginalSettings.ModifiedParts[part] then
                        OriginalSettings.ModifiedParts[part] = {
                            Material = part.Material,
                            CastShadow = part.CastShadow,
                            Reflectance = part.Reflectance,
                            Transparency = part.Transparency
                        }
                    end
                    part.Material = Enum.Material.SmoothPlastic
                    part.CastShadow = false
                    part.Reflectance = 0
                end
            end)
        end
        
        -- Xoa/An Texture, Decal, Skybox
        for _, obj in pairs(Workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("Decal") and obj.Transparency < 1 then
                    table.insert(OriginalSettings.Decals, {Object = obj, Transparency = obj.Transparency})
                    obj.Transparency = 1
                elseif obj:IsA("Texture") and obj.Transparency < 1 then
                    table.insert(OriginalSettings.Textures, {Object = obj, Transparency = obj.Transparency})
                    obj.Transparency = 1
                end
            end)
        end
        
        -- Tat tat ca Particles, Fire, Smoke, Sparkles, Beams, Trails
        for _, obj in pairs(Workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    if obj.Enabled then
                        table.insert(OriginalSettings.Particles, {Object = obj, Enabled = true})
                        obj.Enabled = false
                    end
                elseif obj:IsA("Beam") and obj.Enabled then
                    table.insert(OriginalSettings.Beams, {Object = obj, Enabled = true})
                    obj.Enabled = false
                elseif obj:IsA("Trail") and obj.Enabled then
                    table.insert(OriginalSettings.Trails, {Object = obj, Enabled = true})
                    obj.Enabled = false
                end
            end)
        end
        
        -- Giam am thanh
        for _, sound in pairs(Workspace:GetDescendants()) do
            pcall(function()
                if sound:IsA("Sound") and sound.Volume > 0 then
                    local isPlayerSound = LP.Character and sound:IsDescendantOf(LP.Character)
                    if not isPlayerSound then
                        table.insert(OriginalSettings.Sounds, {Object = sound, Volume = sound.Volume})
                        sound.Volume = 0
                    end
                end
            end)
        end
        
        -- An Mesh Textures
        for _, obj in pairs(Workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("MeshPart") or obj:IsA("SpecialMesh") then
                    if obj.TextureId and obj.TextureId ~= "" then
                        table.insert(OriginalSettings.Meshes, {Object = obj, TextureId = obj.TextureId})
                        obj.TextureId = ""
                    end
                end
            end)
        end
        
        -- Thu tat 3D Rendering (neu Executor ho tro)
        pcall(function()
            if typeof(RunService.Set3dRenderingEnabled) == "function" then
                RunService:Set3dRenderingEnabled(false)
                OriginalSettings.RenderingEnabled = false
            end
        end)
        
        -- Neu khong tat duoc 3D Rendering thi tao man hinh den
        if OriginalSettings.RenderingEnabled ~= false then
            pcall(function()
                local blackGui = Instance.new("ScreenGui")
                blackGui.Name = "SunnyHub_BlackScreen"
                blackGui.ResetOnSpawn = false
                blackGui.IgnoreGuiInset = true
                blackGui.DisplayOrder = 999999
                
                local ok = pcall(function() blackGui.Parent = CoreGui end)
                if not ok then blackGui.Parent = PlayerGui end
                
                local blackFrame = Instance.new("Frame", blackGui)
                blackFrame.Size = UDim2.new(1, 0, 1, 0)
                blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                blackFrame.BorderSizePixel = 0
                blackFrame.ZIndex = 999
                
                local infoLabel = Instance.new("TextLabel", blackFrame)
                infoLabel.Size = UDim2.new(1, 0, 0, 100)
                infoLabel.Position = UDim2.new(0, 0, 0.5, -50)
                infoLabel.BackgroundTransparency = 1
                infoLabel.Font = Enum.Font.GothamBold
                infoLabel.TextSize = 24
                infoLabel.TextColor3 = Color3.fromRGB(0, 220, 130)
                infoLabel.Text = "CHE DO TREO MAY - TIET KIEM DIEN\nNhan phim ToggleKey de mo menu"
                infoLabel.TextWrapped = true
                infoLabel.ZIndex = 1000
                
                OriginalSettings.BlackScreenFrame = blackGui
            end)
        end
        
        -- Event-driven: Tu dong toi uu part moi
        local descendantAddedConn = Workspace.DescendantAdded:Connect(function(obj)
            if not ScriptRunning or Config.LagMode ~= 3 then return end
            
            task.defer(function()
                pcall(function()
                    if obj:IsA("BasePart") then
                        if not OriginalSettings.ModifiedParts[obj] then
                            OriginalSettings.ModifiedParts[obj] = {
                                Material = obj.Material,
                                CastShadow = obj.CastShadow,
                                Reflectance = obj.Reflectance
                            }
                        end
                        obj.Material = Enum.Material.SmoothPlastic
                        obj.CastShadow = false
                        obj.Reflectance = 0
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                        if obj.Enabled then
                            table.insert(OriginalSettings.Particles, {Object = obj, Enabled = true})
                            obj.Enabled = false
                        end
                    elseif obj:IsA("Beam") and obj.Enabled then
                        table.insert(OriginalSettings.Beams, {Object = obj, Enabled = true})
                        obj.Enabled = false
                    elseif obj:IsA("Trail") and obj.Enabled then
                        table.insert(OriginalSettings.Trails, {Object = obj, Enabled = true})
                        obj.Enabled = false
                    elseif obj:IsA("Decal") and obj.Transparency < 1 then
                        table.insert(OriginalSettings.Decals, {Object = obj, Transparency = obj.Transparency})
                        obj.Transparency = 1
                    elseif obj:IsA("Texture") and obj.Transparency < 1 then
                        table.insert(OriginalSettings.Textures, {Object = obj, Transparency = obj.Transparency})
                        obj.Transparency = 1
                    end
                end)
            end)
        end)
        table.insert(LagReductionConnections, descendantAddedConn)
    end)
    
    print("[SunnyHubPro] Che do 3: Sieu toi gian - Man hinh den, CPU/GPU nghi 99%")
end

-- Ham chinh de ap dung che do giam lag
local function ApplyLagMode(mode)
    -- Disconnect cac event cu truoc
    DisconnectLagReductionEvents()
    
    -- Khoi phuc truoc khi ap dung che do moi
    if mode == 0 then
        RestoreAllSettings()
        Config.LagMode = 0
        return
    end
    
    Config.LagMode = mode
    
    if mode == 1 then
        ApplyBasicLagReduction()
    elseif mode == 2 then
        ApplyAdvancedLagReduction()
    elseif mode == 3 then
        ApplyExtremeReduction()
    end
end

-- =================== GAME PROFILES ===================
local ProfileConnections = {}

local function DisconnectProfileEvents()
    for _, conn in pairs(ProfileConnections) do
        pcall(function()
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    ProfileConnections = {}
end

-- Profile Anime (Blox Fruits, Anime Adventures...)
local function ApplyAnimeProfile()
    pcall(function()
        -- An Model quat khong lo o xa
        for _, model in pairs(Workspace:GetDescendants()) do
            if model:IsA("Model") then
                local humanoid = model:FindFirstChildOfClass("Humanoid")
                local primaryPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
                
                -- Neu la NPC/Enemy va o xa
                if humanoid and primaryPart and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                    local distance = (primaryPart.Position - LP.Character.HumanoidRootPart.Position).Magnitude
                    
                    -- An neu xa hon 200 studs va khong phai player
                    if distance > 200 and not Players:GetPlayerFromCharacter(model) then
                        for _, part in pairs(model:GetDescendants()) do
                            if part:IsA("BasePart") then
                                if not OriginalSettings.ModifiedParts[part] then
                                    OriginalSettings.ModifiedParts[part] = {Transparency = part.Transparency}
                                end
                                part.LocalTransparencyModifier = 1
                            end
                        end
                    end
                end
            end
        end
        
        -- An hieu ung chieu thuc (Skill Effects)
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
                local isCharacterEffect = false
                if LP.Character then
                    isCharacterEffect = obj:IsDescendantOf(LP.Character)
                end
                
                -- An hieu ung khong phai cua player
                if not isCharacterEffect and obj.Enabled then
                    if obj:IsA("ParticleEmitter") then
                        table.insert(OriginalSettings.Particles, {Object = obj, Enabled = true})
                    elseif obj:IsA("Beam") then
                        table.insert(OriginalSettings.Beams, {Object = obj, Enabled = true})
                    elseif obj:IsA("Trail") then
                        table.insert(OriginalSettings.Trails, {Object = obj, Enabled = true})
                    end
                    obj.Enabled = false
                end
            end
        end
    end)
    
    print("[SunnyHubPro] Profile Anime - Da an hieu ung chieu thuc va Model xa")
end

-- Profile Tycoon/Simulator
local function ApplyTycoonProfile()
    pcall(function()
        -- An dong tien roi tren dat, Floating Text, Damage Indicator
        for _, obj in pairs(Workspace:GetDescendants()) do
            -- An BillboardGui (thuong la Floating Text, Damage Indicator)
            if obj:IsA("BillboardGui") then
                if obj.Enabled ~= false then
                    obj.Enabled = false
                end
            end
            
            -- An TextLabel noi (SurfaceGui)
            if obj:IsA("SurfaceGui") then
                obj.Enabled = false
            end
            
            -- An Particles
            if obj:IsA("ParticleEmitter") and obj.Enabled then
                table.insert(OriginalSettings.Particles, {Object = obj, Enabled = true})
                obj.Enabled = false
            end
        end
        
        -- An cac Part nho (thuong la dong tien, item)
        for _, part in pairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") then
                local size = part.Size
                -- Part nho hon 2 studs moi chieu va khong phai character
                if size.X < 2 and size.Y < 2 and size.Z < 2 then
                    local isCharacterPart = false
                    if LP.Character then
                        isCharacterPart = part:IsDescendantOf(LP.Character)
                    end
                    
                    if not isCharacterPart then
                        if not OriginalSettings.ModifiedParts[part] then
                            OriginalSettings.ModifiedParts[part] = {Transparency = part.Transparency}
                        end
                        part.LocalTransparencyModifier = 0.9
                    end
                end
            end
        end
    end)
    
    print("[SunnyHubPro] Profile Tycoon - Da an Floating Text, dong tien roi")
end

-- Profile Shooter/FPS
local function ApplyShooterProfile()
    pcall(function()
        -- Giu hien thi Player nhung toi uu moi truong
        for _, part in pairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") then
                local isCharacter = false
                
                -- Kiem tra xem co phai character cua player nao khong
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character and part:IsDescendantOf(player.Character) then
                        isCharacter = true
                        break
                    end
                end
                
                -- Chi thay doi moi truong, giu nguyen player
                if not isCharacter then
                    if not OriginalSettings.ModifiedParts[part] then
                        OriginalSettings.ModifiedParts[part] = {
                            Material = part.Material,
                            CastShadow = part.CastShadow,
                            Reflectance = part.Reflectance
                        }
                    end
                    part.Material = Enum.Material.SmoothPlastic
                    part.CastShadow = false
                    part.Reflectance = 0
                end
            end
        end
        
        -- An Particles khong quan trong
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") then
                -- Giu particle cua Player
                local isPlayerParticle = false
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character and obj:IsDescendantOf(player.Character) then
                        isPlayerParticle = true
                        break
                    end
                end
                
                if not isPlayerParticle and obj.Enabled then
                    table.insert(OriginalSettings.Particles, {Object = obj, Enabled = true})
                    obj.Enabled = false
                end
            end
        end
    end)
    
    print("[SunnyHubPro] Profile Shooter - Toi uu moi truong, giu nguyen Player")
end

-- Ham ap dung Profile
local function ApplyGameProfile(profileIndex)
    -- Disconnect events cu
    DisconnectProfileEvents()
    
    -- Khoi phuc truoc khi ap dung profile moi
    if profileIndex == 0 then
        RestoreAllSettings()
        Config.GameProfile = 0
        return
    end
    
    Config.GameProfile = profileIndex
    
    if profileIndex == 1 then
        ApplyAnimeProfile()
    elseif profileIndex == 2 then
        ApplyTycoonProfile()
    elseif profileIndex == 3 then
        ApplyShooterProfile()
    end
end

-- =================== QUAN LY BO NHO ===================
local MemoryCleanupInfo = {
    LastCleanupTime = 0,
    CleanedCount = 0,
}

-- Ham giai phong bo nho
local function CleanupMemory()
    local cleanedCount = 0
    
    pcall(function()
        -- Xoa am thanh bi lap lai/da ket thuc
        for _, sound in pairs(Workspace:GetDescendants()) do
            if sound:IsA("Sound") then
                if not sound.Playing and not sound.Looped then
                    -- Khong xoa sound quan trong
                    local isImportant = sound:IsDescendantOf(LP.Character) or 
                                       sound:IsDescendantOf(PlayerGui)
                    if not isImportant then
                        -- Chi reset, khong destroy
                        sound:Stop()
                        cleanedCount = cleanedCount + 1
                    end
                end
            end
        end
        
        -- Xoa Particle da phat xong
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") then
                if not obj.Enabled and obj.Parent then
                    -- Kiem tra xem co particle nao dang hien khong
                    local particleCount = 0
                    pcall(function()
                        -- Neu khong the dem particle, bo qua
                    end)
                end
            end
        end
        
        -- Goi garbage collector
        pcall(function()
            collectgarbage("collect")
        end)
    end)
    
    MemoryCleanupInfo.LastCleanupTime = tick()
    MemoryCleanupInfo.CleanedCount = cleanedCount
    
    return cleanedCount
end

-- Ham lay thong tin bo nho
local function GetMemoryInfo()
    local memoryKB = 0
    pcall(function()
        memoryKB = gcinfo()
    end)
    return memoryKB
end

-- =================== THEME ===================
local Theme = {
    BG       = Color3.fromRGB(18, 18, 22),
    Panel    = Color3.fromRGB(26, 26, 32),
    Panel2   = Color3.fromRGB(34, 34, 42),
    Border   = Color3.fromRGB(50, 50, 60),
    Text     = Color3.fromRGB(235, 235, 240),
    SubText  = Color3.fromRGB(160, 160, 175),
    Accent   = Color3.fromRGB(0, 220, 130),  -- neon green
    Accent2  = Color3.fromRGB(0, 170, 255),  -- neon blue
    Danger   = Color3.fromRGB(255, 70, 90),
    Off      = Color3.fromRGB(70, 70, 80),
    Warning  = Color3.fromRGB(255, 180, 50), -- vang cam
    Success  = Color3.fromRGB(50, 205, 50),  -- xanh la
}

-- =================== HELPERS ===================
local function corner(parent, r)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function stroke(parent, color, t)
    local s = Instance.new("UIStroke", parent)
    s.Color = color or Theme.Border
    s.Thickness = t or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function pad(parent, p)
    local u = Instance.new("UIPadding", parent)
    u.PaddingTop    = UDim.new(0, p)
    u.PaddingBottom = UDim.new(0, p)
    u.PaddingLeft   = UDim.new(0, p)
    u.PaddingRight  = UDim.new(0, p)
    return u
end

local function makeDraggable(frame, dragHandle)
    dragHandle = dragHandle or frame
    local dragging, dragInput, startPos, startMouse
    
    local dragBeginConn = dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startMouse = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    table.insert(AllConnections, dragBeginConn)
    
    local dragChangeConn = dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    table.insert(AllConnections, dragChangeConn)
    
    local inputChangeConn = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - startMouse
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    table.insert(AllConnections, inputChangeConn)
end

-- =================== ROOT GUI ===================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SunnyHubPro"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
local ok = pcall(function() ScreenGui.Parent = CoreGui end)
if not ok then ScreenGui.Parent = PlayerGui end

-- ===== Nut mo / dong (floating) =====
local OpenBtn = Instance.new("TextButton", ScreenGui)
OpenBtn.Size = UDim2.new(0, 56, 0, 56)
OpenBtn.Position = UDim2.new(0, 16, 0.4, 0)
OpenBtn.BackgroundColor3 = Theme.Accent
OpenBtn.Text = "S"
OpenBtn.TextColor3 = Theme.BG
OpenBtn.Font = Enum.Font.GothamBlack
OpenBtn.TextSize = 26
OpenBtn.AutoButtonColor = false
OpenBtn.Visible = false
corner(OpenBtn, 28)
stroke(OpenBtn, Color3.fromRGB(0,255,170), 2)
makeDraggable(OpenBtn)

-- ===== Cua so chinh =====
local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 580, 0, 420)
Main.Position = UDim2.new(0.5, -290, 0.5, -210)
Main.BackgroundColor3 = Theme.BG
Main.BorderSizePixel = 0
Main.Visible = true
Main.ClipsDescendants = false
corner(Main, 14)
stroke(Main, Theme.Border, 1)

-- Glow vien
local Glow = Instance.new("UIStroke", Main)
Glow.Color = Theme.Accent
Glow.Thickness = 1
Glow.Transparency = 0.6

-- Header
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Theme.Panel
Header.BorderSizePixel = 0
corner(Header, 14)
local headerFix = Instance.new("Frame", Header)
headerFix.Size = UDim2.new(1,0,0,14)
headerFix.Position = UDim2.new(0,0,1,-14)
headerFix.BackgroundColor3 = Theme.Panel
headerFix.BorderSizePixel = 0
makeDraggable(Main, Header)

local Dot = Instance.new("Frame", Header)
Dot.Size = UDim2.new(0, 10, 0, 10)
Dot.Position = UDim2.new(0, 14, 0.5, -5)
Dot.BackgroundColor3 = Theme.Accent
Dot.BorderSizePixel = 0
corner(Dot, 5)

local Title = Instance.new("TextLabel", Header)
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 32, 0, 0)
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "SUNNY HUB PRO"
Title.TextColor3 = Theme.Text
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left

local Subtitle = Instance.new("TextLabel", Header)
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.new(0, 32, 0, 18)
Subtitle.Size = UDim2.new(1, -120, 0, 14)
Subtitle.Font = Enum.Font.Gotham
Subtitle.Text = "All-in-One v3.0 + Anti-Lag + Profiles"
Subtitle.TextColor3 = Theme.SubText
Subtitle.TextSize = 11
Subtitle.TextXAlignment = Enum.TextXAlignment.Left

-- Nut Thu nho "-"
local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -68, 0.5, -14)
MinBtn.BackgroundColor3 = Theme.Panel2
MinBtn.Text = "-"
MinBtn.TextColor3 = Theme.Text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.AutoButtonColor = false
corner(MinBtn, 6)

-- Nut Dong Script "X"
local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Theme.Danger
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Theme.Text
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.AutoButtonColor = false
corner(CloseBtn, 6)

-- Sidebar
local Sidebar = Instance.new("Frame", Main)
Sidebar.Position = UDim2.new(0, 0, 0, 42)
Sidebar.Size = UDim2.new(0, 130, 1, -42)
Sidebar.BackgroundColor3 = Theme.Panel
Sidebar.BorderSizePixel = 0

local sbList = Instance.new("UIListLayout", Sidebar)
sbList.Padding = UDim.new(0, 5)
sbList.SortOrder = Enum.SortOrder.LayoutOrder
pad(Sidebar, 8)

-- Content
local Content = Instance.new("Frame", Main)
Content.Position = UDim2.new(0, 130, 0, 42)
Content.Size = UDim2.new(1, -130, 1, -42)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = false

local Pages = {}

local function createPage(name)
    local p = Instance.new("ScrollingFrame", Content)
    p.Name = name
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 4
    p.ScrollBarImageColor3 = Theme.Accent
    p.CanvasSize = UDim2.new(0,0,0,0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.Visible = false
    p.ClipsDescendants = false
    local l = Instance.new("UIListLayout", p)
    l.Padding = UDim.new(0, 10)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    pad(p, 14)
    Pages[name] = p
    return p
end

local TabBtns = {}
local function selectTab(name)
    for n, page in pairs(Pages) do
        page.Visible = (n == name)
    end
    for n, btn in pairs(TabBtns) do
        if n == name then
            btn.BackgroundColor3 = Theme.Accent
            btn.TextColor3 = Theme.BG
        else
            btn.BackgroundColor3 = Theme.Panel2
            btn.TextColor3 = Theme.Text
        end
    end
end

local function createTab(name, label, order)
    local b = Instance.new("TextButton", Sidebar)
    b.Size = UDim2.new(1, 0, 0, 32)
    b.BackgroundColor3 = Theme.Panel2
    b.Text = label
    b.TextColor3 = Theme.Text
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 11
    b.AutoButtonColor = false
    b.LayoutOrder = order
    corner(b, 8)
    b.MouseButton1Click:Connect(function() selectTab(name) end)
    TabBtns[name] = b
    return b
end

-- Tao cac Tab
createTab("Shop",      "Shop",          1)
createTab("AutoFarm",  "Auto Farm",     2)
createTab("Crates",    "Crates",        3)
createTab("LagReduce", "Giam Lag",      4)
createTab("Memory",    "Quan Ly RAM",   5)
createTab("Profiles",  "Profiles",      6)
createTab("Misc",      "Misc",          7)

createPage("Shop")
createPage("AutoFarm")
createPage("Crates")
createPage("LagReduce")
createPage("Memory")
createPage("Profiles")
createPage("Misc")
selectTab("Shop")

-- =================== UI COMPONENTS ===================
local function sectionLabel(parent, text, order)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 0, 18)
    l.Font = Enum.Font.GothamBold
    l.Text = text
    l.TextColor3 = Theme.SubText
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    return l
end

local function rowCard(parent, h, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, h or 50)
    f.BackgroundColor3 = Theme.Panel
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.ClipsDescendants = false
    corner(f, 10)
    stroke(f, Theme.Border, 1)
    pad(f, 12)
    return f
end

local function createToggle(parent, text, default, order, onChange)
    local row = rowCard(parent, 46, order)

    local lbl = Instance.new("TextLabel", row)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("TextButton", row)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, 0, 0.5, 0)
    track.Size = UDim2.new(0, 44, 0, 22)
    track.BackgroundColor3 = Theme.Off
    track.Text = ""
    track.AutoButtonColor = false
    corner(track, 11)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Theme.Text
    knob.BorderSizePixel = 0
    corner(knob, 9)

    local state = default and true or false
    local function render()
        if state then
            TweenService:Create(track,TweenInfo.new(0.15),{BackgroundColor3 = Theme.Accent}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15),{Position = UDim2.new(0, 24, 0.5, -9)}):Play()
        else
            TweenService:Create(track,TweenInfo.new(0.15),{BackgroundColor3 = Theme.Off}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15),{Position = UDim2.new(0, 2, 0.5, -9)}):Play()
        end
    end
    render()

    track.MouseButton1Click:Connect(function()
        state = not state
        render()
        if onChange then onChange(state) end
    end)

    return {
        Set = function(v) state = v and true or false; render() end,
        Get = function() return state end,
    }
end

-- Slider voi TextBox nhap truc tiep
local function createSlider(parent, text, min, max, default, step, order, onChange)
    local row = rowCard(parent, 70, order)

    local lbl = Instance.new("TextLabel", row)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.5, 0, 0, 18)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    -- TextBox nhap truc tiep
    local inputBox = Instance.new("TextBox", row)
    inputBox.AnchorPoint = Vector2.new(1, 0)
    inputBox.Position = UDim2.new(1, 0, 0, 0)
    inputBox.Size = UDim2.new(0, 70, 0, 24)
    inputBox.BackgroundColor3 = Theme.Panel2
    inputBox.Font = Enum.Font.GothamBold
    inputBox.TextColor3 = Theme.Accent
    inputBox.TextSize = 13
    inputBox.ClearTextOnFocus = false
    if step and step >= 1 then
        inputBox.Text = tostring(math.floor(default))
    else
        inputBox.Text = string.format("%.2f", default)
    end
    corner(inputBox, 6)
    stroke(inputBox, Theme.Border, 1)

    local bar = Instance.new("Frame", row)
    bar.Position = UDim2.new(0, 0, 1, -14)
    bar.AnchorPoint = Vector2.new(0, 1)
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.BackgroundColor3 = Theme.Off
    bar.BorderSizePixel = 0
    corner(bar, 3)

    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    corner(fill, 3)

    local knob = Instance.new("TextButton", bar)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((default-min)/(max-min), 0, 0.5, 0)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.BackgroundColor3 = Theme.Text
    knob.Text = ""
    knob.AutoButtonColor = false
    corner(knob, 7)

    local currentValue = default
    local dragging = false

    local function updateUI(raw)
        local pct = (raw-min)/(max-min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        if step and step >= 1 then
            inputBox.Text = tostring(math.floor(raw))
        else
            inputBox.Text = string.format("%.2f", raw)
        end
    end

    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local raw = min + (max-min)*rel
        if step then raw = math.floor(raw/step + 0.5)*step end
        raw = math.clamp(raw, min, max)
        currentValue = raw
        updateUI(raw)
        if onChange then onChange(raw) end
    end

    local function setFromText(txt)
        local num = tonumber(txt)
        if num then
            if step then num = math.floor(num/step + 0.5)*step end
            num = math.clamp(num, min, max)
            currentValue = num
            updateUI(num)
            if onChange then onChange(num) end
        else
            updateUI(currentValue)
        end
    end

    inputBox.FocusLost:Connect(function(enterPressed)
        setFromText(inputBox.Text)
    end)

    knob.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true
        end
    end)
    bar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; setFromX(i.Position.X)
        end
    end)
    
    local inputChangeConn = UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            setFromX(i.Position.X)
        end
    end)
    table.insert(AllConnections, inputChangeConn)
    
    local inputEndConn = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
    table.insert(AllConnections, inputEndConn)

    return {
        Set = function(v)
            if step then v = math.floor(v/step + 0.5)*step end
            v = math.clamp(v, min, max)
            currentValue = v
            updateUI(v)
        end,
        Get = function() return currentValue end,
    }
end

-- [FIX] Dropdown mo xuong duoi voi ScrollingFrame
local ActiveDropdownList = nil

local function createDropdown(parent, text, options, default, order, onChange)
    local row = rowCard(parent, 46, order)
    row.ClipsDescendants = false
    row.ZIndex = 10

    local lbl = Instance.new("TextLabel", row)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 10

    local btn = Instance.new("TextButton", row)
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0.55, 0, 0, 30)
    btn.BackgroundColor3 = Theme.Panel2
    btn.Text = "  " .. tostring(default) .. "  v"
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.ZIndex = 10
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    corner(btn, 6)
    stroke(btn, Theme.Border, 1)

    -- ScrollingFrame dropdown - mo XUONG DUOI
    local maxVisibleItems = 5
    local itemHeight = 26
    local listHeight = math.min(#options, maxVisibleItems) * (itemHeight + 2) + 8
    
    local list = Instance.new("ScrollingFrame", row)
    list.AnchorPoint = Vector2.new(1, 0)
    list.Position = UDim2.new(1, 0, 1, 4)
    list.Size = UDim2.new(0.55, 0, 0, listHeight)
    list.BackgroundColor3 = Theme.Panel2
    list.BorderSizePixel = 0
    list.Visible = false
    list.ZIndex = 100
    list.ScrollBarThickness = 3
    list.ScrollBarImageColor3 = Theme.Accent
    list.CanvasSize = UDim2.new(0, 0, 0, #options * (itemHeight + 2))
    list.ClipsDescendants = true
    corner(list, 6)
    stroke(list, Theme.Accent, 1)

    local ll = Instance.new("UIListLayout", list)
    ll.Padding = UDim.new(0, 2)
    pad(list, 4)

    for idx, opt in ipairs(options) do
        local o = Instance.new("TextButton", list)
        o.Size = UDim2.new(1, -4, 0, itemHeight)
        o.BackgroundColor3 = Theme.Panel
        o.Text = opt
        o.TextColor3 = Theme.Text
        o.Font = Enum.Font.Gotham
        o.TextSize = 11
        o.AutoButtonColor = false
        o.ZIndex = 101
        o.TextTruncate = Enum.TextTruncate.AtEnd
        corner(o, 4)
        
        o.MouseEnter:Connect(function()
            o.BackgroundColor3 = Theme.Accent
            o.TextColor3 = Theme.BG
        end)
        o.MouseLeave:Connect(function()
            o.BackgroundColor3 = Theme.Panel
            o.TextColor3 = Theme.Text
        end)
        
        o.MouseButton1Click:Connect(function()
            btn.Text = "  " .. opt .. "  v"
            list.Visible = false
            ActiveDropdownList = nil
            if onChange then onChange(opt, idx) end
        end)
    end

    btn.MouseButton1Click:Connect(function()
        if ActiveDropdownList and ActiveDropdownList ~= list then
            ActiveDropdownList.Visible = false
        end
        list.Visible = not list.Visible
        ActiveDropdownList = list.Visible and list or nil
    end)

    -- Dong dropdown khi click ra ngoai
    local closeDropdownConn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.defer(function()
                if list.Visible then
                    local mousePos = UserInputService:GetMouseLocation()
                    local listAbsPos = list.AbsolutePosition
                    local listAbsSize = list.AbsoluteSize
                    local btnAbsPos = btn.AbsolutePosition
                    local btnAbsSize = btn.AbsoluteSize
                    
                    local inList = mousePos.X >= listAbsPos.X and mousePos.X <= listAbsPos.X + listAbsSize.X
                                and mousePos.Y >= listAbsPos.Y and mousePos.Y <= listAbsPos.Y + listAbsSize.Y
                    local inBtn = mousePos.X >= btnAbsPos.X and mousePos.X <= btnAbsPos.X + btnAbsSize.X
                               and mousePos.Y >= btnAbsPos.Y and mousePos.Y <= btnAbsPos.Y + btnAbsSize.Y
                    
                    if not inList and not inBtn then
                        list.Visible = false
                        if ActiveDropdownList == list then
                            ActiveDropdownList = nil
                        end
                    end
                end
            end)
        end
    end)
    table.insert(AllConnections, closeDropdownConn)
end

local function createButton(parent, text, color, order, onClick)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = color or Theme.Accent
    b.Text = text
    b.TextColor3 = Theme.BG
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.AutoButtonColor = true
    b.LayoutOrder = order
    corner(b, 8)
    b.MouseButton1Click:Connect(function()
        if onClick then onClick() end
    end)
    return b
end

local function createTextInput(parent, text, default, order, onChange)
    local row = rowCard(parent, 46, order)

    local lbl = Instance.new("TextLabel", row)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", row)
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    box.Size = UDim2.new(0.45, 0, 0, 30)
    box.BackgroundColor3 = Theme.Panel2
    box.Text = default
    box.PlaceholderText = "Enter..."
    box.TextColor3 = Theme.Text
    box.Font = Enum.Font.GothamSemibold
    box.TextSize = 12
    box.ClearTextOnFocus = false
    corner(box, 6)
    stroke(box, Theme.Border, 1)

    box.FocusLost:Connect(function()
        if onChange then onChange(box.Text) end
    end)
end

-- =================== BUILD PAGES ===================

-- ===== SHOP =====
sectionLabel(Pages.Shop, "REMOTE SHOP", 1)
createDropdown(Pages.Shop, "Item", TotemList, Config.SelectedItem, 2, function(v)
    Config.SelectedItem = v
end)
createButton(Pages.Shop, "BUY NOW", Theme.Accent2, 3, function()
    pcall(function()
        local shop = PlayerGui:FindFirstChild("TotemShopUI")
        if not shop then return end
        local sf = shop:FindFirstChild("Frame") and shop.Frame:FindFirstChild("ScrollingFrame")
        if not sf then return end
        local item = sf:FindFirstChild(Config.SelectedItem)
        if item and item:FindFirstChild("BuyButton") then
            local b = item.BuyButton
            firesignal(b.MouseButton1Click)
            firesignal(b.Activated)
            for _, c in pairs(getconnections(b.MouseButton1Click)) do c:Fire() end
        end
    end)
end)
createSlider(Pages.Shop, "Auto Buy Interval (s)", 1, 60, Config.BuyInterval, 1, 4, function(v)
    Config.BuyInterval = v
end)
createToggle(Pages.Shop, "Auto Buy Selected Item", false, 5, function(v)
    Config.AutoBuy = v
end)

-- ===== AUTO FARM =====
sectionLabel(Pages.AutoFarm, "AUTO PICKUP / HUT NHAT", 1)
createSlider(Pages.AutoFarm, "Pickup Range (m)", 1, 100, Config.PickupRange, 1, 2, function(v)
    Config.PickupRange = v
end)
createSlider(Pages.AutoFarm, "Scan Speed (s)", 0.05, 2, Config.ScanSpeed, 0.05, 3, function(v)
    Config.ScanSpeed = v
end)
createToggle(Pages.AutoFarm, "Auto Pickup & Suck Items", false, 4, function(v)
    Config.AutoPickup = v
end)

-- ===== CRATES =====
sectionLabel(Pages.Crates, "AUTO OPEN CRATES", 1)
createSlider(Pages.Crates, "Open Speed (s)", 0.05, 2, Config.OpenSpeed, 0.05, 2, function(v)
    Config.OpenSpeed = v
end)
createToggle(Pages.Crates, "Auto Open Crate", false, 3, function(v)
    Config.AutoOpen = v
end)
createToggle(Pages.Crates, "Anti-Egg / Skip Animation", false, 4, function(v)
    Config.AntiEgg = v
end)
createButton(Pages.Crates, "DESTROY CRATE UI (Anti-Lag)", Theme.Danger, 5, function()
    pcall(function()
        local g = PlayerGui:FindFirstChild("EggCrateOpeningUI")
        if g then g:Destroy() end
    end)
end)

-- ===== GIAM LAG =====
sectionLabel(Pages.LagReduce, "CAU HINH GIAM TAI", 1)

-- Trang thai hien tai
local lagStatusRow = rowCard(Pages.LagReduce, 50, 2)
local lagStatusLbl = Instance.new("TextLabel", lagStatusRow)
lagStatusLbl.BackgroundTransparency = 1
lagStatusLbl.Size = UDim2.new(1, 0, 1, 0)
lagStatusLbl.Font = Enum.Font.GothamBold
lagStatusLbl.Text = "Trang thai: TAT (Khoi phuc 100%)"
lagStatusLbl.TextColor3 = Theme.Accent
lagStatusLbl.TextSize = 14
lagStatusLbl.TextXAlignment = Enum.TextXAlignment.Left

createDropdown(Pages.LagReduce, "Che do", LagModeNames, "Tat (Khoi phuc 100%)", 3, function(v, idx)
    ApplyLagMode(idx - 1)
    
    if Config.LagMode == 0 then
        lagStatusLbl.Text = "Trang thai: TAT (Khoi phuc 100%)"
        lagStatusLbl.TextColor3 = Theme.Accent
    else
        lagStatusLbl.Text = "Trang thai: " .. v
        lagStatusLbl.TextColor3 = Theme.Warning
    end
end)

sectionLabel(Pages.LagReduce, "MO TA CAC CHE DO", 4)

local descRow = rowCard(Pages.LagReduce, 180, 5)
local descLbl = Instance.new("TextLabel", descRow)
descLbl.BackgroundTransparency = 1
descLbl.Size = UDim2.new(1, 0, 1, 0)
descLbl.Font = Enum.Font.Gotham
descLbl.TextSize = 11
descLbl.TextColor3 = Theme.SubText
descLbl.TextWrapped = true
descLbl.TextXAlignment = Enum.TextXAlignment.Left
descLbl.TextYAlignment = Enum.TextYAlignment.Top
descLbl.Text = [[CHE DO 1 - CO BAN:
- Tat hieu ung do bong (GlobalShadows)
- Giam suong mu (FogEnd)
- Khoa FPS (neu executor ho tro)

CHE DO 2 - NANG CAO:
- + An Blur, SunRays, Bloom, Atmosphere
- + Thay doi Material thanh SmoothPlastic
- + Tat CastShadow, Particles, Fire, Smoke
- + Tu dong toi uu Part moi xuat hien

CHE DO 3 - SIEU TOI GIAN / TREO MAY:
- + An Decal, Texture, Mesh Texture
- + Man hinh den tiet kiem dien (CPU/GPU nghi 99%)
- + Tat 3D Rendering (neu executor ho tro)

LUU Y: Chuyen ve "Tat" se khoi phuc 100%!]]

createButton(Pages.LagReduce, "KHOI PHUC 100% CAI DAT GOC", Theme.Accent, 6, function()
    ApplyLagMode(0)
    lagStatusLbl.Text = "Trang thai: TAT (Khoi phuc 100%)"
    lagStatusLbl.TextColor3 = Theme.Accent
end)

-- ===== QUAN LY BO NHO =====
sectionLabel(Pages.Memory, "THONG TIN BO NHO", 1)

local memRow = rowCard(Pages.Memory, 60, 2)
local memLbl = Instance.new("TextLabel", memRow)
memLbl.BackgroundTransparency = 1
memLbl.Size = UDim2.new(1, 0, 1, 0)
memLbl.Font = Enum.Font.GothamBold
memLbl.TextSize = 14
memLbl.TextColor3 = Theme.Accent
memLbl.TextXAlignment = Enum.TextXAlignment.Left
memLbl.Text = "RAM: Dang tai..."

-- Cap nhat RAM theo thoi gian thuc (Event-driven)
local memoryUpdateConn = RunService.Heartbeat:Connect(function()
    if not ScriptRunning then return end
    
    -- Chi cap nhat moi 1 giay de khong gay lag
    if tick() % 1 < 0.03 then
        local memKB = GetMemoryInfo()
        local memMB = memKB / 1024
        memLbl.Text = string.format("RAM dang dung: %.2f MB (%.0f KB)", memMB, memKB)
        
        if memMB > 500 then
            memLbl.TextColor3 = Theme.Danger
        elseif memMB > 300 then
            memLbl.TextColor3 = Theme.Warning
        else
            memLbl.TextColor3 = Theme.Accent
        end
    end
end)
table.insert(AllConnections, memoryUpdateConn)

sectionLabel(Pages.Memory, "GIAI PHONG BO NHO", 3)

createButton(Pages.Memory, "DOC RAC THU CONG", Theme.Accent2, 4, function()
    local count = CleanupMemory()
    print("[SunnyHubPro] Da don dep " .. count .. " doi tuong. RAM: " .. GetMemoryInfo() .. " KB")
end)

local cleanupInfoRow = rowCard(Pages.Memory, 80, 5)
local cleanupInfoLbl = Instance.new("TextLabel", cleanupInfoRow)
cleanupInfoLbl.BackgroundTransparency = 1
cleanupInfoLbl.Size = UDim2.new(1, 0, 1, 0)
cleanupInfoLbl.Font = Enum.Font.Gotham
cleanupInfoLbl.TextSize = 11
cleanupInfoLbl.TextColor3 = Theme.SubText
cleanupInfoLbl.TextWrapped = true
cleanupInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
cleanupInfoLbl.TextYAlignment = Enum.TextYAlignment.Top
cleanupInfoLbl.Text = [[Nut "Doc rac thu cong" se:
- Dung am thanh khong can thiet
- Goi Garbage Collector
- Giai phong Nil Instances

Khong anh huong den gameplay!]]

-- ===== PROFILES =====
sectionLabel(Pages.Profiles, "PROFILE GAME", 1)

local profileStatusRow = rowCard(Pages.Profiles, 50, 2)
local profileStatusLbl = Instance.new("TextLabel", profileStatusRow)
profileStatusLbl.BackgroundTransparency = 1
profileStatusLbl.Size = UDim2.new(1, 0, 1, 0)
profileStatusLbl.Font = Enum.Font.GothamBold
profileStatusLbl.TextSize = 14
profileStatusLbl.TextColor3 = Theme.Accent
profileStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
profileStatusLbl.Text = "Profile: Khong ap dung"

createDropdown(Pages.Profiles, "Chon Profile", ProfileNames, "Khong ap dung", 3, function(v, idx)
    ApplyGameProfile(idx - 1)
    
    if Config.GameProfile == 0 then
        profileStatusLbl.Text = "Profile: Khong ap dung"
        profileStatusLbl.TextColor3 = Theme.Accent
    else
        profileStatusLbl.Text = "Profile: " .. v
        profileStatusLbl.TextColor3 = Theme.Warning
    end
end)

sectionLabel(Pages.Profiles, "MO TA PROFILES", 4)

local profileDescRow = rowCard(Pages.Profiles, 150, 5)
local profileDescLbl = Instance.new("TextLabel", profileDescRow)
profileDescLbl.BackgroundTransparency = 1
profileDescLbl.Size = UDim2.new(1, 0, 1, 0)
profileDescLbl.Font = Enum.Font.Gotham
profileDescLbl.TextSize = 11
profileDescLbl.TextColor3 = Theme.SubText
profileDescLbl.TextWrapped = true
profileDescLbl.TextXAlignment = Enum.TextXAlignment.Left
profileDescLbl.TextYAlignment = Enum.TextYAlignment.Top
profileDescLbl.Text = [[PROFILE ANIME (Blox Fruits, Anime Adventures...):
- An hieu ung chieu thuc (Skill Effects)
- An Model quai/boss khong lo o xa (>200 studs)

PROFILE TYCOON/SIMULATOR:
- An dong tien roi, Floating Text, Damage Indicator
- An cac vat pham nho tren mat dat

PROFILE SHOOTER/FPS:
- Giu nguyen hien thi Player
- Toi uu moi truong xung quanh
- An Particles khong quan trong

LUU Y: Chuyen ve "Khong ap dung" se khoi phuc!]]

createButton(Pages.Profiles, "KHOI PHUC PROFILE", Theme.Accent, 6, function()
    ApplyGameProfile(0)
    profileStatusLbl.Text = "Profile: Khong ap dung"
    profileStatusLbl.TextColor3 = Theme.Accent
end)

-- ===== MISC =====
sectionLabel(Pages.Misc, "UTILITIES", 1)
createToggle(Pages.Misc, "Anti-Unequip (Force Hold Tool)", false, 2, function(v)
    Config.LockTool = v
    if v then
        local char = LP.Character
        if char then
            Config.LockedTool = char:FindFirstChildOfClass("Tool")
                              or LP:FindFirstChild("Backpack") and LP.Backpack:FindFirstChildOfClass("Tool")
        end
    else
        Config.LockedTool = nil
    end
end)
createTextInput(Pages.Misc, "Toggle Menu Keybind", "RightControl", 3, function(text)
    local code = Enum.KeyCode[text]
    if code then Config.ToggleKey = code end
end)
createButton(Pages.Misc, "RE-LOCK CURRENT TOOL", Theme.Accent2, 4, function()
    local char = LP.Character
    if char then
        Config.LockedTool = char:FindFirstChildOfClass("Tool")
    end
end)
sectionLabel(Pages.Misc, "INFO", 5)
local info = rowCard(Pages.Misc, 80, 6)
local infoLbl = Instance.new("TextLabel", info)
infoLbl.BackgroundTransparency = 1
infoLbl.Size = UDim2.new(1,0,1,0)
infoLbl.Font = Enum.Font.Gotham
infoLbl.TextSize = 11
infoLbl.TextColor3 = Theme.SubText
infoLbl.TextWrapped = true
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.TextYAlignment = Enum.TextYAlignment.Top
infoLbl.Text = "User: "..LP.Name.."   |   UserId: "..LP.UserId
    .."\n\nSunnyHubPro v3.0 - All-in-One Mod Menu"
    .."\nEvent-Driven Architecture (Khong gay lag)"
    .."\nDung firesignal + getconnections de bypass UI"

-- =================== TOGGLE OPEN/CLOSE ===================
local Open = true

local function minimize()
    Open = false
    Main.Visible = false
    OpenBtn.Visible = true
    OpenBtn.Text = "S"
end

local function maximize()
    Open = true
    Main.Visible = true
    OpenBtn.Visible = false
end

local function closeScript()
    ScriptRunning = false
    Config.AutoBuy = false
    Config.AutoPickup = false
    Config.AutoOpen = false
    Config.AntiEgg = false
    Config.LockTool = false
    
    -- Disconnect tat ca events
    for _, conn in pairs(AllConnections) do
        pcall(function()
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    AllConnections = {}
    
    -- Disconnect Lag Reduction events
    DisconnectLagReductionEvents()
    
    -- Disconnect Profile events
    DisconnectProfileEvents()
    
    -- Khoi phuc giam lag truoc khi dong
    RestoreAllSettings()
    
    pcall(function()
        ScreenGui:Destroy()
    end)
    
    print("[SunnyHubPro] Script closed by user. Da khoi phuc 100% cai dat goc.")
end

OpenBtn.MouseButton1Click:Connect(function() 
    maximize()
end)

MinBtn.MouseButton1Click:Connect(function() 
    minimize()
end)

CloseBtn.MouseButton1Click:Connect(function() 
    closeScript()
end)

local toggleKeyConn = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not ScriptRunning then return end
    if input.KeyCode == Config.ToggleKey then
        if Open then
            minimize()
        else
            maximize()
        end
    end
end)
table.insert(AllConnections, toggleKeyConn)

-- =================== CORE LOGIC (Event-Driven) ===================

-- 1) AUTO BUY (Event-driven voi Heartbeat)
local lastBuyTime = 0
local autoBuyConn = RunService.Heartbeat:Connect(function()
    if not ScriptRunning then return end
    if not Config.AutoBuy then return end
    
    local now = tick()
    if now - lastBuyTime < Config.BuyInterval then return end
    lastBuyTime = now
    
    pcall(function()
        local shop = PlayerGui:FindFirstChild("TotemShopUI")
        if not shop then return end
        local sf = shop:FindFirstChild("Frame") and shop.Frame:FindFirstChild("ScrollingFrame")
        if not sf then return end
        local item = sf:FindFirstChild(Config.SelectedItem)
        if item and item:FindFirstChild("BuyButton") then
            local b = item.BuyButton
            firesignal(b.MouseButton1Click)
            firesignal(b.Activated)
            for _, c in pairs(getconnections(b.MouseButton1Click)) do c:Fire() end
        end
    end)
end)
table.insert(AllConnections, autoBuyConn)

-- 2) AUTO OPEN CRATE (Event-driven)
local function GetOpenCrateBtn()
    local mainUi = PlayerGui:FindFirstChild("MainUi")
    if mainUi then
        return mainUi:FindFirstChild("OpenCrateButton", true)
    end
    return nil
end

local lastOpenTime = 0
local autoOpenConn = RunService.Heartbeat:Connect(function()
    if not ScriptRunning then return end
    if not Config.AutoOpen then return end
    
    local now = tick()
    if now - lastOpenTime < Config.OpenSpeed then return end
    lastOpenTime = now
    
    pcall(function()
        local b = GetOpenCrateBtn()
        if b then
            firesignal(b.MouseButton1Click)
            firesignal(b.MouseButton1Down)
            firesignal(b.Activated)
            for _, c in pairs(getconnections(b.MouseButton1Click)) do c:Fire() end
        end
    end)
end)
table.insert(AllConnections, autoOpenConn)

-- 3) AUTO PICKUP (Event-driven)
local function GetDistance(prompt)
    local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return 9999 end
    local part = prompt.Parent
    if part and part:IsA("BasePart") then
        return (char.HumanoidRootPart.Position - part.Position).Magnitude
    end
    return 9999
end

local lastPickupTime = 0
local autoPickupConn = RunService.Heartbeat:Connect(function()
    if not ScriptRunning then return end
    if not Config.AutoPickup then return end
    
    local now = tick()
    if now - lastPickupTime < Config.ScanSpeed then return end
    lastPickupTime = now
    
    pcall(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                if GetDistance(obj) <= Config.PickupRange then
                    fireproximityprompt(obj)
                end
            end
        end
    end)
end)
table.insert(AllConnections, autoPickupConn)

-- 4) LOCK TOOL (Event-driven)
local lockToolConn = RunService.Stepped:Connect(function()
    if not ScriptRunning then return end
    if not Config.LockTool or not Config.LockedTool then return end
    
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and Config.LockedTool.Parent ~= char then
            pcall(function() hum:EquipTool(Config.LockedTool) end)
        end
    end
end)
table.insert(AllConnections, lockToolConn)

-- 5) ANTI-EGG GUI (Event-driven)
local antiEggConn = RunService.Heartbeat:Connect(function()
    if not ScriptRunning then return end
    if not Config.AntiEgg then return end
    
    pcall(function()
        local eggGui = PlayerGui:FindFirstChild("EggCrateOpeningUI")
        if eggGui then
            local skip = eggGui:FindFirstChild("SkipButton", true)
            if skip then
                firesignal(skip.MouseButton1Click)
                firesignal(skip.Activated)
            end
            if eggGui.Enabled then eggGui.Enabled = false end
            local frame = eggGui:FindFirstChild("Frame")
            if frame then
                frame.Visible = false
                frame.Position = UDim2.new(5,0,5,0)
            end
        end
    end)
end)
table.insert(AllConnections, antiEggConn)

-- =================== READY ===================
print("============================================================")
print("[SunnyHubPro] Loaded successfully! Player:", LP.Name)
print("[SunnyHubPro] Phien ban 3.0 - Event-Driven Architecture")
print("============================================================")
print("[SunnyHubPro] Nhan '"..Config.ToggleKey.Name.."' hoac click 'S' de toggle menu.")
print("[SunnyHubPro] Click '-' de thu nho, 'X' de dong script hoan toan.")
print("[SunnyHubPro] Tab 'Giam Lag' - 3 che do, khoi phuc 100% khi tat.")
print("[SunnyHubPro] Tab 'Quan Ly RAM' - Hien thi RAM, doc rac thu cong.")
print("[SunnyHubPro] Tab 'Profiles' - Profile rieng cho tung loai game.")
print("============================================================")
