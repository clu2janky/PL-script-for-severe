--[[ 
    PRISON LIFE EXPLOIT SCRIPT
    Built with Pseudosynonym UI Library & Severe's API
]]

-- ═══════════════════════════════════════════════════════════════
-- SECTION 1: LIBRARY INITIALIZATION
-- ═══════════════════════════════════════════════════════════════

-- Load the UI Library
local Bytecode, Load, Library

pcall(function()
    print("Fetching Pseudosynonym library...)")
    Bytecode = game:HttpGet("https://raw.githubusercontent.com/DCHARLESAKAMRGREEN/Severe-Luas/main/Libraries/Pseudosynonym.lua")
    local byteLen = string.len(Bytecode)
    print("Library bytecode fetched (" .. tostring(byteLen) .. " bytes)")
end)

if not Bytecode then
    print("Failed to fetch library bytecode!")
    return
end

local success, err = pcall(function()
    print("Loading bytecode with luau.load...)")
    Load = luau.load(Bytecode)
    print("Bytecode loaded, load function type: " .. type(Load))
    
    print("Executing library initialization...)")
    Library = Load()
    print("Library initialized, type: " .. type(Library))
end)

if not success then
    print("Error loading library:")
    print("  " .. tostring(err))
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
    
    print("Creating main window...)")
    Window = Library:CreateWindow({
        Title = "Prison Life @jankyclu",
        Tag = "v1.0.5",
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
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Weapon Configuration Table - DEFINED EARLY FOR USE IN CALLBACKS
local OriginalWeaponStats = {}
local WeaponModSettings = {}
local AvailableWeapons = {}

-- Settings variables (defined early so callbacks can use them)
local VerboseLogging = true
local AutoApplyMods = false
local NotificationsEnabled = true
local NotificationDuration = 3
local GunModsLoopEnabled = true

-- Notification function
local function SendNotification(title, message)
    if not NotificationsEnabled then return end
    
    pcall(function()
        -- Try to use the library's notification system if available
        if Library and Library.Notify then
            Library:Notify({
                Title = title,
                Description = message,
                Duration = NotificationDuration
            })
        else
            -- Fallback to console
            print("[" .. title .. "] " .. message)
        end
    end)
end

-- UI Element references (defined early)
local NoRecoilToggle, NoSpreadToggle, RapidFireToggle, RapidFireSpeed, DamageMultiplier, SpreadReduction, InfiniteAmmoToggle



-- Store Prison Life relevant data
local TeleportLocations = {
    ["Cafeteria"] = Vector3.new(921, 99, 2283),
    ["Yard"] = Vector3.new(716, 97, 2469),
    ["Cells"] = Vector3.new(900, 114, 2497),
    ["Guard Tower"] = Vector3.new(822, 125, 2585),
    ["Armory"] = Vector3.new(819, 99, 2232),
    ["Roof"] = Vector3.new(957, 131, 2231),
    ["Police Station"] = Vector3.new(692, 99, 2244),
    ["City/car"] = Vector3.new(-192, 54, 1881),
    ["Crim Base"] = Vector3.new(-975, 108, 2044),
    ["Jail Entrance"] = Vector3.new(503, 102, 2246)
}

-- ═══════════════════════════════════════════════════════════════
-- SECTION 4: TELEPORT TAB
-- ═══════════════════════════════════════════════════════════════

local TeleportTab = Window:AddTab({ Name = "Teleport" })

local TeleportContainer = TeleportTab:AddContainer({ Name = "Locations", Side = "Left", AutoSize = true })

TeleportContainer:AddLabel({ Name = "Quick Teleport" })
TeleportContainer:AddSeparator()

for locationName, locationPos in pairs(TeleportLocations) do
    TeleportContainer:AddButton({
        Name = "TP to " .. locationName,
        Callback = function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(locationPos)
                print("Teleported to " .. locationName)
            end
        end
    })
end

-- Custom Teleport
local CustomTPContainer = TeleportTab:AddContainer({ Name = "Custom TP", Side = "Right", AutoSize = true })

local XInput = CustomTPContainer:AddInput({ Name = "X", Text = "0" })
local YInput = CustomTPContainer:AddInput({ Name = "Y", Text = "0" })
local ZInput = CustomTPContainer:AddInput({ Name = "Z", Text = "0" })

CustomTPContainer:AddButton({
    Name = "Teleport to Custom Position",
    Callback = function()
        local x = tonumber(XInput.Text or "0") or 0
        local y = tonumber(YInput.Text or "0") or 0
        local z = tonumber(ZInput.Text or "0") or 0
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
            print("Teleported to " .. tostring(Vector3.new(x, y, z)))
        end
    end
})

CustomTPContainer:AddButton({
    Name = "Copy Current Position",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            if hrp and hrp.Position then
                local pos = hrp.Position
                if typeof(pos) == "Vector3" then
                    local posStr = tostring(Vector3.new(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z)))
                    print("Position: " .. posStr)
                else
                    print("Position is not a Vector3")
                end
            end
        end
    end
})

CustomTPContainer:AddLabel({ Name = "Look in console for copied pos" })

-- ═══════════════════════════════════════════════════════════════
-- SECTION 5: GUN MODS TAB & FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

local GunModsTab = Window:AddTab({ Name = "Gun Mods" })

-- Per-weapon mod settings
local WeaponModToggles = {}  -- WeaponModToggles[weaponName] = {NoRecoil, NoSpread, RapidFire, InfiniteAmmo}
local WeaponModSliders = {}  -- WeaponModSliders[weaponName] = {RapidFireSpeed, DamageMultiplier, SpreadReduction}
local WeaponContainersCreated = {}  -- Track which weapon containers have been created to avoid duplicates

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
local ControlContainer = GunModsTab:AddContainer({ Name = "Controls", Side = "Left", AutoSize = true })
ControlContainer:AddLabel({ Name = "Info & Debug" })
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
ControlContainer:AddSeparator()
ControlContainer:AddLabel({ Name = "Auto-loads when u equip weapons" })



-- Dynamic weapon loading loop
task.spawn(function()
    local lastWeapons = {}
    
    while true do
        task.wait(1)
        
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
        
        -- Check for new weapons only
        for _, weaponName in ipairs(currentWeapons) do
            if not table.find(lastWeapons, weaponName) and not WeaponContainersCreated[weaponName] then
                -- New weapon detected, create container only for this one
                pcall(function()
                    -- Skip non-gun tools
                    if weaponName == "Handcuffs" or weaponName == "Taser" or weaponName == "Riot Shield" then
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
                    if not weaponContainer then
                        print("Failed to create container for " .. weaponName)
                        return
                    end
                    WeaponContainersCreated[weaponName] = true
                    
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

-- ═══════════════════════════════════════════════════════════════
-- SECTION 6: SETTINGS TAB
-- ═══════════════════════════════════════════════════════════════

print("Creating Settings Tab...")

local SettingsTab
local success, err = pcall(function()
    SettingsTab = Window:AddTab({ Name = "Settings" })
    print("Settings Tab created successfully")
end)

if not success then
    print("Error creating Settings Tab:")
    print("  " .. tostring(err))
end

if not SettingsTab then
    print("Settings Tab is nil!")
else
    local SettingsContainer = SettingsTab:AddContainer({ Name = "Menu", Side = "Left", AutoSize = true })

SettingsContainer:AddMenuBind({})
SettingsContainer:AddSeparator()

pcall(function()
    SettingsContainer:AddWatermark({
        Watermark = "PrisonLife | " .. LocalPlayer.Name,
        ShowFPS = true
    })
end)

pcall(function()
    SettingsContainer:AddKeybindList({})
end)

SettingsContainer:AddButton({
    Name = "Reset Position",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(TeleportLocations["Cafeteria"])
            SendNotification("Reset", "Position reset to Cafeteria")
        end
    end
})

SettingsContainer:AddButton({
    Name = "Unload Script",
    Unsafe = true,
    Callback = function()
        Library:Unload()
        print("Script unloaded!")
    end
})

SettingsContainer:AddSeparator()

-- UI & DISPLAY SETTINGS
local UIDisplayContainer = SettingsTab:AddContainer({ Name = "UI & Display", Side = "Right", AutoSize = true })

UIDisplayContainer:AddLabel({ Name = "Display Options" })

local WatermarkEnabled = false
UIDisplayContainer:AddToggle({
    Name = "Show Watermark",
    Value = false,
    Callback = function(Value)
        WatermarkEnabled = Value
        print(Value and "Watermark enabled" or "Watermark disabled")
    end
})

local FPSEnabled = false
UIDisplayContainer:AddToggle({
    Name = "Show FPS Counter",
    Value = false,
    Callback = function(Value)
        FPSEnabled = Value
        print(Value and "FPS counter enabled" or "FPS counter disabled")
    end
})

UIDisplayContainer:AddSeparator()

-- SCRIPT BEHAVIOR SETTINGS
local BehaviorContainer = SettingsTab:AddContainer({ Name = "Script Behavior", Side = "Left", AutoSize = true })

BehaviorContainer:AddLabel({ Name = "Logging & Behavior" })

BehaviorContainer:AddToggle({
    Name = "Auto-Apply Mods on Equip",
    Value = false,
    Callback = function(Value)
        AutoApplyMods = Value
        local msg = Value and "Auto-apply ENABLED (will apply mods to equipped weapons)" or "Auto-apply disabled"
        print(msg)
        SendNotification("Auto-Apply", msg)
    end
})

BehaviorContainer:AddSeparator()
BehaviorContainer:AddLabel({ Name = "Data Management" })

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

BehaviorContainer:AddSeparator()

-- PERFORMANCE SETTINGS
local PerformanceContainer = SettingsTab:AddContainer({ Name = "Performance", Side = "Right", AutoSize = true })

PerformanceContainer:AddLabel({ Name = "Optimization" })

PerformanceContainer:AddToggle({
    Name = "Gun Mods Patching Loop",
    Value = false,
    Callback = function(Value)
        GunModsLoopEnabled = Value
        local msg = Value and "Gun Mods loop enabled" or "Gun Mods loop disabled (mods won't persist)"
        print(msg)
        SendNotification("Performance", msg)
    end
})

PerformanceContainer:AddLabel({ Name = "Note: Disabling patching loop saves" })
PerformanceContainer:AddLabel({ Name = "CPU but mods may not stay active." })

PerformanceContainer:AddSeparator()

-- NOTIFICATIONS SETTINGS
local NotificationsContainer = SettingsTab:AddContainer({ Name = "Notifications", Side = "Left", AutoSize = true })

NotificationsContainer:AddLabel({ Name = "Notification Options" })

NotificationsContainer:AddToggle({
    Name = "Enable Notifications",
    Value = false,
    Callback = function(Value)
        NotificationsEnabled = Value
        print(Value and "Notifications enabled" or "Notifications disabled")
    end
})

NotificationsContainer:AddSlider({
    Name = "Notification Duration (sec)",
    Min = 1,
    Max = 10,
    Default = 3,
    Rounding = 1,
    Callback = function(Value)
        NotificationDuration = Value
        print("Notification duration: " .. tostring(Value) .. "s")
    end
})

NotificationsContainer:AddSeparator()

    print("Settings Tab fully initialized!")
end

print("Prison Life Script loaded successfully!")
print("Press RightShift to toggle the menu")
