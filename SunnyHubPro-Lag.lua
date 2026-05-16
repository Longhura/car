--[[
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    ANTI-LAG CORE - PERFORMANCE OPTIMIZER                      ║
    ║                         Phiên bản: 3.0.0 Ultimate                             ║
    ║                    Tác giả: Performance Optimization Team                     ║
    ║                                                                               ║
    ║  Script tối ưu hóa hiệu năng chuyên nghiệp cho Roblox                        ║
    ║  Sử dụng kiến trúc Event-Driven, không gây lag hoặc memory leak              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
]]

--============================================================================--
--                         MODULE: SERVICE CACHE                               --
--  Cache tất cả Service vào biến Local để tăng tốc độ truy xuất              --
--============================================================================--

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

-- Biến Player Local
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

--============================================================================--
--                         MODULE: CONFIG                                      --
--  Lưu trữ tất cả cấu hình và trạng thái của script                          --
--============================================================================--

local ConfigModule = {}

-- Cấu hình mặc định
ConfigModule.Settings = {
    -- Cấu hình chung
    ScriptEnabled = true,
    DebugMode = false,
    AutoSaveConfig = true,
    
    -- Cấu hình giảm lag
    LagReductionMode = 0, -- 0: Tắt, 1: Cơ bản, 2: Nâng cao, 3: Siêu mạnh
    BlackScreenEnabled = false,
    FPSCapEnabled = false,
    FPSCapValue = 60,
    
    -- Cấu hình bộ nhớ
    AutoGarbageCollection = false,
    GCInterval = 30, -- Giây
    
    -- Profile game
    CurrentProfile = "Default", -- Default, Anime, Tycoon, Shooter
    
    -- UI Settings
    UIScale = 1,
    UITransparency = 0.1,
    DragEnabled = true,
    MinimizeOnStart = false
}

-- Trạng thái runtime
ConfigModule.State = {
    -- Connections đang hoạt động (để cleanup)
    ActiveConnections = {},
    
    -- Trạng thái UI
    IsMinimized = false,
    IsDragging = false,
    DragStart = nil,
    StartPosition = nil,
    
    -- Thống kê
    PartsOptimized = 0,
    EffectsRemoved = 0,
    MemoryFreed = 0,
    
    -- Cached original values (để restore)
    OriginalLighting = {},
    OriginalMaterials = {},
    OriginalEffects = {}
}

-- Danh sách các Instance cần tối ưu
ConfigModule.OptimizationTargets = {
    Effects = {
        "BlurEffect",
        "SunRaysEffect", 
        "ColorCorrectionEffect",
        "BloomEffect",
        "DepthOfFieldEffect",
        "Atmosphere"
    },
    Particles = {
        "ParticleEmitter",
        "Trail",
        "Beam",
        "Fire",
        "Smoke",
        "Sparkles"
    },
    Visuals = {
        "Decal",
        "Texture",
        "SurfaceAppearance"
    },
    Sounds = {
        "Sound"
    }
}

-- Profile cấu hình cho từng loại game
ConfigModule.GameProfiles = {
    Default = {
        Name = "Mặc Định",
        Description = "Cấu hình cân bằng cho mọi loại game",
        Settings = {
            HideParticles = true,
            HideTrails = true,
            HideDecals = false,
            HideTextures = false,
            SimplifyMaterials = true,
            HideDistantObjects = false,
            DistanceThreshold = 500
        }
    },
    Anime = {
        Name = "Anime Game",
        Description = "Tối ưu cho Blox Fruits, Anime Adventures, Grand Piece...",
        Settings = {
            HideParticles = true,
            HideTrails = true,
            HideDecals = true,
            HideTextures = false,
            SimplifyMaterials = true,
            HideDistantObjects = true,
            DistanceThreshold = 300,
            HideSkillEffects = true,
            HideLargeNPCs = true,
            NPCSizeThreshold = 50
        }
    },
    Tycoon = {
        Name = "Tycoon/Simulator",
        Description = "Tối ưu cho Pet Simulator, Tycoon games...",
        Settings = {
            HideParticles = true,
            HideTrails = true,
            HideDecals = true,
            HideTextures = true,
            SimplifyMaterials = true,
            HideDistantObjects = true,
            DistanceThreshold = 200,
            HideFloatingText = true,
            HideDroppedItems = true,
            HideDamageIndicators = true
        }
    },
    Shooter = {
        Name = "Shooter/FPS",
        Description = "Tối ưu cho Arsenal, Phantom Forces, Bad Business...",
        Settings = {
            HideParticles = false, -- Giữ lại để thấy đạn
            HideTrails = false,
            HideDecals = true,
            HideTextures = true,
            SimplifyMaterials = true,
            HideDistantObjects = false,
            DistanceThreshold = 1000,
            KeepPlayerVisibility = true,
            OptimizeEnvironment = true,
            ReduceMuzzleFlash = true
        }
    }
}

-- Hàm lưu cấu hình (sử dụng writefile nếu có)
function ConfigModule:SaveConfig()
    if not self.Settings.AutoSaveConfig then return end
    
    local success, err = pcall(function()
        if writefile then
            local configData = HttpService:JSONEncode(self.Settings)
            writefile("AntiLagCore_Config.json", configData)
        end
    end)
    
    if not success and self.Settings.DebugMode then
        warn("[AntiLagCore] Không thể lưu cấu hình: " .. tostring(err))
    end
end

-- Hàm tải cấu hình
function ConfigModule:LoadConfig()
    local success, err = pcall(function()
        if readfile and isfile and isfile("AntiLagCore_Config.json") then
            local configData = readfile("AntiLagCore_Config.json")
            local loadedSettings = HttpService:JSONDecode(configData)
            
            -- Merge với settings mặc định (để có các key mới)
            for key, value in pairs(loadedSettings) do
                if self.Settings[key] ~= nil then
                    self.Settings[key] = value
                end
            end
        end
    end)
    
    if not success and self.Settings.DebugMode then
        warn("[AntiLagCore] Không thể tải cấu hình: " .. tostring(err))
    end
end

-- Hàm reset cấu hình về mặc định
function ConfigModule:ResetConfig()
    self.Settings = {
        ScriptEnabled = true,
        DebugMode = false,
        AutoSaveConfig = true,
        LagReductionMode = 0,
        BlackScreenEnabled = false,
        FPSCapEnabled = false,
        FPSCapValue = 60,
        AutoGarbageCollection = false,
        GCInterval = 30,
        CurrentProfile = "Default",
        UIScale = 1,
        UITransparency = 0.1,
        DragEnabled = true,
        MinimizeOnStart = false
    }
    self:SaveConfig()
end

--============================================================================--
--                         MODULE: UTILITIES                                   --
--  Các hàm tiện ích dùng chung                                               --
--============================================================================--

local UtilsModule = {}

-- Hàm kiểm tra Instance có hợp lệ không
function UtilsModule:IsValidInstance(instance)
    return instance and typeof(instance) == "Instance" and instance.Parent ~= nil
end

-- Hàm lấy khoảng cách từ Player đến một Part
function UtilsModule:GetDistanceFromPlayer(part)
    if not self:IsValidInstance(part) then return math.huge end
    if not LocalPlayer.Character then return math.huge end
    
    local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return math.huge end
    
    local partPosition
    if part:IsA("BasePart") then
        partPosition = part.Position
    elseif part:IsA("Model") then
        local primaryPart = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            partPosition = primaryPart.Position
        else
            return math.huge
        end
    else
        return math.huge
    end
    
    return (humanoidRootPart.Position - partPosition).Magnitude
end

-- Hàm lấy kích thước của Model
function UtilsModule:GetModelSize(model)
    if not self:IsValidInstance(model) then return 0 end
    
    local success, result = pcall(function()
        if model:IsA("Model") then
            local cf, size = model:GetBoundingBox()
            return math.max(size.X, size.Y, size.Z)
        elseif model:IsA("BasePart") then
            return math.max(model.Size.X, model.Size.Y, model.Size.Z)
        end
        return 0
    end)
    
    return success and result or 0
end

-- Hàm đăng ký Connection với cleanup tự động
function UtilsModule:RegisterConnection(connection, category)
    category = category or "General"
    
    if not ConfigModule.State.ActiveConnections[category] then
        ConfigModule.State.ActiveConnections[category] = {}
    end
    
    table.insert(ConfigModule.State.ActiveConnections[category], connection)
    return connection
end

-- Hàm cleanup tất cả Connection theo category
function UtilsModule:CleanupConnections(category)
    if category then
        -- Cleanup một category cụ thể
        local connections = ConfigModule.State.ActiveConnections[category]
        if connections then
            for _, connection in ipairs(connections) do
                if typeof(connection) == "RBXScriptConnection" then
                    connection:Disconnect()
                end
            end
            ConfigModule.State.ActiveConnections[category] = {}
        end
    else
        -- Cleanup tất cả
        for cat, connections in pairs(ConfigModule.State.ActiveConnections) do
            for _, connection in ipairs(connections) do
                if typeof(connection) == "RBXScriptConnection" then
                    connection:Disconnect()
                end
            end
        end
        ConfigModule.State.ActiveConnections = {}
    end
end

-- Hàm format số với đơn vị (KB, MB, GB)
function UtilsModule:FormatBytes(bytes)
    if bytes < 1024 then
        return string.format("%.0f B", bytes)
    elseif bytes < 1048576 then
        return string.format("%.2f KB", bytes / 1024)
    elseif bytes < 1073741824 then
        return string.format("%.2f MB", bytes / 1048576)
    else
        return string.format("%.2f GB", bytes / 1073741824)
    end
end

-- Hàm format thời gian
function UtilsModule:FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%02d:%02d", minutes, secs)
    end
end

-- Hàm tạo UUID ngẫu nhiên
function UtilsModule:GenerateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

-- Hàm deep clone table
function UtilsModule:DeepClone(original)
    local clone = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            clone[key] = self:DeepClone(value)
        else
            clone[key] = value
        end
    end
    return clone
end

-- Hàm lerp cho animation
function UtilsModule:Lerp(a, b, t)
    return a + (b - a) * t
end

-- Hàm easing (Quad Out)
function UtilsModule:EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

-- Hàm easing (Quad In Out)
function UtilsModule:EaseInOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return 1 - math.pow(-2 * t + 2, 2) / 2
    end
end

--============================================================================--
--                         MODULE: OPTIMIZATION                                --
--  Chứa tất cả logic tối ưu hóa hiệu năng                                    --
--============================================================================--

local OptimizeModule = {}

-- Cache các giá trị Lighting gốc
function OptimizeModule:CacheLightingValues()
    local lighting = ConfigModule.State.OriginalLighting
    
    lighting.GlobalShadows = Lighting.GlobalShadows
    lighting.FogEnd = Lighting.FogEnd
    lighting.FogStart = Lighting.FogStart
    lighting.Brightness = Lighting.Brightness
    lighting.ClockTime = Lighting.ClockTime
    lighting.GeographicLatitude = Lighting.GeographicLatitude
    lighting.OutdoorAmbient = Lighting.OutdoorAmbient
    lighting.Ambient = Lighting.Ambient
    lighting.ColorShift_Bottom = Lighting.ColorShift_Bottom
    lighting.ColorShift_Top = Lighting.ColorShift_Top
    lighting.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
    lighting.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    lighting.ShadowSoftness = Lighting.ShadowSoftness
    lighting.Technology = Lighting.Technology
end

-- Khôi phục Lighting về giá trị gốc
function OptimizeModule:RestoreLightingValues()
    local lighting = ConfigModule.State.OriginalLighting
    
    if next(lighting) then
        pcall(function()
            Lighting.GlobalShadows = lighting.GlobalShadows
            Lighting.FogEnd = lighting.FogEnd
            Lighting.FogStart = lighting.FogStart
            Lighting.Brightness = lighting.Brightness
            Lighting.OutdoorAmbient = lighting.OutdoorAmbient
            Lighting.Ambient = lighting.Ambient
        end)
    end
end

--============================================================================--
--                    CHẾ ĐỘ 1: GIẢM LAG CƠ BẢN (YẾU)                          --
--============================================================================--

function OptimizeModule:ApplyBasicOptimization()
    -- Cleanup connections cũ trước
    UtilsModule:CleanupConnections("BasicOptimization")
    
    -- Cache lighting values nếu chưa có
    if not next(ConfigModule.State.OriginalLighting) then
        self:CacheLightingValues()
    end
    
    -- Tắt Global Shadows
    pcall(function()
        Lighting.GlobalShadows = false
    end)
    
    -- Giảm sương mù
    pcall(function()
        Lighting.FogEnd = 999999
        Lighting.FogStart = 999998
    end)
    
    -- Giảm độ sáng môi trường nhẹ
    pcall(function()
        Lighting.EnvironmentDiffuseScale = 0.5
        Lighting.EnvironmentSpecularScale = 0.5
    end)
    
    -- Áp dụng FPS Cap nếu được bật
    if ConfigModule.Settings.FPSCapEnabled then
        self:SetFPSCap(ConfigModule.Settings.FPSCapValue)
    end
    
    ConfigModule.State.PartsOptimized = ConfigModule.State.PartsOptimized + 1
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã áp dụng tối ưu cơ bản")
    end
end

--============================================================================--
--                    CHẾ ĐỘ 2: TỐI ƯU NÂNG CAO (VỪA)                          --
--============================================================================--

function OptimizeModule:ApplyAdvancedOptimization()
    -- Cleanup connections cũ
    UtilsModule:CleanupConnections("AdvancedOptimization")
    
    -- Áp dụng tối ưu cơ bản trước
    self:ApplyBasicOptimization()
    
    -- Ẩn tất cả hiệu ứng Lighting
    for _, effectName in ipairs(ConfigModule.OptimizationTargets.Effects) do
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA(effectName) then
                -- Lưu trạng thái gốc
                if not ConfigModule.State.OriginalEffects[effect] then
                    ConfigModule.State.OriginalEffects[effect] = effect.Enabled
                end
                effect.Enabled = false
                ConfigModule.State.EffectsRemoved = ConfigModule.State.EffectsRemoved + 1
            end
        end
    end
    
    -- Xử lý Atmosphere riêng
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Atmosphere") then
            if not ConfigModule.State.OriginalEffects[child] then
                ConfigModule.State.OriginalEffects[child] = {
                    Density = child.Density,
                    Offset = child.Offset
                }
            end
            child.Density = 0
            child.Offset = 0
        end
    end
    
    -- Đơn giản hóa Materials cho tất cả Parts hiện có
    self:SimplifyAllMaterials()
    
    -- Đăng ký Event để tối ưu Parts mới
    local descendantConnection = Workspace.DescendantAdded:Connect(function(descendant)
        task.defer(function()
            if descendant:IsA("BasePart") then
                self:SimplifyPartMaterial(descendant)
            elseif self:ShouldHideInstance(descendant) then
                self:HideInstance(descendant)
            end
        end)
    end)
    
    UtilsModule:RegisterConnection(descendantConnection, "AdvancedOptimization")
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã áp dụng tối ưu nâng cao")
    end
end

-- Đơn giản hóa Material của một Part
function OptimizeModule:SimplifyPartMaterial(part)
    if not UtilsModule:IsValidInstance(part) then return end
    if not part:IsA("BasePart") then return end
    
    -- Lưu Material gốc
    if not ConfigModule.State.OriginalMaterials[part] then
        ConfigModule.State.OriginalMaterials[part] = part.Material
    end
    
    -- Chuyển sang SmoothPlastic (nhẹ nhất)
    pcall(function()
        part.Material = Enum.Material.SmoothPlastic
        part.Reflectance = 0
    end)
    
    ConfigModule.State.PartsOptimized = ConfigModule.State.PartsOptimized + 1
end

-- Đơn giản hóa Material cho tất cả Parts trong Workspace
function OptimizeModule:SimplifyAllMaterials()
    local count = 0
    local batchSize = 50
    local currentBatch = 0
    
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("BasePart") then
            self:SimplifyPartMaterial(descendant)
            count = count + 1
            currentBatch = currentBatch + 1
            
            -- Yield sau mỗi batch để không gây lag
            if currentBatch >= batchSize then
                currentBatch = 0
                task.wait()
            end
        end
    end
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã đơn giản hóa " .. count .. " Parts")
    end
end

-- Kiểm tra xem có nên ẩn Instance không
function OptimizeModule:ShouldHideInstance(instance)
    local profile = ConfigModule.GameProfiles[ConfigModule.Settings.CurrentProfile]
    if not profile then return false end
    
    local settings = profile.Settings
    
    -- Kiểm tra Particles
    if settings.HideParticles then
        for _, particleType in ipairs(ConfigModule.OptimizationTargets.Particles) do
            if instance:IsA(particleType) then
                return true
            end
        end
    end
    
    -- Kiểm tra Decals/Textures
    if settings.HideDecals and instance:IsA("Decal") then
        return true
    end
    
    if settings.HideTextures and instance:IsA("Texture") then
        return true
    end
    
    return false
end

-- Ẩn một Instance
function OptimizeModule:HideInstance(instance)
    if not UtilsModule:IsValidInstance(instance) then return end
    
    pcall(function()
        if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or 
           instance:IsA("Beam") or instance:IsA("Fire") or 
           instance:IsA("Smoke") or instance:IsA("Sparkles") then
            instance.Enabled = false
        elseif instance:IsA("Decal") or instance:IsA("Texture") then
            instance.Transparency = 1
        elseif instance:IsA("Sound") then
            instance.Volume = 0
        end
    end)
    
    ConfigModule.State.EffectsRemoved = ConfigModule.State.EffectsRemoved + 1
end

--============================================================================--
--                 CHẾ ĐỘ 3: SIÊU TỐI GIẢN (MẠNH NHẤT)                         --
--============================================================================--

function OptimizeModule:ApplyExtremeOptimization()
    -- Cleanup connections cũ
    UtilsModule:CleanupConnections("ExtremeOptimization")
    
    -- Áp dụng tối ưu nâng cao trước
    self:ApplyAdvancedOptimization()
    
    -- Xóa tất cả Particles, Trails, Beams
    self:RemoveAllParticleEffects()
    
    -- Xóa tất cả Decals và Textures
    self:RemoveAllVisualEffects()
    
    -- Xóa Skybox
    self:RemoveSkybox()
    
    -- Tối ưu Terrain
    self:OptimizeTerrain()
    
    -- Giảm chất lượng nước và kính
    self:OptimizeMaterialService()
    
    -- Đăng ký Event để xóa effects mới
    local descendantConnection = Workspace.DescendantAdded:Connect(function(descendant)
        task.defer(function()
            self:ProcessNewDescendant(descendant)
        end)
    end)
    
    UtilsModule:RegisterConnection(descendantConnection, "ExtremeOptimization")
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã áp dụng tối ưu siêu mạnh")
    end
end

-- Xóa tất cả Particle Effects
function OptimizeModule:RemoveAllParticleEffects()
    local count = 0
    local batchSize = 100
    local currentBatch = 0
    
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        for _, particleType in ipairs(ConfigModule.OptimizationTargets.Particles) do
            if descendant:IsA(particleType) then
                pcall(function()
                    descendant.Enabled = false
                    -- Đối với Trail và Beam, reset thêm
                    if descendant:IsA("Trail") then
                        descendant.Lifetime = 0
                    end
                end)
                count = count + 1
                break
            end
        end
        
        currentBatch = currentBatch + 1
        if currentBatch >= batchSize then
            currentBatch = 0
            task.wait()
        end
    end
    
    ConfigModule.State.EffectsRemoved = ConfigModule.State.EffectsRemoved + count
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã xóa " .. count .. " Particle Effects")
    end
end

-- Xóa tất cả Visual Effects (Decals, Textures)
function OptimizeModule:RemoveAllVisualEffects()
    local count = 0
    local batchSize = 100
    local currentBatch = 0
    
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        for _, visualType in ipairs(ConfigModule.OptimizationTargets.Visuals) do
            if descendant:IsA(visualType) then
                pcall(function()
                    descendant.Transparency = 1
                    if descendant:IsA("SurfaceAppearance") then
                        descendant:Destroy()
                    end
                end)
                count = count + 1
                break
            end
        end
        
        currentBatch = currentBatch + 1
        if currentBatch >= batchSize then
            currentBatch = 0
            task.wait()
        end
    end
    
    ConfigModule.State.EffectsRemoved = ConfigModule.State.EffectsRemoved + count
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã xóa " .. count .. " Visual Effects")
    end
end

-- Xóa Skybox
function OptimizeModule:RemoveSkybox()
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Sky") then
            pcall(function()
                child.SkyboxBk = ""
                child.SkyboxDn = ""
                child.SkyboxFt = ""
                child.SkyboxLf = ""
                child.SkyboxRt = ""
                child.SkyboxUp = ""
                child.SunTextureId = ""
                child.MoonTextureId = ""
            end)
        end
    end
end

-- Tối ưu Terrain
function OptimizeModule:OptimizeTerrain()
    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
        end
    end)
end

-- Tối ưu MaterialService (Nước, Kính)
function OptimizeModule:OptimizeMaterialService()
    pcall(function()
        -- Lấy hoặc tạo MaterialVariant cho Glass
        local glassVariant = MaterialService:FindFirstChild("Glass")
        if not glassVariant then
            glassVariant = Instance.new("MaterialVariant")
            glassVariant.Name = "Glass"
            glassVariant.BaseMaterial = Enum.Material.Glass
            glassVariant.Parent = MaterialService
        end
        
        -- Đơn giản hóa Glass
        if glassVariant:IsA("MaterialVariant") then
            glassVariant.StudsPerTile = 10
        end
    end)
end

-- Xử lý Descendant mới (cho Event-driven)
function OptimizeModule:ProcessNewDescendant(descendant)
    if not UtilsModule:IsValidInstance(descendant) then return end
    
    local mode = ConfigModule.Settings.LagReductionMode
    
    if mode >= 3 then
        -- Chế độ siêu mạnh: xóa hầu hết effects
        for _, particleType in ipairs(ConfigModule.OptimizationTargets.Particles) do
            if descendant:IsA(particleType) then
                pcall(function()
                    descendant.Enabled = false
                end)
                return
            end
        end
        
        for _, visualType in ipairs(ConfigModule.OptimizationTargets.Visuals) do
            if descendant:IsA(visualType) then
                pcall(function()
                    descendant.Transparency = 1
                end)
                return
            end
        end
    end
    
    if mode >= 2 then
        -- Chế độ nâng cao: đơn giản hóa materials
        if descendant:IsA("BasePart") then
            self:SimplifyPartMaterial(descendant)
        end
    end
end

--============================================================================--
--                    MÀN HÌNH ĐEN (BLACK SCREEN MODE)                         --
--============================================================================--

function OptimizeModule:EnableBlackScreen()
    -- Kiểm tra xem có hỗ trợ Set3dRenderingEnabled không
    local has3DRenderControl = pcall(function()
        return RunService.Set3dRenderingEnabled
    end)
    
    if has3DRenderControl then
        -- Sử dụng Set3dRenderingEnabled nếu có
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
        end)
    else
        -- Fallback: Tạo Frame đen phủ toàn màn hình
        self:CreateBlackScreenOverlay()
    end
    
    ConfigModule.Settings.BlackScreenEnabled = true
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã bật màn hình đen")
    end
end

function OptimizeModule:DisableBlackScreen()
    local has3DRenderControl = pcall(function()
        return RunService.Set3dRenderingEnabled
    end)
    
    if has3DRenderControl then
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
    end
    
    -- Xóa overlay nếu có
    self:RemoveBlackScreenOverlay()
    
    ConfigModule.Settings.BlackScreenEnabled = false
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã tắt màn hình đen")
    end
end

function OptimizeModule:CreateBlackScreenOverlay()
    -- Xóa overlay cũ nếu có
    self:RemoveBlackScreenOverlay()
    
    -- Tạo ScreenGui mới
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AntiLagCore_BlackScreen"
    screenGui.DisplayOrder = 999999
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    
    -- Tạo Frame đen
    local blackFrame = Instance.new("Frame")
    blackFrame.Name = "BlackOverlay"
    blackFrame.Size = UDim2.new(1, 0, 1, 0)
    blackFrame.Position = UDim2.new(0, 0, 0, 0)
    blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    blackFrame.BackgroundTransparency = 0
    blackFrame.BorderSizePixel = 0
    blackFrame.ZIndex = 999999
    blackFrame.Parent = screenGui
    
    -- Thêm text thông báo
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(0.8, 0, 0, 100)
    infoLabel.Position = UDim2.new(0.1, 0, 0.5, -50)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.Text = "CHẾ ĐỘ TREO MÁY ĐANG BẬT\n\nCPU/GPU đang nghỉ ngơi\nNhấn phím bất kỳ hoặc click để tắt"
    infoLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
    infoLabel.TextSize = 24
    infoLabel.TextWrapped = true
    infoLabel.ZIndex = 1000000
    infoLabel.Parent = blackFrame
    
    -- Hiệu ứng nhấp nháy cho text
    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local tween = TweenService:Create(infoLabel, tweenInfo, {TextTransparency = 0.5})
    tween:Play()
    
    -- Parent vào CoreGui hoặc PlayerGui
    local success = pcall(function()
        screenGui.Parent = CoreGui
    end)
    
    if not success then
        screenGui.Parent = PlayerGui
    end
    
    -- Đăng ký input để tắt
    local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if not processed then
            self:DisableBlackScreen()
        end
    end)
    
    UtilsModule:RegisterConnection(inputConnection, "BlackScreen")
end

function OptimizeModule:RemoveBlackScreenOverlay()
    -- Tìm và xóa trong CoreGui
    local coreGuiOverlay = CoreGui:FindFirstChild("AntiLagCore_BlackScreen")
    if coreGuiOverlay then
        coreGuiOverlay:Destroy()
    end
    
    -- Tìm và xóa trong PlayerGui
    local playerGuiOverlay = PlayerGui:FindFirstChild("AntiLagCore_BlackScreen")
    if playerGuiOverlay then
        playerGuiOverlay:Destroy()
    end
    
    -- Cleanup connections
    UtilsModule:CleanupConnections("BlackScreen")
end

--============================================================================--
--                           FPS CAP CONTROL                                   --
--============================================================================--

function OptimizeModule:SetFPSCap(fps)
    local success = pcall(function()
        if setfpscap then
            setfpscap(fps)
        elseif set_fps_cap then
            set_fps_cap(fps)
        end
    end)
    
    if success then
        ConfigModule.Settings.FPSCapValue = fps
        if ConfigModule.Settings.DebugMode then
            print("[AntiLagCore] Đã đặt FPS Cap: " .. fps)
        end
    end
end

function OptimizeModule:RemoveFPSCap()
    local success = pcall(function()
        if setfpscap then
            setfpscap(9999)
        elseif set_fps_cap then
            set_fps_cap(9999)
        end
    end)
    
    if success and ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã gỡ FPS Cap")
    end
end

--============================================================================--
--                    ÁP DỤNG CHẾ ĐỘ TỐI ƯU TỔNG HỢP                           --
--============================================================================--

function OptimizeModule:ApplyOptimizationMode(mode)
    -- Cleanup tất cả connections cũ
    UtilsModule:CleanupConnections("BasicOptimization")
    UtilsModule:CleanupConnections("AdvancedOptimization")
    UtilsModule:CleanupConnections("ExtremeOptimization")
    
    -- Reset state
    ConfigModule.State.PartsOptimized = 0
    ConfigModule.State.EffectsRemoved = 0
    
    ConfigModule.Settings.LagReductionMode = mode
    
    if mode == 0 then
        -- Tắt tất cả tối ưu, khôi phục về gốc
        self:RestoreAllSettings()
    elseif mode == 1 then
        self:ApplyBasicOptimization()
    elseif mode == 2 then
        self:ApplyAdvancedOptimization()
    elseif mode == 3 then
        self:ApplyExtremeOptimization()
    end
    
    ConfigModule:SaveConfig()
end

-- Khôi phục tất cả settings về gốc
function OptimizeModule:RestoreAllSettings()
    -- Khôi phục Lighting
    self:RestoreLightingValues()
    
    -- Khôi phục Effects
    for effect, originalValue in pairs(ConfigModule.State.OriginalEffects) do
        if UtilsModule:IsValidInstance(effect) then
            pcall(function()
                if typeof(originalValue) == "boolean" then
                    effect.Enabled = originalValue
                elseif typeof(originalValue) == "table" then
                    for prop, val in pairs(originalValue) do
                        effect[prop] = val
                    end
                end
            end)
        end
    end
    
    -- Khôi phục Materials
    for part, originalMaterial in pairs(ConfigModule.State.OriginalMaterials) do
        if UtilsModule:IsValidInstance(part) then
            pcall(function()
                part.Material = originalMaterial
            end)
        end
    end
    
    -- Gỡ FPS Cap
    if ConfigModule.Settings.FPSCapEnabled then
        self:RemoveFPSCap()
    end
    
    -- Tắt Black Screen
    if ConfigModule.Settings.BlackScreenEnabled then
        self:DisableBlackScreen()
    end
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã khôi phục tất cả settings")
    end
end

--============================================================================--
--                         MODULE: MEMORY CLEANER                              --
--  Tối ưu hóa bộ nhớ và dọn rác                                              --
--============================================================================--

local MemoryModule = {}

-- Lấy thông tin bộ nhớ hiện tại
function MemoryModule:GetMemoryUsage()
    local memoryKB = 0
    
    local success = pcall(function()
        memoryKB = gcinfo()
    end)
    
    if not success then
        -- Fallback: sử dụng Stats service
        pcall(function()
            local memStats = Stats:FindFirstChild("MemoryStoreService")
            if memStats then
                memoryKB = memStats:GetValue() / 1024
            end
        end)
    end
    
    return memoryKB
end

-- Lấy thông tin chi tiết bộ nhớ
function MemoryModule:GetDetailedMemoryInfo()
    local info = {
        TotalMemory = self:GetMemoryUsage(),
        Instances = {
            Parts = 0,
            Scripts = 0,
            Sounds = 0,
            Particles = 0,
            Other = 0
        }
    }
    
    -- Đếm số lượng Instances
    local success = pcall(function()
        for _, descendant in ipairs(game:GetDescendants()) do
            if descendant:IsA("BasePart") then
                info.Instances.Parts = info.Instances.Parts + 1
            elseif descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
                info.Instances.Scripts = info.Instances.Scripts + 1
            elseif descendant:IsA("Sound") then
                info.Instances.Sounds = info.Instances.Sounds + 1
            elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
                info.Instances.Particles = info.Instances.Particles + 1
            else
                info.Instances.Other = info.Instances.Other + 1
            end
        end
    end)
    
    return info
end

-- Dọn rác thủ công
function MemoryModule:CollectGarbage()
    local beforeMemory = self:GetMemoryUsage()
    
    -- Force garbage collection
    local success = pcall(function()
        collectgarbage("collect")
    end)
    
    -- Xóa Sounds đã phát xong
    self:CleanupFinishedSounds()
    
    -- Xóa Particles đã hết lifetime
    self:CleanupDeadParticles()
    
    -- Xóa Instances mồ côi
    self:CleanupOrphanedInstances()
    
    -- Đợi một chút và collect lại
    task.wait(0.1)
    pcall(function()
        collectgarbage("collect")
    end)
    
    local afterMemory = self:GetMemoryUsage()
    local freedMemory = math.max(0, beforeMemory - afterMemory)
    
    ConfigModule.State.MemoryFreed = ConfigModule.State.MemoryFreed + freedMemory
    
    if ConfigModule.Settings.DebugMode then
        print(string.format("[AntiLagCore] Đã giải phóng %.2f KB bộ nhớ", freedMemory))
    end
    
    return freedMemory
end

-- Dọn Sounds đã phát xong
function MemoryModule:CleanupFinishedSounds()
    local count = 0
    
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Sound") then
            pcall(function()
                if not descendant.IsPlaying and descendant.TimePosition >= descendant.TimeLength - 0.1 then
                    -- Sound đã phát xong, giảm volume
                    descendant.Volume = 0
                    count = count + 1
                end
            end)
        end
    end
    
    return count
end

-- Dọn Particles đã chết
function MemoryModule:CleanupDeadParticles()
    local count = 0
    
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") then
            pcall(function()
                if not descendant.Enabled and descendant.Rate == 0 then
                    descendant:Clear()
                    count = count + 1
                end
            end)
        end
    end
    
    return count
end

-- Dọn Instances mồ côi
function MemoryModule:CleanupOrphanedInstances()
    local count = 0
    
    -- Tìm các Connection bị leak (không còn valid)
    for category, connections in pairs(ConfigModule.State.ActiveConnections) do
        local validConnections = {}
        for _, conn in ipairs(connections) do
            if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                table.insert(validConnections, conn)
            else
                count = count + 1
            end
        end
        ConfigModule.State.ActiveConnections[category] = validConnections
    end
    
    return count
end

-- Bật Auto Garbage Collection
function MemoryModule:EnableAutoGC()
    -- Cleanup connection cũ
    UtilsModule:CleanupConnections("AutoGC")
    
    ConfigModule.Settings.AutoGarbageCollection = true
    
    -- Tạo connection mới
    local lastGCTime = 0
    local interval = ConfigModule.Settings.GCInterval
    
    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - lastGCTime >= interval then
            lastGCTime = currentTime
            task.defer(function()
                self:CollectGarbage()
            end)
        end
    end)
    
    UtilsModule:RegisterConnection(heartbeatConnection, "AutoGC")
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã bật Auto GC với interval " .. interval .. "s")
    end
end

-- Tắt Auto Garbage Collection
function MemoryModule:DisableAutoGC()
    UtilsModule:CleanupConnections("AutoGC")
    ConfigModule.Settings.AutoGarbageCollection = false
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã tắt Auto GC")
    end
end

--============================================================================--
--                         MODULE: GAME PROFILES                               --
--  Cấu hình tối ưu cho từng loại game                                        --
--============================================================================--

local ProfileModule = {}

-- Áp dụng Profile
function ProfileModule:ApplyProfile(profileName)
    local profile = ConfigModule.GameProfiles[profileName]
    if not profile then
        warn("[AntiLagCore] Không tìm thấy profile: " .. profileName)
        return false
    end
    
    -- Cleanup connections cũ
    UtilsModule:CleanupConnections("Profile")
    
    ConfigModule.Settings.CurrentProfile = profileName
    local settings = profile.Settings
    
    -- Áp dụng các cài đặt của profile
    if settings.HideParticles then
        self:HideAllParticles()
    end
    
    if settings.HideTrails then
        self:HideAllTrails()
    end
    
    if settings.HideDecals then
        self:HideAllDecals()
    end
    
    if settings.HideTextures then
        self:HideAllTextures()
    end
    
    if settings.SimplifyMaterials then
        OptimizeModule:SimplifyAllMaterials()
    end
    
    if settings.HideDistantObjects then
        self:EnableDistanceCulling(settings.DistanceThreshold)
    end
    
    -- Profile-specific settings
    if profileName == "Anime" then
        self:ApplyAnimeProfileSettings(settings)
    elseif profileName == "Tycoon" then
        self:ApplyTycoonProfileSettings(settings)
    elseif profileName == "Shooter" then
        self:ApplyShooterProfileSettings(settings)
    end
    
    -- Đăng ký Event để áp dụng cho Instances mới
    local descendantConnection = Workspace.DescendantAdded:Connect(function(descendant)
        task.defer(function()
            self:ProcessNewInstanceForProfile(descendant, settings)
        end)
    end)
    
    UtilsModule:RegisterConnection(descendantConnection, "Profile")
    
    ConfigModule:SaveConfig()
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] Đã áp dụng profile: " .. profile.Name)
    end
    
    return true
end

-- Ẩn tất cả Particles
function ProfileModule:HideAllParticles()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") then
            pcall(function()
                descendant.Enabled = false
            end)
        end
    end
end

-- Ẩn tất cả Trails
function ProfileModule:HideAllTrails()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Trail") then
            pcall(function()
                descendant.Enabled = false
            end)
        end
    end
end

-- Ẩn tất cả Decals
function ProfileModule:HideAllDecals()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Decal") then
            pcall(function()
                descendant.Transparency = 1
            end)
        end
    end
end

-- Ẩn tất cả Textures
function ProfileModule:HideAllTextures()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Texture") then
            pcall(function()
                descendant.Transparency = 1
            end)
        end
    end
end

-- Bật Distance Culling
function ProfileModule:EnableDistanceCulling(threshold)
    -- Cleanup connection cũ
    UtilsModule:CleanupConnections("DistanceCulling")
    
    local hiddenParts = {}
    
    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        task.defer(function()
            for _, descendant in ipairs(Workspace:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    local distance = UtilsModule:GetDistanceFromPlayer(descendant)
                    
                    if distance > threshold then
                        if not hiddenParts[descendant] then
                            hiddenParts[descendant] = descendant.Transparency
                            pcall(function()
                                descendant.Transparency = 1
                            end)
                        end
                    else
                        if hiddenParts[descendant] then
                            pcall(function()
                                descendant.Transparency = hiddenParts[descendant]
                            end)
                            hiddenParts[descendant] = nil
                        end
                    end
                end
            end
        end)
    end)
    
    UtilsModule:RegisterConnection(heartbeatConnection, "DistanceCulling")
end

-- Settings đặc biệt cho Anime games
function ProfileModule:ApplyAnimeProfileSettings(settings)
    -- Ẩn NPCs lớn
    if settings.HideLargeNPCs then
        local threshold = settings.NPCSizeThreshold or 50
        
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
                local size = UtilsModule:GetModelSize(descendant)
                if size > threshold then
                    pcall(function()
                        for _, part in ipairs(descendant:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Transparency = 0.9
                            end
                        end
                    end)
                end
            end
        end
    end
    
    -- Ẩn skill effects (tìm theo naming pattern)
    if settings.HideSkillEffects then
        local skillPatterns = {"skill", "effect", "attack", "ability", "aura", "vfx", "fx"}
        
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            local nameLower = descendant.Name:lower()
            for _, pattern in ipairs(skillPatterns) do
                if nameLower:find(pattern) then
                    if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
                        pcall(function()
                            descendant.Enabled = false
                        end)
                    end
                    break
                end
            end
        end
    end
end

-- Settings đặc biệt cho Tycoon games
function ProfileModule:ApplyTycoonProfileSettings(settings)
    -- Ẩn floating text
    if settings.HideFloatingText then
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            if descendant:IsA("BillboardGui") then
                pcall(function()
                    descendant.Enabled = false
                end)
            end
        end
    end
    
    -- Ẩn dropped items (tìm theo naming pattern)
    if settings.HideDroppedItems then
        local dropPatterns = {"drop", "coin", "money", "cash", "gem", "collect", "pickup"}
        
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            local nameLower = descendant.Name:lower()
            for _, pattern in ipairs(dropPatterns) do
                if nameLower:find(pattern) then
                    if descendant:IsA("BasePart") then
                        pcall(function()
                            descendant.Transparency = 1
                        end)
                    end
                    break
                end
            end
        end
    end
    
    -- Ẩn damage indicators
    if settings.HideDamageIndicators then
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            if descendant:IsA("BillboardGui") then
                local nameLower = descendant.Name:lower()
                if nameLower:find("damage") or nameLower:find("hit") or nameLower:find("indicator") then
                    pcall(function()
                        descendant.Enabled = false
                    end)
                end
            end
        end
    end
end

-- Settings đặc biệt cho Shooter games
function ProfileModule:ApplyShooterProfileSettings(settings)
    -- Giữ Player visibility
    if settings.KeepPlayerVisibility then
        -- Không ẩn các Player characters
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 0
                    end
                end
            end
        end
    end
    
    -- Tối ưu môi trường
    if settings.OptimizeEnvironment then
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            if descendant:IsA("BasePart") then
                local nameLower = descendant.Name:lower()
                -- Không tối ưu các parts liên quan đến player
                if not nameLower:find("player") and not nameLower:find("character") then
                    pcall(function()
                        descendant.CastShadow = false
                    end)
                end
            end
        end
    end
    
    -- Giảm muzzle flash
    if settings.ReduceMuzzleFlash then
        local muzzlePatterns = {"muzzle", "flash", "fire", "shoot", "gun"}
        
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            local nameLower = descendant.Name:lower()
            for _, pattern in ipairs(muzzlePatterns) do
                if nameLower:find(pattern) then
                    if descendant:IsA("ParticleEmitter") or descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
                        pcall(function()
                            if descendant:IsA("ParticleEmitter") then
                                descendant.Rate = math.min(descendant.Rate, 5)
                            elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
                                descendant.Brightness = descendant.Brightness * 0.3
                            end
                        end)
                    end
                    break
                end
            end
        end
    end
end

-- Xử lý Instance mới theo Profile
function ProfileModule:ProcessNewInstanceForProfile(instance, settings)
    if not UtilsModule:IsValidInstance(instance) then return end
    
    if settings.HideParticles and instance:IsA("ParticleEmitter") then
        pcall(function() instance.Enabled = false end)
    end
    
    if settings.HideTrails and instance:IsA("Trail") then
        pcall(function() instance.Enabled = false end)
    end
    
    if settings.HideDecals and instance:IsA("Decal") then
        pcall(function() instance.Transparency = 1 end)
    end
    
    if settings.HideTextures and instance:IsA("Texture") then
        pcall(function() instance.Transparency = 1 end)
    end
    
    if settings.SimplifyMaterials and instance:IsA("BasePart") then
        OptimizeModule:SimplifyPartMaterial(instance)
    end
end

--============================================================================--
--                              MODULE: UI                                     --
--  Tạo giao diện người dùng mượt mà với Tween                                --
--============================================================================--

local UIModule = {}

-- Theme colors
UIModule.Theme = {
    Background = Color3.fromRGB(15, 15, 20),
    BackgroundSecondary = Color3.fromRGB(25, 25, 35),
    BackgroundTertiary = Color3.fromRGB(35, 35, 50),
    Accent = Color3.fromRGB(0, 200, 150),
    AccentSecondary = Color3.fromRGB(0, 255, 200),
    AccentDanger = Color3.fromRGB(255, 80, 80),
    AccentWarning = Color3.fromRGB(255, 180, 50),
    Text = Color3.fromRGB(240, 240, 245),
    TextSecondary = Color3.fromRGB(150, 150, 165),
    TextMuted = Color3.fromRGB(100, 100, 120),
    Border = Color3.fromRGB(50, 50, 70),
    Shadow = Color3.fromRGB(0, 0, 0)
}

-- UI Elements cache
UIModule.Elements = {}

-- Tạo ScreenGui chính
function UIModule:CreateMainUI()
    -- Xóa UI cũ nếu có
    self:DestroyUI()
    
    -- Tạo ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AntiLagCore_UI"
    screenGui.DisplayOrder = 99999
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Parent vào CoreGui hoặc PlayerGui
    local success = pcall(function()
        screenGui.Parent = CoreGui
    end)
    
    if not success then
        screenGui.Parent = PlayerGui
    end
    
    self.Elements.ScreenGui = screenGui
    
    -- Tạo Main Frame
    self:CreateMainFrame()
    
    -- Tạo Mini Toolbar (khi minimize)
    self:CreateMiniToolbar()
    
    -- Áp dụng minimize state nếu cần
    if ConfigModule.Settings.MinimizeOnStart then
        self:MinimizeUI()
    end
    
    return screenGui
end

-- Tạo Main Frame
function UIModule:CreateMainFrame()
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 380, 0, 520)
    mainFrame.Position = UDim2.new(0.5, -190, 0.5, -260)
    mainFrame.BackgroundColor3 = self.Theme.Background
    mainFrame.BackgroundTransparency = ConfigModule.Settings.UITransparency
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = self.Elements.ScreenGui
    
    self.Elements.MainFrame = mainFrame
    
    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Border stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = self.Theme.Border
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = mainFrame
    
    -- Drop shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.Position = UDim2.new(0, -20, 0, -20)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = self.Theme.Shadow
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ZIndex = -1
    shadow.Parent = mainFrame
    
    -- Tạo Title Bar
    self:CreateTitleBar()
    
    -- Tạo Tab Bar
    self:CreateTabBar()
    
    -- Tạo Tab Contents
    self:CreateTabContents()
    
    -- Tạo Status Bar
    self:CreateStatusBar()
end

-- Tạo Title Bar
function UIModule:CreateTitleBar()
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 45)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = self.Theme.BackgroundSecondary
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    titleBar.Parent = self.Elements.MainFrame
    
    self.Elements.TitleBar = titleBar
    
    -- Corner cho title bar (chỉ góc trên)
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    -- Bottom padding để che góc dưới
    local bottomCover = Instance.new("Frame")
    bottomCover.Name = "BottomCover"
    bottomCover.Size = UDim2.new(1, 0, 0, 12)
    bottomCover.Position = UDim2.new(0, 0, 1, -12)
    bottomCover.BackgroundColor3 = self.Theme.BackgroundSecondary
    bottomCover.BackgroundTransparency = 0.3
    bottomCover.BorderSizePixel = 0
    bottomCover.Parent = titleBar
    
    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 30, 0, 30)
    icon.Position = UDim2.new(0, 12, 0.5, -15)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.Text = "⚡"
    icon.TextColor3 = self.Theme.Accent
    icon.TextSize = 20
    icon.Parent = titleBar
    
    -- Title text
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0, 200, 1, 0)
    title.Position = UDim2.new(0, 45, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "ANTI-LAG CORE"
    title.TextColor3 = self.Theme.Text
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Version text
    local version = Instance.new("TextLabel")
    version.Name = "Version"
    version.Size = UDim2.new(0, 50, 1, 0)
    version.Position = UDim2.new(0, 170, 0, 0)
    version.BackgroundTransparency = 1
    version.Font = Enum.Font.Gotham
    version.Text = "v3.0"
    version.TextColor3 = self.Theme.TextMuted
    version.TextSize = 11
    version.TextXAlignment = Enum.TextXAlignment.Left
    version.Parent = titleBar
    
    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(1, -75, 0.5, -15)
    minimizeBtn.BackgroundColor3 = self.Theme.BackgroundTertiary
    minimizeBtn.BackgroundTransparency = 0.5
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = self.Theme.TextSecondary
    minimizeBtn.TextSize = 18
    minimizeBtn.AutoButtonColor = false
    minimizeBtn.Parent = titleBar
    
    local minimizeBtnCorner = Instance.new("UICorner")
    minimizeBtnCorner.CornerRadius = UDim.new(0, 6)
    minimizeBtnCorner.Parent = minimizeBtn
    
    self.Elements.MinimizeBtn = minimizeBtn
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
    closeBtn.BackgroundColor3 = self.Theme.AccentDanger
    closeBtn.BackgroundTransparency = 0.7
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "×"
    closeBtn.TextColor3 = self.Theme.Text
    closeBtn.TextSize = 18
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = titleBar
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn
    
    self.Elements.CloseBtn = closeBtn
    
    -- Setup drag functionality
    self:SetupDragging(titleBar)
    
    -- Setup button events
    self:SetupTitleBarEvents()
end

-- Setup Dragging (Sửa lỗi: Kéo thả mượt mà bằng Vector2 delta calculation)
function UIModule:SetupDragging(dragHandle)
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    
    -- Cập nhật vị trí trực tiếp không dùng Tween để tránh lag
    local function update(input)
        local delta = input.Position - dragStart
        self.Elements.MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            -- Kiểm tra xem có click vào nút không (MinimizeBtn, CloseBtn)
            local mousePos = UserInputService:GetMouseLocation()
            local minimizeBtn = self.Elements.MinimizeBtn
            local closeBtn = self.Elements.CloseBtn
            
            -- Nếu click vào nút thì không kéo
            if minimizeBtn and closeBtn then
                local minAbsPos = minimizeBtn.AbsolutePosition
                local minAbsSize = minimizeBtn.AbsoluteSize
                local closeAbsPos = closeBtn.AbsolutePosition
                local closeAbsSize = closeBtn.AbsoluteSize
                
                local inMinimize = mousePos.X >= minAbsPos.X and mousePos.X <= minAbsPos.X + minAbsSize.X
                    and mousePos.Y >= minAbsPos.Y and mousePos.Y <= minAbsPos.Y + minAbsSize.Y
                local inClose = mousePos.X >= closeAbsPos.X and mousePos.X <= closeAbsPos.X + closeAbsSize.X
                    and mousePos.Y >= closeAbsPos.Y and mousePos.Y <= closeAbsPos.Y + closeAbsSize.Y
                
                if inMinimize or inClose then
                    return -- Không kéo nếu click vào nút
                end
            end
            
            dragging = true
            dragStart = input.Position
            startPos = self.Elements.MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- Setup Title Bar Events
function UIModule:SetupTitleBarEvents()
    -- Minimize button hover
    self.Elements.MinimizeBtn.MouseEnter:Connect(function()
        local tween = TweenService:Create(self.Elements.MinimizeBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.3,
            TextColor3 = self.Theme.Text
        })
        tween:Play()
    end)
    
    self.Elements.MinimizeBtn.MouseLeave:Connect(function()
        local tween = TweenService:Create(self.Elements.MinimizeBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.5,
            TextColor3 = self.Theme.TextSecondary
        })
        tween:Play()
    end)
    
    self.Elements.MinimizeBtn.MouseButton1Click:Connect(function()
        self:MinimizeUI()
    end)
    
    -- Close button hover
    self.Elements.CloseBtn.MouseEnter:Connect(function()
        local tween = TweenService:Create(self.Elements.CloseBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.3
        })
        tween:Play()
    end)
    
    self.Elements.CloseBtn.MouseLeave:Connect(function()
        local tween = TweenService:Create(self.Elements.CloseBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.7
        })
        tween:Play()
    end)
    
    self.Elements.CloseBtn.MouseButton1Click:Connect(function()
        self:DestroyUI()
    end)
end

-- Tạo Tab Bar
function UIModule:CreateTabBar()
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, -20, 0, 40)
    tabBar.Position = UDim2.new(0, 10, 0, 50)
    tabBar.BackgroundColor3 = self.Theme.BackgroundSecondary
    tabBar.BackgroundTransparency = 0.5
    tabBar.BorderSizePixel = 0
    tabBar.Parent = self.Elements.MainFrame
    
    self.Elements.TabBar = tabBar
    
    local tabBarCorner = Instance.new("UICorner")
    tabBarCorner.CornerRadius = UDim.new(0, 8)
    tabBarCorner.Parent = tabBar
    
    -- Tab layout
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabBar
    
    -- Create tabs
    local tabs = {
        {Name = "LagReduction", Text = "Giảm Lag", Icon = "🔧"},
        {Name = "Memory", Text = "Bộ Nhớ", Icon = "💾"},
        {Name = "Profiles", Text = "Profiles", Icon = "🎮"}
    }
    
    self.Elements.Tabs = {}
    
    for i, tabData in ipairs(tabs) do
        local tab = Instance.new("TextButton")
        tab.Name = tabData.Name .. "Tab"
        tab.Size = UDim2.new(0, 110, 0, 32)
        tab.BackgroundColor3 = i == 1 and self.Theme.Accent or self.Theme.BackgroundTertiary
        tab.BackgroundTransparency = i == 1 and 0.3 or 0.7
        tab.BorderSizePixel = 0
        tab.Font = Enum.Font.GothamMedium
        tab.Text = tabData.Icon .. " " .. tabData.Text
        tab.TextColor3 = i == 1 and self.Theme.Text or self.Theme.TextSecondary
        tab.TextSize = 12
        tab.AutoButtonColor = false
        tab.Parent = tabBar
        
        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 6)
        tabCorner.Parent = tab
        
        self.Elements.Tabs[tabData.Name] = tab
        
        -- Tab click event
        tab.MouseButton1Click:Connect(function()
            self:SwitchTab(tabData.Name)
        end)
        
        -- Hover effects
        tab.MouseEnter:Connect(function()
            if ConfigModule.State.CurrentTab ~= tabData.Name then
                local tween = TweenService:Create(tab, TweenInfo.new(0.2), {
                    BackgroundTransparency = 0.5
                })
                tween:Play()
            end
        end)
        
        tab.MouseLeave:Connect(function()
            if ConfigModule.State.CurrentTab ~= tabData.Name then
                local tween = TweenService:Create(tab, TweenInfo.new(0.2), {
                    BackgroundTransparency = 0.7
                })
                tween:Play()
            end
        end)
    end
    
    ConfigModule.State.CurrentTab = "LagReduction"
end

-- Tạo Tab Contents
function UIModule:CreateTabContents()
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, -20, 1, -140)
    contentContainer.Position = UDim2.new(0, 10, 0, 95)
    contentContainer.BackgroundTransparency = 1
    contentContainer.ClipsDescendants = true
    contentContainer.Parent = self.Elements.MainFrame
    
    self.Elements.ContentContainer = contentContainer
    
    -- Tạo nội dung cho từng tab
    self:CreateLagReductionTab()
    self:CreateMemoryTab()
    self:CreateProfilesTab()
end

-- Tạo Tab Giảm Lag
function UIModule:CreateLagReductionTab()
    local lagTab = Instance.new("ScrollingFrame")
    lagTab.Name = "LagReductionContent"
    lagTab.Size = UDim2.new(1, 0, 1, 0)
    lagTab.Position = UDim2.new(0, 0, 0, 0)
    lagTab.BackgroundTransparency = 1
    lagTab.BorderSizePixel = 0
    lagTab.ScrollBarThickness = 4
    lagTab.ScrollBarImageColor3 = self.Theme.Accent
    lagTab.ScrollBarImageTransparency = 0.5
    lagTab.CanvasSize = UDim2.new(0, 0, 0, 400)
    lagTab.Visible = true
    lagTab.Parent = self.Elements.ContentContainer
    
    self.Elements.LagReductionContent = lagTab
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 10)
    layout.Parent = lagTab
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.Parent = lagTab
    
    -- Chế độ 1: Giảm Lag Cơ Bản
    self:CreateToggleCard(lagTab, {
        Name = "BasicMode",
        Title = "Chế Độ Cơ Bản",
        Description = "Tắt bóng, giảm sương mù, khóa FPS",
        Icon = "🔋",
        Color = self.Theme.Accent,
        OnToggle = function(enabled)
            if enabled then
                OptimizeModule:ApplyOptimizationMode(1)
            else
                OptimizeModule:ApplyOptimizationMode(0)
            end
        end
    })
    
    -- Chế độ 2: Tối Ưu Nâng Cao
    self:CreateToggleCard(lagTab, {
        Name = "AdvancedMode",
        Title = "Tối Ưu Nâng Cao",
        Description = "Ẩn hiệu ứng, đơn giản hóa vật liệu",
        Icon = "⚡",
        Color = self.Theme.AccentWarning,
        OnToggle = function(enabled)
            if enabled then
                OptimizeModule:ApplyOptimizationMode(2)
            else
                OptimizeModule:ApplyOptimizationMode(0)
            end
        end
    })
    
    -- Chế độ 3: Siêu Tối Giản
    self:CreateToggleCard(lagTab, {
        Name = "ExtremeMode",
        Title = "Siêu Tối Giản",
        Description = "Xóa textures, particles, skybox",
        Icon = "🔥",
        Color = self.Theme.AccentDanger,
        OnToggle = function(enabled)
            if enabled then
                OptimizeModule:ApplyOptimizationMode(3)
            else
                OptimizeModule:ApplyOptimizationMode(0)
            end
        end
    })
    
    -- Black Screen Mode
    self:CreateToggleCard(lagTab, {
        Name = "BlackScreenMode",
        Title = "Màn Hình Đen",
        Description = "Tắt render 3D khi treo máy xuyên đêm",
        Icon = "🌙",
        Color = Color3.fromRGB(80, 80, 100),
        IsDanger = true,
        OnToggle = function(enabled)
            if enabled then
                OptimizeModule:EnableBlackScreen()
            else
                OptimizeModule:DisableBlackScreen()
            end
        end
    })
    
    -- FPS Cap Slider
    self:CreateSliderCard(lagTab, {
        Name = "FPSCap",
        Title = "Khóa FPS",
        Description = "Giới hạn FPS để ổn định hiệu năng",
        Icon = "📊",
        Min = 15,
        Max = 240,
        Default = 60,
        Step = 5,
        OnChange = function(value)
            ConfigModule.Settings.FPSCapValue = value
            if ConfigModule.Settings.FPSCapEnabled then
                OptimizeModule:SetFPSCap(value)
            end
        end,
        OnToggle = function(enabled)
            ConfigModule.Settings.FPSCapEnabled = enabled
            if enabled then
                OptimizeModule:SetFPSCap(ConfigModule.Settings.FPSCapValue)
            else
                OptimizeModule:RemoveFPSCap()
            end
        end
    })
end

-- Tạo Tab Bộ Nhớ
function UIModule:CreateMemoryTab()
    local memoryTab = Instance.new("ScrollingFrame")
    memoryTab.Name = "MemoryContent"
    memoryTab.Size = UDim2.new(1, 0, 1, 0)
    memoryTab.Position = UDim2.new(0, 0, 0, 0)
    memoryTab.BackgroundTransparency = 1
    memoryTab.BorderSizePixel = 0
    memoryTab.ScrollBarThickness = 4
    memoryTab.ScrollBarImageColor3 = self.Theme.Accent
    memoryTab.ScrollBarImageTransparency = 0.5
    memoryTab.CanvasSize = UDim2.new(0, 0, 0, 350)
    memoryTab.Visible = false
    memoryTab.Parent = self.Elements.ContentContainer
    
    self.Elements.MemoryContent = memoryTab
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 10)
    layout.Parent = memoryTab
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.Parent = memoryTab
    
    -- Memory Usage Display
    self:CreateMemoryDisplay(memoryTab)
    
    -- Auto GC Toggle
    self:CreateToggleCard(memoryTab, {
        Name = "AutoGC",
        Title = "Tự Động Dọn Rác",
        Description = "Tự động giải phóng bộ nhớ định kỳ",
        Icon = "♻️",
        Color = self.Theme.Accent,
        OnToggle = function(enabled)
            if enabled then
                MemoryModule:EnableAutoGC()
            else
                MemoryModule:DisableAutoGC()
            end
        end
    })
    
    -- Manual GC Button
    self:CreateActionButton(memoryTab, {
        Name = "ManualGC",
        Title = "Dọn Rác Thủ Công",
        Description = "Giải phóng bộ nhớ ngay lập tức",
        Icon = "🗑️",
        Color = self.Theme.AccentWarning,
        OnClick = function()
            local freed = MemoryModule:CollectGarbage()
            -- Update UI với kết quả
        end
    })
end

-- Tạo Memory Display
function UIModule:CreateMemoryDisplay(parent)
    local displayCard = Instance.new("Frame")
    displayCard.Name = "MemoryDisplay"
    displayCard.Size = UDim2.new(1, -10, 0, 150)
    displayCard.BackgroundColor3 = self.Theme.BackgroundSecondary
    displayCard.BackgroundTransparency = 0.5
    displayCard.BorderSizePixel = 0
    displayCard.Parent = parent
    
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = displayCard
    
    -- Ring Progress (circular)
    local ringContainer = Instance.new("Frame")
    ringContainer.Name = "RingContainer"
    ringContainer.Size = UDim2.new(0, 100, 0, 100)
    ringContainer.Position = UDim2.new(0.5, -50, 0, 20)
    ringContainer.BackgroundTransparency = 1
    ringContainer.Parent = displayCard
    
    -- Background ring
    local bgRing = Instance.new("ImageLabel")
    bgRing.Name = "BackgroundRing"
    bgRing.Size = UDim2.new(1, 0, 1, 0)
    bgRing.BackgroundTransparency = 1
    bgRing.Image = "rbxassetid://3570695787"
    bgRing.ImageColor3 = self.Theme.BackgroundTertiary
    bgRing.Parent = ringContainer
    
    -- Progress ring
    local progressRing = Instance.new("ImageLabel")
    progressRing.Name = "ProgressRing"
    progressRing.Size = UDim2.new(1, 0, 1, 0)
    progressRing.BackgroundTransparency = 1
    progressRing.Image = "rbxassetid://3570695787"
    progressRing.ImageColor3 = self.Theme.Accent
    progressRing.Parent = ringContainer
    
    -- Center text
    local centerText = Instance.new("TextLabel")
    centerText.Name = "CenterText"
    centerText.Size = UDim2.new(1, 0, 0, 30)
    centerText.Position = UDim2.new(0, 0, 0.5, -15)
    centerText.BackgroundTransparency = 1
    centerText.Font = Enum.Font.GothamBold
    centerText.Text = "0 KB"
    centerText.TextColor3 = self.Theme.Text
    centerText.TextSize = 16
    centerText.Parent = ringContainer
    
    self.Elements.MemoryText = centerText
    
    -- Label
    local memoryLabel = Instance.new("TextLabel")
    memoryLabel.Name = "MemoryLabel"
    memoryLabel.Size = UDim2.new(1, 0, 0, 20)
    memoryLabel.Position = UDim2.new(0, 0, 1, -25)
    memoryLabel.BackgroundTransparency = 1
    memoryLabel.Font = Enum.Font.Gotham
    memoryLabel.Text = "Bộ nhớ đang sử dụng"
    memoryLabel.TextColor3 = self.Theme.TextSecondary
    memoryLabel.TextSize = 11
    memoryLabel.Parent = displayCard
    
    -- Setup real-time update
    self:SetupMemoryUpdater()
end

-- Setup Memory Updater
function UIModule:SetupMemoryUpdater()
    local connection = RunService.Heartbeat:Connect(function()
        if self.Elements.MemoryText then
            local memoryKB = MemoryModule:GetMemoryUsage()
            self.Elements.MemoryText.Text = UtilsModule:FormatBytes(memoryKB * 1024)
        end
    end)
    
    UtilsModule:RegisterConnection(connection, "UIMemoryUpdate")
end

-- Tạo Tab Profiles
function UIModule:CreateProfilesTab()
    local profilesTab = Instance.new("ScrollingFrame")
    profilesTab.Name = "ProfilesContent"
    profilesTab.Size = UDim2.new(1, 0, 1, 0)
    profilesTab.Position = UDim2.new(0, 0, 0, 0)
    profilesTab.BackgroundTransparency = 1
    profilesTab.BorderSizePixel = 0
    profilesTab.ScrollBarThickness = 4
    profilesTab.ScrollBarImageColor3 = self.Theme.Accent
    profilesTab.ScrollBarImageTransparency = 0.5
    profilesTab.CanvasSize = UDim2.new(0, 0, 0, 320)
    profilesTab.Visible = false
    profilesTab.Parent = self.Elements.ContentContainer
    
    self.Elements.ProfilesContent = profilesTab
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = profilesTab
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.Parent = profilesTab
    
    -- Tạo radio buttons cho profiles
    local profiles = {"Default", "Anime", "Tycoon", "Shooter"}
    
    self.Elements.ProfileRadios = {}
    
    for _, profileName in ipairs(profiles) do
        local profile = ConfigModule.GameProfiles[profileName]
        self:CreateProfileRadio(profilesTab, profileName, profile)
    end
end

-- Tạo Profile Radio Button
function UIModule:CreateProfileRadio(parent, profileName, profile)
    local radioCard = Instance.new("TextButton")
    radioCard.Name = profileName .. "Radio"
    radioCard.Size = UDim2.new(1, -10, 0, 70)
    radioCard.BackgroundColor3 = self.Theme.BackgroundSecondary
    radioCard.BackgroundTransparency = 0.5
    radioCard.BorderSizePixel = 0
    radioCard.Text = ""
    radioCard.AutoButtonColor = false
    radioCard.Parent = parent
    
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = radioCard
    
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = ConfigModule.Settings.CurrentProfile == profileName and self.Theme.Accent or self.Theme.Border
    cardStroke.Thickness = ConfigModule.Settings.CurrentProfile == profileName and 2 or 1
    cardStroke.Transparency = 0.5
    cardStroke.Parent = radioCard
    
    -- Radio indicator
    local radioOuter = Instance.new("Frame")
    radioOuter.Name = "RadioOuter"
    radioOuter.Size = UDim2.new(0, 20, 0, 20)
    radioOuter.Position = UDim2.new(0, 15, 0.5, -10)
    radioOuter.BackgroundColor3 = self.Theme.BackgroundTertiary
    radioOuter.BorderSizePixel = 0
    radioOuter.Parent = radioCard
    
    local radioOuterCorner = Instance.new("UICorner")
    radioOuterCorner.CornerRadius = UDim.new(1, 0)
    radioOuterCorner.Parent = radioOuter
    
    local radioInner = Instance.new("Frame")
    radioInner.Name = "RadioInner"
    radioInner.Size = UDim2.new(0, 10, 0, 10)
    radioInner.Position = UDim2.new(0.5, -5, 0.5, -5)
    radioInner.BackgroundColor3 = self.Theme.Accent
    radioInner.BackgroundTransparency = ConfigModule.Settings.CurrentProfile == profileName and 0 or 1
    radioInner.BorderSizePixel = 0
    radioInner.Parent = radioOuter
    
    local radioInnerCorner = Instance.new("UICorner")
    radioInnerCorner.CornerRadius = UDim.new(1, 0)
    radioInnerCorner.Parent = radioInner
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -60, 0, 20)
    title.Position = UDim2.new(0, 45, 0, 12)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = profile.Name
    title.TextColor3 = self.Theme.Text
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = radioCard
    
    -- Description
    local desc = Instance.new("TextLabel")
    desc.Name = "Description"
    desc.Size = UDim2.new(1, -60, 0, 30)
    desc.Position = UDim2.new(0, 45, 0, 32)
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.Gotham
    desc.Text = profile.Description
    desc.TextColor3 = self.Theme.TextSecondary
    desc.TextSize = 11
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextWrapped = true
    desc.Parent = radioCard
    
    self.Elements.ProfileRadios[profileName] = {
        Card = radioCard,
        Stroke = cardStroke,
        Inner = radioInner
    }
    
    -- Click event
    radioCard.MouseButton1Click:Connect(function()
        self:SelectProfile(profileName)
    end)
    
    -- Hover effects
    radioCard.MouseEnter:Connect(function()
        local tween = TweenService:Create(radioCard, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.3
        })
        tween:Play()
    end)
    
    radioCard.MouseLeave:Connect(function()
        local tween = TweenService:Create(radioCard, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.5
        })
        tween:Play()
    end)
end

-- Select Profile
function UIModule:SelectProfile(profileName)
    -- Update all radios
    for name, elements in pairs(self.Elements.ProfileRadios) do
        local isSelected = name == profileName
        
        local strokeTween = TweenService:Create(elements.Stroke, TweenInfo.new(0.3), {
            Color = isSelected and self.Theme.Accent or self.Theme.Border,
            Thickness = isSelected and 2 or 1
        })
        strokeTween:Play()
        
        local innerTween = TweenService:Create(elements.Inner, TweenInfo.new(0.3), {
            BackgroundTransparency = isSelected and 0 or 1
        })
        innerTween:Play()
    end
    
    -- Apply profile
    ProfileModule:ApplyProfile(profileName)
end

-- Tạo Toggle Card (card với switch)
function UIModule:CreateToggleCard(parent, options)
    local card = Instance.new("Frame")
    card.Name = options.Name .. "Card"
    card.Size = UDim2.new(1, -10, 0, 70)
    card.BackgroundColor3 = self.Theme.BackgroundSecondary
    card.BackgroundTransparency = 0.5
    card.BorderSizePixel = 0
    card.Parent = parent
    
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card
    
    -- Glow effect (hidden by default)
    local glow = Instance.new("UIStroke")
    glow.Name = "Glow"
    glow.Color = options.IsDanger and self.Theme.AccentDanger or options.Color
    glow.Thickness = 0
    glow.Transparency = 0.3
    glow.Parent = card
    
    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 35, 0, 35)
    icon.Position = UDim2.new(0, 15, 0.5, -17)
    icon.BackgroundColor3 = options.Color
    icon.BackgroundTransparency = 0.8
    icon.Font = Enum.Font.GothamBold
    icon.Text = options.Icon
    icon.TextColor3 = options.Color
    icon.TextSize = 18
    icon.Parent = card
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 8)
    iconCorner.Parent = icon
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -120, 0, 20)
    title.Position = UDim2.new(0, 60, 0, 15)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = options.Title
    title.TextColor3 = self.Theme.Text
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card
    
    -- Description
    local desc = Instance.new("TextLabel")
    desc.Name = "Description"
    desc.Size = UDim2.new(1, -120, 0, 20)
    desc.Position = UDim2.new(0, 60, 0, 38)
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.Gotham
    desc.Text = options.Description
    desc.TextColor3 = self.Theme.TextSecondary
    desc.TextSize = 11
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = card
    
    -- Toggle Switch
    local toggleBg = Instance.new("TextButton")
    toggleBg.Name = "ToggleBg"
    toggleBg.Size = UDim2.new(0, 50, 0, 26)
    toggleBg.Position = UDim2.new(1, -65, 0.5, -13)
    toggleBg.BackgroundColor3 = self.Theme.BackgroundTertiary
    toggleBg.BorderSizePixel = 0
    toggleBg.Text = ""
    toggleBg.AutoButtonColor = false
    toggleBg.Parent = card
    
    local toggleBgCorner = Instance.new("UICorner")
    toggleBgCorner.CornerRadius = UDim.new(1, 0)
    toggleBgCorner.Parent = toggleBg
    
    local toggleKnob = Instance.new("Frame")
    toggleKnob.Name = "Knob"
    toggleKnob.Size = UDim2.new(0, 20, 0, 20)
    toggleKnob.Position = UDim2.new(0, 3, 0.5, -10)
    toggleKnob.BackgroundColor3 = self.Theme.Text
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleBg
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = toggleKnob
    
    -- Toggle state
    local isEnabled = false
    
    local function updateToggle(enabled, animate)
        isEnabled = enabled
        
        local duration = animate and 0.3 or 0
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        local bgColor = enabled and (options.IsDanger and self.Theme.AccentDanger or options.Color) or self.Theme.BackgroundTertiary
        local knobPos = enabled and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
        local glowThickness = enabled and 2 or 0
        
        local bgTween = TweenService:Create(toggleBg, tweenInfo, {BackgroundColor3 = bgColor})
        local knobTween = TweenService:Create(toggleKnob, tweenInfo, {Position = knobPos})
        local glowTween = TweenService:Create(glow, tweenInfo, {Thickness = glowThickness})
        
        bgTween:Play()
        knobTween:Play()
        glowTween:Play()
    end
    
    toggleBg.MouseButton1Click:Connect(function()
        updateToggle(not isEnabled, true)
        if options.OnToggle then
            options.OnToggle(isEnabled)
        end
    end)
    
    self.Elements[options.Name .. "Toggle"] = {
        Update = updateToggle,
        GetState = function() return isEnabled end
    }
end

-- Tạo Slider Card
function UIModule:CreateSliderCard(parent, options)
    local card = Instance.new("Frame")
    card.Name = options.Name .. "Card"
    card.Size = UDim2.new(1, -10, 0, 90)
    card.BackgroundColor3 = self.Theme.BackgroundSecondary
    card.BackgroundTransparency = 0.5
    card.BorderSizePixel = 0
    card.Parent = parent
    
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card
    
    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 35, 0, 35)
    icon.Position = UDim2.new(0, 15, 0, 12)
    icon.BackgroundColor3 = self.Theme.Accent
    icon.BackgroundTransparency = 0.8
    icon.Font = Enum.Font.GothamBold
    icon.Text = options.Icon
    icon.TextColor3 = self.Theme.Accent
    icon.TextSize = 18
    icon.Parent = card
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 8)
    iconCorner.Parent = icon
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -150, 0, 20)
    title.Position = UDim2.new(0, 60, 0, 12)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = options.Title
    title.TextColor3 = self.Theme.Text
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card
    
    -- Value display
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Size = UDim2.new(0, 60, 0, 20)
    valueLabel.Position = UDim2.new(1, -75, 0, 12)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = tostring(options.Default) .. " FPS"
    valueLabel.TextColor3 = self.Theme.Accent
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = card
    
    -- Slider track
    local sliderTrack = Instance.new("Frame")
    sliderTrack.Name = "Track"
    sliderTrack.Size = UDim2.new(1, -30, 0, 6)
    sliderTrack.Position = UDim2.new(0, 15, 0, 55)
    sliderTrack.BackgroundColor3 = self.Theme.BackgroundTertiary
    sliderTrack.BorderSizePixel = 0
    sliderTrack.Parent = card
    
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = sliderTrack
    
    -- Slider fill
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "Fill"
    sliderFill.Size = UDim2.new((options.Default - options.Min) / (options.Max - options.Min), 0, 1, 0)
    sliderFill.BackgroundColor3 = self.Theme.Accent
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderTrack
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill
    
    -- Slider knob
    local sliderKnob = Instance.new("Frame")
    sliderKnob.Name = "Knob"
    sliderKnob.Size = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position = UDim2.new((options.Default - options.Min) / (options.Max - options.Min), -8, 0.5, -8)
    sliderKnob.BackgroundColor3 = self.Theme.Text
    sliderKnob.BorderSizePixel = 0
    sliderKnob.Parent = sliderTrack
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = sliderKnob
    
    -- Slider interaction
    local currentValue = options.Default
    local dragging = false
    
    local function updateSlider(input)
        local trackAbsPos = sliderTrack.AbsolutePosition.X
        local trackAbsSize = sliderTrack.AbsoluteSize.X
        local mousePos = input.Position.X
        
        local percent = math.clamp((mousePos - trackAbsPos) / trackAbsSize, 0, 1)
        local value = options.Min + (options.Max - options.Min) * percent
        
        -- Apply step
        if options.Step then
            value = math.floor(value / options.Step + 0.5) * options.Step
        end
        
        value = math.clamp(value, options.Min, options.Max)
        currentValue = value
        
        local fillPercent = (value - options.Min) / (options.Max - options.Min)
        
        sliderFill.Size = UDim2.new(fillPercent, 0, 1, 0)
        sliderKnob.Position = UDim2.new(fillPercent, -8, 0.5, -8)
        valueLabel.Text = tostring(math.floor(value)) .. " FPS"
        
        if options.OnChange then
            options.OnChange(value)
        end
    end
    
    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    
    -- Toggle for enabling slider
    local toggleBg = Instance.new("TextButton")
    toggleBg.Name = "ToggleBg"
    toggleBg.Size = UDim2.new(0, 40, 0, 20)
    toggleBg.Position = UDim2.new(1, -55, 0, 55)
    toggleBg.BackgroundColor3 = self.Theme.BackgroundTertiary
    toggleBg.BorderSizePixel = 0
    toggleBg.Text = ""
    toggleBg.AutoButtonColor = false
    toggleBg.Parent = card
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBg
    
    local toggleKnob = Instance.new("Frame")
    toggleKnob.Size = UDim2.new(0, 14, 0, 14)
    toggleKnob.Position = UDim2.new(0, 3, 0.5, -7)
    toggleKnob.BackgroundColor3 = self.Theme.Text
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleBg
    
    local toggleKnobCorner = Instance.new("UICorner")
    toggleKnobCorner.CornerRadius = UDim.new(1, 0)
    toggleKnobCorner.Parent = toggleKnob
    
    local isEnabled = false
    
    toggleBg.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        
        local bgColor = isEnabled and self.Theme.Accent or self.Theme.BackgroundTertiary
        local knobPos = isEnabled and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        
        TweenService:Create(toggleBg, TweenInfo.new(0.3), {BackgroundColor3 = bgColor}):Play()
        TweenService:Create(toggleKnob, TweenInfo.new(0.3), {Position = knobPos}):Play()
        
        if options.OnToggle then
            options.OnToggle(isEnabled)
        end
    end)
end

-- Tạo Action Button
function UIModule:CreateActionButton(parent, options)
    local button = Instance.new("TextButton")
    button.Name = options.Name .. "Button"
    button.Size = UDim2.new(1, -10, 0, 50)
    button.BackgroundColor3 = options.Color
    button.BackgroundTransparency = 0.7
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = parent
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 10)
    buttonCorner.Parent = button
    
    local buttonStroke = Instance.new("UIStroke")
    buttonStroke.Color = options.Color
    buttonStroke.Thickness = 1
    buttonStroke.Transparency = 0.5
    buttonStroke.Parent = button
    
    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 30, 0, 30)
    icon.Position = UDim2.new(0, 15, 0.5, -15)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.Text = options.Icon
    icon.TextColor3 = options.Color
    icon.TextSize = 18
    icon.Parent = button
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 20)
    title.Position = UDim2.new(0, 50, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = options.Title
    title.TextColor3 = self.Theme.Text
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = button
    
    -- Description
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -60, 0, 15)
    desc.Position = UDim2.new(0, 50, 0, 28)
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.Gotham
    desc.Text = options.Description
    desc.TextColor3 = self.Theme.TextSecondary
    desc.TextSize = 10
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = button
    
    -- Loading indicator
    local loadingIcon = Instance.new("TextLabel")
    loadingIcon.Name = "LoadingIcon"
    loadingIcon.Size = UDim2.new(0, 20, 0, 20)
    loadingIcon.Position = UDim2.new(1, -35, 0.5, -10)
    loadingIcon.BackgroundTransparency = 1
    loadingIcon.Font = Enum.Font.GothamBold
    loadingIcon.Text = "⟳"
    loadingIcon.TextColor3 = options.Color
    loadingIcon.TextSize = 16
    loadingIcon.Visible = false
    loadingIcon.Parent = button
    
    local isProcessing = false
    
    button.MouseButton1Click:Connect(function()
        if isProcessing then return end
        
        isProcessing = true
        loadingIcon.Visible = true
        
        -- Spin animation
        local spinTween = TweenService:Create(loadingIcon, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
            Rotation = 360
        })
        spinTween:Play()
        
        -- Execute action
        task.spawn(function()
            if options.OnClick then
                options.OnClick()
            end
            
            task.wait(0.5)
            
            spinTween:Cancel()
            loadingIcon.Visible = false
            loadingIcon.Rotation = 0
            isProcessing = false
        end)
    end)
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundTransparency = 0.7}):Play()
    end)
end

-- Tạo Status Bar
function UIModule:CreateStatusBar()
    local statusBar = Instance.new("Frame")
    statusBar.Name = "StatusBar"
    statusBar.Size = UDim2.new(1, 0, 0, 35)
    statusBar.Position = UDim2.new(0, 0, 1, -35)
    statusBar.BackgroundColor3 = self.Theme.BackgroundSecondary
    statusBar.BackgroundTransparency = 0.3
    statusBar.BorderSizePixel = 0
    statusBar.Parent = self.Elements.MainFrame
    
    -- Corner (bottom only)
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 12)
    statusCorner.Parent = statusBar
    
    local topCover = Instance.new("Frame")
    topCover.Size = UDim2.new(1, 0, 0, 12)
    topCover.Position = UDim2.new(0, 0, 0, 0)
    topCover.BackgroundColor3 = self.Theme.BackgroundSecondary
    topCover.BackgroundTransparency = 0.3
    topCover.BorderSizePixel = 0
    topCover.Parent = statusBar
    
    -- Status text
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(0.5, 0, 1, 0)
    statusText.Position = UDim2.new(0, 15, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Font = Enum.Font.Gotham
    statusText.Text = "Sẵn sàng"
    statusText.TextColor3 = self.Theme.Accent
    statusText.TextSize = 11
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = statusBar
    
    self.Elements.StatusText = statusText
    
    -- Stats text
    local statsText = Instance.new("TextLabel")
    statsText.Name = "StatsText"
    statsText.Size = UDim2.new(0.5, -15, 1, 0)
    statsText.Position = UDim2.new(0.5, 0, 0, 0)
    statsText.BackgroundTransparency = 1
    statsText.Font = Enum.Font.Gotham
    statsText.Text = "Parts: 0 | Effects: 0"
    statsText.TextColor3 = self.Theme.TextMuted
    statsText.TextSize = 10
    statsText.TextXAlignment = Enum.TextXAlignment.Right
    statsText.Parent = statusBar
    
    self.Elements.StatsText = statsText
    
    -- Setup stats updater
    self:SetupStatsUpdater()
end

-- Setup Stats Updater
function UIModule:SetupStatsUpdater()
    local connection = RunService.Heartbeat:Connect(function()
        if self.Elements.StatsText then
            self.Elements.StatsText.Text = string.format(
                "Parts: %d | Effects: %d",
                ConfigModule.State.PartsOptimized,
                ConfigModule.State.EffectsRemoved
            )
        end
    end)
    
    UtilsModule:RegisterConnection(connection, "UIStatsUpdate")
end

-- Tạo Mini Toolbar (Icon nổi khi thu nhỏ)
function UIModule:CreateMiniToolbar()
    local miniToolbar = Instance.new("Frame")
    miniToolbar.Name = "MiniToolbar"
    miniToolbar.Size = UDim2.new(0, 55, 0, 55)
    miniToolbar.Position = UDim2.new(0, 20, 0.5, -27)
    miniToolbar.BackgroundColor3 = self.Theme.Background
    miniToolbar.BackgroundTransparency = 0.1
    miniToolbar.BorderSizePixel = 0
    miniToolbar.Visible = false
    miniToolbar.Active = true
    miniToolbar.Parent = self.Elements.ScreenGui
    
    self.Elements.MiniToolbar = miniToolbar
    
    -- Bo tròn hoàn toàn thành hình tròn
    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(1, 0)
    miniCorner.Parent = miniToolbar
    
    -- Viền phát sáng neon
    local miniStroke = Instance.new("UIStroke")
    miniStroke.Name = "GlowStroke"
    miniStroke.Color = self.Theme.Accent
    miniStroke.Thickness = 2
    miniStroke.Transparency = 0.2
    miniStroke.Parent = miniToolbar
    
    self.Elements.MiniStroke = miniStroke
    
    -- Glow effect layer bên ngoài
    local glowOuter = Instance.new("UIStroke")
    glowOuter.Name = "GlowOuter"
    glowOuter.Color = self.Theme.Accent
    glowOuter.Thickness = 4
    glowOuter.Transparency = 0.7
    glowOuter.Parent = miniToolbar
    
    -- Expand button
    local expandBtn = Instance.new("TextButton")
    expandBtn.Name = "ExpandBtn"
    expandBtn.Size = UDim2.new(1, 0, 1, 0)
    expandBtn.BackgroundTransparency = 1
    expandBtn.Font = Enum.Font.GothamBold
    expandBtn.Text = "⚡"
    expandBtn.TextColor3 = self.Theme.Accent
    expandBtn.TextSize = 26
    expandBtn.AutoButtonColor = false
    expandBtn.Parent = miniToolbar
    
    -- Tooltip
    local tooltip = Instance.new("TextLabel")
    tooltip.Name = "Tooltip"
    tooltip.Size = UDim2.new(0, 100, 0, 25)
    tooltip.Position = UDim2.new(1, 10, 0.5, -12)
    tooltip.BackgroundColor3 = self.Theme.BackgroundSecondary
    tooltip.BackgroundTransparency = 0.2
    tooltip.BorderSizePixel = 0
    tooltip.Font = Enum.Font.Gotham
    tooltip.Text = "Mở Anti-Lag"
    tooltip.TextColor3 = self.Theme.Text
    tooltip.TextSize = 11
    tooltip.Visible = false
    tooltip.Parent = miniToolbar
    
    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 6)
    tooltipCorner.Parent = tooltip
    
    -- Pulse animation (breathing effect)
    local pulseIn = TweenService:Create(miniStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Transparency = 0.6,
        Thickness = 3
    })
    
    local glowPulse = TweenService:Create(glowOuter, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Transparency = 0.9
    })
    
    -- Click để mở rộng UI
    expandBtn.MouseButton1Click:Connect(function()
        self:ExpandUI()
    end)
    
    -- Hover effects
    expandBtn.MouseEnter:Connect(function()
        pulseIn:Pause()
        glowPulse:Pause()
        
        TweenService:Create(miniStroke, TweenInfo.new(0.2), {
            Transparency = 0,
            Thickness = 3,
            Color = self.Theme.AccentSecondary
        }):Play()
        
        TweenService:Create(glowOuter, TweenInfo.new(0.2), {
            Transparency = 0.5
        }):Play()
        
        TweenService:Create(expandBtn, TweenInfo.new(0.2), {
            TextSize = 30,
            TextColor3 = self.Theme.AccentSecondary
        }):Play()
        
        TweenService:Create(miniToolbar, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 60, 0, 60)
        }):Play()
        
        tooltip.Visible = true
    end)
    
    expandBtn.MouseLeave:Connect(function()
        TweenService:Create(miniStroke, TweenInfo.new(0.2), {
            Transparency = 0.2,
            Thickness = 2,
            Color = self.Theme.Accent
        }):Play()
        
        TweenService:Create(glowOuter, TweenInfo.new(0.2), {
            Transparency = 0.7
        }):Play()
        
        TweenService:Create(expandBtn, TweenInfo.new(0.2), {
            TextSize = 26,
            TextColor3 = self.Theme.Accent
        }):Play()
        
        TweenService:Create(miniToolbar, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 55, 0, 55)
        }):Play()
        
        tooltip.Visible = false
        
        -- Resume pulse animations
        pulseIn:Play()
        glowPulse:Play()
    end)
    
    -- Store pulse tween references
    self.Elements.MiniPulse = pulseIn
    self.Elements.MiniGlowPulse = glowPulse
    
    -- Setup mini toolbar dragging
    self:SetupMiniDragging(miniToolbar)
end

-- Setup Mini Toolbar Dragging
function UIModule:SetupMiniDragging(toolbar)
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        toolbar.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    
    toolbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = toolbar.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    toolbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- Switch Tab
function UIModule:SwitchTab(tabName)
    ConfigModule.State.CurrentTab = tabName
    
    -- Update tab buttons
    for name, tab in pairs(self.Elements.Tabs) do
        local isActive = name == tabName
        
        local bgTween = TweenService:Create(tab, TweenInfo.new(0.3), {
            BackgroundColor3 = isActive and self.Theme.Accent or self.Theme.BackgroundTertiary,
            BackgroundTransparency = isActive and 0.3 or 0.7
        })
        bgTween:Play()
        
        local textTween = TweenService:Create(tab, TweenInfo.new(0.3), {
            TextColor3 = isActive and self.Theme.Text or self.Theme.TextSecondary
        })
        textTween:Play()
    end
    
    -- Show/hide content
    local contents = {
        LagReduction = self.Elements.LagReductionContent,
        Memory = self.Elements.MemoryContent,
        Profiles = self.Elements.ProfilesContent
    }
    
    for name, content in pairs(contents) do
        if content then
            content.Visible = (name == tabName)
        end
    end
end

-- Minimize UI (Thu nhỏ thành icon nổi)
function UIModule:MinimizeUI()
    ConfigModule.State.IsMinimized = true
    
    -- Lưu vị trí hiện tại của MainFrame để restore sau
    self.LastMainFramePosition = self.Elements.MainFrame.Position
    
    -- Animate main frame thu nhỏ và biến mất
    local hideTween = TweenService:Create(self.Elements.MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 55, 0, 55),
        BackgroundTransparency = 1
    })
    
    hideTween.Completed:Connect(function()
        self.Elements.MainFrame.Visible = false
        
        -- Hiển thị Mini Toolbar (icon nổi)
        self.Elements.MiniToolbar.Visible = true
        self.Elements.MiniToolbar.Size = UDim2.new(0, 0, 0, 0)
        
        -- Animate mini toolbar xuất hiện với hiệu ứng pop
        TweenService:Create(self.Elements.MiniToolbar, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 55, 0, 55)
        }):Play()
        
        -- Bắt đầu pulse animation
        if self.Elements.MiniPulse then
            self.Elements.MiniPulse:Play()
        end
        if self.Elements.MiniGlowPulse then
            self.Elements.MiniGlowPulse:Play()
        end
    end)
    
    hideTween:Play()
    
    -- Update status
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] UI đã thu nhỏ thành icon")
    end
end

-- Expand UI (Mở rộng từ icon thành menu đầy đủ)
function UIModule:ExpandUI()
    ConfigModule.State.IsMinimized = false
    
    -- Dừng pulse animations
    if self.Elements.MiniPulse then
        self.Elements.MiniPulse:Pause()
    end
    if self.Elements.MiniGlowPulse then
        self.Elements.MiniGlowPulse:Pause()
    end
    
    -- Animate mini toolbar thu nhỏ và biến mất
    local hideTween = TweenService:Create(self.Elements.MiniToolbar, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    
    hideTween.Completed:Connect(function()
        self.Elements.MiniToolbar.Visible = false
        
        -- Hiển thị MainFrame
        self.Elements.MainFrame.Visible = true
        self.Elements.MainFrame.BackgroundTransparency = ConfigModule.Settings.UITransparency
        
        -- Khôi phục vị trí cũ hoặc vị trí mặc định
        local targetPos = self.LastMainFramePosition or UDim2.new(0.5, -190, 0.5, -260)
        
        -- Animate main frame xuất hiện với hiệu ứng pop
        self.Elements.MainFrame.Size = UDim2.new(0, 55, 0, 55)
        self.Elements.MainFrame.Position = UDim2.new(
            targetPos.X.Scale,
            targetPos.X.Offset + 162, -- Center offset
            targetPos.Y.Scale,
            targetPos.Y.Offset + 232  -- Center offset
        )
        
        TweenService:Create(self.Elements.MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 380, 0, 520),
            Position = targetPos
        }):Play()
    end)
    
    hideTween:Play()
    
    -- Update status
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] UI đã mở rộng")
    end
end

-- Destroy UI
function UIModule:DestroyUI()
    -- Cleanup all connections
    UtilsModule:CleanupConnections()
    
    -- Destroy screen gui
    if self.Elements.ScreenGui then
        self.Elements.ScreenGui:Destroy()
    end
    
    self.Elements = {}
    
    if ConfigModule.Settings.DebugMode then
        print("[AntiLagCore] UI đã được đóng")
    end
end

-- Update Status
function UIModule:UpdateStatus(text, isError)
    if self.Elements.StatusText then
        self.Elements.StatusText.Text = text
        self.Elements.StatusText.TextColor3 = isError and self.Theme.AccentDanger or self.Theme.Accent
    end
end

--============================================================================--
--                          MAIN INITIALIZATION                                --
--============================================================================--

local function Initialize()
    -- Load config
    ConfigModule:LoadConfig()
    
    -- Cache lighting values
    OptimizeModule:CacheLightingValues()
    
    -- Create UI
    UIModule:CreateMainUI()
    
    -- Apply saved settings
    if ConfigModule.Settings.LagReductionMode > 0 then
        OptimizeModule:ApplyOptimizationMode(ConfigModule.Settings.LagReductionMode)
    end
    
    if ConfigModule.Settings.AutoGarbageCollection then
        MemoryModule:EnableAutoGC()
    end
    
    if ConfigModule.Settings.CurrentProfile ~= "Default" then
        ProfileModule:ApplyProfile(ConfigModule.Settings.CurrentProfile)
    end
    
    print([[
    ╔══════════════════════════════════════════════════════════════╗
    ║              ANTI-LAG CORE v3.0 - ĐÃ KHỞI ĐỘNG               ║
    ║                                                              ║
    ║  Script tối ưu hóa hiệu năng Roblox                          ║
    ║  Kiến trúc: Event-Driven (Không gây lag)                     ║
    ║  Chức năng: Giảm lag, Dọn bộ nhớ, Game Profiles              ║
    ║                                                              ║
    ║  Sử dụng: Kéo thả giao diện để di chuyển                     ║
    ║           Nhấn [-] để thu nhỏ, [×] để đóng                   ║
    ╚══════════════════════════════════════════════════════════════╝
    ]])
    
    UIModule:UpdateStatus("Đã khởi động thành công!")
end

-- Run initialization
Initialize()

-- Export modules for external access (optional)
return {
    Config = ConfigModule,
    Optimize = OptimizeModule,
    Memory = MemoryModule,
    Profile = ProfileModule,
    UI = UIModule,
    Utils = UtilsModule
}
