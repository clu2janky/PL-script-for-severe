
local Bytecode, Load, Library

pcall(function()
    print("Fetching Pseudosynonym library...")
    Bytecode = game:HttpGet("https://raw.githubusercontent.com/DCHARLESAKAMRGREEN/Severe-Luas/main/Libraries/Pseudosynonym.lua")
    local byteLen = string.len(Bytecode)
    print("Library bytecode fetched (" .. tostring(byteLen) .. " bytes)")
end)

if not Bytecode then
    print("Failed to fetch library bytecode!")
    return
end

local success, err = pcall(function()
    print("Loading bytecode...")
    
    local loadSuccess
    local loadFunc
    
    -- Try luau.load first, fallback to loadstring if it fails
    if typeof(luau) == "table" and typeof(luau.load) == "function" then
        print("Attempting luau.load...")
        loadSuccess, loadFunc = pcall(function()
            return luau.load(Bytecode)
        end)
    else
        print("luau.load not available, using loadstring fallback...")
        loadSuccess = true
        loadFunc = loadstring(Bytecode)
    end
    
    if not loadSuccess or not loadFunc then
        print("ERROR: Failed to compile bytecode!")
        print("  " .. tostring(loadFunc))
        error("Bytecode compilation failed")
    end
    
    print("Bytecode loaded, load function type: " .. type(loadFunc))
    Load = loadFunc
    
    print("Executing library initialization...")
    local initSuccess
    initSuccess, Library = pcall(function()
        return Load()
    end)
    
    if not initSuccess then
        print("ERROR: Failed to initialize library!")
        print("  " .. tostring(Library))
        error("Library initialization failed")
    end
    
    print("Library initialized, type: " .. type(Library))
end)

if not success then
    print("CRITICAL ERROR loading library:")
    print("  " .. tostring(err))
    print("\nTroubleshooting:")
    print("  1. Check your internet connection")
    print("  2. Try again in a few seconds")
    print("  3. The Pseudosynonym library may be temporarily unavailable")
    return
end

if not Library then
    print("Library is nil after initialization!")
    return
end

print("Library loaded successfully:", type(Library))

-- Create Main Window
local Window

local success, err = pcall(function()
    if not Library or not Library.CreateWindow then
        print("Library.CreateWindow not found!")
        print("  Library type: " .. type(Library))
        if type(Library) == "table" then
            print("  Library contents: " .. table.concat(getkeystable and getkeystable(Library) or {"<unable to list>"}, ", "))
        end
        return
    end
    
    print("Creating main window...")
    Window = Library:CreateWindow({
        Title = "Prison Life - Severe Edition",
        Tag = "@lurk116 - v2.6.1",
        Keybind = "Insert"
    })
    print("Window created!")
end)

if not success then
    print("Error creating window:")
    print("  " .. tostring(err))
    return
end

if not Window then
    print("Window creation failed! (returned nil)")
    return
end

print("Window initialized successfully")

-- ═══════════════════════════════════════════════════════════════
-- SECTION 2: SERVICES & CONFIGURATION
-- ═══════════════════════════════════════════════════════════════

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- UserInputService may not be available in Severe API
local UserInputService
pcall(function()
    UserInputService = game:GetService("UserInputService")
end)

-- Wait for LocalPlayer to be available
local LocalPlayer
repeat
    LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then
        task.wait(0.1)
    end
until LocalPlayer

local Camera = workspace.CurrentCamera

-- Weapon Configuration Table - DEFINED EARLY FOR USE IN CALLBACKS
local OriginalWeaponStats = {}
local WeaponModSettings = {}
local AvailableWeapons = {}

-- Notification function
local function SendNotification(title, message)
    print("[" .. title .. "] " .. message)
end

-- Settings variables (direct assignment)
local VerboseLogging = true
local AutoApplyMods = false
local GunModsLoopEnabled = true

-- UI Element references (defined early)
local NoRecoilToggle, NoSpreadToggle, RapidFireToggle, RapidFireSpeed, DamageMultiplier, SpreadReduction, InfiniteAmmoToggle



-- Store Prison Life relevant data (using Severe API vector.create)
local TeleportLocations = {
    ["Cafeteria"] = vector.create(921, 99, 2283),
    ["Yard"] = vector.create(716, 97, 2469),
    ["Cells"] = vector.create(900, 114, 2497),
    ["Guard Tower"] = vector.create(822, 125, 2585),
    ["Armory"] = vector.create(819, 99, 2232),
    ["Roof"] = vector.create(957, 131, 2231),
    ["Police Station"] = vector.create(692, 99, 2244),
    ["City/car"] = vector.create(-192, 54, 1881),
    ["Criminal Base"] = vector.create(-975, 108, 2044),
    ["Jail Entrance"] = vector.create(503, 102, 2246)
}

-- Teleport cooldown to prevent anti-cheat detection
local LastTeleportTime = 0
local TeleportCooldown = 1.0  -- 1 second between teleports
local TeleportCooldownEnabled = true  -- Toggle to enable/disable cooldown

-- ═══════════════════════════════════════════════════════════════
-- SECTION 4: TELEPORT TAB
-- ═══════════════════════════════════════════════════════════════

local TeleportTab = Window:AddTab({ Name = "Teleport" })

local TeleportContainer = TeleportTab:AddContainer({ Name = "Locations", Side = "Left", AutoSize = true })
TeleportContainer:AddSeparator()

for locationName, locationPos in pairs(TeleportLocations) do
    TeleportContainer:AddButton({
        Name = "> " .. locationName .. " <",
        Callback = function()
            -- Check cooldown to prevent anti-cheat detection
            local currentTime = tick()
            if TeleportCooldownEnabled and (currentTime - LastTeleportTime < TeleportCooldown) then
                local waitTime = math.ceil((TeleportCooldown - (currentTime - LastTeleportTime)) * 10) / 10
                print("⏳ Teleport cooldown: Wait " .. waitTime .. "s before next TP")
                SendNotification("Cooldown", "Wait " .. waitTime .. "s")
                return
            end
            LastTeleportTime = currentTime
            
            if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                -- Use Severe API: directly set .Position with vector type
                local targetPos = locationPos
                if typeof(targetPos) == "Vector3" then
                    -- Convert Vector3 to Severe vector
                    targetPos = vector.create(targetPos.X, targetPos.Y, targetPos.Z)
                end
                LocalPlayer.Character.HumanoidRootPart.Position = targetPos
                print("Teleported to " .. locationName)
            end
        end
    })
end

-- Custom Teleport
local CustomTPContainer = TeleportTab:AddContainer({ Name = "Custom TP", Side = "Right", AutoSize = true })
local StoredPositions = {}  -- Table to store copied positions
local PositionNameInput = nil

CustomTPContainer:AddSeparator()

local SavedPositionsContainer = TeleportTab:AddContainer({ Name = "Saved Positions", Side = "Right", AutoSize = true })

-- Add input field for position name
PositionNameInput = CustomTPContainer:AddInput({
    Name = "Position Name",
    Text = "My Location"
})

CustomTPContainer:AddButton({
    Name = "Copy Current Position",
    Callback = function()
        if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            if hrp then
                local pos = hrp.Position
                
                -- Handle both Vector3 and vector types
                if typeof(pos) == "Vector3" or typeof(pos) == "vector" then
                    local flooredPos
                    if typeof(pos) == "vector" then
                        flooredPos = vector.create(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z))
                    else
                        flooredPos = vector.create(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
                    end
                    local posStr = tostring(flooredPos)
                    
                    local customName = PositionNameInput and PositionNameInput.Value or ""
                    if customName == "" or customName == "My Location" then
                        customName = "Pos " .. #StoredPositions + 1
                    end
                    
                    table.insert(StoredPositions, {
                        name = customName,
                        x = math.floor(flooredPos.x),
                        y = math.floor(flooredPos.y),
                        z = math.floor(flooredPos.z)
                    })
                    
                    print("Saved position: " .. customName .. " at " .. posStr)
                    SendNotification("Position", "Saved: " .. customName)
                    
                    -- Capture the saved position in the closure
                    local savedPos = StoredPositions[#StoredPositions]
                    
                    -- Add button to teleport to this position
                    SavedPositionsContainer:AddButton({
                        Name = customName .. " " .. posStr,
                        Callback = function()
                            local currentTime = tick()
                            if TeleportCooldownEnabled and (currentTime - LastTeleportTime < TeleportCooldown) then
                                local waitTime = math.ceil((TeleportCooldown - (currentTime - LastTeleportTime)) * 10) / 10
                                print("⏳ Teleport cooldown: Wait " .. waitTime .. "s")
                                SendNotification("Cooldown", "Wait " .. waitTime .. "s")
                                return
                            end
                            LastTeleportTime = currentTime
                            
                            if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                local reconstructedPos = vector.create(savedPos.x, savedPos.y, savedPos.z)
                                LocalPlayer.Character.HumanoidRootPart.Position = reconstructedPos
                                print("Teleported to " .. customName)
                            end
                        end
                    })
                else
                    print("Position is not a Vector3 or vector - type is: " .. typeof(pos))
                end
            end
        end
    end
})

-- ═══════════════════════════════════════════════════════════════
-- SECTION 5: GUN MODS TAB & FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

local GunModsTab = Window:AddTab({ Name = "Gun Mods" })

-- Per-weapon mod settings
local WeaponModToggles = {}  -- WeaponModToggles[weaponName] = {NoRecoil, NoSpread, RapidFire, InfiniteAmmo}
local WeaponModSliders = {}  -- WeaponModSliders[weaponName] = {RapidFireSpeed, DamageMultiplier, SpreadReduction}
local WeaponContainersCreated = {}  -- Track which weapon containers have been created to avoid duplicates
local WeaponContainers = {}  -- Store actual container references to reuse them
local OriginalWeaponStats = {}  -- Initialize BEFORE it's used elsewhere

-- Respawn detection removed - gun mods system simplified

-- Keep global references for compatibility
NoRecoilToggle = { Value = false }
NoSpreadToggle = { Value = false }
RapidFireToggle = { Value = false }
RapidFireSpeed = { Value = 2 }
DamageMultiplier = { Value = 1 }
SpreadReduction = { Value = 1 }
InfiniteAmmoToggle = { Value = false }

-- Updated ApplyGunModsNow to use per-weapon settings
local function ApplyGunModsNowPerWeapon(tool, weaponName)
    if not tool or not weaponName then return end
    
    local toolName = tool.Name
    
    -- Get weapon-specific settings
    if not WeaponModToggles[weaponName] then
        WeaponModToggles[weaponName] = {
            NoRecoil = { Value = false },
            NoSpread = { Value = false },
            RapidFire = { Value = false },
            InfiniteAmmo = { Value = false }
        }
    end
    if not WeaponModSliders[weaponName] then
        WeaponModSliders[weaponName] = {
            RapidFireSpeed = { Value = 2 },
            DamageMultiplier = { Value = 1 },
            SpreadReduction = { Value = 1 }
        }
    end
    
    local noRecoil = WeaponModToggles[weaponName].NoRecoil
    local noSpread = WeaponModToggles[weaponName].NoSpread
    local rapidFire = WeaponModToggles[weaponName].RapidFire
    local infiniteAmmo = WeaponModToggles[weaponName].InfiniteAmmo
    local rapidFireSpeed = WeaponModSliders[weaponName].RapidFireSpeed
    local damageMultiplier = WeaponModSliders[weaponName].DamageMultiplier
    local spreadReduction = WeaponModSliders[weaponName].SpreadReduction
    
    -- Store original stats on first modification
    if not OriginalWeaponStats[toolName] then
        OriginalWeaponStats[toolName] = {}
        
        -- Get attributes (Prison Life stores weapon properties as attributes!)
        local attrs = tool:GetAttributes()
        if attrs and type(attrs) == "table" then
            for key, val in pairs(attrs) do
                if type(val) == "string" then
                    OriginalWeaponStats[toolName][key] = tonumber(val) or val
                else
                    OriginalWeaponStats[toolName][key] = val
                end
            end
        end
        
        print("Weapon stats stored: " .. toolName)
        print("  - AccurateRange: " .. tostring(OriginalWeaponStats[toolName].AccurateRange))
        print("  - FireRate: " .. tostring(OriginalWeaponStats[toolName].FireRate))
        print("  - CurrentAmmo: " .. tostring(OriginalWeaponStats[toolName].CurrentAmmo))
    end
    
    -- APPLY MODS - SetAttribute persistence
    pcall(function()
        -- NO SPREAD
        if noSpread.Value then
            local spreadReductionAmount = spreadReduction.Value
            local originalSpreadRadius = OriginalWeaponStats[toolName].SpreadRadius or 0.022
            local newSpreadRadius = originalSpreadRadius * (1 - spreadReductionAmount)
            tool:SetAttribute("SpreadRadius", math.max(newSpreadRadius, 0.001))
            print("NO SPREAD applied")
        end
        
        -- RAPID FIRE
        if rapidFire.Value then
            local fireRateMultiplier = rapidFireSpeed.Value
            local originalFireRate = OriginalWeaponStats[toolName].FireRate or 0.1
            local newFireRate = originalFireRate / fireRateMultiplier
            tool:SetAttribute("FireRate", newFireRate)
            tool:SetAttribute("AutoFire", true)
            print("RAPID FIRE applied")
        end
        
        -- NO RECOIL
        if noRecoil.Value then
            local originalRange = OriginalWeaponStats[toolName].AccurateRange or 90
            local newAccurateRange = originalRange * 0.5
            tool:SetAttribute("AccurateRange", math.max(newAccurateRange, 0.1))
            print("NO RECOIL applied")
        end
        
        -- INFINITE AMMO
        if infiniteAmmo.Value then
            tool:SetAttribute("CurrentAmmo", 999999)
            print("INFINITE AMMO applied")
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- DYNAMIC WEAPON LOADING - Creates UI containers as weapons are equipped
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- CONTROLS SECTION - Info & Debug
-- ═══════════════════════════════════════════════════════════════
local ControlContainer
pcall(function()
    ControlContainer = GunModsTab:AddContainer({ Name = "Controls", Side = "Left", AutoSize = true })
end)

if ControlContainer then
    pcall(function()
        ControlContainer:AddLabel({ Name = "Info & Debug" })
    end)
    
    pcall(function()
        ControlContainer:AddButton({
            Name = "Debug Info",
            Callback = function()
                print("\n" .. string.rep("=", 50))
                print("=== WEAPON INFO ===")
                print(string.rep("=", 50))
                
                local tool = nil
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                if backpack then
                    tool = backpack:FindFirstChildOfClass("Tool")
                end
                if not tool and LocalPlayer.Character then
                    tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                end
                
                if tool then
                    print("\nCurrent: " .. tool.Name)
                    local attrs = tool:GetAttributes()
                    if attrs and type(attrs) == "table" and next(attrs) then
                        print("Attributes:")
                        for key, val in pairs(attrs) do
                            print("  " .. key .. " = " .. tostring(val))
                        end
                    end
                else
                    print("No weapon equipped")
                end
                print("\n" .. string.rep("=", 50))
            end
        })
    end)

    pcall(function()
        ControlContainer:AddButton({
            Name = "Refresh Gun Mods",
            Callback = function()
                if LocalPlayer.Character then
                    pcall(function()
                        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool then
                            local weaponName = tool.Name
                            
                            if WeaponModToggles[weaponName] then
                                local hasActiveMods = 
                                    WeaponModToggles[weaponName].NoRecoil.Value or
                                    WeaponModToggles[weaponName].NoSpread.Value or
                                    WeaponModToggles[weaponName].RapidFire.Value or
                                    WeaponModToggles[weaponName].InfiniteAmmo.Value
                                
                                if hasActiveMods then
                                    ApplyGunModsNowPerWeapon(tool, weaponName)
                                    print("Gun mods refreshed on " .. weaponName)
                                    SendNotification("Refresh", "Mods applied to " .. weaponName)
                                else
                                    print("No active mods on " .. weaponName)
                                    SendNotification("Refresh", "No mods enabled on " .. weaponName)
                                end
                            else
                                print("No mods configured for " .. weaponName)
                                SendNotification("Refresh", "No mods for " .. weaponName)
                            end
                        else
                            print("No weapon equipped")
                            SendNotification("Refresh", "No weapon equipped")
                        end
                    end)
                end
            end
        })
    end)

    pcall(function()
        ControlContainer:AddSeparator()
    end)
    
    pcall(function()
        ControlContainer:AddLabel({ Name = "Auto-loads when u equip weapons" })
    end)
end



-- Dynamic weapon loading loop
task.spawn(function()
    local lastWeapons = {}
    
    while true do
        task.wait(1)
        
        if GunModsTab and type(GunModsTab) == "table" then
            local currentWeapons = {}
        
        -- Get weapons from character
        if LocalPlayer.Character then
            for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
                if item.ClassName == "Tool" then
                    table.insert(currentWeapons, item.Name)
                end
            end
        end
        
        -- Get weapons from backpack
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item.ClassName == "Tool" and not table.find(currentWeapons, item.Name) then
                    table.insert(currentWeapons, item.Name)
                end
            end
        end
        
        -- Remove containers for weapons that no longer exist
        for weaponName in pairs(WeaponContainersCreated) do
            if not table.find(currentWeapons, weaponName) then
                -- KEEP WeaponContainersCreated marked - reuse the same container
                -- Just clear the toggles so it appears empty
                WeaponModToggles[weaponName] = nil
                WeaponModSliders[weaponName] = nil
                OriginalWeaponStats[weaponName] = nil
            end
        end
        
        -- Check for new weapons only
        for _, weaponName in ipairs(currentWeapons) do
            if not table.find(lastWeapons, weaponName) and not WeaponContainersCreated[weaponName] then
                -- New weapon detected, create container only for this one
                pcall(function()
                    -- Skip non-gun tools
                    if weaponName == "Handcuffs" or weaponName == "Taser" or weaponName == "Riot Shield" or weaponName == "Card" or weaponName == "Hammer" then
                        return
                    end
                    
                    -- Verify GunModsTab is valid before using it
                    if not GunModsTab or type(GunModsTab) ~= "table" or not GunModsTab.AddContainer then
                        return
                    end
                    
                    -- Initialize storage for this weapon
                    if not WeaponModToggles[weaponName] then
                        WeaponModToggles[weaponName] = {
                            NoRecoil = { Value = false },
                            NoSpread = { Value = false },
                            RapidFire = { Value = false },
                            InfiniteAmmo = { Value = false }
                        }
                    end
                    if not WeaponModSliders[weaponName] then
                        WeaponModSliders[weaponName] = {
                            RapidFireSpeed = { Value = 2 },
                            DamageMultiplier = { Value = 1 },
                            SpreadReduction = { Value = 1 }
                        }
                    end
                    
                    -- Alternate sides for better balance
                    local weaponCount = 0
                    for _ in pairs(WeaponContainersCreated) do
                        weaponCount = weaponCount + 1
                    end
                    local side = (weaponCount % 2 == 0) and "Left" or "Right"
                    
                    -- Create container for this weapon
                    local weaponContainer = GunModsTab:AddContainer({ Name = "[" .. weaponName .. "]", Side = side, AutoSize = true })
                    if not weaponContainer or type(weaponContainer) ~= "table" then
                        print("Failed to create container for " .. weaponName .. " (invalid return)")
                        return
                    end
                    WeaponContainersCreated[weaponName] = true
                    WeaponContainers[weaponName] = weaponContainer  -- Store reference
                    
                    -- Toggles
                    if weaponContainer.AddLabel then
                        weaponContainer:AddLabel({ Name = "Mods" })
                    end
                    WeaponModToggles[weaponName].NoRecoil = weaponContainer:AddToggle({ Name = "No Recoil", Value = false })
                    WeaponModToggles[weaponName].NoSpread = weaponContainer:AddToggle({ Name = "No Spread", Value = false })
                    WeaponModToggles[weaponName].RapidFire = weaponContainer:AddToggle({ Name = "Rapid Fire", Value = false })
                    WeaponModToggles[weaponName].InfiniteAmmo = weaponContainer:AddToggle({ Name = "Infinite Ammo", Value = false })
                    
                    if weaponContainer.AddSeparator then
                        weaponContainer:AddSeparator()
                    end
                    
                    -- Sliders
                    if weaponContainer.AddLabel then
                        weaponContainer:AddLabel({ Name = "Settings" })
                    end
                    WeaponModSliders[weaponName].RapidFireSpeed = weaponContainer:AddSlider({
                        Name = "Fire Rate Multiplier",
                        Min = 1,
                        Max = 5,
                        Default = 2,
                        Rounding = 0.1
                    })
                    
                    WeaponModSliders[weaponName].SpreadReduction = weaponContainer:AddSlider({
                        Name = "Spread Reduction",
                        Min = 0,
                        Max = 1,
                        Default = 1,
                        Rounding = 0.05
                    })
                    
                    if weaponContainer.AddSeparator then
                        weaponContainer:AddSeparator()
                    end
                    
                    -- Apply button for this weapon
                    if weaponContainer.AddButton then
                        weaponContainer:AddButton({
                            Name = "Apply Mods",
                            Callback = function()
                            print("\nAPPLYING MODS TO " .. weaponName .. "\n")
                            
                            local tool = nil
                            local backpack = LocalPlayer:FindFirstChild("Backpack")
                            if backpack then
                                tool = backpack:FindFirstChild(weaponName)
                            end
                            
                            if not tool and LocalPlayer.Character then
                                tool = LocalPlayer.Character:FindFirstChild(weaponName)
                            end
                            
                            if tool then
                                ApplyGunModsNowPerWeapon(tool, weaponName)
                                print("Mods applied!")
                            else
                                print("Could not find weapon: " .. weaponName)
                            end
                            end
                        })
                    end
                    
                    print("Added weapon: " .. weaponName)
                end)
            end
        end
        
        lastWeapons = currentWeapons
        else
            task.wait(0.5)
        end
    end
end)

-- AUTO-APPLY MODS WHEN WEAPON EQUIPPED (if enabled in settings)
task.spawn(function()
    local lastToolName = nil
    
    while true do
        task.wait(0.3)
        
        if AutoApplyMods and LocalPlayer.Character then
            pcall(function()
                local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    local weaponName = tool.Name
                    
                    -- Only apply when a NEW weapon is equipped (prevent spam)
                    if weaponName ~= lastToolName then
                        lastToolName = weaponName
                        
                        -- Wait for weapon toggles to be created by dynamic loader
                        task.wait(0.2)
                        
                        if WeaponModToggles[weaponName] then
                            local hasActiveMods = 
                                WeaponModToggles[weaponName].NoRecoil.Value or
                                WeaponModToggles[weaponName].NoSpread.Value or
                                WeaponModToggles[weaponName].RapidFire.Value or
                                WeaponModToggles[weaponName].InfiniteAmmo.Value
                            
                            if hasActiveMods then
                                print("AUTO-APPLYING MODS TO " .. weaponName)
                                ApplyGunModsNowPerWeapon(tool, weaponName)
                                SendNotification("Auto-Apply", "Mods applied to " .. weaponName)
                            else
                                print("" .. weaponName .. " equipped but no mods enabled")
                            end
                        else
                            print("Toggles not initialized for " .. weaponName .. " yet")
                        end
                    end
                else
                    lastToolName = nil
                end
            end)
        end
    end
end)

-- RESPAWN DETECTION - Reapply mods when character respawns
task.spawn(function()
    local lastCharacter = nil
    
    while true do
        task.wait(0.5)
        
        if LocalPlayer then
            local currentCharacter = LocalPlayer.Character
            
            -- Detect character respawn (character changed)
            if currentCharacter and currentCharacter ~= lastCharacter then
                lastCharacter = currentCharacter
                print("[RESPAWN] Character respawned, preparing to reapply mods...")
                
                -- Wait a moment for tools to load
                task.wait(1)
                
                -- Reapply mods to all equipped tools
                pcall(function()
                    for _, item in ipairs(currentCharacter:GetChildren()) do
                        if item.ClassName == "Tool" then
                            local weaponName = item.Name
                            if WeaponModToggles[weaponName] then
                                local hasActiveMods = 
                                    WeaponModToggles[weaponName].NoRecoil.Value or
                                    WeaponModToggles[weaponName].NoSpread.Value or
                                    WeaponModToggles[weaponName].RapidFire.Value or
                                    WeaponModToggles[weaponName].InfiniteAmmo.Value
                                
                                if hasActiveMods then
                                    print("[RESPAWN] Reapplying mods to " .. weaponName)
                                    ApplyGunModsNowPerWeapon(item, weaponName)
                                end
                            end
                        end
                    end
                end)
            elseif not currentCharacter then
                lastCharacter = nil
            end
        end
    end
end)

-- REFRESH GUN MODS EVERY 5 SECONDS (if enabled in settings)
task.spawn(function()
    while true do
        task.wait(5)
        
        if GunModsLoopEnabled and LocalPlayer.Character then
            pcall(function()
                local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    local weaponName = tool.Name
                    
                    -- Check if this weapon has any active mods
                    if WeaponModToggles[weaponName] then
                        local hasActiveMods = 
                            WeaponModToggles[weaponName].NoRecoil.Value or
                            WeaponModToggles[weaponName].NoSpread.Value or
                            WeaponModToggles[weaponName].RapidFire.Value or
                            WeaponModToggles[weaponName].InfiniteAmmo.Value
                        
                        if hasActiveMods then
                            ApplyGunModsNowPerWeapon(tool, weaponName)
                        end
                    end
                end
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ANTI-KICK SYSTEM
-- ═══════════════════════════════════════════════════════════════

local AntiKickEnabled = false
local AntiAFKEnabled = false
local KickBlockedCount = 0

-- Anti-AFK: Simulate activity to prevent AFK kicks
task.spawn(function()
    while true do
        task.wait(30)
        
        if AntiAFKEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                -- Simulate movement to show activity
                local hrp = LocalPlayer.Character.HumanoidRootPart
                local originalPos = hrp.Position
                
                -- Small movement
                hrp.Position = originalPos + vector.create(0.5, 0, 0)
                task.wait(0.1)
                hrp.Position = originalPos
                
                print("[ANTI-AFK] ✓ Activity simulated")
            end)
        end
    end
end)

-- Monitor for disconnect attempts
local lastDisconnectWarning = 0
pcall(function()
    if Players and Players.PlayerRemoving then
        Players.PlayerRemoving:Connect(function(player)
            if player == LocalPlayer then
                if AntiKickEnabled then
                    KickBlockedCount = KickBlockedCount + 1
                    print("[ANTI-KICK] ✗ Kick/Disconnect detected!")
                else
                    print("[DISCONNECT] Player removed from game")
                end
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- SECTION 5.5: PLAYER TAB - GUNS & ITEMS GIVER
-- ═══════════════════════════════════════════════════════════════

local PlayerTab = Window:AddTab({ Name = "Misc" })

-- Available guns in Prison Life (from game.Workspace.Prison_ITEMS.giver)
local AvailableGuns = {
    "M4A1",
    "Remington 870",
    "AK-47",
    "MP5"
}

local GunsContainer
pcall(function()
    GunsContainer = PlayerTab:AddContainer({ Name = "Get Weapons", Side = "Left", AutoSize = true })
end)

if GunsContainer then
    pcall(function()
        GunsContainer:AddSeparator()
    end)

    for _, gunName in ipairs(AvailableGuns) do
        pcall(function()
            GunsContainer:AddButton({
                Name = gunName,
                Callback = function()
                    task.spawn(function()
                        if not (LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then
                            print("ERROR: No character/HRP")
                            return
                        end
                        
                        pcall(function()
                            print("\n" .. string.rep("=", 80))
                            print("GETTING " .. gunName:upper())
                            print(string.rep("=", 80))
                            
                            local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                            local originalPos = rootPart.Position
                            local found = false
                            
                            print("[STEP 1] Original Position: " .. tostring(originalPos))
                            
                            -- Search workspace children
                            for _, part in ipairs(workspace:GetChildren()) do
                                if part.Name == "TouchGiver" then
                                    local toolName = part:GetAttribute("ToolName")
                                    if toolName == gunName then
                                        local touchPart = part:FindFirstChild("TouchGiver")
                                        if touchPart then
                                            print("[STEP 2] ✓ Found gun TouchGiver at: " .. tostring(touchPart.Position))
                                            
                                            local targetPos = touchPart.Position
                                            
                                            print("[STEP 3] Teleporting to gun...")
                                            rootPart.Position = targetPos
                                            print("[STEP 3] At gun location, waiting for touch...")
                                            
                                            task.wait(0.3)
                                            print("[STEP 4] Checking for gun acquisition...")
                                            
                                            -- Verify the gun was actually acquired
                                            local backpack = LocalPlayer:FindFirstChild("Backpack")
                                            local hasGun = false
                                            
                                            if backpack and backpack:FindFirstChild(gunName) then
                                                hasGun = true
                                            elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(gunName) then
                                                hasGun = true
                                            end
                                            
                                            if hasGun then
                                                print("[STEP 4] ✓ Gun acquired!")
                                            else
                                                print("[STEP 4] ✗ Gun NOT acquired - delivery failed")
                                            end
                                            
                                            print("[STEP 5] Teleporting back to original position...")
                                            rootPart.Position = originalPos
                                            
                                            if hasGun then
                                                SendNotification("Gun", "Got " .. gunName .. "!")
                                                print("\n✓ Got " .. gunName .. "!")
                                            else
                                                SendNotification("Gun", "Failed to get " .. gunName)
                                                print("\n✗ Failed to get " .. gunName)
                                            end
                                            print(string.rep("=", 80) .. "\n")
                                            found = true
                                            return
                                        end
                                    end
                                end
                            end
                            
                            -- Search workspace descendants if not found
                            if not found then
                                for _, part in ipairs(workspace:GetDescendants()) do
                                    if part.Name == "TouchGiver" then
                                        local toolName = part:GetAttribute("ToolName")
                                        if toolName == gunName then
                                            local touchPart = part:FindFirstChild("TouchGiver") or part
                                            if touchPart then
                                                print("[STEP 2] ✓ Found gun TouchGiver (descendants) at: " .. tostring(touchPart.Position))
                                                
                                                local targetPos = touchPart.Position
                                                
                                                print("[STEP 3] Teleporting to gun...")
                                                rootPart.Position = targetPos
                                                print("[STEP 3] At gun location, waiting for touch...")
                                                
                                                task.wait(0.3)
                                                print("[STEP 4] Checking for gun acquisition...")
                                                
                                                -- Verify the gun was actually acquired
                                                local backpack = LocalPlayer:FindFirstChild("Backpack")
                                                local hasGun = false
                                                
                                                if backpack and backpack:FindFirstChild(gunName) then
                                                    hasGun = true
                                                elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(gunName) then
                                                    hasGun = true
                                                end
                                                
                                                if hasGun then
                                                    print("[STEP 4] ✓ Gun acquired!")
                                                else
                                                    print("[STEP 4] ✗ Gun NOT acquired - delivery failed")
                                                end
                                                
                                                print("[STEP 5] Teleporting back to original position...")
                                                rootPart.Position = originalPos
                                                
                                                if hasGun then
                                                    SendNotification("Gun", "Got " .. gunName .. "!")
                                                    print("\n✓ Got " .. gunName .. "!")
                                                else
                                                    SendNotification("Gun", "Failed to get " .. gunName)
                                                    print("\n✗ Failed to get " .. gunName)
                                                end
                                                print(string.rep("=", 80) .. "\n")
                                                found = true
                                                return
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end)
                end
            })
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SECTION 6: SETTINGS TAB
-- ═══════════════════════════════════════════════════════════════

print("Creating Settings Tab...")
print("Window type: " .. type(Window))
print("Window.AddTab type: " .. type(Window.AddTab))

local SettingsTab
local success, err = pcall(function()
    if not Window or type(Window) ~= "table" then
        error("Window is not a valid table")
    end
    if not Window.AddTab or type(Window.AddTab) ~= "function" then
        error("Window.AddTab is not a function")
    end
    
    SettingsTab = Window:AddTab({ Name = "Settings" })
    print("Settings Tab created successfully")
end)

if not success then
    print("Error creating Settings Tab:")
    print("  " .. tostring(err))
    print("Skipping Settings Tab...")
    SettingsTab = nil
    return
end

if not SettingsTab then
    print("Settings Tab is nil - skipping Settings UI initialization")
else
    local SettingsContainer
    pcall(function()
        SettingsContainer = SettingsTab:AddContainer({ Name = "Menu Settings", Side = "Left", AutoSize = true })
    end)
    
    if SettingsContainer then
        -- Only add basic buttons, skip special methods
        pcall(function()
            SettingsContainer:AddButton({
                Name = "Reset Position",
                Callback = function()
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local cafePos = TeleportLocations["Cafeteria"]
                        if typeof(cafePos) == "Vector3" then
                            cafePos = vector.create(cafePos.X, cafePos.Y, cafePos.Z)
                        end
                        LocalPlayer.Character.HumanoidRootPart.Position = cafePos
                        SendNotification("Reset", "Position reset to Cafeteria")
                    end
                end
            })
        end)

        pcall(function()
            SettingsContainer:AddButton({
                Name = "Refresh Script",
                Callback = function()
                    print("[REFRESH] Reloading UI...")
                    SendNotification("Refresh", "Script refreshed!")
                    print("[REFRESH] ✓ Script refreshed successfully")
                end
            })
        end)

        pcall(function()
            SettingsContainer:AddButton({
                Name = "Unload Script",
                Unsafe = true,
                Callback = function()
                    Library:Unload()
                    print("Script unloaded!")
                end
            })
        end)
    end

    SettingsContainer:AddMenuBind({})
    SettingsContainer:AddWatermark({
    Watermark = "Prison Life ! | Severe | Build: 2.6.1",
    ShowFPS = true
})

-- SCRIPT BEHAVIOR SETTINGS
    local BehaviorContainer
    pcall(function()
        BehaviorContainer = SettingsTab:AddContainer({ Name = "Script Behavior", Side = "Left", AutoSize = true })
    end)

    if BehaviorContainer then
        pcall(function()
            BehaviorContainer:AddToggle({
                Name = "Auto-Apply Mods on Equip",
                Value = AutoApplyMods,
                Callback = function(Value)
                    AutoApplyMods = Value
                    local msg = Value and "Auto-apply ENABLED (will apply mods to equipped weapons)" or "Auto-apply disabled"
                    print(msg)
                    SendNotification("Auto-Apply", msg)
                end
            })
        end)

        pcall(function()
            BehaviorContainer:AddSeparator()
        end)
        
        pcall(function()
            BehaviorContainer:AddLabel({ Name = "Data Management" })
        end)

        pcall(function()
            BehaviorContainer:AddButton({
                Name = "Reset All Weapon Stats",
                Callback = function()
                    OriginalWeaponStats = {}
                    WeaponModToggles = {}
                    WeaponModSliders = {}
                    WeaponContainersCreated = {}
                    print("All weapon stats reset!")
                    print("Refresh weapons list to reload")
                    SendNotification("Reset", "All weapon stats cleared!")
                end
            })
        end)
    end



    -- PERFORMANCE SETTINGS
    local PerformanceContainer
    pcall(function()
        PerformanceContainer = SettingsTab:AddContainer({ Name = "Performance", Side = "Right", AutoSize = true })
    end)

    if PerformanceContainer then
        pcall(function()
            PerformanceContainer:AddToggle({
                Name = "Gun Mods Patching Loop",
                Value = GunModsLoopEnabled,
                Callback = function(Value)
                    GunModsLoopEnabled = Value
                    local msg = Value and "Gun Mods loop enabled" or "Gun Mods loop disabled"
                    print(msg)
                    SendNotification("Performance", msg)
                end
            })
        end)

        pcall(function()
            PerformanceContainer:AddLabel({ Name = "Note: Disabling patching loop saves" })
        end)
        
        pcall(function()
            PerformanceContainer:AddLabel({ Name = "CPU but mods may not stay active." })
        end)

        pcall(function()
            PerformanceContainer:AddSeparator()
        end)

        pcall(function()
            PerformanceContainer:AddToggle({
                Name = "Teleport Cooldown",
                Value = TeleportCooldownEnabled,
                Callback = function(Value)
                    TeleportCooldownEnabled = Value
                    local msg = Value and "Teleport cooldown enabled (1s between TPs)" or "Teleport cooldown disabled"
                    print(msg)
                    SendNotification("Teleport", msg)
                end
            })
        end)
    end




    -- ANTI-KICK SETTINGS
    local AntiKickContainer
    pcall(function()
        AntiKickContainer = SettingsTab:AddContainer({ Name = "Anti-Kick(slightly works)", Side = "Left", AutoSize = true })
    end)

    if AntiKickContainer then
        pcall(function()
            AntiKickContainer:AddLabel({ Name = "Protection" })
        end)

        pcall(function()
            AntiKickContainer:AddToggle({
                Name = "Block Kick Attempts",
                Value = AntiKickEnabled,
                Callback = function(Value)
                    AntiKickEnabled = Value
                    local msg = Value and "Anti-Kick enabled" or "Anti-Kick disabled"
                    print(msg)
                    SendNotification("Anti-Kick", msg)
                end
            })
        end)

        pcall(function()
            AntiKickContainer:AddToggle({
                Name = "Prevent AFK Kick",
                Value = AntiAFKEnabled,
                Callback = function(Value)
                    AntiAFKEnabled = Value
                    local msg = Value and "Anti-AFK enabled (simulates activity)" or "Anti-AFK disabled"
                    print(msg)
                    SendNotification("Anti-AFK", msg)
                end
            })
        end)

        pcall(function()
            AntiKickContainer:AddSeparator()
        end)

        pcall(function()
            AntiKickContainer:AddButton({
                Name = "Reset Kick Counter",
                Callback = function()
                    KickBlockedCount = 0
                    print("Kick counter reset: 0")
                    SendNotification("Anti-Kick", "Counter reset")
                end
            })
        end)

        pcall(function()
            AntiKickContainer:AddLabel({ Name = "Kicks Blocked: " .. tostring(KickBlockedCount) })
        end)
    end

    print("Settings Tab fully initialized!")
end

print("Prison Life Script loaded successfully!")
print("Press RightShift to toggle the menu")

